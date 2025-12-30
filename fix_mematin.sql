-- ========================================
-- תיקון מהיר - בעיית status='ממתין'
-- ========================================

\echo '🔧 מתקן את בעיית ממתין...'

-- שלב 1: עדכון שורות קיימות עם status='ממתין' ל-NULL
UPDATE temp_residents_csv 
SET status = NULL 
WHERE status = 'ממתין';

\echo '✅ עודכנו שורות עם status=ממתין ל-NULL'

-- שלב 2: עדכון הפונקציה לתמוך ב-'ממתין' בעתיד
DROP FUNCTION IF EXISTS public.process_residents_csv();

CREATE FUNCTION public.process_residents_csv() RETURNS INTEGER
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
    existing_person INT;
    clean_phone TEXT;
    clean_mobile TEXT;
    clean_mobile2 TEXT;
    rows_processed INTEGER := 0;
BEGIN
    -- לולאה על כל שורה ב-temp_residents_csv
    -- ✅ תיקון: תומך גם ב-status = 'ממתין'
    FOR rec IN SELECT * FROM temp_residents_csv 
        WHERE status IS NULL OR status = '' OR status = 'ממתין'
        ORDER BY temp_id
    LOOP
        rows_processed := rows_processed + 1;
        
        -- נירמול טלפונים
        clean_phone := format_il_phone(rec.phone);
        clean_mobile := format_il_phone(rec.mobile);
        clean_mobile2 := format_il_phone(rec.mobile2);

        ------------------------------------------------------------------
        -- 🔍 בדיקה 1: התאמה מלאה → merged
        ------------------------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM person p
            WHERE LOWER(TRIM(p.lastname)) = LOWER(TRIM(rec.lastname))
              AND LOWER(TRIM(p.father_name)) = LOWER(TRIM(rec.father_name))
              AND (
                    format_il_phone(p.phone) = clean_phone OR
                    format_il_phone(p.mobile) = clean_mobile OR
                    format_il_phone(p.mobile2) = clean_mobile2
              )
              AND COALESCE(p.streetcode, 0) = COALESCE(rec.streetcode, 0)
              AND COALESCE(p.buildingnumber, '') = COALESCE(rec.buildingnumber, '')
              AND COALESCE(p.apartmentnumber, '') = COALESCE(rec.apartmentnumber, '')
        ) THEN
            -- מציאת ה-personid
            SELECT personid INTO existing_person
            FROM person p
            WHERE LOWER(TRIM(p.lastname)) = LOWER(TRIM(rec.lastname))
              AND LOWER(TRIM(p.father_name)) = LOWER(TRIM(rec.father_name))
              AND (
                    format_il_phone(p.phone) = clean_phone OR
                    format_il_phone(p.mobile) = clean_mobile OR
                    format_il_phone(p.mobile2) = clean_mobile2
              )
              AND COALESCE(p.streetcode, 0) = COALESCE(rec.streetcode, 0)
              AND COALESCE(p.buildingnumber, '') = COALESCE(rec.buildingnumber, '')
              AND COALESCE(p.apartmentnumber, '') = COALESCE(rec.apartmentnumber, '')
            LIMIT 1;

            -- עדכון נתונים
            UPDATE person
            SET
                mother_name = COALESCE(rec.mother_name, mother_name),
                entrance = COALESCE(rec.entrance, entrance),
                mobile2 = COALESCE(clean_mobile2, mobile2),
                email = COALESCE(rec.email, email),
                standing_order = COALESCE(rec.standing_order, standing_order)
            WHERE personid = existing_person;

            -- תיעוד לארכיון
            INSERT INTO person_archive(
                temp_id, personid_target, status, status_note,
                lastname, father_name, mother_name,
                streetcode, buildingnumber, entrance, apartmentnumber,
                phone, mobile, mobile2, email, standing_order
            )
            VALUES (
                rec.temp_id, existing_person, 'merged', 'אוחדה עם רשומה קיימת',
                rec.lastname, rec.father_name, rec.mother_name,
                rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
            );

            UPDATE temp_residents_csv
            SET status = 'אוחד', processed_at = now()
            WHERE temp_id = rec.temp_id;

        ------------------------------------------------------------------
        -- 🔍 בדיקה 2: התאמה חלקית → partial_match
        ------------------------------------------------------------------
        ELSIF EXISTS (
            SELECT 1 FROM person p
            WHERE
                format_il_phone(p.phone)   = clean_phone OR
                format_il_phone(p.mobile)  = clean_mobile OR
                format_il_phone(p.mobile2) = clean_mobile2 OR
                (
                    COALESCE(p.streetcode, 0) = COALESCE(rec.streetcode, 0)
                    AND COALESCE(p.buildingnumber, '') = COALESCE(rec.buildingnumber, '')
                    AND COALESCE(p.apartmentnumber, '') = COALESCE(rec.apartmentnumber, '')
                )
        ) THEN
            INSERT INTO person_archive(
                temp_id, personid_target, status, status_note,
                lastname, father_name, mother_name,
                streetcode, buildingnumber, entrance, apartmentnumber,
                phone, mobile, mobile2, email, standing_order
            )
            VALUES (
                rec.temp_id, NULL, 'partial_match', 'התאמה חלקית – טלפון או כתובת קיימים',
                rec.lastname, rec.father_name, rec.mother_name,
                rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
            );

            UPDATE temp_residents_csv
            SET status = 'התאמה חלקית', processed_at = now()
            WHERE temp_id = rec.temp_id;

        ------------------------------------------------------------------
        -- 🔍 בדיקה 3: נתונים חסרים → skipped
        ------------------------------------------------------------------
        ELSIF rec.lastname IS NULL OR TRIM(rec.lastname) = '' OR 
              rec.father_name IS NULL OR TRIM(rec.father_name) = '' OR
              rec.streetname IS NULL OR TRIM(rec.streetname) = '' OR
              rec.buildingnumber IS NULL OR TRIM(rec.buildingnumber) = '' OR
              rec.apartmentnumber IS NULL OR TRIM(rec.apartmentnumber) = '' THEN

            -- Build detailed error message
            DECLARE
                missing_fields TEXT := '';
            BEGIN
                IF rec.lastname IS NULL OR TRIM(rec.lastname) = '' THEN
                    missing_fields := missing_fields || 'שם משפחה, ';
                END IF;
                IF rec.father_name IS NULL OR TRIM(rec.father_name) = '' THEN
                    missing_fields := missing_fields || 'שם פרטי, ';
                END IF;
                IF rec.streetname IS NULL OR TRIM(rec.streetname) = '' THEN
                    missing_fields := missing_fields || 'רחוב, ';
                END IF;
                IF rec.buildingnumber IS NULL OR TRIM(rec.buildingnumber) = '' THEN
                    missing_fields := missing_fields || 'מספר בניין, ';
                END IF;
                IF rec.apartmentnumber IS NULL OR TRIM(rec.apartmentnumber) = '' THEN
                    missing_fields := missing_fields || 'מספר דירה, ';
                END IF;
                
                missing_fields := RTRIM(missing_fields, ', ');

                INSERT INTO person_archive(
                    temp_id, personid_target, status, status_note,
                    lastname, father_name, mother_name,
                    streetcode, buildingnumber, entrance, apartmentnumber,
                    phone, mobile, mobile2, email, standing_order
                )
                VALUES (
                    rec.temp_id, NULL, 'skipped', 'חסרים נתונים חיוניים: ' || missing_fields,
                    rec.lastname, rec.father_name, rec.mother_name,
                    rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                    clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
                );

                UPDATE temp_residents_csv
                SET status = 'נדחה', processed_at = now()
                WHERE temp_id = rec.temp_id;
            END;

        ------------------------------------------------------------------
        -- ✅ מצב 4: רשומה חדשה → inserted
        ------------------------------------------------------------------
        ELSE
            INSERT INTO person(
                code, lastname, father_name, mother_name,
                streetcode, buildingnumber, entrance, apartmentnumber,
                phone, mobile, mobile2, email, standing_order
            )
            VALUES (
                rec.code, rec.lastname, rec.father_name, rec.mother_name,
                rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
            )
            ON CONFLICT (code) DO UPDATE SET
                lastname = EXCLUDED.lastname,
                father_name = EXCLUDED.father_name,
                mother_name = EXCLUDED.mother_name,
                streetcode = EXCLUDED.streetcode,
                buildingnumber = EXCLUDED.buildingnumber,
                entrance = EXCLUDED.entrance,
                apartmentnumber = EXCLUDED.apartmentnumber,
                phone = EXCLUDED.phone,
                mobile = EXCLUDED.mobile,
                mobile2 = EXCLUDED.mobile2,
                email = EXCLUDED.email,
                standing_order = EXCLUDED.standing_order
            RETURNING personid INTO existing_person;

            INSERT INTO person_archive(
                temp_id, personid_target, status, status_note,
                lastname, father_name, mother_name,
                streetcode, buildingnumber, entrance, apartmentnumber,
                phone, mobile, mobile2, email, standing_order
            )
            VALUES (
                rec.temp_id, existing_person, 'inserted', 'נוספה רשומה חדשה',
                rec.lastname, rec.father_name, rec.mother_name,
                rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
            );

            UPDATE temp_residents_csv
            SET status = 'הופץ', processed_at = now()
            WHERE temp_id = rec.temp_id;
        END IF;

    END LOOP;
    
    RETURN rows_processed;
END;
$$;

\echo '✅ הפונקציה עודכנה לתמוך ב-status=ממתין'

-- שלב 3: הרץ את העיבוד עכשיו
SELECT process_residents_csv() AS rows_processed;

\echo '✅ תיקון הושלם!'
