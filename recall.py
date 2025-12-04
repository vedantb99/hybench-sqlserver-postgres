import pyodbc
import time
import pandas as pd
import random

# --- Configuration ---
SERVER = "localhost"
DATABASE = "index_hybench_100k" # <--- The script ensures we use this DB
OUTPUT_FILE = "recall_results.csv"
K_VALUES = [10, 20, 30, 50, 100, 200]
# ---------------------

conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"

def get_vectors(cursor):
    """Fetches 2 random vectors to use for queries."""
    print("Fetching random query vectors...", end=" ")
    cursor.execute("SELECT TOP 2 CAST(text_embedding AS VARCHAR(MAX)) FROM dbo.text ORDER BY NEWID()")
    rows = cursor.fetchall()
    print("Done.")
    return rows[0][0], rows[1][0]

def get_page_vector(cursor):
    """Fetches 1 random page vector for NQ11."""
    cursor.execute("SELECT TOP 1 CAST(page_embedding AS VARCHAR(MAX)) FROM dbo.page ORDER BY NEWID()")
    return cursor.fetchone()[0]

def calculate_recall(gt_ids, idx_ids):
    if not gt_ids: return 0.0
    overlap = len(gt_ids.intersection(idx_ids))
    return (overlap / len(gt_ids)) * 100.0

def run_benchmark():
    conn = pyodbc.connect(conn_str)
    conn.autocommit = True
    cursor = conn.cursor()
    
    # 1. Enable Preview Features
    try:
        print("Enabling Preview Features...", end=" ")
        cursor.execute("ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;")
        print("Done.")
    except:
        print("Already enabled or failed (ignoring).")

    # 2. Get Query Vectors
    vec_text_1, vec_text_2 = get_vectors(cursor)
    vec_page = get_page_vector(cursor)

    results = []

    for k in K_VALUES[:1]:
        print(f"\n=== Benchmarking K={k} ===")
        
        # --- QUERY DICTIONARY (Updated with Quotes & Fixes) ---
        queries = [
            # --- Q1: Standard k-NN ---
            {
                "name": "Q1",
                "gt": f"SELECT TOP {k} old_id FROM dbo.text ORDER BY VECTOR_DISTANCE('cosine', CAST('{vec_text_1}' AS VECTOR(384)), text_embedding) ASC",
                "idx": f"SELECT old_id FROM VECTOR_SEARCH(TABLE=dbo.text, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_1}' AS VECTOR(384)), METRIC='cosine', TOP_N={k})"
            },
            
            # --- NQ11: Aggregation on Page k-NN ---
            {
                "name": "NQ11",
                "gt": f"SELECT TOP {k} page_id FROM dbo.page ORDER BY VECTOR_DISTANCE('cosine', CAST('{vec_page}' AS VECTOR(384)), page_embedding) ASC",
                "idx": f"SELECT page_id FROM VECTOR_SEARCH(TABLE=dbo.page, COLUMN=page_embedding, SIMILAR_TO=CAST('{vec_page}' AS VECTOR(384)), METRIC='cosine', TOP_N={k})"
            },

            # --- NQ13: Aggregation on Text k-NN ---
            {
                "name": "NQ13",
                "gt": f"SELECT TOP {k} old_id FROM dbo.text ORDER BY VECTOR_DISTANCE('cosine', CAST('{vec_text_1}' AS VECTOR(384)), text_embedding) ASC",
                "idx": f"SELECT old_id FROM VECTOR_SEARCH(TABLE=dbo.text, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_1}' AS VECTOR(384)), METRIC='cosine', TOP_N={k})"
            },

            # --- NQ16: Multi-Target (Union) ---
            {
                "name": "NQ16",
                "gt": f"""
                    SELECT TOP {k} old_id FROM dbo.text 
                    ORDER BY LEAST(
                        VECTOR_DISTANCE('cosine', CAST('{vec_text_1}' AS VECTOR(384)), text_embedding),
                        VECTOR_DISTANCE('cosine', CAST('{vec_text_2}' AS VECTOR(384)), text_embedding)
                    ) ASC
                """,
                "idx": f"""
                    SELECT TOP {k} t.old_id FROM (
                        SELECT old_id, distance FROM VECTOR_SEARCH(TABLE=dbo.text, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_1}' AS VECTOR(384)), METRIC='cosine', TOP_N={k})
                        UNION ALL
                        SELECT old_id, distance FROM VECTOR_SEARCH(TABLE=dbo.text, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_2}' AS VECTOR(384)), METRIC='cosine', TOP_N={k})
                    ) t ORDER BY t.distance ASC
                """
            },

            # --- NQ18: Exclusion ---
            {
                "name": "NQ18",
                "gt": f"""
                    SELECT TOP {k} old_id FROM dbo.text 
                    WHERE old_id NOT IN (
                        SELECT TOP {k} old_id FROM dbo.text ORDER BY VECTOR_DISTANCE('cosine', CAST('{vec_text_2}' AS VECTOR(384)), text_embedding) ASC
                    )
                    ORDER BY VECTOR_DISTANCE('cosine', CAST('{vec_text_1}' AS VECTOR(384)), text_embedding) ASC
                """,
                "idx": f"""
                    SELECT TOP {k} t.old_id FROM VECTOR_SEARCH(TABLE=dbo.text AS t, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_1}' AS VECTOR(384)), METRIC='cosine', TOP_N={k*2}) s
                    WHERE t.old_id NOT IN (
                        SELECT t2.old_id FROM VECTOR_SEARCH(TABLE=dbo.text AS t2, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_2}' AS VECTOR(384)), METRIC='cosine', TOP_N={k}) s2
                    )
                    ORDER BY s.distance ASC
                """
            },

            # --- IQ1: Pagination ---
            # Logic: Fetch the LAST 10 items ending at rank K
            {
                "name": "IQ1",
                "gt": f"""
                    SELECT old_id FROM dbo.text 
                    ORDER BY VECTOR_DISTANCE('cosine', CAST('{vec_text_1}' AS VECTOR(384)), text_embedding) ASC
                    OFFSET {k-10 if k>=10 else 0} ROWS FETCH NEXT 10 ROWS ONLY
                """,
                "idx": f"""
                    SELECT t.old_id FROM VECTOR_SEARCH(TABLE=dbo.text AS t, COLUMN=text_embedding, SIMILAR_TO=CAST('{vec_text_1}' AS VECTOR(384)), METRIC='cosine', TOP_N={k}) s
                    ORDER BY s.distance ASC, t.old_id ASC
                    OFFSET {k-10 if k>=10 else 0} ROWS FETCH NEXT 10 ROWS ONLY
                """
            }
        ]

        for q in queries[:1]:
            print(f"Running {q['name']}...", end=" ", flush=True)
            
            try:
                # 1. Ground Truth
                t0 = time.time()
                cursor.execute(q['gt'])
                gt_ids = set(row[0] for row in cursor.fetchall())
                gt_ms = (time.time() - t0) * 1000

                # 2. Index Search
                t0 = time.time()
                cursor.execute(q['idx'])
                idx_ids = set(row[0] for row in cursor.fetchall())
                idx_ms = (time.time() - t0) * 1000

                # 3. Calculate Stats
                recall = calculate_recall(gt_ids, idx_ids)
                accel = gt_ms / idx_ms if idx_ms > 0 else 0

                print(f"Recall: {recall:.1f}%, Accel: {accel:.1f}x")

                results.append({
                    "Query": q['name'],
                    "K": k,
                    "Recall_Pct": round(recall, 2),
                    "Index_Latency_MS": round(idx_ms, 2),
                    "Exact_Latency_MS": round(gt_ms, 2),
                    "Acceleration": round(accel, 2)
                })

            except Exception as e:
                print("FAILED.")
                print(f"  Error: {e}")

    # Save Results
    pd.DataFrame(results).to_csv(OUTPUT_FILE, index=False)
    print(f"\nDone! Results saved to {OUTPUT_FILE}")
    conn.close()

if __name__ == "__main__":
    run_benchmark()