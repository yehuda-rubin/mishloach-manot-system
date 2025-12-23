"""
Utility functions for Mishloach Manot System
"""
import psycopg2
from psycopg2.extras import RealDictCursor
from app.config import Config
import csv
import io

def get_db_connection():
    """Get database connection with RealDictCursor"""
    return psycopg2.connect(Config.DATABASE_URL, cursor_factory=RealDictCursor)


def execute_function(func_name, params=None):
    """Execute a PostgreSQL function"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        if params:
            placeholders = ', '.join(['%s'] * len(params))
            query = f"SELECT {func_name}({placeholders})"
            cur.execute(query, params)
        else:
            cur.execute(f"SELECT {func_name}()")
        
        result = cur.fetchone()
        conn.commit()
        return result
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cur.close()
        conn.close()


def get_table_data(table_name, limit=50, offset=0, search=None, order_by=None):
    """Get paginated table data"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        # Build query
        query = f'SELECT * FROM {table_name}'
        count_query = f'SELECT COUNT(*) as count FROM {table_name}'
        params = []
        
        # Add search if provided
        if search:
            # Get column names
            cur.execute(f"SELECT column_name FROM information_schema.columns WHERE table_name = %s", (table_name,))
            columns = [row['column_name'] for row in cur.fetchall()]
            
            # Build WHERE clause for text columns
            text_columns = []
            cur.execute(f"""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = %s 
                AND data_type IN ('text', 'character varying', 'character')
            """, (table_name,))
            text_columns = [row['column_name'] for row in cur.fetchall()]
            
            if text_columns:
                where_clause = ' OR '.join([f"{col}::text ILIKE %s" for col in text_columns])
                query += f" WHERE {where_clause}"
                count_query += f" WHERE {where_clause}"
                params = [f"%{search}%"] * len(text_columns)
        
        # Add order by
        if order_by:
            query += f" ORDER BY {order_by}"
        
        # Add pagination
        query += " LIMIT %s OFFSET %s"
        
        # Get total count
        if params:
            cur.execute(count_query, params)
        else:
            cur.execute(count_query)
        total = cur.fetchone()['count']
        
        # Get data
        cur.execute(query, params + [limit, offset])
        data = cur.fetchall()
        
        return {
            'data': data,
            'total': total,
            'limit': limit,
            'offset': offset
        }
    finally:
        cur.close()
        conn.close()


def get_view_data(view_name, limit=None):
    """Get data from a view"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        if limit:
            cur.execute(f"SELECT * FROM {view_name} LIMIT %s", (limit,))
        else:
            cur.execute(f"SELECT * FROM {view_name}")
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()


def export_to_csv(data, columns):
    """Export data to CSV format"""
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=columns)
    writer.writeheader()
    writer.writerows(data)
    return output.getvalue()


def get_function_parameters(func_name):
    """Get parameters for a PostgreSQL function"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("""
            SELECT 
                p.parameter_name,
                p.data_type,
                p.parameter_default
            FROM information_schema.parameters p
            WHERE p.specific_schema = 'public'
            AND p.specific_name IN (
                SELECT specific_name 
                FROM information_schema.routines 
                WHERE routine_name = %s
                AND routine_schema = 'public'
            )
            AND p.parameter_mode = 'IN'
            ORDER BY p.ordinal_position
        """, (func_name,))
        
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()


def get_all_functions():
    """Get list of all public functions"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("""
            SELECT routine_name as name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
            AND routine_type = 'FUNCTION'
            ORDER BY routine_name
        """)
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()


def get_all_views():
    """Get list of all views"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("""
            SELECT table_name as name
            FROM information_schema.views
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()


def get_all_tables():
    """Get list of all tables"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("""
            SELECT table_name as name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()
