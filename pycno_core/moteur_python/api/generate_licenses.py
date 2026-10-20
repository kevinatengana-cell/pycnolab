import sqlite3
import random
import string

DB_PATH = "licenses.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_key TEXT UNIQUE NOT NULL,
            duration_days INTEGER NOT NULL,
            is_used INTEGER DEFAULT 0,
            used_by_hwid TEXT,
            activated_at TEXT
        )
    """)
    conn.commit()
    conn.close()

def generate_key(prefix="1M"):
    chars = string.ascii_uppercase + string.digits
    parts = [''.join(random.choices(chars, k=4)) for _ in range(3)]
    return f"{prefix}-" + "-".join(parts)

def bulk_generate(count=10, duration_days=30, prefix="1M"):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    keys = []
    for _ in range(count):
        k = generate_key(prefix)
        try:
            cursor.execute("INSERT INTO licenses (license_key, duration_days) VALUES (?, ?)", (k, duration_days))
            keys.append(k)
        except sqlite3.IntegrityError:
            pass
    conn.commit()
    conn.close()
    return keys

if __name__ == "__main__":
    print("=== Générateur de clés Pycnolab ===")
    m1_keys = bulk_generate(5, 30, "1M")
    print("\nClés 1 Mois (30 jours) :")
    for k in m1_keys:
        print(" -", k)
        
    y1_keys = bulk_generate(2, 365, "1Y")
    print("\nClés 1 An (365 jours) :")
    for k in y1_keys:
        print(" -", k)
