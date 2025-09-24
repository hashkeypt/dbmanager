-- Simular a lógica do sync

-- 1. O que o sync vê quando conecta ao banco postgres
\c postgres
SELECT 'Permissões vistas no banco postgres:' as info;
SELECT grantee, table_schema, table_name, privilege_type 
FROM information_schema.table_privileges 
WHERE grantee = 'teste';

-- 2. Usuários detectados
SELECT 'Usuários detectados:' as info;
SELECT usename FROM pg_user 
WHERE usename NOT IN ('postgres', 'admin_postgres')
AND usename NOT LIKE 'pg_%';

-- 3. O que existe no backend_db
\c backend_db
SELECT 'Permissões no backend_db:' as info;
SELECT grantee, table_schema, table_name, privilege_type 
FROM information_schema.table_privileges 
WHERE grantee = 'teste';