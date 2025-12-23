# 📁 Project Structure

```
mishloach-manot-system/
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
├── .env.example
├── README.md
│
├── migrations/
│   ├── 01_schema.sql
│   ├── 02_fixes.sql
│   └── 03_seed.sql
│
├── app/
│   ├── __init__.py
│   ├── app.py              # Main Flask application
│   ├── config.py           # Configuration
│   ├── models.py           # SQLAlchemy models (optional)
│   ├── auth.py             # Authentication
│   └── utils.py            # Helper functions
│
├── scripts/
│   ├── etl_residents.py    # ETL for residents CSV/Excel
│   ├── etl_outer_orders.py # ETL for outer orders
│   └── sample_data.py      # Generate sample data
│
├── templates/
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── upload_residents.html
│   ├── upload_orders.html
│   ├── run_procedures.html
│   ├── view_tables.html
│   └── reports.html
│
├── static/
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── main.js
│
├── tests/
│   ├── __init__.py
│   ├── test_etl_residents.py
│   ├── test_etl_orders.py
│   ├── test_api.py
│   ├── test_views.py
│   └── conftest.py
│
└── examples/
    ├── raw_residents_example.xlsx
    └── outer_orders_example.csv
```
