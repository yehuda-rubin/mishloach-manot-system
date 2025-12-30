-- Add new columns to outerapporder to match Excel file structure
ALTER TABLE outerapporder ADD COLUMN IF NOT EXISTS station_name TEXT;
ALTER TABLE outerapporder ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10,2);
ALTER TABLE outerapporder ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE outerapporder ADD COLUMN IF NOT EXISTS card_last4 TEXT;
ALTER TABLE outerapporder ADD COLUMN IF NOT EXISTS transaction_id TEXT;
