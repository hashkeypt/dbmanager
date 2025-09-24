-- Debug sync issues for PostgreSQL

-- 1. Verificar permissões do dbmanager
SELECT 'dbmanager Permissions:' as info;
SELECT user_id, server_id, database_name, schema_name, table_name, operations 
FROM unified_permissions 
WHERE server_id = '1dcfcc6d-1735-4e99-8d17-c20ab39277d2'
AND permission_status = 'active';

-- 2. Verificar service users
SELECT 'Service Users:' as info;
SELECT id, username FROM service_users WHERE username = 'teste';

-- 3. Verificar unified_managed_users
SELECT 'Unified Managed Users:' as info;
SELECT user_id, username, user_type 
FROM unified_managed_users 
WHERE username = 'teste';

-- 4. Verificar discrepâncias recentes
SELECT 'Recent Discrepancies:' as info;
SELECT type, username, object_name, reason, status
FROM sync_discrepancies 
WHERE server_id = '1dcfcc6d-1735-4e99-8d17-c20ab39277d2'
ORDER BY created_at DESC
LIMIT 5;