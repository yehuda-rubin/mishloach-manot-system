"""
ETL Script for Outer Orders CSV Files
מערכת ETL לקבצי הזמנות חיצוניות
"""

import pandas as pd
import psycopg2
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import Config


# Rating to package_size mapping
RATING_MAP = {
    1: 'סמלי',
    2: 'מכובד',
    3: 'מפואר',
    '1': 'סמלי',
    '2': 'מכובד',
    '3': 'מפואר'
}


def load_orders_file(filepath):
    """Load orders from CSV or Excel file"""
    if filepath.endswith('.csv'):
        df = pd.read_csv(filepath, encoding='utf-8-sig')
    else:
        df = pd.read_excel(filepath)
    
    # Clean column names
    df.columns = df.columns.str.strip()
    
    return df


def insert_orders(conn, df):
    """Insert orders into outerapporder table"""
    cur = conn.cursor()
    
    rows_inserted = 0
    for _, row in df.iterrows():
        try:
            # Extract sender_code (order_code)
            sender_code = str(row.get('order_code', ''))
            
            # Extract invitees (guest_list)
            invitees = str(row.get('guest_list', ''))
            
            # Map rating to package_size
            rating = row.get('rating')
            package_size = RATING_MAP.get(rating, RATING_MAP.get(str(rating), 'סמלי'))
            
            cur.execute("""
                INSERT INTO outerapporder 
                (sender_code, invitees, package_size, origin, created_at, status)
                VALUES (%s, %s, %s, %s, NOW(), 'waiting')
            """, (
                sender_code,
                invitees,
                package_size,
                'external_app'
            ))
            
            rows_inserted += 1
            
        except Exception as e:
            print(f"Error inserting order: {e}")
            continue
    
    conn.commit()
    cur.close()
    
    return rows_inserted


def distribute_orders(conn):
    """Run distribute_all_outer_orders function"""
    cur = conn.cursor()
    
    try:
        print("Distributing orders...")
        cur.execute("SELECT distribute_all_outer_orders()")
        result = cur.fetchone()
        distributed = result[0] if result else 0
        conn.commit()
        
        return distributed
        
    except Exception as e:
        conn.rollback()
        print(f"Error distributing orders: {e}")
        raise
    finally:
        cur.close()


def get_distribution_stats(conn):
    """Get distribution statistics"""
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            status,
            COUNT(*) as count
        FROM outerapporder
        GROUP BY status
    """)
    
    stats = cur.fetchall()
    
    # Get error logs
    cur.execute("""
        SELECT 
            severity,
            reason_code,
            COUNT(*) as count
        FROM outerapporder_error_log
        GROUP BY severity, reason_code
        ORDER BY severity, reason_code
    """)
    
    errors = cur.fetchall()
    
    cur.close()
    
    return stats, errors


def main(filepath):
    """Main ETL process"""
    print(f"Starting ETL process for orders: {filepath}")
    
    # Load file
    print("Loading file...")
    df = load_orders_file(filepath)
    print(f"Loaded {len(df)} orders")
    
    # Connect to database
    print("Connecting to database...")
    conn = psycopg2.connect(Config.DATABASE_URL)
    
    try:
        # Insert orders
        print("Inserting orders...")
        rows_inserted = insert_orders(conn, df)
        print(f"Inserted {rows_inserted} orders")
        
        # Distribute orders
        distributed = distribute_orders(conn)
        print(f"Distributed {distributed} order items")
        
        # Get stats
        stats, errors = get_distribution_stats(conn)
        
        print("\nDistribution Statistics:")
        for status, count in stats:
            print(f"  {status}: {count}")
        
        if errors:
            print("\nErrors:")
            for severity, reason_code, count in errors:
                print(f"  {severity} - {reason_code}: {count}")
        
        print("\n✅ ETL process completed successfully!")
        
    except Exception as e:
        print(f"\n❌ ETL process failed: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python etl_outer_orders.py <filepath>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    main(filepath)
