import pyodbc
import pandas as pd
import json
import time

# --- Configuration ---
YOUR_SERVER_NAME = "localhost" 
DB_NAME = "index_hybench_100k" # <-- NEW DATABASE
DRIVER = "{ODBC Driver 17 for SQL Server}"
ROWS_TO_LOAD = 100000 # <-- NEW LIMIT
# ---------------------

conn_str = f"DRIVER={DRIVER};SERVER={YOUR_SERVER_NAME};DATABASE={DB_NAME};Trusted_Connection=yes;"

def process_page_table(conn):
    print("\n--- Processing Page Table (100k) ---")
    df_page = pd.read_sql(f"SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as rn FROM dbo.stage_page", conn).head(ROWS_TO_LOAD)
    df_extra = pd.read_sql(f"SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as rn FROM dbo.stage_page_extra", conn).head(ROWS_TO_LOAD)
    df_emb = pd.read_sql(f"SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as rn FROM dbo.stage_page_embedding", conn).head(ROWS_TO_LOAD)
    df = df_page.merge(df_extra, on="rn").merge(df_emb, on="rn")
    print(f"Preparing {len(df)} rows for high-speed insert...")
    data_to_insert = []
    for _, row in df.iterrows():
        page_title = row['page_title'] if pd.notna(row['page_title']) else ''
        page_touched = row['page_touched'] if pd.notna(row['page_touched']) else None
        page_len = int(row['page_len']) if pd.notna(row['page_len']) else 0
        data_to_insert.append((
            int(row['page_id']), page_title, 0, 0, page_touched,
            page_touched, None, page_len, row['embedding_json']
        ))
    sql_insert = "INSERT INTO dbo.page VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    cursor = conn.cursor()
    cursor.fast_executemany = True
    start_time = time.time()
    cursor.executemany(sql_insert, data_to_insert)
    conn.commit()
    print(f"--- Page table complete in {time.time() - start_time:.2f} seconds ---")

def process_text_table(conn):
    print("\n--- Processing Text Table (100k) ---")
    df_text = pd.read_sql(f"SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as rn FROM dbo.stage_text", conn).head(ROWS_TO_LOAD)
    df_emb = pd.read_sql(f"SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as rn FROM dbo.stage_text_embedding", conn).head(ROWS_TO_LOAD)
    df = df_text.merge(df_emb, on="rn")
    print(f"Preparing {len(df)} rows for high-speed insert...")
    data_to_insert = []
    for _, row in df.iterrows():
        text_content = row['old_text'] if pd.notna(row['old_text']) else ''
        data_to_insert.append((int(row['old_id']), text_content, 'utf-8', row['embedding_json']))
    sql_insert = "INSERT INTO dbo.text VALUES (?, ?, ?, ?)"
    cursor = conn.cursor()
    cursor.fast_executemany = True
    start_time = time.time()
    cursor.executemany(sql_insert, data_to_insert)
    conn.commit()
    print(f"--- Text table complete in {time.time() - start_time:.2f} seconds ---")

def process_revision_table(conn):
    print("\n--- Processing Revision Table (100k) ---")
    df_rev = pd.read_sql(f"SELECT * FROM dbo.stage_revision", conn).head(ROWS_TO_LOAD)
    print(f"Preparing {len(df_rev)} rows for high-speed insert...")
    data_to_insert = []
    for _, row in df_rev.iterrows():
        rev_timestamp = row['rev_timestamp'] if pd.notna(row['rev_timestamp']) else None
        rev_minor_edit = int(row['rev_minor_edit']) if pd.notna(row['rev_minor_edit']) else 0
        rev_actor = row['rev_actor'] if pd.notna(row['rev_actor']) else None
        data_to_insert.append((
            int(row['rev_id']), int(row['rev_page_id']), int(row['rev_id']),
            rev_timestamp, rev_minor_edit, rev_actor, None
        ))
    sql_insert = "INSERT INTO dbo.revision VALUES (?, ?, ?, ?, ?, ?, ?)"
    cursor = conn.cursor()
    cursor.fast_executemany = True
    start_time = time.time()
    cursor.executemany(sql_insert, data_to_insert)
    conn.commit()
    print(f"--- Revision table complete in {time.time() - start_time:.2f} seconds ---")

def cleanup(conn):
    print("\n--- Cleaning up all staging tables ---")
    cursor = conn.cursor()
    cursor.execute("DROP TABLE dbo.stage_page;")
    cursor.execute("DROP TABLE dbo.stage_page_extra;")
    cursor.execute("DROP TABLE dbo.stage_page_embedding;")
    cursor.execute("DROP TABLE dbo.stage_text;")
    cursor.execute("DROP TABLE dbo.stage_text_embedding;")
    cursor.execute("DROP TABLE dbo.stage_revision;")
    conn.commit()
    print("Cleanup complete.")

if __name__ == "__main__":
    try:
        conn = pyodbc.connect(conn_str)
        print(f"Successfully connected to {YOUR_SERVER_NAME} -> {DB_NAME}")
        process_page_table(conn)
        process_text_table(conn)
        process_revision_table(conn)
        cleanup(conn)
        print("\n--- ALL DATA (100k) LOADED SUCCESSFULLY! ---")
        conn.close()
    except Exception as e:
        print("\n--- AN ERROR OCCURRED ---")
        print(e)