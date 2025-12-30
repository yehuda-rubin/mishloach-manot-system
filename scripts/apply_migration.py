import psycopg2
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import Config

def apply_migration(filepath):
    print(f"Applying migration: {filepath}")
    conn = psycopg2.connect(Config.DATABASE_URL)
    cur = conn.cursor()
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            sql = f.read()
            
        cur.execute(sql)
        conn.commit()
        print("Migration applied successfully!")
        
    except Exception as e:
        conn.rollback()
        print(f"Error applying migration: {e}")
        raise
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python apply_migration.py <sql_file>")
        sys.exit(1)
        
    apply_migration(sys.argv[1])
