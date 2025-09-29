-- =====================================================
-- Script de Migração para Produção - DBManager v2.0 (CORRIGIDO)
-- =====================================================
-- Data: 2025-01-29
-- Descrição: Atualiza o banco de produção com as novas estruturas
--            implementadas no sistema de sincronização refatorado
--
-- IMPORTANTE: Executar com cuidado em produção!
-- Recomendado fazer backup antes de executar
-- =====================================================

BEGIN;

-- =====================================================
-- 1. ADICIONAR COLUNAS FALTANTES NAS TABELAS EXISTENTES
-- =====================================================

-- Tabela users: adicionar colunas de idioma e nome
ALTER TABLE users
ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'pt',
ADD COLUMN IF NOT EXISTS name VARCHAR(255);

-- Tabela system_license: adicionar colunas de licença
ALTER TABLE system_license
ADD COLUMN IF NOT EXISTS license_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP;

-- Tabela servers: adicionar coluna database_name
ALTER TABLE servers
ADD COLUMN IF NOT EXISTS database_name VARCHAR(255);

-- =====================================================
-- 2. CRIAR NOVAS TABELAS ESSENCIAIS
-- =====================================================

-- Tabela de estatísticas de discrepâncias (otimização de performance)
CREATE TABLE IF NOT EXISTS sync_discrepancy_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    stat_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_count INTEGER DEFAULT 0,
    pending_count INTEGER DEFAULT 0,
    corrected_count INTEGER DEFAULT 0,
    accepted_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    by_type JSONB DEFAULT '{}',
    by_username JSONB DEFAULT '{}',
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_server_date UNIQUE (server_id, stat_date)
);

-- Tabela de tolerância de licença
CREATE TABLE IF NOT EXISTS license_tolerance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id VARCHAR(255) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    tolerance_started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    grace_period_days INTEGER NOT NULL DEFAULT 15,
    notification_sent_at TIMESTAMP,
    blocked_at TIMESTAMP,
    original_limit INTEGER NOT NULL,
    current_usage INTEGER NOT NULL,
    tolerance_percentage NUMERIC(5,2) NOT NULL DEFAULT 30.00,
    tolerance_minimum INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_license_resource UNIQUE (license_id, resource_type)
);

-- Tabela de notificações de tolerância
CREATE TABLE IF NOT EXISTS license_tolerance_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tolerance_id UUID REFERENCES license_tolerance(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL,
    recipient_email VARCHAR(255) NOT NULL,
    recipient_user_id UUID,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    email_subject TEXT,
    email_body TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 3. CRIAR ÍNDICES DE OTIMIZAÇÃO PARA SYNC
-- =====================================================

-- Índices para sync_discrepancies (se não existirem)
CREATE INDEX IF NOT EXISTS idx_disc_accepted
ON sync_discrepancies(status, accepted_by, detected_at DESC)
WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_server_status
ON sync_discrepancies(server_id, status);

CREATE INDEX IF NOT EXISTS idx_disc_pending_count
ON sync_discrepancies(server_id, status)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_disc_not_corrected
ON sync_discrepancies(corrected, detected_at DESC)
WHERE corrected = false;

CREATE INDEX IF NOT EXISTS idx_disc_status_detected_server
ON sync_discrepancies(status, detected_at DESC, server_id)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_disc_username_status
ON sync_discrepancies(username, status, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_disc_server_status_type_detected
ON sync_discrepancies(server_id, status, type, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_disc_detected_at_partition
ON sync_discrepancies(detected_at, server_id);

-- Índices para sync_results
CREATE INDEX IF NOT EXISTS idx_sync_results_server_date
ON sync_results(server_id, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_sync_results_status
ON sync_results(status);

-- Índices para accepted_unmanaged_users
CREATE INDEX IF NOT EXISTS idx_accepted_unmanaged_users_server
ON accepted_unmanaged_users(server_id);

CREATE INDEX IF NOT EXISTS idx_accepted_unmanaged_users_username
ON accepted_unmanaged_users(username);

-- =====================================================
-- 4. CRIAR OU ATUALIZAR FUNÇÕES NECESSÁRIAS
-- =====================================================

-- Função para verificar tolerância de licença
CREATE OR REPLACE FUNCTION check_license_tolerance(
    p_resource_type VARCHAR(50),
    p_current_usage INTEGER,
    p_limit_value INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    v_tolerance_percentage NUMERIC := 30.0;
    v_tolerance_minimum INTEGER := 1;
    v_max_allowed INTEGER;
BEGIN
    -- Calcular o máximo permitido com tolerância
    v_max_allowed := GREATEST(
        p_limit_value + v_tolerance_minimum,
        CEIL(p_limit_value * (1 + v_tolerance_percentage / 100))
    );

    -- Retornar se o uso está dentro da tolerância
    RETURN p_current_usage <= v_max_allowed;
END;
$$ LANGUAGE plpgsql;

-- Função para atualizar updated_at em system_license
CREATE OR REPLACE FUNCTION update_license_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para system_license
DROP TRIGGER IF EXISTS update_system_license_updated_at ON system_license;
CREATE TRIGGER update_system_license_updated_at
BEFORE UPDATE ON system_license
FOR EACH ROW
EXECUTE FUNCTION update_license_updated_at();

-- Função para atualizar estatísticas de discrepâncias
CREATE OR REPLACE FUNCTION trigger_update_discrepancy_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_old_status VARCHAR(50);
    v_new_status VARCHAR(50);
BEGIN
    v_old_status := COALESCE(OLD.status, '');
    v_new_status := COALESCE(NEW.status, '');

    -- Se o status mudou, atualizar as estatísticas
    IF v_old_status != v_new_status OR TG_OP = 'INSERT' THEN
        -- Inserir ou atualizar estatísticas
        INSERT INTO sync_discrepancy_stats (
            server_id,
            stat_date,
            total_count,
            pending_count,
            corrected_count,
            accepted_count,
            error_count,
            last_updated
        )
        VALUES (
            NEW.server_id,
            CURRENT_DATE,
            1,
            CASE WHEN v_new_status = 'pending' THEN 1 ELSE 0 END,
            CASE WHEN v_new_status = 'corrected' THEN 1 ELSE 0 END,
            CASE WHEN v_new_status = 'accepted' THEN 1 ELSE 0 END,
            CASE WHEN v_new_status = 'error' THEN 1 ELSE 0 END,
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (server_id, stat_date)
        DO UPDATE SET
            total_count = sync_discrepancy_stats.total_count +
                CASE WHEN TG_OP = 'INSERT' THEN 1 ELSE 0 END,
            pending_count = sync_discrepancy_stats.pending_count +
                CASE
                    WHEN v_new_status = 'pending' AND v_old_status != 'pending' THEN 1
                    WHEN v_new_status != 'pending' AND v_old_status = 'pending' THEN -1
                    ELSE 0
                END,
            corrected_count = sync_discrepancy_stats.corrected_count +
                CASE
                    WHEN v_new_status = 'corrected' AND v_old_status != 'corrected' THEN 1
                    WHEN v_new_status != 'corrected' AND v_old_status = 'corrected' THEN -1
                    ELSE 0
                END,
            accepted_count = sync_discrepancy_stats.accepted_count +
                CASE
                    WHEN v_new_status = 'accepted' AND v_old_status != 'accepted' THEN 1
                    WHEN v_new_status != 'accepted' AND v_old_status = 'accepted' THEN -1
                    ELSE 0
                END,
            error_count = sync_discrepancy_stats.error_count +
                CASE
                    WHEN v_new_status = 'error' AND v_old_status != 'error' THEN 1
                    WHEN v_new_status != 'error' AND v_old_status = 'error' THEN -1
                    ELSE 0
                END,
            last_updated = CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger se não existir
DROP TRIGGER IF EXISTS update_discrepancy_stats_trigger ON sync_discrepancies;
CREATE TRIGGER update_discrepancy_stats_trigger
AFTER INSERT OR UPDATE OF status ON sync_discrepancies
FOR EACH ROW
EXECUTE FUNCTION trigger_update_discrepancy_stats();

-- =====================================================
-- 5. CRIAR OU ATUALIZAR VIEWS (CORRIGIDO)
-- =====================================================

-- Primeiro, dropar a view existente se houver
DROP VIEW IF EXISTS sync_status_view CASCADE;

-- Recriar a view com a estrutura correta
CREATE VIEW sync_status_view AS
SELECT
    s.id AS server_id,
    s.name AS server_name,
    s.host,
    s.type AS db_type,
    s.sync_enabled,
    s.last_sync,
    s.next_sync,
    COALESCE(sr.status, 'never_synced') AS sync_status,
    sr.start_time AS last_sync_start,
    sr.end_time AS last_sync_end,
    sr.duration AS last_sync_duration_seconds,
    sr.discrepancies AS last_discrepancies_count,
    sr.unmanaged_users AS last_unmanaged_users_count,
    sr.error_message AS last_error,
    COALESCE(disc_stats.pending_count, 0) AS pending_discrepancies,
    COALESCE(disc_stats.accepted_count, 0) AS accepted_discrepancies,
    COALESCE(disc_stats.corrected_count, 0) AS corrected_discrepancies
FROM servers s
LEFT JOIN LATERAL (
    SELECT *
    FROM sync_results
    WHERE server_id = s.id
    ORDER BY start_time DESC
    LIMIT 1
) sr ON true
LEFT JOIN sync_discrepancy_stats disc_stats ON
    disc_stats.server_id = s.id AND
    disc_stats.stat_date = CURRENT_DATE
WHERE s.type IN ('postgres', 'mysql', 'mssql', 'oracle');

-- =====================================================
-- 6. AJUSTAR CONFIGURAÇÕES DE TABELAS PARA PERFORMANCE
-- =====================================================

-- Configurar fillfactor para tabelas com muitas atualizações
ALTER TABLE sync_discrepancies SET (fillfactor = 85);
ALTER TABLE sync_results SET (fillfactor = 90);
ALTER TABLE sync_discrepancy_stats SET (fillfactor = 85);

-- =====================================================
-- 7. POPULAR ESTATÍSTICAS INICIAIS
-- =====================================================

-- Popular estatísticas de discrepâncias existentes
INSERT INTO sync_discrepancy_stats (
    server_id,
    stat_date,
    total_count,
    pending_count,
    corrected_count,
    accepted_count,
    error_count,
    by_type,
    by_username,
    last_updated
)
SELECT
    server_id,
    CURRENT_DATE,
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'pending'),
    COUNT(*) FILTER (WHERE status = 'corrected'),
    COUNT(*) FILTER (WHERE status = 'accepted'),
    COUNT(*) FILTER (WHERE status = 'error'),
    jsonb_object_agg(
        type,
        type_count
    ) FILTER (WHERE type IS NOT NULL),
    jsonb_object_agg(
        username,
        username_count
    ) FILTER (WHERE username IS NOT NULL),
    CURRENT_TIMESTAMP
FROM (
    SELECT
        server_id,
        status,
        type,
        COUNT(*) OVER (PARTITION BY server_id, type) as type_count,
        username,
        COUNT(*) OVER (PARTITION BY server_id, username) as username_count
    FROM sync_discrepancies
    WHERE detected_at >= CURRENT_DATE
) sub
GROUP BY server_id
ON CONFLICT (server_id, stat_date) DO NOTHING;

-- =====================================================
-- 8. VALIDAÇÕES E LIMPEZA
-- =====================================================

-- Verificar e corrigir discrepâncias duplicadas
WITH duplicates AS (
    SELECT
        server_id,
        username,
        object_name,
        type,
        MIN(id) as keep_id,
        MAX(detection_count) as max_count,
        COUNT(*) as duplicate_count
    FROM sync_discrepancies
    WHERE status = 'pending'
    GROUP BY server_id, username, object_name, type
    HAVING COUNT(*) > 1
)
UPDATE sync_discrepancies sd
SET
    detection_count = d.max_count + d.duplicate_count - 1,
    status = 'merged'
FROM duplicates d
WHERE sd.server_id = d.server_id
  AND sd.username = d.username
  AND sd.object_name = d.object_name
  AND sd.type = d.type
  AND sd.id != d.keep_id;

-- Deletar discrepâncias marcadas como merged
DELETE FROM sync_discrepancies WHERE status = 'merged';

-- =====================================================
-- 9. GRANT DE PERMISSÕES
-- =====================================================

-- Garantir que o usuário dbmanager tem todas as permissões necessárias
GRANT ALL ON sync_discrepancy_stats TO dbmanager;
GRANT ALL ON license_tolerance TO dbmanager;
GRANT ALL ON license_tolerance_notifications TO dbmanager;
GRANT ALL ON sync_status_view TO dbmanager;

-- =====================================================
-- 10. ANÁLISE E VACUUM
-- =====================================================

-- Atualizar estatísticas das tabelas modificadas
ANALYZE sync_discrepancies;
ANALYZE sync_results;
ANALYZE sync_discrepancy_stats;
ANALYZE system_license;
ANALYZE users;
ANALYZE servers;

-- Fazer vacuum para recuperar espaço
VACUUM (ANALYZE) sync_discrepancies;
VACUUM (ANALYZE) sync_results;

COMMIT;

-- =====================================================
-- SCRIPT DE VALIDAÇÃO (executar após migração)
-- =====================================================
/*
-- Verificar se todas as mudanças foram aplicadas:
SELECT
    'users.preferred_language' as check_item,
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='preferred_language') as exists
UNION ALL
SELECT
    'users.name',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='name')
UNION ALL
SELECT
    'system_license.license_id',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='system_license' AND column_name='license_id')
UNION ALL
SELECT
    'system_license.expires_at',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='system_license' AND column_name='expires_at')
UNION ALL
SELECT
    'servers.database_name',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='servers' AND column_name='database_name')
UNION ALL
SELECT
    'sync_discrepancy_stats table',
    EXISTS(SELECT 1 FROM information_schema.tables
           WHERE table_name='sync_discrepancy_stats')
UNION ALL
SELECT
    'license_tolerance table',
    EXISTS(SELECT 1 FROM information_schema.tables
           WHERE table_name='license_tolerance')
UNION ALL
SELECT
    'sync_status_view',
    EXISTS(SELECT 1 FROM information_schema.views
           WHERE table_name='sync_status_view')
ORDER BY check_item;
*/

-- =====================================================
-- ROLLBACK (caso necessário)
-- =====================================================
/*
BEGIN;

-- Remover colunas adicionadas
ALTER TABLE users DROP COLUMN IF EXISTS preferred_language;
ALTER TABLE users DROP COLUMN IF EXISTS name;
ALTER TABLE system_license DROP COLUMN IF EXISTS license_id;
ALTER TABLE system_license DROP COLUMN IF EXISTS expires_at;
ALTER TABLE servers DROP COLUMN IF EXISTS database_name;

-- Remover views
DROP VIEW IF EXISTS sync_status_view CASCADE;

-- Remover tabelas criadas
DROP TABLE IF EXISTS sync_discrepancy_stats CASCADE;
DROP TABLE IF EXISTS license_tolerance_notifications CASCADE;
DROP TABLE IF EXISTS license_tolerance CASCADE;

-- Remover índices criados
DROP INDEX IF EXISTS idx_disc_accepted;
DROP INDEX IF EXISTS idx_sync_discrepancies_server_status;
DROP INDEX IF EXISTS idx_disc_pending_count;
DROP INDEX IF EXISTS idx_disc_not_corrected;
DROP INDEX IF EXISTS idx_disc_status_detected_server;
DROP INDEX IF EXISTS idx_disc_username_status;
DROP INDEX IF EXISTS idx_disc_server_status_type_detected;
DROP INDEX IF EXISTS idx_disc_detected_at_partition;
DROP INDEX IF EXISTS idx_sync_results_server_date;
DROP INDEX IF EXISTS idx_sync_results_status;
DROP INDEX IF EXISTS idx_accepted_unmanaged_users_server;
DROP INDEX IF EXISTS idx_accepted_unmanaged_users_username;

-- Remover funções e triggers
DROP TRIGGER IF EXISTS update_discrepancy_stats_trigger ON sync_discrepancies;
DROP FUNCTION IF EXISTS trigger_update_discrepancy_stats();
DROP FUNCTION IF EXISTS check_license_tolerance(VARCHAR, INTEGER, INTEGER);
DROP TRIGGER IF EXISTS update_system_license_updated_at ON system_license;
DROP FUNCTION IF EXISTS update_license_updated_at();

COMMIT;
*/

-- =====================================================
-- FIM DO SCRIPT DE MIGRAÇÃO
-- =====================================================