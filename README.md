# 🎁 מערכת ניהול משלוחי מנות
## Mishloach Manot Management System

מערכת מקיפה לניהול תושבים, הזמנות משלוחי מנות, ותשלומים.

---

## 📋 תוכן עניינים

- [סקירה](#סקירה)
- [תכונות](#תכונות)
- [דרישות מערכת](#דרישות-מערכת)
- [התקנה](#התקנה)
- [הרצה](#הרצה)
- [שימוש במערכת](#שימוש-במערכת)
- [מבנה הפרויקט](#מבנה-הפרויקט)
- [API](#api)
- [בדיקות](#בדיקות)
- [פתרון בעיות](#פתרון-בעיות)

---

## 🎯 סקירה

מערכת ניהול משלוחי מנות היא יישום full-stack המספק פתרון מקיף לניהול:
- **תושבים**: רישום, עדכון ואיחוד אוטומטי של תושבים
- **הזמנות**: קליטה והפצה אוטומטית של הזמנות משלוחי מנות
- **תשלומים**: מעקב אחר תשלומים והנחות
- **דוחות**: דוחות מפורטים עם יצוא ל-CSV
- **החזרה אוטומטית**: מנגנון אוטומטי להחזרת משלוחים

---

## ✨ תכונות

### 🏠 ניהול תושבים
- ✅ העלאת קבצי CSV/Excel
- ✅ ניקוי וולידציה אוטומטית
- ✅ תקינה של מספרי טלפון לפורמט ישראלי
- ✅ איחוד אוטומטי של תושבים קיימים
- ✅ רישום רחובות חדשים

### 📦 ניהול הזמנות
- ✅ קליטת הזמנות מקובץ חיצוני
- ✅ הפצה אוטומטית למוזמנים
- ✅ תמיכה במספר דרגות מנות (סמלי, מכובד, מפואר)
- ✅ מנגנון החזרה אוטומטית
- ✅ מעקב אחר סטטוס הזמנות

### 💰 ניהול תשלומים
- ✅ מעקב אחר תשלומים לפי משפחה
- ✅ חישוב הנחות אוטומטי
- ✅ דוחות חיובים מפורטים

### 📊 דוחות
- ✅ סיכום חשבונות עם הנחות
- ✅ איזון משפחות (שלחו מול קיבלו)
- ✅ חלוקת מנות לפי בניין
- ✅ פעילות החזרה אוטומטית
- ✅ יצוא לקבצי CSV

### 🔐 אבטחה
- ✅ מערכת התחברות מאובטחת
- ✅ הפרדה בין משתמשים
- ✅ הצפנת סיסמאות

---

## 💻 דרישות מערכת

- Docker & Docker Compose
- Python 3.11+
- PostgreSQL 15+
- 4GB RAM (מינימום)
- 2GB שטח דיסק

---

## 📥 התקנה

### שלב 1: שכפול הפרויקט

```bash
git clone <repository-url>
cd mishloach-manot-system
```

### שלב 2: הגדרת משתני סביבה

```bash
cp .env.example .env
```

ערוך את קובץ `.env` והתאם את הערכים:

```env
DATABASE_URL=postgresql://postgres:postgres123@db:5432/mishloach_manot
SECRET_KEY=your-secret-key-here
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
```

### שלב 3: בניית ה-Docker Images

```bash
docker-compose build
```

---

## 🚀 הרצה

### הרצת המערכת

```bash
docker-compose up -d
```

המערכת תהיה זמינה בכתובת: **http://localhost:5000**

### עצירת המערכת

```bash
docker-compose down
```

### צפייה בלוגים

```bash
docker-compose logs -f web
```

---

## 📖 שימוש במערכת

### התחברות ראשונית

1. גלוש לכתובת: http://localhost:5000
2. התחבר עם:
   - **שם משתמש**: `admin`
   - **סיסמה**: `admin123`

### העלאת תושבים

1. היכנס ל**"העלאת תושבים"**
2. בחר קובץ CSV/Excel עם העמודות הבאות:

```
code,lastname,father_name,mother_name,streetname,buildingnumber,
entrance,apartmentnumber,phone,mobile,mobile2,email,standing_order
```

3. לחץ על **"העלה קובץ"**
4. המערכת תעבד את הקובץ אוטומטית

**דוגמה לשורה בקובץ:**
```
1,כהן,דוד,שרה,באר שבע,10,א,5,025551234,0501234567,,david@example.com,2
```

### העלאת הזמנות

1. היכנס ל**"העלאת הזמנות"**
2. בחר קובץ CSV/Excel עם העמודות הבאות:

```
order_code,guest_list,rating
```

3. לחץ על **"העלה והפץ הזמנות"**

**דוגמה לשורה בקובץ:**
```
1,2|3|4|5,2
```

**פירוש:**
- `order_code`: 1 (קוד השולח)
- `guest_list`: 2|3|4|5 (רשימת מוזמנים מופרדת ב-|)
- `rating`: 2 (דרגה: 1=סמלי, 2=מכובד, 3=מפואר)

### הרצת פרוצדורות

1. היכנס ל**"הרצת פרוצדורות"**
2. בחר פונקציה מהרשימה
3. אם הפונקציה דורשת פרמטרים, הזן אותם
4. לחץ על **"הרץ פונקציה"**

**פונקציות נפוצות:**
- `raw_to_temp_stage` - העברת נתונים מ-RAW ל-TEMP
- `process_residents_csv` - עיבוד תושבים
- `distribute_all_outer_orders` - הפצת הזמנות
- `apply_autoreturn_from_outer` - הפעלת החזרה אוטומטית

### צפייה בדוחות

1. היכנס ל**"דוחות"**
2. בחר דוח מהרשימה
3. הנתונים יוצגו בטבלה
4. לחץ על **"יצא ל-CSV"** להורדת הדוח

**דוחות זמינים:**
- `v_accounts_summary` - סיכום חשבונות
- `v_families_balance` - איזון משפחות
- `v_packages_per_building` - חלוקת מנות לפי בניין
- `v_autoreturn_activity` - פעילות החזרה אוטומטית

---

## 📁 מבנה הפרויקט

```
mishloach-manot-system/
├── app/                      # קוד האפליקציה
│   ├── app.py               # Flask application ראשי
│   ├── auth.py              # מערכת אימות
│   ├── config.py            # הגדרות
│   └── utils.py             # פונקציות עזר
├── migrations/              # מיגרציות SQL
│   ├── 01_schema.sql       # סכמת מסד הנתונים
│   ├── 02_fixes.sql        # תיקונים
│   └── 03_seed.sql         # נתוני דוגמה
├── templates/               # תבניות HTML
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── upload_residents.html
│   ├── upload_orders.html
│   ├── run_procedures.html
│   ├── view_tables.html
│   └── reports.html
├── static/                  # קבצים סטטיים
│   ├── css/style.css
│   └── js/main.js
├── scripts/                 # סקריפטי ETL
│   ├── etl_residents.py
│   └── etl_outer_orders.py
├── tests/                   # בדיקות
│   ├── conftest.py
│   ├── test_api.py
│   └── test_etl_residents.py
├── docker-compose.yml       # הגדרות Docker
├── Dockerfile              # בניית הקונטיינר
├── requirements.txt        # תלויות Python
└── README.md              # תיעוד זה
```

---

## 🔌 API

### Authentication

```bash
POST /login
Content-Type: application/x-www-form-urlencoded

username=admin&password=admin123
```

### Get Table Data

```bash
GET /api/table-data/{table_name}?limit=50&offset=0&search=query
```

**פרמטרים:**
- `limit`: מספר שורות להחזיר
- `offset`: היסט לפגינציה
- `search`: מילת חיפוש (אופציונלי)

### Get View Data

```bash
GET /api/view-data/{view_name}
```

### Export View to CSV

```bash
GET /api/export-view/{view_name}
```

### Get Function Parameters

```bash
GET /api/function-params/{function_name}
```

---

## 🧪 בדיקות

### הרצת כל הבדיקות

```bash
docker-compose exec web pytest
```

### הרצת בדיקות ספציפיות

```bash
# בדיקות API
docker-compose exec web pytest tests/test_api.py

# בדיקות ETL
docker-compose exec web pytest tests/test_etl_residents.py
```

### הרצה עם כיסוי קוד

```bash
docker-compose exec web pytest --cov=app
```

---

## 🐛 פתרון בעיות

### בעיה: המערכת לא עולה

**פתרון:**
```bash
docker-compose down -v
docker-compose up --build
```

### בעיה: שגיאת חיבור למסד נתונים

**פתרון:**
1. בדוק ש-PostgreSQL רץ:
   ```bash
   docker-compose ps
   ```
2. בדוק את הלוגים:
   ```bash
   docker-compose logs db
   ```

### בעיה: קובץ לא מתעלה

**סיבות אפשריות:**
- גודל הקובץ מעל 16MB
- פורמט קובץ לא נתמך
- עמודות חסרות בקובץ

**פתרון:**
1. בדוק שהקובץ קטן מ-16MB
2. וודא שהפורמט הוא CSV או Excel
3. בדוק שכל העמודות הנדרשות קיימות

### בעיה: הזמנות לא מופצות

**פתרון:**
1. בדוק שהשולח קיים במערכת
2. בדוק שהמוזמנים קיימים במערכת
3. הרץ את הפונקציה `distribute_all_outer_orders` ידנית
4. בדוק את טבלת השגיאות:
   ```sql
   SELECT * FROM outerapporder_error_log ORDER BY created_at DESC LIMIT 10;
   ```

---

## 🔒 אבטחה

### שינוי סיסמת המנהל

1. התחבר למערכת
2. חבר ל-PostgreSQL:
   ```bash
   docker-compose exec db psql -U postgres -d mishloach_manot
   ```
3. הרץ:
   ```sql
   UPDATE app_users SET password_hash = 'NEW_HASHED_PASSWORD' WHERE username = 'admin';
   ```

### הצפנת סיסמאות

המערכת משתמשת ב-PBKDF2 SHA256 להצפנת סיסמאות.

---

## 📊 מחירים והנחות

### מחירים בסיסיים
- **סמלי (דרגה 1)**: 11 ש"ח
- **מכובד (דרגה 2)**: 10 ש"ח
- **מפואר (דרגה 3)**: 9 ש"ח

### הנחות אוטומטיות
המערכת מחשבת הנחות לפי סה"כ סכום ההזמנות:

- **עד 180 ש"ח**: 5% הנחה
- **180-360 ש"ח**: 10% הנחה
- **מעל 360 ש"ח**: 20% הנחה

---

## 🔄 החזרה אוטומטית

משפחות המסומנות עם `autoreturn = true` יקבלו אוטומטית הזמנה חזרה לכל מי ששלח להן.

**איך זה עובד:**
1. משפחה A שולחת למשפחה B
2. אם למשפחה B יש `autoreturn = true`
3. המערכת יוצרת אוטומטית הזמנה חזרה מ-B ל-A
4. ההזמנה מסומנת כ-`origin_type = 'autoreturn'`

---

## 🛠️ פיתוח

### הוספת פיצ'ר חדש

1. צור branch חדש
2. פתח את הקוד
3. הוסף בדיקות
4. הרץ בדיקות
5. צור Pull Request

### מבנה הקוד

```python
# app/app.py - הוספת route חדש

@app.route('/new-feature')
@login_required
def new_feature():
    # הקוד שלך כאן
    return render_template('new_feature.html')
```

---

## 📞 תמיכה

לשאלות ובעיות, פנה ל:
- **Email**: support@example.com
- **GitHub Issues**: [Link to issues]

---

## 📝 רישיון

MIT License - ראה קובץ LICENSE לפרטים

---

## 🙏 תודות

פרויקט זה נבנה עם:
- Flask
- PostgreSQL
- Bootstrap 5 RTL
- Docker

---

**נבנה עם ❤️ למען הקהילה**
