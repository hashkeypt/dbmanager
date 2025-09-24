-- Script de Limpeza Emergencial para Query Audit Logs
-- Use este script quando a função automática estiver falhando por timeout
-- Execute cada seção separadamente se necessário

-- 1. ANÁLISE: Verificar o tamanho das tabelas
SELECT 
    'query_audit_log' as table_name,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('query_audit_log')) as total_size
UNION ALL
SELECT 
    'query_audit_alerts' as table_name,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('query_audit_alerts')) as total_size;

-- 2. ANÁLISE: Verificar quantos registros órfãos existem
SELECT COUNT(*) as orphaned_alerts
FROM query_audit_alerts qaa
LEFT JOIN query_audit_log qal ON qaa.query_audit_log_id = qal.id
WHERE qaa.query_audit_log_id IS NOT NULL
AND qal.id IS NULL;

-- 3. LIMPEZA: Remover alertas órfãos em lotes pequenos
-- Execute várias vezes até retornar 0 registros deletados
DO $$
DECLARE
    deleted_count INTEGER;
    total_deleted INTEGER := 0;
BEGIN
    LOOP
        -- Deletar em lotes de 500 registros por vez
        DELETE FROM query_audit_alerts
        WHERE id IN (
            SELECT qaa.id
            FROM query_audit_alerts qaa
            LEFT JOIN query_audit_log qal ON qaa.query_audit_log_id = qal.id
            WHERE qaa.query_audit_log_id IS NOT NULL
            AND qal.id IS NULL
            LIMIT 500
        );
        
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        total_deleted := total_deleted + deleted_count;
        
        -- Sair quando não houver mais registros para deletar
        EXIT WHEN deleted_count = 0;
        
        -- Pequena pausa para não sobrecarregar o banco
        PERFORM pg_sleep(0.1);
        
        -- Log de progresso a cada 5000 registros
        IF total_deleted % 5000 = 0 AND total_deleted > 0 THEN
            RAISE NOTICE 'Progresso: % alertas órfãos deletados até agora...', total_deleted;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Limpeza concluída! Total de alertas órfãos removidos: %', total_deleted;
END $$;

-- 4. LIMPEZA: Remover logs antigos por servidor (ajuste os dias conforme necessário)
-- Execute para cada servidor separadamente se necessário
DO $$
DECLARE
    server_record RECORD;
    deleted_count INTEGER;
    total_deleted INTEGER := 0;
BEGIN
    -- Para cada servidor com configuração de auditoria
    FOR server_record IN 
        SELECT 
            s.id as server_id,
            s.name as server_name,
            COALESCE(qac.retention_days, 30) as retention_days
        FROM servers s
        LEFT JOIN query_audit_config qac ON s.id = qac.server_id
        WHERE s.query_audit_enabled = true
    LOOP
        -- Deletar logs antigos em lotes
        LOOP
            DELETE FROM query_audit_log
            WHERE id IN (
                SELECT id 
                FROM query_audit_log
                WHERE server_id = server_record.server_id
                AND captured_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * server_record.retention_days
                LIMIT 1000
            );
            
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            total_deleted := total_deleted + deleted_count;
            
            EXIT WHEN deleted_count = 0;
            
            -- Pequena pausa
            PERFORM pg_sleep(0.1);
        END LOOP;
        
        IF total_deleted > 0 THEN
            RAISE NOTICE 'Servidor %: % logs antigos removidos', server_record.server_name, total_deleted;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Limpeza total concluída: % logs removidos', total_deleted;
END $$;

-- 5. MANUTENÇÃO: Criar índices se não existirem
CREATE INDEX IF NOT EXISTS idx_query_audit_alerts_log_id 
ON query_audit_alerts(query_audit_log_id) 
WHERE query_audit_log_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_query_audit_log_cleanup 
ON query_audit_log (server_id, captured_at);

CREATE INDEX IF NOT EXISTS idx_query_audit_log_server_date
ON query_audit_log (server_id, captured_at DESC);

-- 6. MANUTENÇÃO: Atualizar estatísticas das tabelas
ANALYZE query_audit_log;
ANALYZE query_audit_alerts;

-- 7. MANUTENÇÃO: Fazer VACUUM para recuperar espaço
VACUUM ANALYZE query_audit_log;
VACUUM ANALYZE query_audit_alerts;

-- 8. VERIFICAÇÃO FINAL: Ver o estado após limpeza
SELECT 
    'query_audit_log' as table_name,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('query_audit_log')) as total_size,
    MIN(captured_at) as oldest_record,
    MAX(captured_at) as newest_record
FROM query_audit_log
UNION ALL
SELECT 
    'query_audit_alerts' as table_name,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('query_audit_alerts')) as total_size,
    MIN(created_at) as oldest_record,
    MAX(created_at) as newest_record
FROM query_audit_alerts;

-- 9. OPCIONAL: Se quiser limpar TODOS os logs mais velhos que X dias (CUIDADO!)
-- DELETE FROM query_audit_log WHERE captured_at < CURRENT_TIMESTAMP - INTERVAL '90 days';

-- 10. OPCIONAL: Resetar completamente as tabelas (MUITO CUIDADO! APAGA TUDO!)
-- TRUNCATE TABLE query_audit_alerts CASCADE;
-- TRUNCATE TABLE query_audit_log CASCADE;