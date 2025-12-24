-- ====================
-- Migration: Add streetcode 999 for unknown streets
-- ====================

-- Insert streetcode 999 as a fallback for unknown streets
INSERT INTO street (streetcode, streetname) VALUES 
(999, 'רחוב לא מזוהה - יש לעדכן!')
ON CONFLICT (streetcode) DO UPDATE 
SET streetname = 'רחוב לא מזוהה - יש לעדכן!';

-- Log the migration
DO $$
BEGIN
    RAISE NOTICE '✅ Added streetcode 999 for unknown streets';
END $$;
