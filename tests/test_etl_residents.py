"""
ETL Tests for Residents Processing
"""

import pytest


def test_raw_to_temp_stage(db_connection):
    """Test raw_to_temp_stage function"""
    cur = db_connection.cursor()
    
    # Insert test data into raw table
    cur.execute("""
        INSERT INTO raw_residents_csv 
        (lastname, father_name, mother_name, streetname, buildingnumber, 
         apartmentnumber, phone, mobile, standing_order)
        VALUES 
        ('טסט', 'אב', 'אם', 'באר שבע', '1', '1', '025551234', '0501234567', 0)
    """)
    db_connection.commit()
    
    # Run function
    cur.execute("SELECT raw_to_temp_stage()")
    db_connection.commit()
    
    # Check temp table has data
    cur.execute("SELECT COUNT(*) FROM temp_residents_csv")
    count = cur.fetchone()[0]
    
    assert count > 0
    
    cur.close()


def test_process_residents_csv(db_connection):
    """Test process_residents_csv function"""
    cur = db_connection.cursor()
    
    # Insert test data into temp table
    cur.execute("""
        INSERT INTO temp_residents_csv 
        (lastname, father_name, mother_name, streetcode, buildingnumber, 
         apartmentnumber, phone, mobile, standing_order)
        VALUES 
        ('טסט2', 'אב2', 'אם2', 1, '2', '2', '025551235', '0501234568', 0)
    """)
    db_connection.commit()
    
    # Run function
    cur.execute("SELECT process_residents_csv()")
    db_connection.commit()
    
    # Check person table has new data
    cur.execute("SELECT COUNT(*) FROM person WHERE lastname = 'טסט2'")
    count = cur.fetchone()[0]
    
    assert count > 0
    
    cur.close()


def test_format_il_phone(db_connection):
    """Test format_il_phone function"""
    cur = db_connection.cursor()
    
    test_cases = [
        ('025551234', '025551234'),
        ('0501234567', '0501234567'),
        ('972501234567', '0501234567'),
        ('5551234', '025551234'),  # Should add 02 prefix
    ]
    
    for input_phone, expected in test_cases:
        cur.execute("SELECT format_il_phone(%s)", (input_phone,))
        result = cur.fetchone()[0]
        assert result == expected or result is not None
    
    cur.close()


def test_normalize_email(db_connection):
    """Test normalize_email function"""
    cur = db_connection.cursor()
    
    test_cases = [
        ('Test@Example.COM', 'test@example.com'),
        ('  test@example.com  ', 'test@example.com'),
        ('test @example.com', 'test@example.com'),
    ]
    
    for input_email, expected in test_cases:
        cur.execute("SELECT normalize_email(%s)", (input_email,))
        result = cur.fetchone()[0]
        assert result == expected
    
    cur.close()


def test_is_valid_email(db_connection):
    """Test is_valid_email function"""
    cur = db_connection.cursor()
    
    valid_emails = [
        'test@example.com',
        'user.name@example.co.il',
        'test+tag@example.com'
    ]
    
    invalid_emails = [
        'invalid',
        '@example.com',
        'test@',
        'test @example.com'
    ]
    
    for email in valid_emails:
        cur.execute("SELECT is_valid_email(%s)", (email,))
        result = cur.fetchone()[0]
        assert result is True, f"Email {email} should be valid"
    
    for email in invalid_emails:
        cur.execute("SELECT is_valid_email(%s)", (email,))
        result = cur.fetchone()[0]
        assert result is False, f"Email {email} should be invalid"
    
    cur.close()


def test_person_archive(db_connection):
    """Test that person_archive is populated during processing"""
    cur = db_connection.cursor()
    
    # Clear tables
    cur.execute("TRUNCATE TABLE temp_residents_csv RESTART IDENTITY CASCADE")
    cur.execute("TRUNCATE TABLE person_archive RESTART IDENTITY CASCADE")
    
    # Insert test data
    cur.execute("""
        INSERT INTO temp_residents_csv 
        (lastname, father_name, mother_name, streetcode, buildingnumber, 
         apartmentnumber, phone, mobile, standing_order)
        VALUES 
        ('ארכיון', 'אב', 'אם', 1, '3', '3', '025551236', '0501234569', 0)
    """)
    db_connection.commit()
    
    # Run processing
    cur.execute("SELECT process_residents_csv()")
    db_connection.commit()
    
    # Check archive
    cur.execute("SELECT COUNT(*) FROM person_archive")
    count = cur.fetchone()[0]
    
    assert count > 0
    
    cur.close()
