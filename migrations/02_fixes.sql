-- ========================================
-- 02_fixes.sql
-- תיקונים ושיפורים לסכמה
-- ========================================

-- ייצור טבלת משתמשים למערכת האימות
CREATE TABLE IF NOT EXISTS public.app_users (
    user_id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP
);

-- הוספת קולום batch_id לטבלת outerapporder למעקב אחר העלאות
ALTER TABLE public.outerapporder 
ADD COLUMN IF NOT EXISTS batch_id UUID DEFAULT gen_random_uuid();

ALTER TABLE public.outerapporder 
ADD COLUMN IF NOT EXISTS uploaded_by TEXT;

-- הוספת אינדקס לשיפור ביצועים
CREATE INDEX IF NOT EXISTS idx_order_sender ON public."Order"(delivery_sender_id);
CREATE INDEX IF NOT EXISTS idx_order_getter ON public."Order"(delivery_getter_id);
CREATE INDEX IF NOT EXISTS idx_order_date ON public."Order"(order_date);
CREATE INDEX IF NOT EXISTS idx_outerapporder_status ON public.outerapporder(status);

-- ייצור טריגר לעדכון אוטומטי של autoreturn
CREATE OR REPLACE FUNCTION trigger_autoreturn() RETURNS TRIGGER AS $$
BEGIN
    -- כשנוצרת הזמנה חדשה, הפעל autoreturn אם רלוונטי
    IF NEW.origin_type != 'autoreturn' THEN
        PERFORM apply_autoreturn_from_outer(NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_order_insert ON public."Order";
CREATE TRIGGER after_order_insert
    AFTER INSERT ON public."Order"
    FOR EACH ROW
    EXECUTE FUNCTION trigger_autoreturn();

-- ========================================
-- פונקציות משופרות שמחזירות ספירה
-- ========================================

-- מחיקת הפונקציה הישנה כדי למנוע שגיאות
DROP FUNCTION IF EXISTS "public"."raw_to_temp_stage"();

-- גרסה משופרת של raw_to_temp_stage שמחזירה מספר שורות
CREATE FUNCTION "public"."raw_to_temp_stage"() RETURNS INTEGER
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
    rows_inserted INTEGER;
BEGIN
  -- ניקוי טבלת TEMP לפני טעינה חדשה
  TRUNCATE TABLE public.temp_residents_csv RESTART IDENTITY;

  -- שלב 1: רישום רחובות חדשים שלא קיימים בטבלת street ללוג
  INSERT INTO public.missing_streets_log (streetname)
  SELECT DISTINCT TRIM(r.streetname)
  FROM public.raw_residents_csv r
  WHERE NOT EXISTS (
      SELECT 1 FROM public.street s
      WHERE LOWER(TRIM(s.streetname)) = LOWER(TRIM(r.streetname))
  )
  AND TRIM(r.streetname) IS NOT NULL
  AND TRIM(r.streetname) != '';

  -- שלב 2: הוספת רחובות חדשים אוטומטית
  INSERT INTO public.street (streetname)
  SELECT DISTINCT TRIM(r.streetname)
  FROM public.raw_residents_csv r
  WHERE TRIM(r.streetname) IS NOT NULL 
    AND TRIM(r.streetname) != ''
    AND NOT EXISTS (
        SELECT 1 FROM public.street s 
        WHERE LOWER(TRIM(s.streetname)) = LOWER(TRIM(r.streetname))
    )
  ON CONFLICT (streetcode) DO NOTHING;
  
  -- שלב 3: העתקת נתונים ל-TEMP עם ה-streetcode הנכון
  INSERT INTO public.temp_residents_csv (
      code, lastname, father_name, mother_name,
      streetcode, streetname, buildingnumber, entrance, apartmentnumber,
      phone, mobile, mobile2, email, standing_order
  )
  SELECT
      CASE 
          WHEN r.code IS NOT NULL AND TRIM(r.code) != '' 
          THEN CAST(TRIM(r.code) AS INTEGER)
          ELSE NULL 
      END,
      TRIM(r.lastname),
      TRIM(r.father_name),
      TRIM(r.mother_name),
      s.streetcode,  -- עכשיו תמיד יהיה streetcode כי הוספנו את כל הרחובות!
      TRIM(r.streetname),
      TRIM(r.buildingnumber),
      TRIM(r.entrance),
      TRIM(r.apartmentnumber),
      TRIM(r.phone),
      TRIM(r.mobile),
      TRIM(r.mobile2),
      normalize_email(r.email),
      COALESCE(r.standing_order, 0)
  FROM public.raw_residents_csv r
  INNER JOIN public.street s  -- שימו לב: INNER JOIN במקום LEFT JOIN!
      ON LOWER(TRIM(s.streetname)) = LOWER(TRIM(r.streetname));

  GET DIAGNOSTICS rows_inserted = ROW_COUNT;
  RETURN rows_inserted;
END;
$_$;

-- גרסה משופרת של process_residents_csv שמחזירה מספר שורות מעובדות
-- מחיקת הפונקציה הישנה כדי למנוע שגיאות
DROP FUNCTION IF EXISTS "public"."process_residents_csv"();

CREATE FUNCTION "public"."process_residents_csv"() RETURNS INTEGER
    LANGUAGE "plpgsql"
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
    FOR rec IN SELECT * FROM temp_residents_csv WHERE status IS NULL OR status = '' ORDER BY temp_id
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
        -- דרישות חובה: lastname, father_name, streetname, buildingnumber, apartmentnumber
        -- (כדי לזהות בוודאות את האדם הנכון למשלוח)
        -- שים לב: רחובות חדשים מתווספים אוטומטית, אז לא צריך לבדוק streetcode=999
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
                
                -- Remove trailing comma and space
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

DO $$
BEGIN
    RAISE NOTICE '✅ Fixes applied successfully!';
END $$;
