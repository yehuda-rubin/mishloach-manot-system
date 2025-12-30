-- ========================================
-- תיקון סופי - process_residents_csv
-- הוספת code ב-INSERT INTO person
-- ========================================

\echo '🔧 מעדכן את הפונקציה process_residents_csv...'

DROP FUNCTION IF EXISTS public.process_residents_csv();

CREATE FUNCTION public.process_residents_csv() RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    rec RECORD;
    existing_person INTEGER;
    clean_phone TEXT;
    clean_mobile TEXT;
    clean_mobile2 TEXT;
    rows_processed INTEGER := 0;
BEGIN
    FOR rec IN 
        SELECT * FROM temp_residents_csv 
        WHERE (status IS NULL OR status = '')
        ORDER BY temp_id
    LOOP
        -- ניקוי טלפונים
        clean_phone   := format_il_phone(rec.phone);
        clean_mobile  := format_il_phone(rec.mobile);
        clean_mobile2 := format_il_phone(rec.mobile2);

        -- בדיקה 1: exact match
        IF EXISTS (
            SELECT 1 FROM person p
            WHERE
                LOWER(TRIM(COALESCE(p.lastname, '')))    = LOWER(TRIM(COALESCE(rec.lastname, '')))
                AND LOWER(TRIM(COALESCE(p.father_name, '')))  = LOWER(TRIM(COALESCE(rec.father_name, '')))
                AND LOWER(TRIM(COALESCE(p.mother_name, '')))  = LOWER(TRIM(COALESCE(rec.mother_name, '')))
                AND COALESCE(p.streetcode, 0)            = COALESCE(rec.streetcode, 0)
                AND COALESCE(p.buildingnumber, '')       = COALESCE(rec.buildingnumber, '')
                AND COALESCE(p.apartmentnumber, '')      = COALESCE(rec.apartmentnumber, '')
        ) THEN
            SELECT p.personid INTO existing_person
            FROM person p
            WHERE
                LOWER(TRIM(COALESCE(p.lastname, '')))    = LOWER(TRIM(COALESCE(rec.lastname, '')))
                AND LOWER(TRIM(COALESCE(p.father_name, '')))  = LOWER(TRIM(COALESCE(rec.father_name, '')))
                AND LOWER(TRIM(COALESCE(p.mother_name, '')))  = LOWER(TRIM(COALESCE(rec.mother_name, '')))
                AND COALESCE(p.streetcode, 0)            = COALESCE(rec.streetcode, 0)
                AND COALESCE(p.buildingnumber, '')       = COALESCE(rec.buildingnumber, '')
                AND COALESCE(p.apartmentnumber, '')      = COALESCE(rec.apartmentnumber, '')
            LIMIT 1;

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

        -- בדיקה 2: partial match
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
                rec.temp_id, NULL, 'partial_match', 'התאמה חלקית - דרוש מיזוג ידני',
                rec.lastname, rec.father_name, rec.mother_name,
                rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
            );

            UPDATE temp_residents_csv
            SET status = 'התאמה חלקית', processed_at = now()
            WHERE temp_id = rec.temp_id;

        -- אם חסרים שדות חובה - דחייה
        ELSIF rec.lastname IS NULL OR TRIM(rec.lastname) = ''
           OR rec.father_name IS NULL OR TRIM(rec.father_name) = ''
           OR rec.streetcode IS NULL
           OR rec.buildingnumber IS NULL OR TRIM(rec.buildingnumber) = ''
           OR rec.apartmentnumber IS NULL OR TRIM(rec.apartmentnumber) = ''
        THEN
            INSERT INTO person_archive(
                temp_id, personid_target, status, status_note,
                lastname, father_name, mother_name,
                streetcode, buildingnumber, entrance, apartmentnumber,
                phone, mobile, mobile2, email, standing_order
            )
            VALUES (
                rec.temp_id, NULL, 'skipped', 'חסרים שדות חובה',
                rec.lastname, rec.father_name, rec.mother_name,
                rec.streetcode, rec.buildingnumber, rec.entrance, rec.apartmentnumber,
                clean_phone, clean_mobile, clean_mobile2, rec.email, rec.standing_order
            );

            UPDATE temp_residents_csv
            SET status = 'נדחה', processed_at = now()
            WHERE temp_id = rec.temp_id;

        -- אחרת - הוספת רשומה חדשה
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

        rows_processed := rows_processed + 1;
    END LOOP;

    RETURN rows_processed;
END;
$$;

\echo '✅ הפונקציה עודכנה בהצלחה!'
\echo '✅ עכשיו code נשמר לכל תושב חדש!'
