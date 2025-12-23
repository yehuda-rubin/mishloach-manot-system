"""
API Tests for Mishloach Manot System
"""

import pytest


def test_home_redirect(client):
    """Test homepage redirects to login"""
    response = client.get('/')
    assert response.status_code == 302
    assert '/login' in response.location


def test_login_page(client):
    """Test login page loads"""
    response = client.get('/login')
    assert response.status_code == 200
    assert 'התחברות'.encode('utf-8') in response.data


def test_login_success(client):
    """Test successful login"""
    response = client.post('/login', data={
        'username': 'admin',
        'password': 'admin123'
    }, follow_redirects=True)
    assert response.status_code == 200
    assert 'dashboard' in response.request.path or 'לוח בקרה'.encode('utf-8') in response.data


def test_login_failure(client):
    """Test failed login"""
    response = client.post('/login', data={
        'username': 'wrong',
        'password': 'wrong'
    })
    assert response.status_code == 200
    assert 'שגוי'.encode('utf-8') in response.data or 'wrong' in response.get_data(as_text=True).lower()


def test_dashboard_requires_login(client):
    """Test dashboard requires authentication"""
    response = client.get('/dashboard')
    assert response.status_code == 302
    assert '/login' in response.location


def test_dashboard_authenticated(authenticated_client):
    """Test dashboard with authentication"""
    response = authenticated_client.get('/dashboard')
    assert response.status_code == 200


def test_upload_residents_page(authenticated_client):
    """Test upload residents page"""
    response = authenticated_client.get('/upload-residents')
    assert response.status_code == 200
    assert 'העלאת תושבים'.encode('utf-8') in response.data


def test_upload_orders_page(authenticated_client):
    """Test upload orders page"""
    response = authenticated_client.get('/upload-orders')
    assert response.status_code == 200
    assert 'העלאת הזמנות'.encode('utf-8') in response.data


def test_run_procedures_page(authenticated_client):
    """Test run procedures page"""
    response = authenticated_client.get('/run-procedures')
    assert response.status_code == 200


def test_view_tables_page(authenticated_client):
    """Test view tables page"""
    response = authenticated_client.get('/view-tables')
    assert response.status_code == 200


def test_reports_page(authenticated_client):
    """Test reports page"""
    response = authenticated_client.get('/reports')
    assert response.status_code == 200


def test_logout(authenticated_client):
    """Test logout"""
    response = authenticated_client.get('/logout', follow_redirects=True)
    assert response.status_code == 200
    assert '/login' in response.request.path


def test_api_table_data(authenticated_client):
    """Test table data API"""
    response = authenticated_client.get('/api/table-data/person?limit=10&offset=0')
    assert response.status_code == 200
    data = response.get_json()
    assert 'data' in data
    assert 'total' in data


def test_api_view_data(authenticated_client):
    """Test view data API"""
    response = authenticated_client.get('/api/view-data/v_families_balance')
    assert response.status_code == 200
    data = response.get_json()
    assert 'data' in data


def test_api_function_params(authenticated_client):
    """Test function parameters API"""
    response = authenticated_client.get('/api/function-params/process_residents_csv')
    assert response.status_code == 200


def test_invalid_table_data(authenticated_client):
    """Test API with invalid table"""
    response = authenticated_client.get('/api/table-data/nonexistent_table')
    assert response.status_code == 400


def test_invalid_view_data(authenticated_client):
    """Test API with invalid view"""
    response = authenticated_client.get('/api/view-data/nonexistent_view')
    assert response.status_code == 400
