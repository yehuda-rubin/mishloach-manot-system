-- ========================================
-- בדיקת 183 התושבים שנדחו
-- ========================================

\echo '🔍 בודק למה תושבים נדחו...'
\echo ''

-- 1. סיבות הדחייה
\echo '📊 סיבות לדחייה:'
SELECT 
    status_note, 
    COUNT(*) as count
FROM person_archive 
WHERE status='skipped' 
GROUP BY status_note
ORDER BY COUNT(*) DESC;

\echo ''
\echo '---'
\echo ''

-- 2. דוגמאות של תושבים שנדחו (5 ראשונים)
\echo '📋 דוגמאות של תושבים שנדחו:'
SELECT 
    archive_id,
    lastname,
    father_name,
    mother_name,
    streetcode,
    buildingnumber,
    apartmentnumber,
    status_note
FROM person_archive 
WHERE status='skipped'
ORDER BY archive_id
LIMIT 5;

\echo ''
\echo '---'
\echo ''

-- 3. ספירה לפי שדות חסרים
\echo '📈 ניתוח שדות חסרים:'
SELECT 
    'lastname ריק' as field,
    COUNT(*) as count
FROM temp_residents_csv
WHERE status = 'נדחה' AND (lastname IS NULL OR TRIM(lastname) = '')
UNION ALL
SELECT 
    'father_name ריק',
    COUNT(*)
FROM temp_residents_csv
WHERE status = 'נדחה' AND (father_name IS NULL OR TRIM(father_name) = '')
UNION ALL
SELECT 
    'streetname ריק',
    COUNT(*)
FROM temp_residents_csv
WHERE status = 'נדחה' AND (streetname IS NULL OR TRIM(streetname) = '')
UNION ALL
SELECT 
    'buildingnumber ריק',
    COUNT(*)
FROM temp_residents_csv
WHERE status = 'נדחה' AND (buildingnumber IS NULL OR TRIM(buildingnumber) = '')
UNION ALL
SELECT 
    'apartmentnumber ריק',
    COUNT(*)
FROM temp_residents_csv
WHERE status = 'נדחה' AND (apartmentnumber IS NULL OR TRIM(apartmentnumber) = '')
ORDER BY count DESC;

\echo ''
\echo '---'
\echo ''

-- 4. התאמה חלקית - כפילויות אפשריות
\echo '⚠️  התאמות חלקיות (כפילויות אפשריות):'
SELECT 
    COUNT(*) as total_partial_matches
FROM person_archive
WHERE status='partial_match';

\echo ''

SELECT 
    lastname,
    father_name,
    streetcode,
    buildingnumber,
    apartmentnumber,
    status_note
FROM person_archive 
WHERE status='partial_match'
ORDER BY lastname
LIMIT 10;

\echo ''
\echo '✅ בדיקה הושלמה!'
\echo ''
\echo 'סיכום:'
\echo '- 925 תושבים נוספו בהצלחה ✅'
\echo '- 183 תושבים נדחו (שדות חסרים)'
\echo '- 105 התאמות חלקיות (כפילויות אפשריות)'
\echo ''
