-- Fires pg_notify every time a row is inserted into sync_operations_log.
-- The channel name is 'sync_company_<company_id>' so each company's
-- SSE clients only wake up for their own data.

CREATE OR REPLACE FUNCTION notify_sync_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('sync_company_' || NEW.company_id::text, '');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_operations_log_notify ON sync_operations_log;
CREATE TRIGGER sync_operations_log_notify
  AFTER INSERT ON sync_operations_log
  FOR EACH ROW
  EXECUTE FUNCTION notify_sync_change();
