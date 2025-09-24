-- Script de debug para PostgreSQL Query Audit

-- 1. Verificar permissões do usuário
SELECT current_user, usesuper FROM pg_user WHERE usename = current_user;

-- 2. Verificar se pg_stat_statements existe e está acessível
SELECT 
    EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') as extension_exists,
    EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'pg_stat_statements' AND schemaname = 'public') as view_exists;

-- 3. Tentar acessar pg_stat_statements
DO $$
BEGIN
    PERFORM COUNT(*) FROM pg_stat_statements;
    RAISE NOTICE 'pg_stat_statements is accessible';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Error accessing pg_stat_statements: %', SQLERRM;
END $$;

-- 4. Verificar configuração do PostgreSQL para pg_stat_statements
SELECT name, setting 
FROM pg_settings 
WHERE name LIKE '%pg_stat_statements%'
ORDER BY name;

-- 5. Verificar se há queries em pg_stat_statements
SELECT 
    COUNT(*) as total_queries,
    COUNT(DISTINCT userid) as unique_users,
    COUNT(DISTINCT dbid) as unique_databases
FROM pg_stat_statements;

-- 6. Mostrar 5 queries de exemplo com informações completas
SELECT 
    pss.userid,
    pss.dbid,
    u.rolname as username,
    d.datname as database_name,
    LEFT(pss.query, 100) as query_sample,
    pss.calls,
    pss.total_time,
    pss.mean_time,
    pss.rows
FROM pg_stat_statements pss
LEFT JOIN pg_user u ON u.usesysid = pss.userid
LEFT JOIN pg_database d ON d.oid = pss.dbid
WHERE pss.query NOT LIKE '%pg_stat_statements%'
    AND pss.query != '<insufficient privilege>'
    AND pss.calls > 0
ORDER BY pss.total_time DESC
LIMIT 5;

-- 7. Verificar se há queries ativas em pg_stat_activity
SELECT 
    COUNT(*) as active_queries,
    COUNT(DISTINCT usename) as unique_users
FROM pg_stat_activity
WHERE state = 'active'
    AND backend_type = 'client backend'
    AND pid != pg_backend_pid();

-- 8. Mostrar queries ativas
SELECT 
    pid,
    usename,
    datname,
    LEFT(query, 100) as query_sample,
    state,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start)) * 1000 as duration_ms
FROM pg_stat_activity
WHERE state = 'active'
    AND backend_type = 'client backend'
    AND pid != pg_backend_pid()
LIMIT 5;

-- 9. Verificar dados coletados no dbmanager
SELECT 
    COUNT(*) as total_logs,
    COUNT(DISTINCT server_id) as servers,
    COUNT(DISTINCT username) as users,
    MIN(captured_at) as first_capture,
    MAX(captured_at) as last_capture
FROM query_audit_log
WHERE captured_at > NOW() - INTERVAL '1 hour';

-- 10. Últimas 5 queries capturadas
SELECT 
    qal.username,
    qal.database_name,
    LEFT(qal.query_text, 100) as query_sample,
    qal.query_type,
    qal.execution_time_ms,
    qal.captured_at,
    qal.metadata->>'source' as source
FROM query_audit_log qal
ORDER BY qal.captured_at DESC
LIMIT 5;