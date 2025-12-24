# 🐛 תיקון מהיר - Jinja2 UndefinedError

## הבעיה
```
jinja2.exceptions.UndefinedError: 'now' is undefined
```

## הפתרון

### אם כבר חילצת את הקבצים:

#### 1. ערוך את `app/app.py` - הוסף אחרי שורה 31:

```python
# Add datetime to template context
@app.context_processor
def inject_now():
    """Inject current datetime into all templates"""
    from datetime import datetime
    return {'now': datetime.now()}
```

**המיקום המדויק** (אחרי `os.makedirs`):
```python
app.config.from_object(Config)

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)


# Add datetime to template context    <-- הוסף כאן!
@app.context_processor
def inject_now():
    """Inject current datetime into all templates"""
    from datetime import datetime
    return {'now': datetime.now()}


# ============================================================
# AUTHENTICATION ROUTES
# ============================================================
```

#### 2. ערוך את `templates/base.html` - שורה 102:

**לפני:**
```html
<p class="mb-0">© {{ now().year }} מערכת ניהול משלוחי מנות | כל הזכויות שמורות</p>
```

**אחרי:**
```html
<p class="mb-0">© {{ now.year }} מערכת ניהול משלוחי מנות | כל הזכויות שמורות</p>
```

### אם עדיין לא חילצת:

הורד את הקובץ המעודכן מהלינק למטה - התיקון כבר בפנים! ✅

---

## בדיקה

אחרי התיקון, הרץ:
```bash
docker-compose down
docker-compose up -d
```

ופתח: http://localhost:5000

אמור לעבוד! 🎉
