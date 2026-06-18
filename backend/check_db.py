import sqlite3
conn = sqlite3.connect('mothers.db')
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
print("TABLES:", [r[0] for r in c.fetchall()])

for table in ['users', 'mothers', 'doctors', 'health_workers']:
    try:
        c.execute(f"SELECT * FROM {table} ORDER BY rowid DESC LIMIT 5")
        rows = c.fetchall()
        cols = [d[0] for d in c.description]
        print(f"\n--- {table} (last 5) ---")
        print("COLS:", cols)
        for r in rows:
            print(r)
    except Exception as e:
        print(f"{table}: {e}")

conn.close()
