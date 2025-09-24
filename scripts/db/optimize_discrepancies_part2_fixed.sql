-- ====================================================================================================
-- PARTE 2: TABELAS E FUNÇÕES DE ESTATÍSTICAS (CORRIGIDA)
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

-- Função para análise de performance (versão simplificada)
CREATE OR REPLACE FUNCTION analyze_discrepancy_performance()
RETURNS TABLE(
    metric_name TEXT,
    metric_value NUMERIC,
    description TEXT
)
LANGUAGE sql
AS $$
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
$$;