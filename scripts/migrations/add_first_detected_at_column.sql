-- Migration: Add first_detected_at column to sync_discrepancies table
-- This migration is safe to run multiple times (uses IF NOT EXISTS)

-- Add first_detected_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sync_discrepancies' 
        AND column_name = 'first_detected_at'
    ) THEN
        ALTER TABLE sync_discrepancies 
        ADD COLUMN first_detected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
        
        -- Initialize existing records with detected_at value
        UPDATE sync_discrepancies 
        SET first_detected_at = detected_at 
        WHERE first_detected_at IS NULL;
        
        RAISE NOTICE 'Column first_detected_at added to sync_discrepancies table and initialized';
    ELSE
        RAISE NOTICE 'Column first_detected_at already exists in sync_discrepancies table';
    END IF;
END $$;

-- Create index for better performance if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_first_detected_at 
ON sync_discrepancies(first_detected_at);

-- Add comment for documentation
COMMENT ON COLUMN sync_discrepancies.first_detected_at IS 'Timestamp when the discrepancy was first detected (never updated)';