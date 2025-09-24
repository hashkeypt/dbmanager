-- Script para corrigir duplicatas no Query Audit e adicionar controles
-- Execute este script no banco de dados do DB-Manager

-- 1. Primeiro, remover duplicatas existentes (mantendo apenas a mais antiga de cada grupo)
WITH duplicates AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY server_id, query_hash, date_trunc('hour', executed_at) 
            ORDER BY captured_at ASC
        ) as rn
    FROM query_audit_log
    WHERE query_hash IS NOT NULL
)
DELETE FROM query_audit_log
WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- 2. Adicionar colunas de controle se não existirem
ALTER TABLE query_audit_config 
ADD COLUMN IF NOT EXISTS last_collected_at TIMESTAMP WITH TIME ZONE;

-- 3. Criar índice único para prevenir futuras duplicatas
-- Dropamos o índice se existir para recriá-lo
DROP INDEX IF EXISTS idx_query_audit_log_dedup;

CREATE UNIQUE INDEX idx_query_audit_log_dedup 
ON query_audit_log (server_id, query_hash, date_trunc('hour', executed_at))
WHERE query_hash IS NOT NULL;

-- 4. Adicionar índice para performance
CREATE INDEX IF NOT EXISTS idx_query_audit_log_server_executed 
ON query_audit_log (server_id, executed_at DESC);

-- 5. Atualizar last_collected_at com o timestamp mais recente de cada servidor
UPDATE query_audit_config qac
SET last_collected_at = (
    SELECT MAX(captured_at) 
    FROM query_audit_log qal 
    WHERE qal.server_id = qac.server_id
)
WHERE EXISTS (
    SELECT 1 FROM query_audit_log qal 
    WHERE qal.server_id = qac.server_id
);

-- 6. Mostrar estatísticas
SELECT 
    'Estatísticas após limpeza:' as info;

SELECT 
    s.name as server_name,
    COUNT(qal.id) as total_queries,
    COUNT(DISTINCT qal.query_hash) as unique_queries,
    MIN(qal.executed_at) as oldest_query,
    MAX(qal.executed_at) as newest_query,
    qac.last_collected_at
FROM servers s
LEFT JOIN query_audit_log qal ON qal.server_id = s.id
LEFT JOIN query_audit_config qac ON qac.server_id = s.id
GROUP BY s.id, s.name, qac.last_collected_at
ORDER BY s.name;