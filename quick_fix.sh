#!/bin/bash
# ========================================
# Quick Fix Script v2
# הרצת המיגרציה + תיקון CAST
# ========================================

echo "🔧 מריץ תיקון מהיר..."
echo ""

# בדיקה אם Docker רץ
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Docker לא רץ! הרץ docker-compose up תחילה"
    exit 1
fi

echo "✅ Docker רץ"
echo ""

# הרצת התיקון המלא
echo "📝 מריץ תיקון מלא (עמודות + CAST)..."
docker-compose exec -T db psql -U postgres -d mishloach_manot -f /migrations/fix_cast.sql

echo ""
echo "✅ תיקון הושלם!"
echo ""
echo "🔄 עכשיו נסה שוב להעלות את הקובץ:"
echo "   1. רענן את הדף (F5)"
echo "   2. לך להעלאת תושבים"
echo "   3. העלה את הקובץ מחדש"
echo ""
