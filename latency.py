import pyodbc
import time
import pandas as pd
import re

# --- Configuration ---
SERVER = "localhost"
DATABASE = "index_hybench_100k"
INPUT_FILE = "non_indexed_queries.sql"
OUTPUT_FILE = "latency_results.csv"
DELIMITER = "-- ### NEXT QUERY ###" 
# ---------------------

conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"

def clean_sql(sql_text):
    """
    Removes SSMS-specific commands (GO) that break Python execution.
    """
    sql_text = re.sub(r'(?m)^\s*GO\s*$', '', sql_text, flags=re.IGNORECASE)
    return sql_text.strip()

def run_benchmarks():
    try:
        conn = pyodbc.connect(conn_str)
        
        # --- FIX: Enable Autocommit to allow Configuration changes ---
        conn.autocommit = True 
        
        cursor = conn.cursor()
        
        # 1. Enable Preview Features ONCE globally
        print("Enabling Preview Features...", end=" ")
        cursor.execute("ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;")
        print("Done.\n")
        
    except Exception as e:
        print(f"Connection Failed: {e}")
        return

    try:
        with open(INPUT_FILE, 'r') as f:
            raw_content = f.read()
    except FileNotFoundError:
        print(f"Error: Could not find file '{INPUT_FILE}'")
        return
    
    queries = raw_content.split(DELIMITER)
    results = []

    print(f"Found {len(queries)} queries to benchmark...")

    for i, raw_sql in enumerate(queries):
        sql = clean_sql(raw_sql)
        if not sql: continue

        print(f"Running Query {i+1}...", end=" ", flush=True)
        
        try:
            start_time = time.time()
            cursor.execute(sql)
            
            row_count = 0
            
            # Iterate through all result sets to handle variable assignments
            while True:
                if cursor.description: 
                    rows = cursor.fetchall()
                    row_count = len(rows)
                    break 
                
                if not cursor.nextset():
                    break

            end_time = time.time()
            duration_ms = (end_time - start_time) * 1000
            
            print(f"Done! ({duration_ms:.2f} ms, {row_count} rows)")
            
            results.append({
                "Query_ID": i + 1,
                "Latency_MS": round(duration_ms, 2),
                "Rows_Returned": row_count,
                "Status": "Success"
            })

        except Exception as e:
            print(f"FAILED.")
            print(f"  Error: {e}")
            results.append({
                "Query_ID": i + 1,
                "Latency_MS": 0,
                "Rows_Returned": 0,
                "Status": "Failed",
                "Error_Msg": str(e)[:200]
            })

    df = pd.DataFrame(results)
    df.to_csv(OUTPUT_FILE, index=False)
    print(f"\nBenchmark complete. Results saved to {OUTPUT_FILE}")
    conn.close()

if __name__ == "__main__":
    run_benchmarks()