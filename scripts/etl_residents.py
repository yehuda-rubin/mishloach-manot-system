"""
ETL Script for Residents CSV/Excel Files
מערכת ETL לקבצי תושבים
"""

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import Config


def load_residents_file(filepath):
    """Load residents from CSV or Excel file"""
    if filepath.endswith('.csv'):
        df = pd.read_csv(filepath, encoding='utf-8-sig')
    else:
        df = pd.read_excel(filepath)
    
    # Clean column names
    df.columns = df.columns.str.strip()
    
    return df


def clear_raw_table(conn):
    """Clear the raw_residents_csv table"""
    cur = conn.cursor()
    cur.execute("TRUNCATE TABLE raw_residents_csv RESTART IDENTITY")
    conn.commit()
    cur.close()


def insert_to_raw(conn, df):
    """Insert data into raw_residents_csv table"""
    cur = conn.cursor()
    
    rows_inserted = 0
    for _, row in df.iterrows():
        try:
            cur.execute("""
                INSERT INTO raw_residents_csv 
                (code, lastname, father_name, mother_name, streetname, 
                 buildingnumber, entrance, apartmentnumber, phone, mobile, 
                 mobile2, email, standing_order)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                str(row.get('code', '')),
                str(row.get('lastname', '')),
                str(row.get('father_name', '')),
                str(row.get('mother_name', '')),
                str(row.get('streetname', '')),
                str(row.get('buildingnumber', '')),
                str(row.get('entrance', '')),
                str(row.get('apartmentnumber', '')),
                str(row.get('phone', '')),
                str(row.get('mobile', '')),
                str(row.get('mobile2', '')),
                str(row.get('email', '')),
                int(row.get('standing_order', 0)) if pd.notna(row.get('standing_order')) else 0
            ))
            rows_inserted += 1
        except Exception as e:
            print(f"Error inserting row: {e}")
            continue
    
    conn.commit()
    cur.close()
    
    return rows_inserted


def run_etl_procedures(conn):
    """Run ETL procedures"""
    cur = conn.cursor()
    
    try:
        print("Running raw_to_temp_stage...")
        cur.execute("SELECT raw_to_temp_stage()")
        conn.commit()
        
        print("Running process_residents_csv...")
        cur.execute("SELECT process_residents_csv()")
        conn.commit()
        
        print("ETL procedures completed successfully!")
        
    except Exception as e:
        conn.rollback()
        print(f"Error running ETL procedures: {e}")
        raise
    finally:
        cur.close()


def get_processing_stats(conn):
    """Get statistics about the processing"""
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            status,
            COUNT(*) as count
        FROM temp_residents_csv
        GROUP BY status
    """)
    
    stats = cur.fetchall()
    cur.close()
    
    return stats


def main(filepath):
    """Main ETL process"""
    print(f"Starting ETL process for: {filepath}")
    
    # Load file
    print("Loading file...")
    df = load_residents_file(filepath)
    print(f"Loaded {len(df)} rows")
    
    # Connect to database
    print("Connecting to database...")
    conn = psycopg2.connect(Config.DATABASE_URL)
    
    try:
        # Clear raw table
        print("Clearing raw table...")
        clear_raw_table(conn)
        
        # Insert to raw table
        print("Inserting data to raw table...")
        rows_inserted = insert_to_raw(conn, df)
        print(f"Inserted {rows_inserted} rows")
        
        # Run ETL procedures
        run_etl_procedures(conn)
        
        # Get stats
        stats = get_processing_stats(conn)
        print("\nProcessing Statistics:")
        for status, count in stats:
            print(f"  {status}: {count}")
        
        print("\n✅ ETL process completed successfully!")
        
    except Exception as e:
        print(f"\n❌ ETL process failed: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python etl_residents.py <filepath>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    main(filepath)
