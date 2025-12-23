"""
Mishloach Manot Management System - Main Application
מערכת ניהול משלוחי מנות

Flask application for managing residents, orders, and package deliveries
"""

from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify, send_file
import os
import sys
from werkzeug.utils import secure_filename
import pandas as pd
import psycopg2
from psycopg2.extras import RealDictCursor
import io
import csv as csv_module
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import Config
from app.auth import login_required, verify_user, update_last_login, get_db_connection
from app.utils import (
    execute_function, get_table_data, get_view_data, export_to_csv,
    get_function_parameters, get_all_functions, get_all_views, get_all_tables
)

# Initialize Flask app
app = Flask(__name__, 
            template_folder='../templates',
            static_folder='../static')
app.config.from_object(Config)

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Add datetime to template context
@app.context_processor
def inject_now():
    """Inject current datetime into all templates"""
    from datetime import datetime
    return {'now': datetime.now()}

# Add datetime to template context
@app.context_processor
def inject_now():
    """Inject current datetime into all templates"""
    from datetime import datetime
    return {'now': datetime.now()}


# ============================================================
# AUTHENTICATION ROUTES
# ============================================================

@app.route('/')
def index():
    """Homepage - redirect to dashboard if logged in, else login"""
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user_id = verify_user(username, password)
        if user_id:
            session['user_id'] = user_id
            session['username'] = username
            update_last_login(user_id)
            flash('התחברת בהצלחה!', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('שם משתמש או סיסמה שגויים', 'danger')
    
    return render_template('login.html')


@app.route('/logout')
def logout():
    """Logout"""
    session.clear()
    flash('התנתקת בהצלחה', 'info')
    return redirect(url_for('login'))


# ============================================================
# DASHBOARD
# ============================================================

@app.route('/dashboard')
@login_required
def dashboard():
    """Main dashboard"""
    from psycopg2.extras import RealDictCursor
    conn = psycopg2.connect(Config.DATABASE_URL)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get statistics
        cur.execute("SELECT COUNT(*) as count FROM person")
        total_residents = cur.fetchone()['count']
        
        cur.execute('SELECT COUNT(*) as count FROM "Order"')
        total_orders = cur.fetchone()['count']
        
        cur.execute("SELECT COUNT(*) as count FROM outerapporder WHERE status = 'waiting'")
        pending_orders = cur.fetchone()['count']
        
        cur.execute("SELECT COUNT(*) as count FROM person WHERE autoreturn = true")
        autoreturn_count = cur.fetchone()['count']
        
        stats = {
            'total_residents': total_residents,
            'total_orders': total_orders,
            'pending_orders': pending_orders,
            'autoreturn_count': autoreturn_count
        }
        
        return render_template('dashboard.html', stats=stats)
    finally:
        cur.close()
        conn.close()


# ============================================================
# UPLOAD RESIDENTS
# ============================================================

@app.route('/upload-residents', methods=['GET', 'POST'])
@login_required
def upload_residents():
    """Upload residents CSV/Excel file"""
    if request.method == 'POST':
        if 'file' not in request.files:
            flash('לא נבחר קובץ', 'danger')
            return redirect(request.url)
        
        file = request.files['file']
        if file.filename == '':
            flash('לא נבחר קובץ', 'danger')
            return redirect(request.url)
        
        if file and Config.allowed_file(file.filename):
            try:
                # Read the file
                if file.filename.endswith('.csv'):
                    df = pd.read_csv(file, encoding='utf-8-sig')
                else:
                    df = pd.read_excel(file)
                
                # Clean column names
                df.columns = df.columns.str.strip()
                
                # Connect to database
                conn = get_db_connection()
                cur = conn.cursor()
                
                # Clear raw table
                cur.execute("TRUNCATE TABLE raw_residents_csv RESTART IDENTITY")
                
                # Insert data
                rows_inserted = 0
                for _, row in df.iterrows():
                    cur.execute("""
                        INSERT INTO raw_residents_csv 
                        (code, lastname, father_name, mother_name, streetname, 
                         buildingnumber, entrance, apartmentnumber, phone, mobile, 
                         mobile2, email, standing_order)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        row.get('code'),
                        row.get('lastname'),
                        row.get('father_name'),
                        row.get('mother_name'),
                        row.get('streetname'),
                        row.get('buildingnumber'),
                        row.get('entrance'),
                        row.get('apartmentnumber'),
                        row.get('phone'),
                        row.get('mobile'),
                        row.get('mobile2'),
                        row.get('email'),
                        int(row.get('standing_order', 0)) if pd.notna(row.get('standing_order')) else 0
                    ))
                    rows_inserted += 1
                
                conn.commit()
                
                # Run ETL process
                cur.execute("SELECT raw_to_temp_stage()")
                cur.execute("SELECT process_residents_csv()")
                conn.commit()
                
                flash(f'הקובץ הועלה בהצלחה! {rows_inserted} שורות נטענו ועובדו', 'success')
                
                cur.close()
                conn.close()
                
                return redirect(url_for('dashboard'))
                
            except Exception as e:
                flash(f'שגיאה בעיבוד הקובץ: {str(e)}', 'danger')
                return redirect(request.url)
        else:
            flash('סוג קובץ לא נתמך. השתמש ב-CSV או Excel', 'danger')
            return redirect(request.url)
    
    return render_template('upload_residents.html')


# ============================================================
# UPLOAD OUTER ORDERS
# ============================================================

@app.route('/upload-orders', methods=['GET', 'POST'])
@login_required
def upload_orders():
    """Upload outer orders CSV file"""
    if request.method == 'POST':
        if 'file' not in request.files:
            flash('לא נבחר קובץ', 'danger')
            return redirect(request.url)
        
        file = request.files['file']
        if file.filename == '':
            flash('לא נבחר קובץ', 'danger')
            return redirect(request.url)
        
        if file and Config.allowed_file(file.filename):
            try:
                # Read CSV
                if file.filename.endswith('.csv'):
                    df = pd.read_csv(file, encoding='utf-8-sig')
                else:
                    df = pd.read_excel(file)
                
                # Clean column names
                df.columns = df.columns.str.strip()
                
                # Map rating to package_size
                rating_map = {
                    1: 'סמלי',
                    2: 'מכובד',
                    3: 'מפואר',
                    '1': 'סמלי',
                    '2': 'מכובד',
                    '3': 'מפואר'
                }
                
                # Connect to database
                conn = get_db_connection()
                cur = conn.cursor()
                
                rows_inserted = 0
                for _, row in df.iterrows():
                    # Extract order_code as sender_code
                    sender_code = str(row.get('order_code', ''))
                    
                    # Extract guest_list as invitees
                    invitees = str(row.get('guest_list', ''))
                    
                    # Map rating to package_size
                    rating = row.get('rating')
                    package_size = rating_map.get(rating, rating_map.get(str(rating), 'סמלי'))
                    
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
                
                conn.commit()
                
                # Run distribution
                cur.execute("SELECT distribute_all_outer_orders()")
                result = cur.fetchone()
                distributed = result[0] if result else 0
                conn.commit()
                
                flash(f'הקובץ הועלה בהצלחה! {rows_inserted} הזמנות נטענו, {distributed} הופצו', 'success')
                
                cur.close()
                conn.close()
                
                return redirect(url_for('dashboard'))
                
            except Exception as e:
                flash(f'שגיאה בעיבוד הקובץ: {str(e)}', 'danger')
                return redirect(request.url)
        else:
            flash('סוג קובץ לא נתמך. השתמש ב-CSV או Excel', 'danger')
            return redirect(request.url)
    
    return render_template('upload_orders.html')


# ============================================================
# RUN PROCEDURES
# ============================================================

@app.route('/run-procedures', methods=['GET', 'POST'])
@login_required
def run_procedures():
    """Run database procedures"""
    functions = get_all_functions()
    
    if request.method == 'POST':
        func_name = request.form.get('function_name')
        
        try:
            # Get function parameters
            params_info = get_function_parameters(func_name)
            params = []
            
            for param in params_info:
                param_name = param['parameter_name']
                param_value = request.form.get(f'param_{param_name}')
                if param_value:
                    params.append(param_value)
            
            # Execute function
            result = execute_function(func_name, params if params else None)
            
            flash(f'הפונקציה {func_name} הורצה בהצלחה! תוצאה: {result}', 'success')
            
        except Exception as e:
            flash(f'שגיאה בהרצת הפונקציה: {str(e)}', 'danger')
    
    return render_template('run_procedures.html', functions=functions)


@app.route('/api/function-params/<func_name>')
@login_required
def get_function_params(func_name):
    """API to get function parameters"""
    try:
        params = get_function_parameters(func_name)
        return jsonify({'params': params})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


# ============================================================
# VIEW TABLES
# ============================================================

@app.route('/view-tables')
@login_required
def view_tables():
    """View all tables"""
    tables = get_all_tables()
    return render_template('view_tables.html', tables=tables)


@app.route('/api/table-data/<table_name>')
@login_required
def get_table_data_api(table_name):
    """API to get table data with pagination"""
    try:
        limit = int(request.args.get('limit', 50))
        offset = int(request.args.get('offset', 0))
        search = request.args.get('search', '')
        order_by = request.args.get('order_by', '')
        
        result = get_table_data(
            table_name,
            limit=limit,
            offset=offset,
            search=search if search else None,
            order_by=order_by if order_by else None
        )
        
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 400


# ============================================================
# REPORTS
# ============================================================

@app.route('/reports')
@login_required
def reports():
    """Reports page"""
    views = get_all_views()
    return render_template('reports.html', views=views)


@app.route('/api/view-data/<view_name>')
@login_required
def get_view_data_api(view_name):
    """API to get view data"""
    try:
        data = get_view_data(view_name)
        return jsonify({'data': data})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


@app.route('/api/export-view/<view_name>')
@login_required
def export_view(view_name):
    """Export view to CSV"""
    try:
        data = get_view_data(view_name)
        
        if not data:
            flash('אין נתונים לייצוא', 'warning')
            return redirect(url_for('reports'))
        
        # Get column names
        columns = list(data[0].keys())
        
        # Create CSV
        output = io.StringIO()
        writer = csv_module.DictWriter(output, fieldnames=columns)
        writer.writeheader()
        writer.writerows(data)
        
        # Create BytesIO object
        csv_data = io.BytesIO(output.getvalue().encode('utf-8-sig'))
        
        return send_file(
            csv_data,
            mimetype='text/csv',
            as_attachment=True,
            download_name=f'{view_name}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
        )
    except Exception as e:
        flash(f'שגיאה בייצוא: {str(e)}', 'danger')
        return redirect(url_for('reports'))


# ============================================================
# ERROR HANDLERS
# ============================================================

@app.errorhandler(404)
def not_found(e):
    return render_template('404.html'), 404


@app.errorhandler(500)
def server_error(e):
    return render_template('500.html'), 500


# ============================================================
# RUN APPLICATION
# ============================================================

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)