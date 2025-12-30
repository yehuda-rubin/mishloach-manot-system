-- ========================================
-- תיקון מהיר עם CAST של code
-- ========================================

-- הוספת עמודת code (אם לא קיימת)
ALTER TABLE public.person 
ADD COLUMN IF NOT EXISTS code INTEGER;

ALTER TABLE public.person 
DROP CONSTRAINT IF EXISTS person_code_key;

ALTER TABLE public.person 
ADD CONSTRAINT person_code_key UNIQUE (code);

CREATE INDEX IF NOT EXISTS idx_person_code ON public.person(code);

ALTER TABLE public.temp_residents_csv 
ADD COLUMN IF NOT EXISTS code INTEGER;

-- עכשיו נעדכן את הפונקציה raw_to_temp_stage
DROP FUNCTION IF EXISTS public.raw_to_temp_stage();

CREATE FUNCTION public.raw_to_temp_stage() RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    rows_inserted INTEGER;
BEGIN
  -- שלב 1: ניקוי טבלת TEMP
  TRUNCATE TABLE public.temp_residents_csv RESTART IDENTITY;

  -- שלב 2: תיעוד רחובות חסרים
  INSERT INTO public.missing_streets_log (streetname)
  SELECT DISTINCT TRIM(r.streetname)
  FROM public.raw_residents_csv r
  WHERE NOT EXISTS (
      SELECT 1 FROM public.street s
      WHERE LOWER(TRIM(s.streetname)) = LOWER(TRIM(r.streetname))
  )
  AND TRIM(r.streetname) IS NOT NULL
  AND TRIM(r.streetname) != '';

  -- שלב 2.5: הוספה אוטומטית של רחובות חדשים
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
      s.streetcode,
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
  INNER JOIN public.street s
      ON LOWER(TRIM(s.streetname)) = LOWER(TRIM(r.streetname));

  GET DIAGNOSTICS rows_inserted = ROW_COUNT;
  RETURN rows_inserted;
END;
$$;

SELECT '✅ הפונקציה עודכנה עם CAST נכון!' as status;
