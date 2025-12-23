-- ========================================
-- 03_seed.sql
-- נתוני דוגמה למערכת
-- ========================================

-- ====================
-- הגדרות מחירים
-- ====================

INSERT INTO public.delivery_settings (setting_name, setting_value) VALUES
('delivery_price', 10.00),
('symbolic_price', 11.00),
('respectable_price', 10.00),
('fancy_price', 9.00)
ON CONFLICT (setting_name) DO NOTHING;

-- ====================
-- רחובות
-- ====================

INSERT INTO public.street (streetcode, streetname) VALUES
(1, 'באר שבע'),
(2, 'בעל התניא'),
(3, 'הירקון'),
(4, 'הרב מנחם פרוש'),
(5, 'הרב קוק'),
(6, 'ירושלים'),
(7, 'תל אביב'),
(8, 'חיפה'),
(9, 'אילת'),
(10, 'צפת')
ON CONFLICT (streetcode) DO NOTHING;

-- ====================
-- דרגות מנות
-- ====================

INSERT INTO public.rating_levels (rating_value, min_amount, max_amount, description) VALUES
(1, 0, 0, 'סמלי - 11 ש"ח'),
(2, 21, 51, 'מכובד - 10 ש"ח (הנחה)'),
(3, 51, NULL, 'מפואר - 9 ש"ח (הנחה גדולה)')
ON CONFLICT (rating_id) DO NOTHING;

-- ====================
-- משתמש ברירת מחדל
-- ====================

-- סיסמה: admin123
INSERT INTO public.app_users (username, password_hash) VALUES
('admin', 'scrypt:32768:8:1$OHClD2y0RjNiLoqN$ba1a98d4ff34cadda0e02c3fb6f5ea9f4e68092e4d6c0b3e21c983e796ba565fd59066c46c8878b2ca8775a81e651ba11b8d1273f578fef4061907c8900ef631')
ON CONFLICT (username) DO NOTHING;

-- ====================
-- 100 משפחות לדוגמה
-- ====================

DO $$
DECLARE
    i INT;
    v_streetcode INT;
    v_building INT;
    v_apartment INT;
    v_phone TEXT;
    v_mobile TEXT;
    v_lastname TEXT;
    v_father_name TEXT;
    v_mother_name TEXT;
    lastnames TEXT[] := ARRAY[
        'כהן', 'לוי', 'ישראלי', 'מזרחי', 'אשכנזי', 'פרידמן', 'שפירא', 'גולדברג', 
        'רוזנברג', 'שוורץ', 'ברק', 'דוד', 'יעקב', 'משה', 'אברהם', 'יצחק',
        'שרה', 'רבקה', 'רחל', 'לאה', 'גרינברג', 'זילברמן', 'ברנשטיין', 'ויינשטיין',
        'קפלן', 'קרמר', 'שולמן', 'גוטמן', 'הלפרין', 'קליין', 'גרוס', 'ברגמן',
        'וייס', 'שטרן', 'בלום', 'רוזן', 'לנדאו', 'הורוויץ', 'אפשטיין', 'פינקלשטיין',
        'סילבר', 'גולד', 'פרל', 'דיאמנט', 'שטיין', 'זלצמן', 'פישר', 'וולף',
        'פוקס', 'בר', 'מנדל', 'ליברמן', 'שפרינג', 'וינטר', 'זומר', 'קציר'
    ];
    father_names TEXT[] := ARRAY[
        'אברהם', 'יצחק', 'יעקב', 'משה', 'אהרן', 'דוד', 'שלמה', 'יוסף',
        'בנימין', 'דן', 'נפתלי', 'גד', 'אשר', 'יששכר', 'זבולון', 'ראובן',
        'שמעון', 'לוי', 'יהודה', 'אפרים', 'מנשה', 'חיים', 'ברוך', 'אליעזר'
    ];
    mother_names TEXT[] := ARRAY[
        'שרה', 'רבקה', 'רחל', 'לאה', 'חנה', 'מרים', 'אסתר', 'דבורה',
        'יעל', 'חוה', 'טובה', 'בתיה', 'שושנה', 'נעמי', 'רות', 'חיה',
        'מלכה', 'דינה', 'תמר', 'ברכה', 'שרה', 'אביגיל', 'צפורה', 'חנני'
    ];
BEGIN
    FOR i IN 1..100 LOOP
        v_streetcode := (i % 10) + 1;
        v_building := (i % 50) + 1;
        v_apartment := (i % 20) + 1;
        v_phone := '0' || (CASE WHEN random() < 0.5 THEN '2' ELSE '3' END) || 
                   LPAD(FLOOR(random() * 10000000)::TEXT, 7, '0');
        v_mobile := '05' || (FLOOR(random() * 10))::TEXT || 
                    LPAD(FLOOR(random() * 1000000)::TEXT, 7, '0');
        v_lastname := lastnames[(FLOOR(random() * array_length(lastnames, 1)) + 1)::INT];
        v_father_name := father_names[(FLOOR(random() * array_length(father_names, 1)) + 1)::INT];
        v_mother_name := mother_names[(FLOOR(random() * array_length(mother_names, 1)) + 1)::INT];
        
        INSERT INTO public.person (
            lastname, father_name, mother_name,
            streetcode, buildingnumber, apartmentnumber,
            phone, mobile,
            standing_order, autoreturn
        ) VALUES (
            v_lastname, v_father_name, v_mother_name,
            v_streetcode, v_building::TEXT, v_apartment::TEXT,
            v_phone, v_mobile,
            (FLOOR(random() * 4))::INT,  -- 0-3
            random() < 0.3  -- 30% יקבלו autoreturn=true
        );
    END LOOP;
    
    RAISE NOTICE '✅ נוספו 100 משפחות';
END $$;

-- ====================
-- 500 הזמנות לדוגמה
-- ====================

DO $$
DECLARE
    i INT;
    v_sender_id INT;
    v_getter_id INT;
    v_package_sizes TEXT[] := ARRAY['סמלי', 'מכובד', 'מפואר'];
    v_package_size TEXT;
    v_price NUMERIC(10,2);
BEGIN
    FOR i IN 1..500 LOOP
        -- בחירת שולח ומקבל אקראיים
        v_sender_id := (FLOOR(random() * 100) + 1)::INT;
        v_getter_id := (FLOOR(random() * 100) + 1)::INT;
        
        -- מניעת שליחה לעצמו
        IF v_sender_id = v_getter_id THEN
            v_getter_id := (v_getter_id % 100) + 1;
        END IF;
        
        -- בחירת סוג מנה ומחיר
        v_package_size := v_package_sizes[(FLOOR(random() * 3) + 1)::INT];
        v_price := CASE v_package_size
            WHEN 'סמלי' THEN 11.00
            WHEN 'מכובד' THEN 10.00
            ELSE 9.00
        END;
        
        INSERT INTO public."Order" (
            delivery_sender_id, delivery_getter_id,
            order_date, package_size, price,
            origin_type
        ) VALUES (
            v_sender_id, v_getter_id,
            CURRENT_DATE - (FLOOR(random() * 30))::INT,
            v_package_size, v_price,
            CASE WHEN random() < 0.1 THEN 'autoreturn' ELSE 'invitees' END
        );
    END LOOP;
    
    RAISE NOTICE '✅ נוספו 500 הזמנות';
END $$;

-- ====================
-- 300 תשלומים לדוגמה
-- ====================

DO $$
DECLARE
    i INT;
    v_person_id INT;
    v_order_id INT;
    v_amount NUMERIC(10,2);
    v_payment_types TEXT[] := ARRAY['cash', 'credit', 'bank_transfer', 'check'];
    v_sources TEXT[] := ARRAY['outer_external', 'internal', 'autoreturn', 'system'];
BEGIN
    FOR i IN 1..300 LOOP
        v_person_id := (FLOOR(random() * 100) + 1)::INT;
        v_order_id := (FLOOR(random() * 500) + 1)::INT;
        v_amount := (FLOOR(random() * 500) + 10)::NUMERIC(10,2);
        
        INSERT INTO public.payment_ledger (
            person_id, order_id,
            payment_type, source, amount
        ) VALUES (
            v_person_id, v_order_id,
            v_payment_types[(FLOOR(random() * 4) + 1)::INT],
            v_sources[(FLOOR(random() * 4) + 1)::INT],
            v_amount
        );
    END LOOP;
    
    RAISE NOTICE '✅ נוספו 300 תשלומים';
END $$;

-- ====================
-- הודעת סיום
-- ====================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ כל נתוני הדוגמה נטענו בהצלחה!';
    RAISE NOTICE '   - 10 רחובות';
    RAISE NOTICE '   - 100 משפחות';
    RAISE NOTICE '   - 500 הזמנות';
    RAISE NOTICE '   - 300 תשלומים';
    RAISE NOTICE '========================================';
END $$;
