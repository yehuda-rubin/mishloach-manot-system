"""
Import Orders from CSV
ייבוא הזמנות מקובץ CSV

This module handles importing orders from a CSV file containing:
- order_code: sender's person code
- guest_list: pipe-separated list of receiver codes (e.g., "270|364|849|387")
"""

import pandas as pd
from datetime import datetime


def import_orders_from_csv(file, conn):
    """
    Import orders from CSV file
    
    Args:
        file: uploaded file object
        conn: database connection
    
    Returns:
        dict: statistics about the import
    """
    # Read CSV
    if file.filename.endswith('.csv'):
        df = pd.read_csv(file, encoding='utf-8-sig')
    else:
        df = pd.read_excel(file)
    
    # Clean column names
    df.columns = df.columns.str.strip()
    
    # Required columns
    required_cols = ['order_code', 'guest_list']
    missing_cols = [col for col in required_cols if col not in [c.lower() for c in df.columns]]
    
    if missing_cols:
        raise ValueError(f"חסרות עמודות חובה: {', '.join(missing_cols)}")
    
    # Normalize column names
    column_mapping = {
        'order_code': 'order_code',
        'guest_list': 'guest_list',
        'created_at': 'created_at',
        'rating': 'rating',
        'total_amount': 'total_amount',
        'payment_method': 'payment_method',
    }
    
    new_column_names = []
    for orig_col in df.columns:
        mapped_col = column_mapping.get(orig_col.strip().lower(), orig_col)
        new_column_names.append(mapped_col)
    
    df.columns = new_column_names
    
    # Statistics
    stats = {
        'total_orders': 0,
        'total_pairs': 0,
        'successful_pairs': 0,
        'failed_pairs': 0,
        'missing_senders': [],
        'missing_receivers': []
    }
    
    cur = conn.cursor()
    
    # Get all person codes for validation
    cur.execute("SELECT code FROM person")
    valid_codes = {row[0] for row in cur.fetchall()}
    
    # Process each order
    for _, row in df.iterrows():
        order_code = str(row.get('order_code', '')).strip()
        guest_list = str(row.get('guest_list', '')).strip()
        
        if not order_code or not guest_list:
            continue
        
        stats['total_orders'] += 1
        
        # Check if sender exists
        try:
            sender_code = int(order_code)
        except (ValueError, TypeError):
            continue
        
        if sender_code not in valid_codes:
            if sender_code not in stats['missing_senders']:
                stats['missing_senders'].append(sender_code)
            continue
        
        # Get sender's personid
        cur.execute("SELECT personid FROM person WHERE code = %s", (sender_code,))
        sender_result = cur.fetchone()
        
        if not sender_result:
            if sender_code not in stats['missing_senders']:
                stats['missing_senders'].append(sender_code)
            continue
        
        sender_id = sender_result[0]
        
        # Parse guest list
        guest_codes = [g.strip() for g in guest_list.split('|') if g.strip()]
        
        for guest_code in guest_codes:
            try:
                receiver_code = int(guest_code)
            except (ValueError, TypeError):
                stats['failed_pairs'] += 1
                continue
            
            stats['total_pairs'] += 1
            
            # Check if receiver exists
            if receiver_code not in valid_codes:
                if receiver_code not in stats['missing_receivers']:
                    stats['missing_receivers'].append(receiver_code)
                stats['failed_pairs'] += 1
                continue
            
            # Get receiver's personid
            cur.execute("SELECT personid FROM person WHERE code = %s", (receiver_code,))
            receiver_result = cur.fetchone()
            
            if not receiver_result:
                if receiver_code not in stats['missing_receivers']:
                    stats['missing_receivers'].append(receiver_code)
                stats['failed_pairs'] += 1
                continue
            
            receiver_id = receiver_result[0]
            
            # Check if order already exists
            cur.execute("""
                SELECT order_id 
                FROM "Order" 
                WHERE delivery_sender_id = %s 
                  AND delivery_getter_id = %s
            """, (sender_id, receiver_id))
            
            if cur.fetchone():
                # Order already exists, skip
                stats['failed_pairs'] += 1
                continue
            
            # Create order
            try:
                cur.execute("""
                    INSERT INTO "Order" (
                        delivery_sender_id,
                        delivery_getter_id,
                        order_date,
                        origin_type
                    ) VALUES (%s, %s, %s, %s)
                """, (
                    sender_id,
                    receiver_id,
                    datetime.now(),
                    'csv_import'
                ))
                
                stats['successful_pairs'] += 1
            except Exception as e:
                print(f"שגיאה ביצירת הזמנה: {e}")
                stats['failed_pairs'] += 1
    
    conn.commit()
    
    return stats
