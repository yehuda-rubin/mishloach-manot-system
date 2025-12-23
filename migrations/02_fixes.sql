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

DO $$
BEGIN
    RAISE NOTICE '✅ Fixes applied successfully!';
END $$;
