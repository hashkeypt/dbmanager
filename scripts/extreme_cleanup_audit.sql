-- SCRIPT DE LIMPEZA EXTREMA - USE COM CUIDADO!
-- Este script remove MUITOS dados de uma vez

-- OPÇÃO 1: Manter apenas últimas 24 horas (muito agressivo)
BEGIN;

-- Verificar quantos registros serão deletados
SELECT 
    COUNT(*) as records_to_delete,
    pg_size_pretty(pg_total_relation_size('query_audit_log')) as current_size
FROM query_audit_log
WHERE captured_at < CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- Deletar tudo mais velho que 24 horas
DELETE FROM query_audit_log
WHERE captured_at < CURRENT_TIMESTAMP - INTERVAL '24 hours';

DELETE FROM query_audit_alerts
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- Se estiver OK, faça COMMIT, senão ROLLBACK
-- COMMIT;
-- ROLLBACK;

-- OPÇÃO 2: Manter apenas últimos 3 dias
BEGIN;

DELETE FROM query_audit_log
WHERE captured_at < CURRENT_TIMESTAMP - INTERVAL '3 days';

DELETE FROM query_audit_alerts
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '3 days';

-- COMMIT ou ROLLBACK
-- COMMIT;

-- OPÇÃO 3: NUCLEAR - Limpar TUDO e começar do zero
-- EXTREMO CUIDADO! Isso apaga TODOS os logs!
/*
TRUNCATE TABLE query_audit_alerts CASCADE;
TRUNCATE TABLE query_audit_log CASCADE;
*/

-- Após qualquer limpeza pesada, execute:
VACUUM FULL query_audit_log;
VACUUM FULL query_audit_alerts;
REINDEX TABLE query_audit_log;
REINDEX TABLE query_audit_alerts;

-- Verificar espaço liberado
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename IN ('query_audit_log', 'query_audit_alerts')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;