import psycopg2
import time
import glob
import csv
import os

# ---------------------------------------
# 1. PostgreSQL Connection Details
# ---------------------------------------
conn = psycopg2.connect(
    dbname="hybench_pg_200k",
    user="postgres",
    password="dbms",
    host="localhost",
    port=5432
)
cur = conn.cursor()

# ---------------------------------------
# 2. Prepare output
# ---------------------------------------
results = []
sql_files = sorted(glob.glob("*.sql"))

print("\nFound", len(sql_files), "SQL files.")
print("Running in alphabetical order:\n")

# ---------------------------------------
# 3. Run each .sql file
# ---------------------------------------
for file in sql_files:
    print(f"➡ Running {file} ...")
    query = open(file, "r", encoding="utf-8").read()

    start_time = time.time()

    row_count = 0  # default

    try:
        cur.execute(query)

        # Try to fetch rows if SELECT query
        try:
            rows = cur.fetchall()
            row_count = len(rows)
        except psycopg2.ProgrammingError:
            # Not a SELECT statement → ignore
            row_count = 0

        conn.commit()

    except Exception as e:
        print(f"❌ ERROR in {file}: {e}")
        conn.rollback()

    end_time = time.time()
    ms = round((end_time - start_time) * 1000, 3)

    print(f"   ✔ Completed in {ms} ms, Rows Returned = {row_count}")

    results.append([file, ms, row_count])

# ---------------------------------------
# 4. Save results to CSV
# ---------------------------------------
with open("latency_results.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["query_file", "latency_ms", "row_count"])
    writer.writerows(results)

print("\n===================================")
print(" ALL QUERIES COMPLETE!")
print(" Results saved to latency_results.csv")
print("===================================\n")
