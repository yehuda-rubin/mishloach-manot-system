-- ========================================
-- 03_add_code_column.sql
-- הוספת עמודת code לטבלת person
-- ========================================

-- הוספת עמודת code לטבלת person
ALTER TABLE public.person 
ADD COLUMN IF NOT EXISTS code INTEGER UNIQUE;

-- יצירת אינדקס לחיפוש מהיר
CREATE INDEX IF NOT EXISTS idx_person_code ON public.person(code);

-- הוספת הערה
COMMENT ON COLUMN public.person.code IS 'קוד ייחודי למשפחה (מיובא מקובץ חיצוני)';

-- הוספת עמודת code גם ל-raw_residents_csv
ALTER TABLE public.raw_residents_csv 
ADD COLUMN IF NOT EXISTS code INTEGER;

-- הוספת עמודת code גם ל-temp_residents_csv
ALTER TABLE public.temp_residents_csv 
ADD COLUMN IF NOT EXISTS code INTEGER;

-- הערה להצלחה
DO $$
BEGIN
    RAISE NOTICE '✅ עמודת code נוספה בהצלחה לכל הטבלאות!';
END $$;
