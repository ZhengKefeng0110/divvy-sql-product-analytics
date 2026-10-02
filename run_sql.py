import sys
import duckdb

sql_file = sys.argv[1]

with open(sql_file, "r", encoding="utf-8") as file:
    query = file.read()

con = duckdb.connect("divvy.duckdb")

result = con.execute(query)

try:
    df = result.fetchdf()

    if len(df.columns) > 0:
        print(df)
    else:
        print("SQL executed successfully.")

except Exception:
    print("SQL executed successfully.")