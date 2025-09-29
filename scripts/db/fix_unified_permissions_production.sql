-- =====================================================
-- Correção da view unified_permissions para Produção
-- =====================================================
-- Data: 2025-01-29
-- Problema: View não tinha a coluna 'id' que o código espera
-- =====================================================

BEGIN;

-- 1. Dropar a view existente
DROP VIEW IF EXISTS unified_permissions CASCADE;

-- 2. Recriar a view com a estrutura correta (incluindo a coluna id)
CREATE VIEW unified_permissions AS
SELECT
    up.id,                      -- IMPORTANTE: Coluna id que estava faltando!
    up.user_id,
    up.server_id,
    up.database_name,
    up.schema_name,
    up.table_name,
    up.operations,
    up.is_permanent,
    up.expires_at,
    up.created_at,
    up.status,
    COALESCE(u.username, su.username) AS username,  -- Username de user ou service_user
    u.email,
    s.name AS server_name,
    s.type AS server_type
FROM user_permissions up
    LEFT JOIN users u ON up.user_id = u.id
    LEFT JOIN service_users su ON up.service_user_id = su.id
    JOIN servers s ON up.server_id = s.id
WHERE up.status = 'active';

-- 3. Garantir permissões
GRANT SELECT ON unified_permissions TO dbmanager;
GRANT ALL ON unified_permissions TO dbmanager;

-- 4. Atualizar estatísticas
ANALYZE user_permissions;
ANALYZE users;
ANALYZE service_users;
ANALYZE servers;

COMMIT;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================
-- Verificar se a view tem a coluna id:
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'unified_permissions'
AND column_name = 'id';

-- Testar a query que estava falhando:
SELECT COUNT(*) as total_permissions
FROM unified_permissions up
JOIN user_permissions p ON up.id = p.id
WHERE up.server_id = (SELECT id FROM servers LIMIT 1)
AND up.status = 'active';

-- Verificar primeiros registros:
SELECT id, user_id, server_id, database_name, table_name, status
FROM unified_permissions
LIMIT 5;