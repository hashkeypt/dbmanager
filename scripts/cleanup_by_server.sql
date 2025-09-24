-- Script para limpar logs por servidor
-- Corrigido: removida referência a s.query_audit_enabled que não existe

-- 1. Ver quanto cada servidor está consumindo
SELECT 
    s.id,
    s.name as server_name,
    COUNT(qal.id) as log_count,
    pg_size_pretty(pg_total_relation_size('query_audit_log') * 
        (COUNT(qal.id)::numeric / (SELECT COUNT(*) FROM query_audit_log))) as estimated_size,
    MIN(qal.captured_at) as oldest_log,
    MAX(qal.captured_at) as newest_log,
    COALESCE(qac.retention_days, 30) as configured_retention_days
FROM servers s
LEFT JOIN query_audit_log qal ON s.id = qal.server_id
LEFT JOIN query_audit_config qac ON s.id = qac.server_id
GROUP BY s.id, s.name, qac.retention_days
ORDER BY COUNT(qal.id) DESC;

-- 2. Limpar logs por servidor baseado na configuração
DO $$
DECLARE
    server_record RECORD;
    deleted_count INTEGER;
    total_deleted INTEGER := 0;
    server_total INTEGER;
BEGIN
    -- Para cada servidor com logs
    FOR server_record IN 
        SELECT 
            s.id as server_id,
            s.name as server_name,
            COALESCE(qac.retention_days, 7) as retention_days, -- Padrão: 7 dias
            COUNT(qal.id) as log_count
        FROM servers s
        LEFT JOIN query_audit_config qac ON s.id = qac.server_id
        INNER JOIN query_audit_log qal ON s.id = qal.server_id
        GROUP BY s.id, s.name, qac.retention_days
        HAVING COUNT(qal.id) > 0
    LOOP
        server_total := 0;
        RAISE NOTICE 'Processando servidor: % (% logs, retenção: % dias)', 
            server_record.server_name, 
            server_record.log_count,
            server_record.retention_days;
        
        -- Deletar logs antigos em lotes
        LOOP
            DELETE FROM query_audit_log
            WHERE id IN (
                SELECT id 
                FROM query_audit_log
                WHERE server_id = server_record.server_id
                AND captured_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * server_record.retention_days
                LIMIT 5000
            );
            
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            server_total := server_total + deleted_count;
            total_deleted := total_deleted + deleted_count;
            
            EXIT WHEN deleted_count = 0;
            
            -- Pequena pausa a cada lote
            IF server_total % 10000 = 0 AND server_total > 0 THEN
                RAISE NOTICE '  ... % logs deletados para %', server_total, server_record.server_name;
                PERFORM pg_sleep(0.2);
            END IF;
        END LOOP;
        
        IF server_total > 0 THEN
            RAISE NOTICE 'Servidor %: % logs removidos', server_record.server_name, server_total;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Limpeza concluída! Total geral: % logs removidos', total_deleted;
    RAISE NOTICE '====================================';
END $$;

-- 3. Garantir que existe configuração para todos os servidores
INSERT INTO query_audit_config (server_id, enabled, retention_days, created_at, updated_at)
SELECT 
    s.id,
    true,
    7, -- Padrão: 7 dias de retenção
    NOW(),
    NOW()
FROM servers s
WHERE NOT EXISTS (
    SELECT 1 FROM query_audit_config qac 
    WHERE qac.server_id = s.id
)
ON CONFLICT (server_id) DO UPDATE
SET retention_days = LEAST(query_audit_config.retention_days, 7),
    updated_at = NOW();

-- 4. Ver o resultado
SELECT 
    'RESULTADO FINAL:' as status,
    COUNT(*) as total_logs,
    pg_size_pretty(pg_total_relation_size('query_audit_log')) as table_size,
    MIN(captured_at) as oldest_log,
    MAX(captured_at) as newest_log
FROM query_audit_log;