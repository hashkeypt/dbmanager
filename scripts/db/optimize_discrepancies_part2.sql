-- ====================================================================================================
-- PARTE 2: TABELAS E FUNÇÕES DE ESTATÍSTICAS
-- ====================================================================================================

-- Criar tabela de estatísticas agregadas
CREATE TABLE IF NOT EXISTS sync_discrepancy_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    stat_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_count INTEGER DEFAULT 0,
    pending_count INTEGER DEFAULT 0,
    corrected_count INTEGER DEFAULT 0,
    accepted_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    by_type JSONB DEFAULT '{}',
    by_username JSONB DEFAULT '{}',
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(server_id, stat_date)
);

CREATE INDEX IF NOT EXISTS idx_disc_stats_server_date ON sync_discrepancy_stats(server_id, stat_date DESC);

-- Função para atualizar estatísticas
CREATE OR REPLACE FUNCTION update_discrepancy_stats(p_server_id VARCHAR(36))
RETURNS void AS $$
BEGIN
    INSERT INTO sync_discrepancy_stats (
        server_id,
        stat_date,
        total_count,
        pending_count,
        corrected_count,
        accepted_count,
        error_count,
        last_updated
    )
    SELECT
        p_server_id,
        CURRENT_DATE,
        COUNT(*) AS total_count,
        COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
        COUNT(*) FILTER (WHERE status = 'corrected') AS corrected_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_count,
        COUNT(*) FILTER (WHERE status = 'error') AS error_count,
        CURRENT_TIMESTAMP
    FROM sync_discrepancies
    WHERE server_id = p_server_id
    AND detected_at >= CURRENT_DATE - INTERVAL '7 days'
    ON CONFLICT (server_id, stat_date)
    DO UPDATE SET
        total_count = EXCLUDED.total_count,
        pending_count = EXCLUDED.pending_count,
        corrected_count = EXCLUDED.corrected_count,
        accepted_count = EXCLUDED.accepted_count,
        error_count = EXCLUDED.error_count,
        last_updated = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Função de limpeza de discrepâncias antigas
CREATE OR REPLACE FUNCTION cleanup_old_discrepancies(
    p_days_to_keep INTEGER DEFAULT 30,
    p_batch_size INTEGER DEFAULT 1000
)
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER := 0;
    v_batch_deleted INTEGER;
BEGIN
    LOOP
        DELETE FROM sync_discrepancies
        WHERE id IN (
            SELECT id
            FROM sync_discrepancies
            WHERE status IN ('corrected', 'accepted')
            AND detected_at < CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL
            LIMIT p_batch_size
        );

        GET DIAGNOSTICS v_batch_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_batch_deleted;
        EXIT WHEN v_batch_deleted = 0;
        PERFORM pg_sleep(0.1);
    END LOOP;

    ANALYZE sync_discrepancies;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Função para análise de performance
CREATE OR REPLACE FUNCTION analyze_discrepancy_performance()
RETURNS TABLE(
    metric_name TEXT,
    metric_value NUMERIC,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'total_records'::TEXT,
           COUNT(*)::NUMERIC,
           'Total de discrepâncias no sistema'::TEXT
    FROM sync_discrepancies
    UNION ALL
    SELECT 'pending_records'::TEXT,
           COUNT(*)::NUMERIC,
           'Total de discrepâncias pendentes'::TEXT
    FROM sync_discrepancies
    WHERE status = 'pending'
    UNION ALL
    SELECT 'table_size_mb'::TEXT,
           pg_relation_size('sync_discrepancies')::NUMERIC / 1024 / 1024,
           'Tamanho da tabela em MB'::TEXT
    UNION ALL
    SELECT 'index_size_mb'::TEXT,
           COALESCE(SUM(pg_relation_size(indexrelid))::NUMERIC / 1024 / 1024, 0),
           'Tamanho total dos índices em MB'::TEXT
    FROM pg_index
    WHERE indrelid = 'sync_discrepancies'::regclass;
END;
$$ LANGUAGE plpgsql;