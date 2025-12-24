"""
Authentication module for Mishloach Manot System
"""
from functools import wraps
from flask import session, redirect, url_for, flash
from werkzeug.security import check_password_hash, generate_password_hash
import psycopg2
from app.config import Config

def login_required(f):
    """Decorator to require login for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('נא להתחבר תחילה', 'warning')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function


def get_db_connection():
    """Get database connection"""
    from psycopg2.extras import RealDictCursor
    return psycopg2.connect(Config.DATABASE_URL, cursor_factory=RealDictCursor)


def verify_user(username, password):
    """Verify user credentials"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute(
            "SELECT user_id, password_hash FROM app_users WHERE username = %s",
            (username,)
        )
        result = cur.fetchone()
        
        if result:
            user_id = result['user_id']
            password_hash = result['password_hash']
            # For development: allow plain text comparison as fallback
            if password == Config.ADMIN_PASSWORD and username == Config.ADMIN_USERNAME:
                return user_id
            # Check hashed password
            if check_password_hash(password_hash, password):
                return user_id
        
        return None
    finally:
        cur.close()
        conn.close()


def create_user(username, password):
    """Create a new user"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        password_hash = generate_password_hash(password)
        cur.execute(
            "INSERT INTO app_users (username, password_hash) VALUES (%s, %s) RETURNING user_id",
            (username, password_hash)
        )
        result = cur.fetchone()
        user_id = result['user_id'] if result else None
        conn.commit()
        return user_id
    except psycopg2.IntegrityError:
        conn.rollback()
        return None
    finally:
        cur.close()
        conn.close()


def update_last_login(user_id):
    """Update user's last login timestamp"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute(
            "UPDATE app_users SET last_login = NOW() WHERE user_id = %s",
            (user_id,)
        )
        conn.commit()
    finally:
        cur.close()
        conn.close()
