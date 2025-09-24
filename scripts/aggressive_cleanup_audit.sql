-- Script de Limpeza Agressiva para Query Audit Logs
-- As tabelas estão com 397K registros e 842MB!

-- 1. Verificar o estado atual
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

-- 2. Deletar logs antigos de forma agressiva (manter apenas últimos 7 dias)
-- Fazendo em lotes para evitar lock prolongado
DO $$
DECLARE
    deleted_count INTEGER;
    total_deleted INTEGER := 0;
    batch_size INTEGER := 5000;
BEGIN
    RAISE NOTICE 'Iniciando limpeza de logs antigos (mantendo apenas últimos 7 dias)...';
    
    LOOP
        -- Deletar logs mais velhos que 7 dias em lotes
        DELETE FROM query_audit_log
        WHERE id IN (
            SELECT id 
            FROM query_audit_log
            WHERE captured_at < CURRENT_TIMESTAMP - INTERVAL '7 days'
            ORDER BY captured_at
            LIMIT batch_size
        );
        
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        total_deleted := total_deleted + deleted_count;
        
        -- Sair quando não houver mais registros para deletar
        EXIT WHEN deleted_count = 0;
        
        -- Log de progresso a cada 50K registros
        IF total_deleted % 50000 = 0 AND total_deleted > 0 THEN
            RAISE NOTICE 'Progresso: % logs deletados até agora...', total_deleted;
            -- Pequena pausa para não sobrecarregar
            PERFORM pg_sleep(0.5);
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Limpeza de logs concluída! Total removido: %', total_deleted;
END $$;

-- 3. Limpar alertas antigos também
DO $$
DECLARE
    deleted_count INTEGER;
    total_deleted INTEGER := 0;
BEGIN
    RAISE NOTICE 'Limpando alertas antigos...';
    
    LOOP
        DELETE FROM query_audit_alerts
        WHERE id IN (
            SELECT id 
            FROM query_audit_alerts
            WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '7 days'
            LIMIT 5000
        );
        
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        total_deleted := total_deleted + deleted_count;
        
        EXIT WHEN deleted_count = 0;
        
        IF total_deleted % 10000 = 0 AND total_deleted > 0 THEN
            RAISE NOTICE 'Progresso: % alertas deletados...', total_deleted;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Limpeza de alertas concluída! Total removido: %', total_deleted;
END $$;

-- 4. Limpar alertas órfãos (sem log correspondente)
DELETE FROM query_audit_alerts qaa
WHERE NOT EXISTS (
    SELECT 1 FROM query_audit_log qal 
    WHERE qal.id = qaa.query_audit_log_id
)
AND query_audit_log_id IS NOT NULL;

-- 5. VACUUM FULL para recuperar espaço em disco (CUIDADO: bloqueia a tabela!)
-- Descomente apenas se puder parar o sistema por alguns minutos
-- VACUUM FULL query_audit_log;
-- VACUUM FULL query_audit_alerts;

-- 6. VACUUM normal e ANALYZE (não bloqueia)
VACUUM ANALYZE query_audit_log;
VACUUM ANALYZE query_audit_alerts;

-- 7. Recriar índices para otimização
REINDEX TABLE query_audit_log;
REINDEX TABLE query_audit_alerts;

-- 8. Verificar resultado final
SELECT 
    'APÓS LIMPEZA:' as status,
    'query_audit_log' as table_name,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('query_audit_log')) as total_size,
    MIN(captured_at) as oldest_record,
    MAX(captured_at) as newest_record
FROM query_audit_log
UNION ALL
SELECT 
    'APÓS LIMPEZA:' as status,
    'query_audit_alerts' as table_name,
    COUNT(*) as total_records,
    pg_size_pretty(pg_total_relation_size('query_audit_alerts')) as total_size,
    MIN(created_at) as oldest_record,
    MAX(created_at) as newest_record
FROM query_audit_alerts;

-- 9. Configurar retenção automática para evitar acúmulo futuro
-- Ajustar para 7 dias de retenção para todos os servidores
UPDATE query_audit_config 
SET retention_days = 7,
    updated_at = NOW()
WHERE retention_days > 7 OR retention_days IS NULL;

-- Se não existir configuração, criar uma padrão
INSERT INTO query_audit_config (server_id, enabled, retention_days, created_at, updated_at)
SELECT id, true, 7, NOW(), NOW()
FROM servers
WHERE NOT EXISTS (
    SELECT 1 FROM query_audit_config qac 
    WHERE qac.server_id = servers.id
);