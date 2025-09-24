-- Função de análise de performance
DROP FUNCTION IF EXISTS analyze_discrepancy_performance();

CREATE FUNCTION analyze_discrepancy_performance()
RETURNS TABLE(
    metric_name TEXT,
    metric_value NUMERIC,
    description TEXT
)
LANGUAGE sql
AS '
    SELECT ''total_records''::TEXT,
           COUNT(*)::NUMERIC,
           ''Total de discrepâncias no sistema''::TEXT
    FROM sync_discrepancies
    UNION ALL
    SELECT ''pending_records''::TEXT,
           COUNT(*)::NUMERIC,
           ''Total de discrepâncias pendentes''::TEXT
    FROM sync_discrepancies
    WHERE status = ''pending''
    UNION ALL
    SELECT ''table_size_mb''::TEXT,
           pg_relation_size(''sync_discrepancies'')::NUMERIC / 1024 / 1024,
           ''Tamanho da tabela em MB''::TEXT
    UNION ALL
    SELECT ''index_size_mb''::TEXT,
           COALESCE(SUM(pg_relation_size(indexrelid))::NUMERIC / 1024 / 1024, 0),
           ''Tamanho total dos índices em MB''::TEXT
    FROM pg_index
    WHERE indrelid = ''sync_discrepancies''::regclass
';