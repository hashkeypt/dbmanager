-- Teste de métricas MySQL

-- 1. Verificar conexões totais
SHOW STATUS LIKE 'Threads_connected';

-- 2. Verificar processos ativos
SELECT 
    USER,
    COUNT(*) as active_sessions,
    GROUP_CONCAT(DISTINCT HOST) as hosts,
    GROUP_CONCAT(DISTINCT DB) as databases
FROM information_schema.PROCESSLIST
WHERE USER IS NOT NULL
GROUP BY USER;

-- 3. Verificar processos detalhados
SELECT * FROM information_schema.PROCESSLIST;

-- 4. Verificar Performance Schema
SHOW VARIABLES LIKE 'performance_schema';

-- 5. Verificar se eventos estão habilitados
SELECT * FROM performance_schema.setup_instruments 
WHERE NAME LIKE 'statement/%' 
LIMIT 10;