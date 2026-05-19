-- Archive table for sync_operations_log rows older than 30 days.
-- Matches the hot table schema exactly (INCLUDING ALL copies constraints + indexes).
CREATE TABLE IF NOT EXISTS sync_operations_log_archive
  (LIKE sync_operations_log INCLUDING ALL);
