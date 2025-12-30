
import pandas as pd
import os
import sys

# Paths to the specific files
RESIDENTS_FILE = r"exel/____CODES_5_3011 (1).csv"
ORDERS_FILE = r"exel/__5785_5 _3011 (1).csv"

def check_residents_mapping():
    print(f"--- Checking Residents File: {RESIDENTS_FILE} ---")
    if not os.path.exists(RESIDENTS_FILE):
        print("File not found!")
        return

    try:
        df = pd.read_csv(RESIDENTS_FILE, encoding='utf-8-sig')
        print("Original Columns:", list(df.columns))
        
        # Simulate app.py logic
        df.columns = df.columns.str.strip()
        
        column_mapping = {
            'last_name': 'lastname',
            'lastname': 'lastname',
            'family_name': 'lastname',
            'surname': 'lastname',
            'father_first_name': 'father_name',
            'father_name': 'father_name',
            'first_name': 'father_name',
            'firstname': 'father_name',
            'mother_first_name': 'mother_name',
            'mother_name': 'mother_name',
            'street': 'streetname',
            'streetname': 'streetname',
            'street_name': 'streetname',
            'building_number': 'buildingnumber',
            'buildingnumber': 'buildingnumber',
            'house_number': 'buildingnumber',
            'housenumber': 'buildingnumber',
            'entrance': 'entrance',
            'apartment_number': 'entrance',
            'apartmentnumber': 'apartmentnumber',
            'apartment': 'apartmentnumber',
            'flat_number': 'apartmentnumber',
            'phone': 'phone',
            'home_phone': 'phone',
            'homephone': 'phone',
            'telephone': 'phone',
            'mobile': 'mobile',
            'mobile1': 'mobile',
            'cell': 'mobile',
            'cellphone': 'mobile',
            'mobile2': 'mobile2',
            'email': 'email',
            'mail': 'email',
            'code': 'code',
            'id': 'code',
            'standing_order': 'standing_order',
            'rating': 'standing_order',
        }

        new_column_names = []
        mapped_columns = {}
        for orig_col in df.columns:
            mapped_col = column_mapping.get(orig_col.lower(), orig_col)
            new_column_names.append(mapped_col)
            if mapped_col != orig_col:
                mapped_columns[orig_col] = mapped_col
        
        df.columns = new_column_names
        
        print("Mapped Columns:", list(df.columns))
        print("Successful mappings:", mapped_columns)
        
        required_cols = ['lastname', 'code']
        missing = [c for c in required_cols if c not in df.columns]
        if missing:
            print(f"❌ Missing required columns: {missing}")
        else:
            print("✅ All required columns present for Residents.")
            
        # Preview data
        print("\nFirst row sample:")
        print(df.iloc[0].to_dict())

    except Exception as e:
        print(f"Error: {e}")

def check_orders_mapping():
    print(f"\n--- Checking Orders File: {ORDERS_FILE} ---")
    if not os.path.exists(ORDERS_FILE):
        print("File not found!")
        return

    try:
        df = pd.read_csv(ORDERS_FILE, encoding='utf-8-sig')
        print("Original Columns:", list(df.columns))
        
        df.columns = df.columns.str.strip()
        
        # App logic just uses .get()
        print("\nVerifying extraction logic:")
        sample = df.iloc[0]
        
        sender_code = str(sample.get('order_code', ''))
        invitees = str(sample.get('guest_list', ''))
        rating = sample.get('rating')
        
        print(f"Extraction result:")
        print(f"order_code -> sender_code: '{sender_code}' (Expected: non-empty)")
        print(f"guest_list -> invitees: '{invitees}' (Expected: non-empty)")
        print(f"rating -> package_size input: '{rating}'")
        
        if sender_code and invitees and rating is not None:
             print("✅ Orders extraction logic seems correct.")
        else:
             print("❌ Extraction failed for some fields.")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_residents_mapping()
    check_orders_mapping()
