-- ====================================================================================================
-- PARTE 1: ÍNDICES OTIMIZADOS
-- ====================================================================================================

-- Remover índices existentes que serão substituídos
DROP INDEX IF EXISTS idx_sync_discrepancies_server;
DROP INDEX IF EXISTS idx_sync_discrepancies_status;
DROP INDEX IF EXISTS idx_sync_discrepancies_type;
DROP INDEX IF EXISTS idx_discrepancy_dashboard_view;

-- Criar índices compostos otimizados
CREATE INDEX IF NOT EXISTS idx_disc_status_detected_server
ON sync_discrepancies(status, detected_at DESC, server_id)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_disc_server_status_type_detected
ON sync_discrepancies(server_id, status, type, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_disc_pending_count
ON sync_discrepancies(server_id, status)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_disc_not_corrected
ON sync_discrepancies(corrected, detected_at DESC)
WHERE corrected = false;

CREATE INDEX IF NOT EXISTS idx_disc_username_status
ON sync_discrepancies(username, status, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_disc_accepted
ON sync_discrepancies(status, accepted_by, detected_at DESC)
WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS idx_disc_detected_at_partition
ON sync_discrepancies(detected_at, server_id);

-- Ajustar fill factor
ALTER TABLE sync_discrepancies SET (fillfactor = 85);

-- Atualizar estatísticas
ANALYZE sync_discrepancies;