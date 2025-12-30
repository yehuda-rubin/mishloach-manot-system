-- ========================================
-- תיקון מהיר - בעיית distribute_all_outer_orders
-- ========================================

\echo '🔧 מתקן את פונקציית distribute_all_outer_orders...'

-- הפונקציה המתוקנת
CREATE OR REPLACE FUNCTION "public"."distribute_all_outer_orders"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  rec RECORD;
  v_sender_id INT;
  v_excel_id INT;
  v_rows_this_rec INT;
  v_total_inserted INT := 0;
  v_delivery_price NUMERIC(10,2);
BEGIN
  -- 🧩 שלב 1: שלוף מחיר משלוח או קבע ברירת מחדל 10.00
  SELECT COALESCE(
    (SELECT setting_value::NUMERIC(10,2)
     FROM public.delivery_settings
     WHERE setting_name = 'delivery_price'
     LIMIT 1),
    10.00
  ) INTO v_delivery_price;

  -- 🧩 שלב 2: עיבוד ההזמנות
  FOR rec IN
    SELECT * FROM public.outerapporder
    WHERE status = 'waiting'
    ORDER BY id
  LOOP
    v_rows_this_rec := 0;
    v_sender_id := public.normalize_sender_code(rec.sender_code::text);
    v_excel_id  := rec.id;

    IF rec.invitees IS NULL OR rec.invitees = '' THEN
      INSERT INTO public.outerapporder_error_log(outer_id, severity, reason_code, message, details)
      VALUES (rec.id, 'error', 'no_invitees', 'אין מוזמנים להזמנה זו (invitees ריק)',
              jsonb_build_object('sender_code', rec.sender_code));

      UPDATE public.outerapporder
      SET status = 'error',
          processed_at = NOW(),
          error_message = 'אין מוזמנים להזמנה זו'
      WHERE id = rec.id;
      CONTINUE;
    END IF;

    -- בדיקה אם השולח קיים
    IF NOT EXISTS (SELECT 1 FROM public.person WHERE personid = v_sender_id) THEN
      INSERT INTO public.outerapporder_error_log(outer_id, severity, reason_code, message, details)
      VALUES (
        rec.id,
        'error',
        'missing_sender',
        format('שולח %s לא קיים בטבלת person', v_sender_id),
        jsonb_build_object('sender_code', rec.sender_code)
      );

      UPDATE public.outerapporder
      SET status = 'error',
          processed_at = NOW(),
          error_message = 'שולח לא קיים בטבלת person'
      WHERE id = rec.id;

      CONTINUE;
    END IF;

    -- הכנסת ההזמנות עצמן
    WITH tokens AS (
      SELECT regexp_split_to_table(rec.invitees, '\|') AS token
    ),
    cleaned AS (
      SELECT NULLIF(trim(token), '') AS token_trim FROM tokens
    ),
    ints AS (
      SELECT DISTINCT token_trim::int AS invitee_id
      FROM cleaned
      WHERE token_trim ~ '^\d+$'
    )
    INSERT INTO public."Order"(
        delivery_sender_id,
        delivery_getter_id,
        order_date,
        excel_import_id,
        origin_type,
        origin_outer_id,
        price,
        package_size
    )
    SELECT 
        v_sender_id, 
        i.invitee_id, 
        CURRENT_DATE, 
        v_excel_id, 
        'invitees', 
        v_excel_id,
        v_delivery_price,
        rec.package_size
    FROM ints i
    WHERE EXISTS (SELECT 1 FROM public.person p WHERE p.personid = i.invitee_id)
    ON CONFLICT DO NOTHING;
    -- ✅ תיקון: הסרנו RETURNING INTO כי מוחזרות מספר שורות

    GET DIAGNOSTICS v_rows_this_rec = ROW_COUNT;

    IF v_rows_this_rec = 0 THEN
      INSERT INTO public.outerapporder_error_log(outer_id, severity, reason_code, message, details)
      VALUES (rec.id, 'warning', 'no_valid_invitees', 'אף מוזמן תקין לא נמצא',
              jsonb_build_object('raw_invitees', rec.invitees));
    END IF;

    v_total_inserted := v_total_inserted + v_rows_this_rec;

    UPDATE public.outerapporder
    SET status = 'success',
        processed_at = NOW(),
        success_count = v_rows_this_rec
    WHERE id = rec.id;
  END LOOP;

  RETURN v_total_inserted;
END;
$_$;

\echo '✅ הפונקציה תוקנה!'
\echo ''
\echo 'עכשיו אפשר להעלות את קובץ ההזמנות מחדש!'
