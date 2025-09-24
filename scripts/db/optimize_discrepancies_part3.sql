-- ====================================================================================================
-- PARTE 3: MATERIALIZED VIEW
-- ====================================================================================================

-- Criar vista materializada para queries complexas
CREATE MATERIALIZED VIEW IF NOT EXISTS discrepancy_summary_mv AS
SELECT
    sd.server_id,
    s.name AS server_name,
    s.environment,
    COUNT(*) AS total_discrepancies,
    COUNT(*) FILTER (WHERE sd.status = 'pending') AS pending_count,
    COUNT(*) FILTER (WHERE sd.status = 'corrected') AS corrected_count,
    COUNT(*) FILTER (WHERE sd.status = 'accepted') AS accepted_count,
    COUNT(*) FILTER (WHERE sd.type = 'unmanaged_user') AS unmanaged_users,
    COUNT(*) FILTER (WHERE sd.type IN ('extra_permission', 'missing_permission')) AS permission_issues,
    MAX(sd.detected_at) AS last_detected,
    MIN(sd.detected_at) FILTER (WHERE sd.status = 'pending') AS oldest_pending
FROM sync_discrepancies sd
JOIN servers s ON s.id = sd.server_id
GROUP BY sd.server_id, s.name, s.environment;

CREATE UNIQUE INDEX IF NOT EXISTS idx_disc_summary_mv_server ON discrepancy_summary_mv(server_id);
CREATE INDEX IF NOT EXISTS idx_disc_summary_mv_env ON discrepancy_summary_mv(environment);

-- Trigger para atualizar estatísticas (simplificado)
CREATE OR REPLACE FUNCTION trigger_update_discrepancy_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        PERFORM update_discrepancy_stats(NEW.server_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger se não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_discrepancy_stats_trigger'
    ) THEN
        CREATE TRIGGER update_discrepancy_stats_trigger
        AFTER INSERT OR UPDATE OF status ON sync_discrepancies
        FOR EACH ROW
        EXECUTE FUNCTION trigger_update_discrepancy_stats();
    END IF;
END;
$$ LANGUAGE plpgsql;