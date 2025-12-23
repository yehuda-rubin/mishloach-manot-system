"""
Pytest configuration and fixtures
"""

import pytest
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.app import app as flask_app
from app.config import Config
import psycopg2


@pytest.fixture
def app():
    """Create Flask app for testing"""
    flask_app.config['TESTING'] = True
    flask_app.config['WTF_CSRF_ENABLED'] = False
    yield flask_app


@pytest.fixture
def client(app):
    """Create test client"""
    return app.test_client()


@pytest.fixture
def db_connection():
    """Create database connection for testing"""
    conn = psycopg2.connect(Config.DATABASE_URL)
    yield conn
    conn.close()


@pytest.fixture
def authenticated_client(client):
    """Create authenticated client"""
    client.post('/login', data={
        'username': Config.ADMIN_USERNAME,
        'password': Config.ADMIN_PASSWORD
    })
    yield client


@pytest.fixture
def sample_residents_data():
    """Sample residents data for testing"""
    return {
        'code': '999',
        'lastname': 'טסט',
        'father_name': 'אב',
        'mother_name': 'אם',
        'streetname': 'באר שבע',
        'buildingnumber': '99',
        'entrance': 'א',
        'apartmentnumber': '1',
        'phone': '025551234',
        'mobile': '0501234567',
        'mobile2': '',
        'email': 'test@example.com',
        'standing_order': 0
    }


@pytest.fixture
def sample_order_data():
    """Sample order data for testing"""
    return {
        'order_code': '1',
        'guest_list': '2|3|4',
        'rating': 1
    }
