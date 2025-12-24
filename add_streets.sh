#!/bin/bash

# ========================================
# תסריט אוטומטי להוספת כל הרחובות מהקובץ
# ========================================

echo "🔍 מחפש רחובות בקובץ שהועלה..."

# שלוף רחובות ייחודיים מהטבלת raw
streets=$(docker-compose exec -T db psql -U postgres -d mishloach_manot -t -c \
"SELECT DISTINCT streetname FROM raw_residents_csv WHERE streetname IS NOT NULL AND TRIM(streetname) != '' ORDER BY streetname;")

# בדוק אם יש רחובות
if [ -z "$streets" ]; then
    echo "❌ לא נמצאו רחובות בקובץ!"
    exit 1
fi

echo "✅ נמצאו רחובות!"
echo ""
echo "📋 רשימת הרחובות:"
echo "$streets"
echo ""

# ספירה
count=$(echo "$streets" | wc -l)
echo "סה\"כ: $count רחובות"
echo ""

read -p "האם להוסיף את כל הרחובות לטבלת street? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "בוטל על ידי המשתמש"
    exit 0
fi

echo "🔄 מוסיף רחובות..."

# הוסף כל רחוב
counter=0
while IFS= read -r street; do
    # trim whitespace
    street=$(echo "$street" | xargs)
    
    if [ ! -z "$street" ]; then
        counter=$((counter + 1))
        echo "[$counter/$count] מוסיף: $street"
        
        # escape single quotes
        street_escaped=$(echo "$street" | sed "s/'/''/g")
        
        docker-compose exec -T db psql -U postgres -d mishloach_manot -c \
        "INSERT INTO street (streetname) VALUES ('$street_escaped') ON CONFLICT DO NOTHING;" \
        > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo "    ✅ הצלחה"
        else
            echo "    ❌ נכשל"
        fi
    fi
done <<< "$streets"

echo ""
echo "✅ הסתיים!"
echo ""

# בדוק כמה רחובות יש עכשיו
total=$(docker-compose exec -T db psql -U postgres -d mishloach_manot -t -c \
"SELECT COUNT(*) FROM street;")

echo "📊 סה\"כ רחובות בטבלה: $(echo $total | xargs)"

echo ""
echo "🎉 עכשיו אפשר להעלות שוב את הקובץ!"
echo "   → http://localhost:5000"
