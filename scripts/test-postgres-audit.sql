-- Script para testar se o PostgreSQL está configurado corretamente para Query Audit

-- 1. Verificar se pg_stat_statements está instalado
SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
) as has_pg_stat_statements;

-- 2. Verificar se pg_stat_statements está acessível
SELECT COUNT(*) as statement_count FROM pg_stat_statements;

-- 3. Mostrar algumas queries de exemplo
SELECT 
    u.rolname as username,
    d.datname as database_name,
    pss.query,
    pss.calls,
    pss.total_time,
    pss.mean_time,
    pss.rows
FROM pg_stat_statements pss
LEFT JOIN pg_user u ON u.usesysid = pss.userid
LEFT JOIN pg_database d ON d.oid = pss.dbid
WHERE pss.query NOT LIKE '%pg_stat_statements%'
    AND pss.query != '<insufficient privilege>'
    AND pss.query IS NOT NULL
    AND pss.query != ''
    AND pss.calls > 0
LIMIT 10;

-- 4. Verificar configuração do PostgreSQL
SHOW shared_preload_libraries;
SHOW pg_stat_statements.track;
SHOW pg_stat_statements.max;

-- 5. Gerar algumas queries de teste
CREATE TABLE IF NOT EXISTS test_audit (id INT, name TEXT);
INSERT INTO test_audit VALUES (1, 'test1'), (2, 'test2');
SELECT * FROM test_audit;
UPDATE test_audit SET name = 'updated' WHERE id = 1;
DELETE FROM test_audit WHERE id = 2;
DROP TABLE IF EXISTS test_audit;

-- 6. Verificar se as queries foram capturadas
SELECT 
    query,
    calls,
    total_time
FROM pg_stat_statements
WHERE query LIKE '%test_audit%'
ORDER BY total_time DESC;