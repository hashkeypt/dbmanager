-- ====================================================================================================
-- SCRIPT DE OTIMIZAÇÃO DE PERFORMANCE PARA SISTEMA DE DISCREPÂNCIAS
-- Objetivo: Permitir que o sistema suporte dezenas de milhares de discrepâncias
-- ====================================================================================================

-- 1. REMOVER ÍNDICES EXISTENTES QUE SERÃO SUBSTITUÍDOS
-- ====================================================================================================
DROP INDEX IF EXISTS idx_sync_discrepancies_server;
DROP INDEX IF EXISTS idx_sync_discrepancies_status;
DROP INDEX IF EXISTS idx_sync_discrepancies_type;
DROP INDEX IF EXISTS idx_discrepancy_dashboard_view;

-- 2. CRIAR ÍNDICES COMPOSTOS OTIMIZADOS
-- ====================================================================================================

-- Índice principal para queries de dashboard com status pendente
CREATE INDEX IF NOT EXISTS idx_disc_status_detected_server
ON sync_discrepancies(status, detected_at DESC, server_id)
WHERE status = 'pending';

-- Índice para queries por servidor com status e tipo
CREATE INDEX IF NOT EXISTS idx_disc_server_status_type_detected
ON sync_discrepancies(server_id, status, type, detected_at DESC);

-- Índice para contagem rápida de discrepâncias pendentes por servidor
CREATE INDEX IF NOT EXISTS idx_disc_pending_count
ON sync_discrepancies(server_id, status)
WHERE status = 'pending';

-- Índice para queries de discrepâncias não corrigidas
CREATE INDEX IF NOT EXISTS idx_disc_not_corrected
ON sync_discrepancies(corrected, detected_at DESC)
WHERE corrected = false;

-- Índice para busca por usuário
CREATE INDEX IF NOT EXISTS idx_disc_username_status
ON sync_discrepancies(username, status, detected_at DESC);

-- Índice para queries de discrepâncias aceitas
CREATE INDEX IF NOT EXISTS idx_disc_accepted
ON sync_discrepancies(status, accepted_by, detected_at DESC)
WHERE status = 'accepted';

-- 3. CRIAR TABELA DE ESTATÍSTICAS AGREGADAS (CACHE)
-- ====================================================================================================
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

CREATE INDEX idx_disc_stats_server_date ON sync_discrepancy_stats(server_id, stat_date DESC);

-- 4. CRIAR FUNÇÃO PARA ATUALIZAR ESTATÍSTICAS
-- ====================================================================================================
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
        by_type,
        by_username,
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
        jsonb_object_agg(type, type_count) FILTER (WHERE type IS NOT NULL) AS by_type,
        jsonb_object_agg(username, user_count) FILTER (WHERE username IS NOT NULL AND user_rank <= 10) AS by_username,
        CURRENT_TIMESTAMP
    FROM (
        SELECT
            status,
            type,
            username,
            COUNT(*) OVER (PARTITION BY type) AS type_count,
            COUNT(*) OVER (PARTITION BY username) AS user_count,
            ROW_NUMBER() OVER (PARTITION BY username ORDER BY COUNT(*) DESC) AS user_rank
        FROM sync_discrepancies
        WHERE server_id = p_server_id
        AND detected_at >= CURRENT_DATE - INTERVAL '7 days'
    ) sub
    ON CONFLICT (server_id, stat_date)
    DO UPDATE SET
        total_count = EXCLUDED.total_count,
        pending_count = EXCLUDED.pending_count,
        corrected_count = EXCLUDED.corrected_count,
        accepted_count = EXCLUDED.accepted_count,
        error_count = EXCLUDED.error_count,
        by_type = EXCLUDED.by_type,
        by_username = EXCLUDED.by_username,
        last_updated = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- 5. CRIAR TRIGGER PARA ATUALIZAR ESTATÍSTICAS AUTOMATICAMENTE
-- ====================================================================================================
CREATE OR REPLACE FUNCTION trigger_update_discrepancy_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Atualiza estatísticas apenas se houver mudança significativa
    IF TG_OP = 'INSERT' OR
       (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        PERFORM update_discrepancy_stats(NEW.server_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger apenas para mudanças importantes
CREATE TRIGGER update_discrepancy_stats_trigger
AFTER INSERT OR UPDATE OF status ON sync_discrepancies
FOR EACH ROW
EXECUTE FUNCTION trigger_update_discrepancy_stats();

-- 6. CRIAR VISTA MATERIALIZADA PARA QUERIES COMPLEXAS
-- ====================================================================================================
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

CREATE UNIQUE INDEX idx_disc_summary_mv_server ON discrepancy_summary_mv(server_id);
CREATE INDEX idx_disc_summary_mv_env ON discrepancy_summary_mv(environment);

-- 7. CRIAR PROCEDIMENTO PARA LIMPEZA DE DISCREPÂNCIAS ANTIGAS
-- ====================================================================================================
CREATE OR REPLACE FUNCTION cleanup_old_discrepancies(
    p_days_to_keep INTEGER DEFAULT 30,
    p_batch_size INTEGER DEFAULT 1000
)
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER := 0;
    v_batch_deleted INTEGER;
BEGIN
    -- Deletar discrepâncias resolvidas mais antigas que p_days_to_keep
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

        -- Sair quando não houver mais registros para deletar
        EXIT WHEN v_batch_deleted = 0;

        -- Pequena pausa para não sobrecarregar o banco
        PERFORM pg_sleep(0.1);
    END LOOP;

    -- Atualizar estatísticas das tabelas
    ANALYZE sync_discrepancies;

    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 8. CRIAR ÍNDICE PARA PARTICIONAMENTO FUTURO
-- ====================================================================================================
-- Preparação para particionamento por data se necessário
CREATE INDEX IF NOT EXISTS idx_disc_detected_at_partition
ON sync_discrepancies(detected_at, server_id);

-- 9. OTIMIZAR CONFIGURAÇÕES DA TABELA
-- ====================================================================================================
-- Ajustar fill factor para reduzir fragmentação em updates frequentes
ALTER TABLE sync_discrepancies SET (fillfactor = 85);

-- 10. CRIAR FUNÇÃO PARA ANÁLISE DE PERFORMANCE
-- ====================================================================================================
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

    SELECT 'avg_records_per_server'::TEXT,
           AVG(cnt)::NUMERIC,
           'Média de discrepâncias por servidor'::TEXT
    FROM (
        SELECT server_id, COUNT(*) as cnt
        FROM sync_discrepancies
        GROUP BY server_id
    ) sub

    UNION ALL

    SELECT 'max_records_per_server'::TEXT,
           MAX(cnt)::NUMERIC,
           'Máximo de discrepâncias em um servidor'::TEXT
    FROM (
        SELECT server_id, COUNT(*) as cnt
        FROM sync_discrepancies
        GROUP BY server_id
    ) sub

    UNION ALL

    SELECT 'table_size_mb'::TEXT,
           pg_relation_size('sync_discrepancies')::NUMERIC / 1024 / 1024,
           'Tamanho da tabela em MB'::TEXT

    UNION ALL

    SELECT 'index_size_mb'::TEXT,
           SUM(pg_relation_size(indexrelid))::NUMERIC / 1024 / 1024,
           'Tamanho total dos índices em MB'::TEXT
    FROM pg_index
    WHERE indrelid = 'sync_discrepancies'::regclass;
END;
$$ LANGUAGE plpgsql;

-- 11. ATUALIZAR ESTATÍSTICAS
-- ====================================================================================================
ANALYZE sync_discrepancies;

-- 12. VERIFICAR E REPORTAR MELHORIAS
-- ====================================================================================================
DO $$
BEGIN
    RAISE NOTICE 'Otimizações de performance aplicadas com sucesso!';
    RAISE NOTICE 'Execute SELECT * FROM analyze_discrepancy_performance() para ver métricas';
    RAISE NOTICE 'Execute REFRESH MATERIALIZED VIEW discrepancy_summary_mv periodicamente';
END $$;