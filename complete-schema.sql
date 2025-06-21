-- Inicialização do Esquema do Banco de Dados PostgreSQL para DB-Manager
-- Este arquivo cria todas as tabelas e configurações iniciais necessárias

-- Configurações
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- Criação de tabelas
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    active BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    universal_db_password VARCHAR(255),
    universal_credentials_updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    last_used TIMESTAMP WITH TIME ZONE,
    avatar_url VARCHAR(255),
    is_object_owner BOOLEAN DEFAULT FALSE,
    object_count INTEGER DEFAULT 0
);

-- Tabela para registrar tentativas de login
CREATE TABLE IF NOT EXISTS login_attempts (
    id VARCHAR(36) PRIMARY KEY DEFAULT generate_uuid(),
    username VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45),
    success BOOLEAN NOT NULL DEFAULT false,
    failure_reason TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_login_attempts_username ON login_attempts(username);
CREATE INDEX IF NOT EXISTS idx_login_attempts_ip_address ON login_attempts(ip_address);
CREATE INDEX IF NOT EXISTS idx_login_attempts_created_at ON login_attempts(created_at);
CREATE INDEX IF NOT EXISTS idx_login_attempts_success ON login_attempts(success);
CREATE INDEX IF NOT EXISTS idx_login_attempts_user_id ON login_attempts(user_id);

-- Índice composto para queries de rate limiting
CREATE INDEX IF NOT EXISTS idx_login_attempts_username_ip_created ON login_attempts(username, ip_address, created_at);

CREATE TABLE IF NOT EXISTS user_activation_tokens (
    token VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT user_activation_tokens_user_id_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS servers (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    host VARCHAR(255) NOT NULL,
    port INTEGER NOT NULL,
    type VARCHAR(50) NOT NULL,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    encrypted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    status VARCHAR(50) DEFAULT 'active',
    last_used TIMESTAMP WITH TIME ZONE,
    databases JSONB DEFAULT '[]'::jsonb,
    schemas JSONB DEFAULT '{}'::jsonb,
    tables JSONB DEFAULT '{}'::jsonb,
    sync_enabled BOOLEAN NOT NULL DEFAULT false,
    last_sync TIMESTAMP WITH TIME ZONE,
    next_sync TIMESTAMP WITH TIME ZONE,
    performance_schema_status TEXT
);

-- ====================================================================================================
-- SERVICE USERS TABLES (movido para antes de access_requests por causa das foreign keys)
-- ====================================================================================================

-- Tabela para usuários de serviço/aplicação
CREATE TABLE IF NOT EXISTS service_users (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    encrypted_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    description TEXT,
    created_by VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_password_reset TIMESTAMP WITH TIME ZONE,
    password_reset_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    secret_path VARCHAR(500),
    secret_provider VARCHAR(50)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_service_users_username ON service_users(username);
CREATE INDEX IF NOT EXISTS idx_service_users_is_active ON service_users(is_active);
CREATE INDEX IF NOT EXISTS idx_service_users_created_by ON service_users(created_by);
CREATE INDEX IF NOT EXISTS idx_service_users_created_at ON service_users(created_at);
CREATE INDEX IF NOT EXISTS idx_service_users_secret_provider ON service_users(secret_provider) WHERE secret_provider IS NOT NULL;

-- Comentários para documentar as colunas de secret manager
COMMENT ON COLUMN service_users.secret_path IS 'Path or identifier of the secret in the secret manager (e.g., ARN for AWS, URL for Azure)';
COMMENT ON COLUMN service_users.secret_provider IS 'Secret manager provider being used (aws, azure, local)';

-- Criar somente a tabela user_permissions (sem a permissions)
CREATE TABLE IF NOT EXISTS user_permissions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    database_name VARCHAR(100),
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    operations TEXT NOT NULL,
    is_permanent BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    granted_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    created_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    level VARCHAR(50) DEFAULT 'table',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    revoked_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    service_user_id VARCHAR(36) REFERENCES service_users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS access_requests (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    database_name VARCHAR(100) NOT NULL DEFAULT '',
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    tables TEXT DEFAULT '[]'::text,
    operations TEXT DEFAULT '[]'::text,
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    response TEXT,
    responded_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_permanent BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE,
    approved_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    rejected_at TIMESTAMP WITH TIME ZONE,
    reject_reason TEXT,
    -- Service user fields
    is_service_user BOOLEAN DEFAULT FALSE,
    service_user_id VARCHAR(36) REFERENCES service_users(id) ON DELETE CASCADE,
    service_user_name VARCHAR(100),
    service_user_description TEXT,
    create_service_user BOOLEAN DEFAULT false,
    service_user_username VARCHAR(100),
    -- Constraint to ensure proper user/service user relationship
    CONSTRAINT check_user_or_service_user CHECK (
        (user_id IS NOT NULL AND service_user_id IS NULL) OR 
        (user_id IS NULL AND service_user_id IS NOT NULL) OR 
        (user_id IS NOT NULL AND is_service_user = true)
    )
);

-- A tabela 'logs' foi removida em favor da 'audit_logs'

CREATE TABLE IF NOT EXISTS system_configuration (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL DEFAULT 'Configuration',
    value JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    category VARCHAR(50),
    data_type VARCHAR(50) DEFAULT 'json',
    description TEXT
);

-- Criar função para gerar UUIDs (para compatibilidade com versões mais antigas do PostgreSQL)
CREATE OR REPLACE FUNCTION generate_uuid()
RETURNS text AS $$
BEGIN
    RETURN md5(random()::text || clock_timestamp()::text);
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(36) PRIMARY KEY DEFAULT generate_uuid(),
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    link TEXT,
    resource_id VARCHAR(36),
    resource_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para configurações gerais do sistema
CREATE TABLE IF NOT EXISTS configurations (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Inserir configuração de sincronização padrão
INSERT INTO configurations (config_key, config_value, updated_at)
VALUES (
    'sync_config', 
    '{"enabled":false,"interval":60,"retryCount":3,"emailNotifications":true,"baseURL":"http://localhost:3000"}',
    CURRENT_TIMESTAMP
) ON CONFLICT (config_key) DO NOTHING;

-- Tabelas para sistema de sincronização
CREATE TABLE IF NOT EXISTS sync_results (
    id VARCHAR(36) PRIMARY KEY,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    database_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration INTEGER DEFAULT 0,
    status VARCHAR(50) NOT NULL,
    error_message TEXT,
    discrepancies INTEGER DEFAULT 0,
    users_found INTEGER DEFAULT 0,
    permissions_found INTEGER DEFAULT 0,
    unmanaged_users INTEGER DEFAULT 0,
    corrections_applied INTEGER DEFAULT 0,
    total_users INTEGER DEFAULT 0,
    succeeded INTEGER DEFAULT 0,
    failed INTEGER DEFAULT 0,
    warnings INTEGER DEFAULT 0,
    error TEXT,
    details JSONB
);

-- Add index for better performance on common queries
CREATE INDEX IF NOT EXISTS idx_sync_results_server_id ON sync_results(server_id);
CREATE INDEX IF NOT EXISTS idx_sync_results_start_time ON sync_results(start_time);
CREATE INDEX IF NOT EXISTS idx_sync_results_status ON sync_results(status);

-- Add sync_details table for storing individual sync items
CREATE TABLE IF NOT EXISTS sync_details (
    id VARCHAR(36) PRIMARY KEY,
    sync_id VARCHAR(36) NOT NULL REFERENCES sync_results(id) ON DELETE CASCADE, 
    item_type VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add sync_configurations table
-- Tabela de configurações globais de sincronização (apenas um registro global)
CREATE TABLE IF NOT EXISTS sync_configurations (
    server_id VARCHAR(36) PRIMARY KEY DEFAULT 'global',
    enabled BOOLEAN NOT NULL DEFAULT false,
    interval_minutes INTEGER NOT NULL DEFAULT 60,
    auto_correct BOOLEAN NOT NULL DEFAULT false,
    notify_on_discrepancy BOOLEAN NOT NULL DEFAULT true,
    notify_on_unmanaged BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(36),
    auto_remove_users BOOLEAN NOT NULL DEFAULT false,
    notification_email VARCHAR(255) DEFAULT ''
);

-- Inserir configuração global padrão se não existir
INSERT INTO sync_configurations (server_id, enabled, interval_minutes, auto_correct, notify_on_discrepancy, notify_on_unmanaged, auto_remove_users, notification_email) 
VALUES ('global', false, 60, false, true, true, false, '')
ON CONFLICT (server_id) DO NOTHING;

-- Create sync_discrepancies table
CREATE TABLE IF NOT EXISTS sync_discrepancies (
    id VARCHAR(36) PRIMARY KEY,
    sync_result_id VARCHAR(36) REFERENCES sync_results(id) ON DELETE CASCADE, -- Removido NOT NULL
    user_id VARCHAR(36),
    username VARCHAR(100) NOT NULL,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    database_name VARCHAR(100) DEFAULT 'Unknown Database', -- Adicionado valor padrão
    table_name VARCHAR(100),
    type VARCHAR(50) NOT NULL,
    details TEXT,  -- Removido NOT NULL
    corrected BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Added for tracking updates
    result_id VARCHAR(36) REFERENCES sync_results(id) ON DELETE CASCADE,
    object_type VARCHAR(50),
    object_name VARCHAR(100),
    action VARCHAR(50),
    reason TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    corrected_at TIMESTAMP WITH TIME ZONE,
    error TEXT,
    accepted_by VARCHAR(255),
    permission_database_name VARCHAR(100),
    permission_table_name VARCHAR(100),
    permission_schema_name VARCHAR(100)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_result ON sync_discrepancies(sync_result_id);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_result_id ON sync_discrepancies(result_id);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_user ON sync_discrepancies(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_server ON sync_discrepancies(server_id);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_type ON sync_discrepancies(type);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_corrected ON sync_discrepancies(corrected);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_status ON sync_discrepancies(status);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_updated_at ON sync_discrepancies(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_perm_db ON sync_discrepancies(permission_database_name);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_perm_table ON sync_discrepancies(permission_table_name);
CREATE INDEX IF NOT EXISTS idx_sync_discrepancies_perm_schema ON sync_discrepancies(permission_schema_name);

-- Add comments explaining important fields
COMMENT ON COLUMN user_permissions.database_name IS 'Nome do banco de dados dentro do servidor onde a permissão se aplica';
COMMENT ON COLUMN user_permissions.status IS 'Estado atual da permissão: active (padrão) ou revoked';
COMMENT ON COLUMN user_permissions.revoked_by IS 'ID do usuário que revogou a permissão';
COMMENT ON COLUMN user_permissions.revoked_at IS 'Data e hora em que a permissão foi revogada';
COMMENT ON COLUMN servers.performance_schema_status IS 'Status e instruções sobre o Performance Schema para servidores MySQL/MariaDB';

-- Criar a view sync_status_view que é usada pelo sistema de sincronização
CREATE OR REPLACE VIEW sync_status_view AS
SELECT
    s.id AS server_id,
    s.name AS database_name,
    s.type AS database_type,
    s.sync_enabled,
    s.last_sync,
    (
        SELECT id
        FROM sync_results
        WHERE server_id = s.id
        ORDER BY start_time DESC
        LIMIT 1
    ) AS last_sync_id,
    (
        SELECT status
        FROM sync_results
        WHERE server_id = s.id
        ORDER BY start_time DESC
        LIMIT 1
    ) AS status,
    (
        SELECT COUNT(*)
        FROM sync_discrepancies
        WHERE server_id = s.id
    ) AS discrepancy_count,
    (
        SELECT COUNT(*)
        FROM sync_discrepancies
        WHERE server_id = s.id AND (status = 'pending' OR status IS NULL)
    ) AS pending_discrepancies,
    (
        SELECT COUNT(*)
        FROM sync_discrepancies
        WHERE server_id = s.id AND type = 'unmanaged_user' 
            AND (status = 'pending' OR status IS NULL)
    ) AS unmanaged_users,
    (
        SELECT COUNT(*)
        FROM sync_discrepancies
        WHERE server_id = s.id AND type = 'missing_user' 
            AND (status = 'pending' OR status IS NULL)
    ) AS missing_users,
    (
        SELECT COUNT(*)
        FROM sync_discrepancies
        WHERE server_id = s.id AND type = 'permission_mismatch' 
            AND (status = 'pending' OR status IS NULL)
    ) AS permission_mismatches
FROM
    servers s
ORDER BY
    s.name;

-- Adicionar comentário para documentar a view
COMMENT ON VIEW sync_status_view IS 'Visão que fornece status de sincronização para todos os servidores de banco de dados, contando apenas discrepâncias pendentes (status = pending ou NULL)';

-- Tabela de auditoria para mudanças de permissões
CREATE TABLE IF NOT EXISTS permission_audit_log (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE, -- Pode ser NULL para service users
    service_user_id VARCHAR(36) REFERENCES service_users(id) ON DELETE CASCADE,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    operations TEXT NOT NULL,
    action VARCHAR(50) NOT NULL, -- 'granted', 'revoked', 'modified'
    action_by_user_id VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Garantir que pelo menos um dos campos esteja preenchido
    CONSTRAINT check_user_or_service_user_audit CHECK (
        (user_id IS NOT NULL AND service_user_id IS NULL) OR 
        (user_id IS NULL AND service_user_id IS NOT NULL)
    )
);

-- Índices para performance da tabela de auditoria
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_user_id ON permission_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_service_user_id ON permission_audit_log(service_user_id);
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_server_id ON permission_audit_log(server_id);
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_table_name ON permission_audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_created_at ON permission_audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_action ON permission_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_permission_audit_log_action_by ON permission_audit_log(action_by_user_id);

-- Create trigger function to update result counters when discrepancies are added/modified
CREATE OR REPLACE FUNCTION update_sync_result_counters()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the discrepancies counter
  UPDATE sync_results
  SET discrepancies = (SELECT COUNT(*) FROM sync_discrepancies WHERE result_id = NEW.result_id)
  WHERE id = NEW.result_id;
  
  -- If this is an unmanaged user discrepancy, also update that specific counter
  IF NEW.type = 'unmanaged_user' THEN
    UPDATE sync_results
    SET unmanaged_users = (SELECT COUNT(*) FROM sync_discrepancies WHERE result_id = NEW.result_id AND type = 'unmanaged_user')
    WHERE id = NEW.result_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update result counters
DROP TRIGGER IF EXISTS update_sync_results_on_discrepancy ON sync_discrepancies;
CREATE TRIGGER update_sync_results_on_discrepancy
AFTER INSERT OR UPDATE ON sync_discrepancies
FOR EACH ROW
EXECUTE FUNCTION update_sync_result_counters();

-- Tabela para enfileiramento de atualizações de senha
CREATE TABLE IF NOT EXISTS password_update_queue (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    old_password TEXT,
    new_password TEXT NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT false,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    retry_count INTEGER NOT NULL DEFAULT 0,
    next_retry_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_password_queue_processed ON password_update_queue(processed);
CREATE INDEX IF NOT EXISTS idx_password_queue_user ON password_update_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_password_queue_server ON password_update_queue(server_id);

-- Tabela para preferências dos usuários
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id VARCHAR(255) PRIMARY KEY,
    value JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabelas para o sistema de auditoria com suporte ao Elasticsearch
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(36) PRIMARY KEY,
    action_type VARCHAR(100) NOT NULL,
    actor_id VARCHAR(36),
    actor_name VARCHAR(100),
    resource VARCHAR(255) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    client_ip VARCHAR(45),
    user_agent TEXT,
    message TEXT,
    details JSONB,
    forwarded BOOLEAN DEFAULT false,
    forwarded_at TIMESTAMP WITH TIME ZONE,
    severity VARCHAR(20) DEFAULT 'info',
    CONSTRAINT audit_logs_actor_id_fk FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Índices para melhorar a performance nas consultas de auditoria
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource_type ON audit_logs(resource_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX IF NOT EXISTS idx_audit_logs_forwarded ON audit_logs(forwarded);

-- Tabela para armazenar configurações das políticas de auditoria
CREATE TABLE IF NOT EXISTS audit_policies (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    enabled BOOLEAN NOT NULL DEFAULT true,
    retention_days INTEGER NOT NULL DEFAULT 90,
    sensitive_fields JSONB DEFAULT '[]'::jsonb,
    event_types JSONB DEFAULT '["*"]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL
);

-- Tabela para armazenar configurações de destinos de encaminhamento de logs
CREATE TABLE IF NOT EXISTS audit_forwarding_destinations (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    endpoint TEXT NOT NULL,
    format VARCHAR(20) NOT NULL DEFAULT 'json',
    headers JSONB DEFAULT '{}'::jsonb,
    enabled BOOLEAN NOT NULL DEFAULT true,
    retry_count INTEGER NOT NULL DEFAULT 3,
    retry_interval INTEGER NOT NULL DEFAULT 5,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL
);

-- Tabela para armazenar configurações de alertas de auditoria
CREATE TABLE IF NOT EXISTS audit_alerts (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    enabled BOOLEAN NOT NULL DEFAULT true,
    condition TEXT NOT NULL,
    event_type VARCHAR(50) DEFAULT '*',
    severity VARCHAR(20) NOT NULL DEFAULT 'medium',
    notification_channels JSONB NOT NULL DEFAULT '["email"]'::jsonb,
    recipients JSONB DEFAULT '[]'::jsonb,
    webhook_url TEXT,
    throttling_period INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    updated_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    last_triggered_at TIMESTAMP WITH TIME ZONE
);

-- Tabela para registrar quando os alertas foram disparados
CREATE TABLE IF NOT EXISTS audit_alert_triggers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id VARCHAR(36) NOT NULL REFERENCES audit_alerts(id) ON DELETE CASCADE,
    triggered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_alert_trigger_unique UNIQUE (alert_id, triggered_at)
);

-- Índice para buscar rapidamente o último disparo
CREATE INDEX IF NOT EXISTS idx_alert_triggers_alert_time ON audit_alert_triggers(alert_id, triggered_at DESC);

-- Tabela para controle de migrações do schema
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(128) PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Inserir configurações padrão para o sistema de auditoria
INSERT INTO system_configuration (id, name, value, category, description)
VALUES (
    'elasticsearch_config',
    'Elasticsearch Configuration',
    '{
        "enabled": false,
        "host": "http://localhost:9200",
        "indexName": "dbmanager-audit-logs",
        "username": "",
        "password": "",
        "apiKey": "",
        "verifySSL": true,
        "timeout": 30,
        "batchSize": 100,
        "retryCount": 3,
        "retryInterval": 5,
        "bufferSize": 10000
    }'::jsonb,
    'audit',
    'Configuration for Elasticsearch audit log integration'
) ON CONFLICT (id) DO NOTHING;

-- Inserir configuração global de auditoria
INSERT INTO system_configuration (id, name, value, category, description)
VALUES (
    'audit_global_config',
    'Audit Global Configuration',
    '{
        "enabled": true,
        "defaultRetentionDays": 90,
        "defaultSensitiveFields": ["password", "auth_token", "credit_card", "ssn"],
        "forwardingEnabled": false
    }'::jsonb,
    'audit',
    'Global configuration for the audit system'
) ON CONFLICT (id) DO NOTHING;

-- Inserir política de auditoria padrão
INSERT INTO audit_policies (
    id, name, description, enabled, retention_days, sensitive_fields, event_types
)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Default Policy',
    'Default audit policy for all events',
    true,
    90,
    '["password", "auth_token", "credit_card", "ssn"]'::jsonb,
    '["*"]'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- Inserir política de auditoria para eventos de segurança
INSERT INTO audit_policies (
    id, name, description, enabled, retention_days, sensitive_fields, event_types
)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    'Security Events',
    'Extended retention for security-related events',
    true,
    365,
    '["password", "auth_token", "credit_card", "ssn"]'::jsonb,
    '["FAILED_LOGIN", "SECURITY_CHANGE", "PERMISSION_CHANGE"]'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- Índices para tabelas de permissões
CREATE INDEX IF NOT EXISTS idx_user_permissions_user_id ON user_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_server_id ON user_permissions(server_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_database_name ON user_permissions(database_name);
CREATE INDEX IF NOT EXISTS idx_user_permissions_server_db ON user_permissions(server_id, database_name);
CREATE INDEX IF NOT EXISTS idx_user_permissions_status ON user_permissions(status);

-- Índices para tabelas de solicitações de acesso
CREATE INDEX IF NOT EXISTS idx_access_requests_user_id ON access_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_access_requests_server_id ON access_requests(server_id);
CREATE INDEX IF NOT EXISTS idx_access_requests_status ON access_requests(status);
CREATE INDEX IF NOT EXISTS idx_access_requests_service_user ON access_requests(is_service_user);
CREATE INDEX IF NOT EXISTS idx_access_requests_service_user_id ON access_requests(service_user_id);

-- Índices para tabelas de notificações
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- Tabela de usuários não gerenciados aceitos
CREATE TABLE IF NOT EXISTS accepted_unmanaged_users (
  id VARCHAR(36) PRIMARY KEY,
  server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE, 
  username VARCHAR(255) NOT NULL, 
  accepted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_by VARCHAR(255) NOT NULL DEFAULT 'system',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP, 
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note TEXT, 
  CONSTRAINT unique_server_username UNIQUE(server_id, username)
);

-- Index para busca rápida
CREATE INDEX IF NOT EXISTS idx_accepted_users_server_user ON accepted_unmanaged_users(server_id, username);
CREATE INDEX IF NOT EXISTS idx_accepted_users_server_id ON accepted_unmanaged_users(server_id);
CREATE INDEX IF NOT EXISTS idx_accepted_users_username ON accepted_unmanaged_users(username);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_accepted_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_accepted_users_updated_at 
BEFORE UPDATE ON accepted_unmanaged_users 
FOR EACH ROW EXECUTE FUNCTION update_accepted_users_updated_at();

-- View para consulta de usuários não gerenciados aceitos
CREATE OR REPLACE VIEW accepted_users_view AS 
SELECT 
    a.id,
    a.server_id,
    a.username,
    a.created_at,
    a.accepted_by AS created_by,
    a.note,
    s.name AS server_name,
    s.type AS server_type
FROM 
    accepted_unmanaged_users a
LEFT JOIN 
    servers s ON a.server_id = s.id
ORDER BY 
    a.created_at DESC;

-- Comentários para documentação
COMMENT ON TABLE accepted_unmanaged_users IS 'Armazena usuários que foram aceitos como não gerenciados em servidores';
COMMENT ON COLUMN accepted_unmanaged_users.id IS 'Chave primária (UUID)';
COMMENT ON COLUMN accepted_unmanaged_users.server_id IS 'ID do servidor onde o usuário existe';
COMMENT ON COLUMN accepted_unmanaged_users.username IS 'Nome de usuário no servidor';
COMMENT ON COLUMN accepted_unmanaged_users.accepted_at IS 'Quando o usuário foi aceito na lista';
COMMENT ON COLUMN accepted_unmanaged_users.accepted_by IS 'Usuário que aceitou este usuário não gerenciado';
COMMENT ON COLUMN accepted_unmanaged_users.created_at IS 'Quando o registro foi criado';
COMMENT ON COLUMN accepted_unmanaged_users.updated_at IS 'Última atualização do registro';
COMMENT ON COLUMN accepted_unmanaged_users.note IS 'Nota opcional sobre por que este usuário foi aceito';

-- Colunas auto_remove_users e notification_email já incluídas na criação da tabela sync_configurations acima

-- Coluna accepted_by já incluída na criação da tabela sync_discrepancies acima
CREATE INDEX IF NOT EXISTS idx_notifications_resource_id ON notifications(resource_id);

-- Tabela para armazenar credenciais de banco de dados
CREATE TABLE IF NOT EXISTS database_credentials (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    username VARCHAR(100) NOT NULL,
    encrypted_password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, server_id)
);

-- Índices para consultas frequentes
CREATE INDEX IF NOT EXISTS idx_database_credentials_user_id ON database_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_database_credentials_server_id ON database_credentials(server_id);

-- Comentários para documentação
COMMENT ON TABLE database_credentials IS 'Armazena credenciais específicas de usuários para bancos de dados';
COMMENT ON COLUMN database_credentials.id IS 'ID único da credencial';
COMMENT ON COLUMN database_credentials.user_id IS 'ID do usuário associado à credencial';
COMMENT ON COLUMN database_credentials.server_id IS 'ID do servidor associado à credencial';
COMMENT ON COLUMN database_credentials.username IS 'Nome de usuário utilizado para acessar o banco de dados';
COMMENT ON COLUMN database_credentials.encrypted_password IS 'Senha criptografada para acessar o banco de dados';

-- O usuário admin será criado pelo script init-admin.sh quando necessário
-- (removida a inserção automática do usuário admin para evitar duplicações)

-- Tabela para rastreamento de permissões recentemente alteradas
CREATE TABLE IF NOT EXISTS recent_permission_changes (
    server_id TEXT NOT NULL,
    username TEXT NOT NULL,
    applied_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    operation TEXT DEFAULT 'applied',
    PRIMARY KEY (server_id, username)
);

-- Adicionar comentários para documentação
COMMENT ON TABLE recent_permission_changes IS 'Rastreia permissões recentemente aplicadas ou revogadas para evitar alertas de discrepância durante o período de graça';
COMMENT ON COLUMN recent_permission_changes.server_id IS 'ID do servidor onde a permissão foi alterada';
COMMENT ON COLUMN recent_permission_changes.username IS 'Nome de usuário afetado pela alteração de permissão';
COMMENT ON COLUMN recent_permission_changes.applied_at IS 'Momento em que a alteração foi aplicada';
COMMENT ON COLUMN recent_permission_changes.expires_at IS 'Momento em que o período de graça expira (tipicamente 5 minutos após a aplicação)';
COMMENT ON COLUMN recent_permission_changes.operation IS 'Tipo de operação: "applied" para permissões concedidas, "revoked" para permissões revogadas';

-- Tabela para rastreamento da frequência de notificações
CREATE TABLE IF NOT EXISTS notification_tracking (
    server_id TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    last_sent_at TIMESTAMP NOT NULL,
    discrepancy_hash TEXT NOT NULL,
    PRIMARY KEY (server_id, notification_type)
);

-- Adicionar comentários para documentação
COMMENT ON TABLE notification_tracking IS 'Rastreia as notificações enviadas para controlar a frequência e evitar envios repetitivos';
COMMENT ON COLUMN notification_tracking.server_id IS 'ID do servidor para o qual a notificação foi enviada';
COMMENT ON COLUMN notification_tracking.notification_type IS 'Tipo de notificação (ex: discrepancies, unmanaged_user)';
COMMENT ON COLUMN notification_tracking.last_sent_at IS 'Momento em que a última notificação deste tipo foi enviada';

-- ====================================================================================================
-- TABELAS DE SEGURANÇA
-- ====================================================================================================

-- Adicionar campo para rastrear última alteração de senha
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMP;

-- Atualizar senhas existentes com a data de criação
UPDATE users SET password_changed_at = created_at WHERE password_changed_at IS NULL;

-- Tabela para histórico de senhas
CREATE TABLE IF NOT EXISTS password_history (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_history_user ON password_history(user_id);
CREATE INDEX IF NOT EXISTS idx_password_history_created ON password_history(created_at);

-- Tabela para auditoria de tentativas de login
CREATE TABLE IF NOT EXISTS login_attempts (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    username VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    attempted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_login_attempts_username ON login_attempts(username);
CREATE INDEX IF NOT EXISTS idx_login_attempts_ip ON login_attempts(ip_address);
CREATE INDEX IF NOT EXISTS idx_login_attempts_time ON login_attempts(attempted_at);

-- Tabela para blacklist de IPs
CREATE TABLE IF NOT EXISTS ip_blacklist (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    ip_address VARCHAR(45) NOT NULL UNIQUE,
    reason VARCHAR(255) NOT NULL,
    blocked_at TIMESTAMP NOT NULL DEFAULT NOW(),
    blocked_until TIMESTAMP,
    blocked_by VARCHAR(36) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_ip_blacklist_ip ON ip_blacklist(ip_address);
CREATE INDEX IF NOT EXISTS idx_ip_blacklist_until ON ip_blacklist(blocked_until);

-- Tabela para tokens de recuperação de senha
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_user ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_password_reset_expires ON password_reset_tokens(expires_at);

-- Tabela para notificações de expiração de senha
CREATE TABLE IF NOT EXISTS password_expiration_notifications (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_date DATE NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, notification_date)
);

CREATE INDEX IF NOT EXISTS idx_password_expiration_user ON password_expiration_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_password_expiration_date ON password_expiration_notifications(notification_date);

-- Comentários para documentação das tabelas de segurança
COMMENT ON TABLE password_history IS 'Histórico de senhas anteriores dos usuários para prevenir reutilização';
COMMENT ON TABLE login_attempts IS 'Registro de todas as tentativas de login para auditoria e detecção de ataques';
COMMENT ON TABLE ip_blacklist IS 'Lista de IPs bloqueados por questões de segurança';
COMMENT ON TABLE password_reset_tokens IS 'Tokens temporários para recuperação de senha';
COMMENT ON TABLE password_expiration_notifications IS 'Controle de notificações enviadas sobre expiração de senha';

COMMENT ON COLUMN users.password_changed_at IS 'Data da última alteração de senha para controle de expiração';
COMMENT ON COLUMN login_attempts.failure_reason IS 'Motivo da falha no login (senha incorreta, conta bloqueada, etc)';
COMMENT ON COLUMN ip_blacklist.blocked_until IS 'Data até quando o IP estará bloqueado (NULL = permanente)';

-- ====================================================================================================
-- CONFIGURAÇÕES DO SISTEMA
-- ====================================================================================================

-- Tabela para configurações do sistema
CREATE TABLE IF NOT EXISTS system_configuration (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    value JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_system_configuration_category ON system_configuration(category);

-- Comentários para documentação
COMMENT ON TABLE system_configuration IS 'Armazena todas as configurações do sistema em formato JSON';
COMMENT ON COLUMN system_configuration.id IS 'Identificador único da configuração (ex: smtp, sso, security)';
COMMENT ON COLUMN system_configuration.name IS 'Nome descritivo da configuração';
COMMENT ON COLUMN system_configuration.category IS 'Categoria da configuração (ex: email, security, sync)';
COMMENT ON COLUMN system_configuration.value IS 'Valores da configuração em formato JSON';

-- Inserir configurações padrão de segurança se não existirem
INSERT INTO system_configuration (id, name, category, value)
VALUES 
    ('security', 'Security Configuration', 'security', '{
        "passwordPolicy": {
            "minLength": 8,
            "requireUppercase": true,
            "requireLowercase": true,
            "requireNumbers": true,
            "requireSpecialChars": true,
            "preventCommonPasswords": true,
            "expirationDays": 90,
            "historyCount": 5
        },
        "sessionPolicy": {
            "sessionTimeout": 30,
            "maxConcurrentSessions": 3,
            "enforceIpLock": false
        },
        "apiSecurity": {
            "rateLimit": 100,
            "requireHttps": true,
            "corsEnabled": true,
            "allowedOrigins": "*"
        }
    }')
ON CONFLICT (id) DO NOTHING;
COMMENT ON COLUMN notification_tracking.discrepancy_hash IS 'Hash calculado das discrepâncias para detectar mudanças no conteúdo';
-- Criar tabela security_events que está faltando

CREATE TABLE IF NOT EXISTS security_events (
    id VARCHAR(36) PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    event_action VARCHAR(100) NOT NULL,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(100),
    ip_address VARCHAR(45),
    user_agent TEXT,
    description TEXT,
    metadata JSONB,
    severity VARCHAR(20) DEFAULT 'info', -- info, warning, error, critical
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para consultas eficientes
CREATE INDEX IF NOT EXISTS idx_security_events_event_type ON security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_user_id ON security_events(user_id);
CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events(created_at);
CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity);

-- Adicionar comentário na tabela
COMMENT ON TABLE security_events IS 'Registra todos os eventos de segurança do sistema';
COMMENT ON COLUMN security_events.event_type IS 'Tipo do evento (login, password_change, config_change, etc)';
COMMENT ON COLUMN security_events.event_action IS 'Ação específica (success, failure, blocked, etc)';
COMMENT ON COLUMN security_events.severity IS 'Severidade do evento: info, warning, error, critical';

-- ====================================================================================================
-- BACKUP TABLES
-- ====================================================================================================

-- Create backup configuration table
CREATE TABLE IF NOT EXISTS backup_configuration (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    enabled BOOLEAN NOT NULL DEFAULT false,
    schedule_cron VARCHAR(100) NOT NULL DEFAULT '0 2 * * *', -- Cron expression for scheduling
    backup_type VARCHAR(50) NOT NULL DEFAULT 'full', -- full, incremental
    retention_days INTEGER NOT NULL DEFAULT 30,
    storage_path VARCHAR(500) NOT NULL DEFAULT '/tmp/dbmanager_backups',
    include_audit_logs BOOLEAN NOT NULL DEFAULT true,
    include_configurations BOOLEAN NOT NULL DEFAULT true,
    include_user_data BOOLEAN NOT NULL DEFAULT true,
    notification_email VARCHAR(255) NOT NULL DEFAULT '',
    -- S3 Configuration fields
    storage_type VARCHAR(20) DEFAULT 'local' CHECK (storage_type IN ('local', 's3')),
    s3_enabled BOOLEAN DEFAULT FALSE,
    s3_bucket_name VARCHAR(255),
    s3_region VARCHAR(50),
    s3_access_key_id VARCHAR(255),
    s3_secret_access_key TEXT, -- Encrypted
    s3_storage_class VARCHAR(50) DEFAULT 'STANDARD',
    s3_prefix VARCHAR(255) DEFAULT 'db-manager-backups',
    s3_enable_versioning BOOLEAN DEFAULT TRUE,
    s3_enable_encryption BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create backup history table
CREATE TABLE IF NOT EXISTS backup_history (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    backup_type VARCHAR(50) NOT NULL, -- manual, scheduled
    status VARCHAR(50) NOT NULL, -- running, completed, failed
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    size_bytes BIGINT,
    file_path VARCHAR(500),
    error_message TEXT,
    created_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    metadata TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_backup_history_status ON backup_history(status);
CREATE INDEX IF NOT EXISTS idx_backup_history_started_at ON backup_history(started_at);
CREATE INDEX IF NOT EXISTS idx_backup_history_backup_type ON backup_history(backup_type);

-- Add comments for documentation
COMMENT ON TABLE backup_configuration IS 'Stores system backup configuration settings';
COMMENT ON TABLE backup_history IS 'Records history of all backup operations';

COMMENT ON COLUMN backup_configuration.schedule_cron IS 'Cron expression for backup scheduling (e.g., "0 2 * * *" for daily at 2 AM)';
COMMENT ON COLUMN backup_configuration.backup_type IS 'Type of backup: full or incremental';
COMMENT ON COLUMN backup_configuration.retention_days IS 'Number of days to retain backup files';
COMMENT ON COLUMN backup_configuration.storage_path IS 'File system path where backups are stored';

COMMENT ON COLUMN backup_history.backup_type IS 'Type of backup: manual or scheduled';
COMMENT ON COLUMN backup_history.status IS 'Current status: running, completed, or failed';
COMMENT ON COLUMN backup_history.started_at IS 'Timestamp when the backup started';
COMMENT ON COLUMN backup_history.completed_at IS 'Timestamp when the backup completed';
COMMENT ON COLUMN backup_history.size_bytes IS 'Size of the backup file in bytes';
COMMENT ON COLUMN backup_history.created_by IS 'User who initiated the backup';
COMMENT ON COLUMN backup_history.metadata IS 'Additional metadata about the backup in JSON format';

-- Insert default backup configuration if it doesn't exist
INSERT INTO backup_configuration (
    id,
    enabled,
    schedule_cron,
    backup_type,
    retention_days,
    storage_path,
    include_audit_logs,
    include_configurations,
    include_user_data
) VALUES (
    'default',
    false,
    '0 2 * * *',
    'full',
    30,
    '/tmp/dbmanager_backups',
    true,
    true,
    true
) ON CONFLICT (id) DO NOTHING;

-- ====================================================================================================
-- SERVICE USERS TABLES ADICIONAIS (tabela principal movida para antes de access_requests)
-- ====================================================================================================

-- REMOVIDO: service_user_permissions - Service users agora usam a tabela user_permissions através do campo service_user_id
-- A tabela user_permissions é usada tanto para usuários regulares quanto para service users

-- Tabela para log de entrega de credenciais
CREATE TABLE IF NOT EXISTS service_user_credential_deliveries (
    id VARCHAR(36) PRIMARY KEY,
    service_user_id VARCHAR(36) NOT NULL REFERENCES service_users(id) ON DELETE CASCADE,
    delivered_to VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivery_method VARCHAR(50) NOT NULL, -- 'email', 'notification'
    delivered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivery_status VARCHAR(50) NOT NULL DEFAULT 'sent', -- 'pending', 'sent', 'failed'
    error_message TEXT,
    email_address VARCHAR(255) -- Endereço de email para onde as credenciais foram enviadas
);

-- Índices para tabela de entrega
CREATE INDEX IF NOT EXISTS idx_credential_deliveries_service_user ON service_user_credential_deliveries(service_user_id);
CREATE INDEX IF NOT EXISTS idx_credential_deliveries_user ON service_user_credential_deliveries(delivered_to);
CREATE INDEX IF NOT EXISTS idx_credential_deliveries_date ON service_user_credential_deliveries(delivered_at);

-- As colunas de service_user já foram adicionadas nas definições das tabelas acima

-- Adicionar constraint UNIQUE que considera service_user_id
ALTER TABLE user_permissions ADD CONSTRAINT user_permissions_unique 
UNIQUE (user_id, service_user_id, server_id, database_name, schema_name, table_name);

-- Adicionar constraint para garantir que user_id ou service_user_id deve estar presente
ALTER TABLE user_permissions ADD CONSTRAINT check_user_or_service_user_perm 
CHECK ((user_id IS NOT NULL AND service_user_id IS NULL) OR (user_id IS NULL AND service_user_id IS NOT NULL));

-- Índice para buscar permissões de service_users
CREATE INDEX IF NOT EXISTS idx_user_permissions_service_user_id ON user_permissions(service_user_id);

-- Tabela de auditoria para ações em service_users
CREATE TABLE IF NOT EXISTS service_user_audit_log (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    service_user_id VARCHAR(36) NOT NULL REFERENCES service_users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'updated', 'deleted', 'password_reset', 'activated', 'deactivated'
    action_by VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índices para auditoria
CREATE INDEX IF NOT EXISTS idx_service_user_audit_log_service_user_id ON service_user_audit_log(service_user_id);
CREATE INDEX IF NOT EXISTS idx_service_user_audit_log_action ON service_user_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_service_user_audit_log_created_at ON service_user_audit_log(created_at);

-- Comentários para documentação
COMMENT ON TABLE service_users IS 'Armazena usuários de serviço/aplicação que são contas técnicas para conexão direta aos bancos de dados';
COMMENT ON COLUMN service_users.id IS 'ID único do usuário de serviço';
COMMENT ON COLUMN service_users.username IS 'Nome de usuário único para o usuário de serviço';
COMMENT ON COLUMN service_users.encrypted_password IS 'Senha criptografada do usuário de serviço';
COMMENT ON COLUMN service_users.is_active IS 'Indica se o usuário de serviço está ativo';
COMMENT ON COLUMN service_users.description IS 'Descrição do propósito do usuário de serviço';
COMMENT ON COLUMN service_users.created_by IS 'ID do usuário que criou este usuário de serviço';
COMMENT ON COLUMN service_users.last_password_reset IS 'Data da última redefinição de senha';
COMMENT ON COLUMN service_users.password_reset_by IS 'ID do usuário que realizou a última redefinição de senha';

COMMENT ON TABLE service_user_credential_deliveries IS 'Log de entrega de credenciais de usuários de serviço';
COMMENT ON TABLE service_user_audit_log IS 'Log de auditoria de todas as ações realizadas em usuários de serviço';

COMMENT ON COLUMN access_requests.service_user_id IS 'ID do usuário de serviço associado (se aplicável)';
COMMENT ON COLUMN access_requests.create_service_user IS 'Indica se a solicitação é para criar um novo usuário de serviço';
COMMENT ON COLUMN access_requests.service_user_username IS 'Nome de usuário proposto para o usuário de serviço';

COMMENT ON COLUMN user_permissions.service_user_id IS 'ID do usuário de serviço (se aplicável)';
-- ==============================================
-- VIEWS UNIFICADAS
-- ==============================================

-- View unificada de permissões (usuários regulares + service users)
DROP VIEW IF EXISTS unified_permissions CASCADE;

CREATE VIEW unified_permissions AS
SELECT 
    'regular'::VARCHAR(20) as user_type,
    u.id as user_id,
    u.username,
    NULL::VARCHAR as encrypted_password,
    u.active as user_active,
    up.id as permission_id,
    up.server_id,
    up.database_name,
    up.schema_name,
    up.table_name,
    up.operations,
    up.status as permission_status,
    up.created_at,
    up.updated_at,
    up.expires_at,
    up.created_by,
    s.name as server_name,
    s.type as server_type,
    s.host as server_host,
    s.port as server_port
FROM users u
INNER JOIN user_permissions up ON u.id = up.user_id
INNER JOIN servers s ON up.server_id = s.id
WHERE (up.status = 'active' OR up.status IS NULL)
  AND u.status = 'active'

UNION ALL

-- Permissões de service users (user_permissions com service_user_id)
SELECT 
    'service'::VARCHAR(20) as user_type,
    su.id as user_id,
    su.username,
    su.encrypted_password,
    su.is_active as user_active,
    up.id as permission_id,
    up.server_id,
    up.database_name,
    up.schema_name,
    up.table_name,
    up.operations,
    up.status as permission_status,
    up.created_at,
    up.updated_at,
    up.expires_at,
    up.created_by,
    s.name as server_name,
    s.type as server_type,
    s.host as server_host,
    s.port as server_port
FROM service_users su
INNER JOIN user_permissions up ON su.id = up.service_user_id
INNER JOIN servers s ON up.server_id = s.id
WHERE (up.status = 'active' OR up.status IS NULL)
  AND su.is_active = true
  AND up.service_user_id IS NOT NULL;

-- View unificada de usuários gerenciados (regulares + service)
DROP VIEW IF EXISTS unified_managed_users CASCADE;

CREATE VIEW unified_managed_users AS
SELECT 
    'regular'::VARCHAR(20) as user_type,
    u.id as user_id,
    u.username,
    u.email,
    u.full_name,
    u.role,
    u.active,
    u.created_at,
    u.updated_at,
    NULL::VARCHAR as encrypted_password,
    NULL::VARCHAR as description
FROM users u
WHERE u.status = 'active'

UNION ALL

SELECT 
    'service'::VARCHAR(20) as user_type,
    su.id as user_id,
    su.username,
    NULL::VARCHAR as email,
    su.username as full_name,
    'service_user'::VARCHAR as role,
    su.is_active as active,
    su.created_at,
    su.updated_at,
    su.encrypted_password,
    su.description
FROM service_users su
WHERE su.is_active = true;

-- Comentários para documentação
COMMENT ON VIEW unified_permissions IS 'View unificada que combina permissões de usuários regulares e usuários de serviço';
COMMENT ON VIEW unified_managed_users IS 'View unificada que lista todos os usuários gerenciados pelo sistema';

-- ====================================================================================================
-- API KEYS TABLES
-- ====================================================================================================

-- Tabela para armazenar chaves de API
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    user_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permissions TEXT[] DEFAULT '{}',
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    ip_whitelist TEXT[],
    usage_count INTEGER DEFAULT 0
);

-- Tabela para rastrear o uso das API keys
CREATE TABLE IF NOT EXISTS api_key_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_key_usage_api_key_id ON api_key_usage(api_key_id);
CREATE INDEX IF NOT EXISTS idx_api_key_usage_created_at ON api_key_usage(created_at);

-- Comentários para documentação
COMMENT ON TABLE api_keys IS 'Armazena chaves de API para acesso programático ao sistema';
COMMENT ON COLUMN api_keys.id IS 'ID único da chave de API';
COMMENT ON COLUMN api_keys.name IS 'Nome descritivo da chave de API';
COMMENT ON COLUMN api_keys.key_hash IS 'Hash da chave de API (a chave real é mostrada apenas na criação)';
COMMENT ON COLUMN api_keys.user_id IS 'ID do usuário que criou a chave';
COMMENT ON COLUMN api_keys.permissions IS 'Lista de permissões concedidas à chave';
COMMENT ON COLUMN api_keys.expires_at IS 'Data de expiração da chave (NULL = sem expiração)';
COMMENT ON COLUMN api_keys.last_used_at IS 'Última vez que a chave foi usada';
COMMENT ON COLUMN api_keys.is_active IS 'Indica se a chave está ativa';
COMMENT ON COLUMN api_keys.description IS 'Descrição do propósito da chave';
COMMENT ON COLUMN api_keys.ip_whitelist IS 'Lista de IPs permitidos (NULL = qualquer IP)';
COMMENT ON COLUMN api_keys.usage_count IS 'Contador de uso da chave';

COMMENT ON TABLE api_key_usage IS 'Registro de uso das chaves de API para auditoria e análise';
COMMENT ON COLUMN api_key_usage.api_key_id IS 'ID da chave de API usada';
COMMENT ON COLUMN api_key_usage.endpoint IS 'Endpoint da API acessado';
COMMENT ON COLUMN api_key_usage.method IS 'Método HTTP usado (GET, POST, etc)';
COMMENT ON COLUMN api_key_usage.status_code IS 'Código de status HTTP retornado';
COMMENT ON COLUMN api_key_usage.ip_address IS 'Endereço IP do cliente';
COMMENT ON COLUMN api_key_usage.user_agent IS 'User-Agent do cliente';

-- Adicionar colunas SSO na tabela users se não existirem
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider_id VARCHAR(255);

-- ====================================================================================================
-- TOKEN BLACKLIST TABLE
-- ====================================================================================================

-- Tabela para armazenar tokens JWT revogados
CREATE TABLE IF NOT EXISTS token_blacklist (
    id VARCHAR(36) PRIMARY KEY,
    token VARCHAR(500) NOT NULL UNIQUE,
    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(255)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_token_blacklist_token ON token_blacklist(token);
CREATE INDEX IF NOT EXISTS idx_token_blacklist_expires ON token_blacklist(expires_at);
CREATE INDEX IF NOT EXISTS idx_token_blacklist_user ON token_blacklist(user_id);

-- Comentários para documentação
COMMENT ON TABLE token_blacklist IS 'Armazena tokens JWT que foram revogados antes de sua expiração natural';
COMMENT ON COLUMN token_blacklist.id IS 'ID único do registro de token revogado';
COMMENT ON COLUMN token_blacklist.token IS 'O token JWT revogado (hash ou token completo)';
COMMENT ON COLUMN token_blacklist.user_id IS 'ID do usuário cujo token foi revogado';
COMMENT ON COLUMN token_blacklist.expires_at IS 'Data de expiração original do token';
COMMENT ON COLUMN token_blacklist.revoked_at IS 'Momento em que o token foi revogado';
COMMENT ON COLUMN token_blacklist.reason IS 'Motivo da revogação (logout, security, password_change, etc)';

-- ==============================================
-- TABELAS DO SISTEMA DE LICENÇAS
-- ==============================================

-- Tabela para armazenar a licença atual do sistema
CREATE TABLE IF NOT EXISTS system_license (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encrypted_data TEXT NOT NULL,        -- Licença em Base64
    checksum VARCHAR(64) NOT NULL,       -- SHA256 para verificar integridade
    last_validated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_heartbeat TIMESTAMP,            -- Última validação online
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice para busca rápida da licença mais recente
CREATE INDEX idx_system_license_created_at ON system_license(created_at DESC);

-- Tabela para lista de revogação local
CREATE TABLE IF NOT EXISTS license_revocation_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id VARCHAR(255) UNIQUE NOT NULL,
    reason TEXT,
    revoked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice para busca rápida de licenças revogadas
CREATE INDEX idx_license_revocation_license_id ON license_revocation_list(license_id);

-- Tabela para auditoria de uso de licença
CREATE TABLE IF NOT EXISTS license_usage_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type VARCHAR(50) NOT NULL,  -- 'servers' ou 'users'
    action VARCHAR(50) NOT NULL,         -- 'create_allowed', 'create_denied', etc.
    count INTEGER NOT NULL,              -- Contagem atual
    limit_value INTEGER NOT NULL,        -- Limite da licença
    exceeded BOOLEAN DEFAULT FALSE,      -- Se excedeu o limite
    customer_id VARCHAR(255),
    license_id VARCHAR(255),
    user_id UUID,                        -- Usuário que tentou a ação
    ip_address VARCHAR(45),
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para análise e relatórios
CREATE INDEX idx_license_usage_timestamp ON license_usage_audit(timestamp DESC);
CREATE INDEX idx_license_usage_resource ON license_usage_audit(resource_type, timestamp DESC);
CREATE INDEX idx_license_usage_exceeded ON license_usage_audit(exceeded, timestamp DESC);
CREATE INDEX idx_license_usage_customer ON license_usage_audit(customer_id, timestamp DESC);

-- Tabela para histórico de validações
CREATE TABLE IF NOT EXISTS license_validation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id VARCHAR(255) NOT NULL,
    validation_type VARCHAR(50) NOT NULL, -- 'online', 'offline', 'startup'
    success BOOLEAN NOT NULL,
    error_message TEXT,
    response_data JSONB,                  -- Resposta do servidor de licenças
    duration_ms INTEGER,                  -- Tempo de resposta
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para análise
CREATE INDEX idx_license_validation_created ON license_validation_history(created_at DESC);
CREATE INDEX idx_license_validation_license ON license_validation_history(license_id, created_at DESC);
CREATE INDEX idx_license_validation_success ON license_validation_history(success, created_at DESC);

-- Tabela para alertas de licença
CREATE TABLE IF NOT EXISTS license_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type VARCHAR(50) NOT NULL,     -- 'limit_warning', 'expiration_warning', etc.
    severity VARCHAR(20) NOT NULL,       -- 'info', 'warning', 'error', 'critical'
    resource_type VARCHAR(50),
    message TEXT NOT NULL,
    details JSONB,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by UUID,
    acknowledged_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para alertas
CREATE INDEX idx_license_alerts_created ON license_alerts(created_at DESC);
CREATE INDEX idx_license_alerts_acknowledged ON license_alerts(acknowledged, created_at DESC);
CREATE INDEX idx_license_alerts_severity ON license_alerts(severity, acknowledged, created_at DESC);

-- View para estatísticas de uso
CREATE OR REPLACE VIEW license_usage_stats AS
SELECT 
    resource_type,
    DATE(timestamp) as date,
    COUNT(*) as total_requests,
    SUM(CASE WHEN exceeded THEN 1 ELSE 0 END) as denied_requests,
    MAX(count) as max_usage,
    AVG(count)::INTEGER as avg_usage,
    MAX(limit_value) as limit_value
FROM license_usage_audit
GROUP BY resource_type, DATE(timestamp);

-- View para status atual da licença
CREATE OR REPLACE VIEW license_current_status AS
SELECT 
    l.id,
    l.last_validated,
    l.last_heartbeat,
    CASE 
        WHEN l.last_heartbeat IS NULL THEN 'never'
        WHEN l.last_heartbeat > NOW() - INTERVAL '1 hour' THEN 'online'
        WHEN l.last_heartbeat > NOW() - INTERVAL '24 hours' THEN 'recent'
        ELSE 'offline'
    END as validation_status,
    l.created_at,
    l.updated_at
FROM system_license l
WHERE l.id = (SELECT id FROM system_license ORDER BY created_at DESC LIMIT 1);

-- Função para limpar dados antigos de auditoria
CREATE OR REPLACE FUNCTION cleanup_old_license_audit_data()
RETURNS void AS $$
BEGIN
    -- Remover dados de auditoria com mais de 90 dias
    DELETE FROM license_usage_audit 
    WHERE timestamp < NOW() - INTERVAL '90 days';
    
    -- Remover histórico de validação com mais de 30 dias
    DELETE FROM license_validation_history 
    WHERE created_at < NOW() - INTERVAL '30 days';
    
    -- Remover alertas reconhecidos com mais de 60 dias
    DELETE FROM license_alerts 
    WHERE acknowledged = TRUE 
    AND acknowledged_at < NOW() - INTERVAL '60 days';
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_license_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_system_license_updated_at
    BEFORE UPDATE ON system_license
    FOR EACH ROW
    EXECUTE FUNCTION update_license_updated_at();

-- Comentários nas tabelas
COMMENT ON TABLE system_license IS 'Armazena a licença atual do sistema DBF-WAF';
COMMENT ON TABLE license_revocation_list IS 'Lista local de licenças revogadas';
COMMENT ON TABLE license_usage_audit IS 'Auditoria de uso de recursos vs limites de licença';
COMMENT ON TABLE license_validation_history IS 'Histórico de validações online/offline';
COMMENT ON TABLE license_alerts IS 'Alertas relacionados a licença (limites, expiração, etc)';
COMMENT ON VIEW license_usage_stats IS 'Estatísticas agregadas de uso de licença';
COMMENT ON VIEW license_current_status IS 'Status atual da licença do sistema';

-- Tabela para armazenar detalhes de objetos owned por usuários (Oracle)
CREATE TABLE IF NOT EXISTS user_owned_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    server_id VARCHAR(255) NOT NULL,
    object_type VARCHAR(50) NOT NULL,
    object_name VARCHAR(255) NOT NULL,
    status VARCHAR(50),
    row_count BIGINT,
    has_data BOOLEAN DEFAULT FALSE,
    last_checked TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers(id) ON DELETE CASCADE,
    UNIQUE(user_id, server_id, object_name)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_user_owned_objects_user_server ON user_owned_objects(user_id, server_id);
CREATE INDEX IF NOT EXISTS idx_user_owned_objects_has_data ON user_owned_objects(has_data) WHERE has_data = true;

-- Comentário na tabela
COMMENT ON TABLE user_owned_objects IS 'Armazena objetos de banco de dados owned por usuários (principalmente Oracle)';


-- Tabela de alertas de expiração de senha de service users (adicionada em 12/06/2025)
-- Tabela para controlar alertas de expiração de senha de service users
CREATE TABLE IF NOT EXISTS service_user_password_expiry_alerts (
    id SERIAL PRIMARY KEY,
    service_user_id VARCHAR(255) NOT NULL REFERENCES service_users(id) ON DELETE CASCADE,
    days_before_expiry INTEGER NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Índice para consultas por service_user_id
CREATE INDEX IF NOT EXISTS idx_service_user_expiry_alerts_user_id ON service_user_password_expiry_alerts(service_user_id);

-- Índice para consultas por data
CREATE INDEX IF NOT EXISTS idx_service_user_expiry_alerts_sent_at ON service_user_password_expiry_alerts(sent_at);

-- Constraint única para evitar múltiplos alertas no mesmo dia
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_daily_alert ON service_user_password_expiry_alerts(service_user_id, days_before_expiry, sent_date);

-- Comentários
COMMENT ON TABLE service_user_password_expiry_alerts IS 'Controle de alertas enviados sobre expiração de senha de service users';
COMMENT ON COLUMN service_user_password_expiry_alerts.service_user_id IS 'ID do service user';
COMMENT ON COLUMN service_user_password_expiry_alerts.days_before_expiry IS 'Quantos dias antes da expiração o alerta foi enviado';
COMMENT ON COLUMN service_user_password_expiry_alerts.sent_at IS 'Data/hora em que o alerta foi enviado';
COMMENT ON COLUMN service_user_password_expiry_alerts.sent_date IS 'Data do envio (para controle de unicidade)';

-- ====================================================================================================
-- TABELAS DE MÉTRICAS
-- ====================================================================================================

-- Tabela de configuração de métricas
CREATE TABLE IF NOT EXISTS metrics_configuration (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    collection_level VARCHAR(20) NOT NULL DEFAULT 'basic',
    collection_interval INTEGER NOT NULL DEFAULT 5, -- Em minutos
    cache_ttl INTEGER NOT NULL DEFAULT 5, -- Em minutos
    max_history_size INTEGER NOT NULL DEFAULT 1000,
    max_digest_length INTEGER NOT NULL DEFAULT 512,
    enable_wait_events BOOLEAN NOT NULL DEFAULT false,
    enable_stage_events BOOLEAN NOT NULL DEFAULT false,
    enable_statement_events BOOLEAN NOT NULL DEFAULT true,
    overhead_threshold NUMERIC(5,2) NOT NULL DEFAULT 5.0, -- Percentual
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Novos campos para PostgreSQL
    pg_stat_statements_enabled BOOLEAN NOT NULL DEFAULT false,
    pg_stat_statements_track VARCHAR(10) NOT NULL DEFAULT 'top',
    pg_slow_query_threshold INTEGER NOT NULL DEFAULT 1000, -- Em milissegundos
    auto_collect_enabled BOOLEAN NOT NULL DEFAULT false,
    auto_collect_interval INTEGER NOT NULL DEFAULT 3600, -- Em segundos
    history_retention_days INTEGER NOT NULL DEFAULT 30,
    generate_daily_reports BOOLEAN NOT NULL DEFAULT false,
    UNIQUE(server_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_metrics_configuration_server_id ON metrics_configuration(server_id);
CREATE INDEX IF NOT EXISTS idx_metrics_configuration_enabled ON metrics_configuration(enabled);

-- Comentários
COMMENT ON TABLE metrics_configuration IS 'Configurações de coleta de métricas por servidor de banco de dados';
COMMENT ON COLUMN metrics_configuration.collection_level IS 'Nível de coleta: disabled, basic, intermediate, full';
COMMENT ON COLUMN metrics_configuration.collection_interval IS 'Intervalo entre coletas em minutos';
COMMENT ON COLUMN metrics_configuration.cache_ttl IS 'Tempo de vida do cache em minutos';
COMMENT ON COLUMN metrics_configuration.max_history_size IS 'Tamanho máximo do events_statements_history_long (MySQL)';
COMMENT ON COLUMN metrics_configuration.max_digest_length IS 'Tamanho máximo do digest de queries (MySQL)';
COMMENT ON COLUMN metrics_configuration.overhead_threshold IS 'Limite máximo de overhead aceitável em percentual';
COMMENT ON COLUMN metrics_configuration.pg_stat_statements_enabled IS 'Se pg_stat_statements está habilitado (PostgreSQL)';
COMMENT ON COLUMN metrics_configuration.pg_slow_query_threshold IS 'Threshold para considerar query lenta em ms (PostgreSQL)';
COMMENT ON COLUMN metrics_configuration.auto_collect_enabled IS 'Se a coleta automática está habilitada';
COMMENT ON COLUMN metrics_configuration.history_retention_days IS 'Dias de retenção do histórico de métricas';

-- Tabela de cache de métricas
CREATE TABLE IF NOT EXISTS metrics_cache (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::VARCHAR,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    metrics_data JSONB NOT NULL,
    cached_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(server_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_metrics_cache_server_id ON metrics_cache(server_id);
CREATE INDEX IF NOT EXISTS idx_metrics_cache_expires_at ON metrics_cache(expires_at);

-- Função para limpar cache expirado
CREATE OR REPLACE FUNCTION cleanup_expired_metrics_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM metrics_cache WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Comentários
COMMENT ON TABLE metrics_cache IS 'Cache de métricas coletadas para reduzir overhead';
COMMENT ON FUNCTION cleanup_expired_metrics_cache() IS 'Remove entradas de cache expiradas';

-- Tabela de histórico de métricas
CREATE TABLE IF NOT EXISTS metrics_history (
    id SERIAL PRIMARY KEY,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    metric_type VARCHAR(50) NOT NULL CHECK (metric_type IN ('query', 'session', 'process', 'resource', 'table', 'index', 'database')),
    metric_data JSONB NOT NULL,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_metrics_history_server_id ON metrics_history(server_id);
CREATE INDEX IF NOT EXISTS idx_metrics_history_metric_type ON metrics_history(metric_type);
CREATE INDEX IF NOT EXISTS idx_metrics_history_collected_at ON metrics_history(collected_at);
CREATE INDEX IF NOT EXISTS idx_metrics_history_server_type_date ON metrics_history(server_id, metric_type, collected_at);

-- Comentários
COMMENT ON TABLE metrics_history IS 'Histórico de métricas coletadas dos servidores';
COMMENT ON COLUMN metrics_history.metric_type IS 'Tipo de métrica: query, session, process, resource, table, index, database';
COMMENT ON COLUMN metrics_history.metric_data IS 'Dados da métrica em formato JSON';

-- Tabela de relatórios de queries por usuário
CREATE TABLE IF NOT EXISTS user_query_reports (
    id SERIAL PRIMARY KEY,
    server_id VARCHAR(36) NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    database_user VARCHAR(255) NOT NULL,
    report_date DATE NOT NULL,
    total_queries INTEGER DEFAULT 0,
    total_execution_time BIGINT DEFAULT 0,
    avg_execution_time BIGINT DEFAULT 0,
    slow_queries INTEGER DEFAULT 0,
    failed_queries INTEGER DEFAULT 0,
    unique_queries INTEGER DEFAULT 0,
    total_rows BIGINT DEFAULT 0,
    query_types JSONB DEFAULT '{}'::jsonb,
    top_queries JSONB DEFAULT '[]'::jsonb,
    hourly_distribution JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(server_id, database_user, report_date)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_user_reports_server_id ON user_query_reports(server_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_user ON user_query_reports(database_user);
CREATE INDEX IF NOT EXISTS idx_user_reports_date ON user_query_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_user_reports_server_user_date ON user_query_reports(server_id, database_user, report_date);

-- Comentários
COMMENT ON TABLE user_query_reports IS 'Relatórios diários de queries executadas por usuário';
COMMENT ON COLUMN user_query_reports.query_types IS 'Contagem de queries por tipo (SELECT, INSERT, UPDATE, DELETE, etc)';
COMMENT ON COLUMN user_query_reports.top_queries IS 'Lista das top queries mais executadas ou custosas';
COMMENT ON COLUMN user_query_reports.failed_queries IS 'Número de queries que falharam durante o período';
COMMENT ON COLUMN user_query_reports.hourly_distribution IS 'Distribuição de queries por hora do dia';