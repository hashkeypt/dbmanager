-- =====================================================
-- Correção da view sync_status_view para Produção
-- =====================================================
-- Data: 2025-01-29
-- Problema: View estava incompatível com o código que espera
--          colunas específicas como database_name, database_type, etc.
-- =====================================================

BEGIN;

-- 1. Dropar a view existente que está incorreta
DROP VIEW IF EXISTS sync_status_view CASCADE;

-- 2. Recriar a view com a estrutura correta (baseada no ambiente local)
CREATE VIEW sync_status_view AS
SELECT
    s.id AS server_id,
    s.name AS database_name,  -- Nome do servidor é usado como database_name
    s.type AS database_type,   -- Tipo do servidor (postgres, mysql, etc)
    s.sync_enabled,
    s.last_sync,
    -- Buscar o último sync_result ID
    (SELECT sr.id
     FROM sync_results sr
     WHERE sr.server_id = s.id
     ORDER BY sr.start_time DESC
     LIMIT 1) AS last_sync_id,

    -- Status do último sync ou 'never_synced'
    COALESCE(
        (SELECT sr.status
         FROM sync_results sr
         WHERE sr.server_id = s.id
         ORDER BY sr.start_time DESC
         LIMIT 1),
        'never_synced'
    ) AS status,

    -- Total de discrepâncias pendentes
    (SELECT COUNT(*)
     FROM sync_discrepancies sd
     WHERE sd.server_id = s.id
     AND sd.status = 'pending') AS discrepancy_count,

    -- Total de discrepâncias pendentes (incluindo NULL status)
    (SELECT COUNT(*)
     FROM sync_discrepancies sd
     WHERE sd.server_id = s.id
     AND (sd.status = 'pending' OR sd.status IS NULL)) AS pending_discrepancies,

    -- Usuários não gerenciados
    (SELECT COUNT(*)
     FROM sync_discrepancies sd
     WHERE sd.server_id = s.id
     AND sd.type = 'unmanaged_user'
     AND (sd.status = 'pending' OR sd.status IS NULL)) AS unmanaged_users,

    -- Usuários faltantes
    (SELECT COUNT(*)
     FROM sync_discrepancies sd
     WHERE sd.server_id = s.id
     AND sd.type = 'missing_user'
     AND (sd.status = 'pending' OR sd.status IS NULL)) AS missing_users,

    -- Incompatibilidades de permissão
    (SELECT COUNT(*)
     FROM sync_discrepancies sd
     WHERE sd.server_id = s.id
     AND sd.type = 'permission_mismatch'
     AND (sd.status = 'pending' OR sd.status IS NULL)) AS permission_mismatches,

    -- Ambiente do servidor
    s.environment,

    -- Discrepâncias de permissão pendentes (missing + extra + mismatch)
    (SELECT COUNT(*)
     FROM sync_discrepancies sd
     WHERE sd.server_id = s.id
     AND sd.type IN ('missing_permission', 'extra_permission', 'permission_mismatch')
     AND (sd.status = 'pending' OR sd.status IS NULL)) AS pending_permission_discrepancies

FROM servers s
WHERE s.status IN ('active', 'connected')
   OR s.status IS NULL  -- Incluir servidores sem status definido
ORDER BY s.name;

-- 3. Garantir permissões
GRANT SELECT ON sync_status_view TO dbmanager;
GRANT ALL ON sync_status_view TO dbmanager;

-- 4. Criar índices adicionais se necessário para performance
-- (apenas se não existirem)
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_server_status_type
ON sync_discrepancies(server_id, status, type);

CREATE INDEX IF NOT EXISTS idx_servers_status
ON servers(status);

-- 5. Atualizar estatísticas
ANALYZE servers;
ANALYZE sync_results;
ANALYZE sync_discrepancies;

COMMIT;

-- =====================================================
-- VERIFICAÇÃO (executar após aplicar o script)
-- =====================================================
-- Verificar se a view foi criada corretamente:
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'sync_status_view'
ORDER BY ordinal_position;

-- Testar se a view retorna dados:
SELECT
    COUNT(*) as total_servers,
    COUNT(CASE WHEN sync_enabled THEN 1 END) as sync_enabled_count,
    COUNT(CASE WHEN status = 'never_synced' THEN 1 END) as never_synced_count
FROM sync_status_view;

-- Verificar primeiras 3 linhas:
SELECT
    server_id,
    database_name,
    database_type,
    sync_enabled,
    status,
    pending_discrepancies
FROM sync_status_view
LIMIT 3;