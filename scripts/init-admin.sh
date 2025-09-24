#!/bin/bash

# Script para inicializar o usuário admin ao instalar uma nova instância do sistema
# Esta versão não requer compilação de código Go, usa apenas comandos SQL

# Ir para o diretório raiz do projeto
cd "$(dirname "$0")/../.." || exit

# Função para imprimir mensagens de log
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Verificar variáveis de ambiente ou usar valores padrão
if [ -z "$DB_CONNECTION_STRING" ]; then
  DB_HOST=${DBMANAGER_DB_HOST:-"127.0.0.1"}
  DB_PORT=${DBMANAGER_DB_PORT:-5433}
  DB_USER=${DBMANAGER_DB_USER:-"dbmanager_admin"}
  DB_PASSWORD=${DBMANAGER_DB_PASSWORD:-"admin_password"}
  DB_NAME=${DBMANAGER_DB_NAME:-"dbmanager_users"}
  log "DB_CONNECTION_STRING não encontrada, usando conexão padrão: $DB_HOST:$DB_PORT/$DB_NAME"
else
  # Extrair partes da URL de conexão (formato esperado: postgres://user:pass@host:port/dbname)
  DB_USER=$(echo $DB_CONNECTION_STRING | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
  DB_PASSWORD=$(echo $DB_CONNECTION_STRING | sed -n 's/.*:\/\/[^:]*:\([^@]*\).*/\1/p')
  DB_HOST=$(echo $DB_CONNECTION_STRING | sed -n 's/.*@\([^:]*\):.*/\1/p')
  DB_PORT=$(echo $DB_CONNECTION_STRING | sed -n 's/.*@[^:]*:\([^\/]*\).*/\1/p')
  DB_NAME=$(echo $DB_CONNECTION_STRING | sed -n 's/.*\/\([^?]*\).*/\1/p')
fi

# Preparar exportações para psql
export PGHOST=$DB_HOST
export PGPORT=$DB_PORT
export PGUSER=$DB_USER
export PGPASSWORD=$DB_PASSWORD
export PGDATABASE=$DB_NAME

# Verificar se o psql está disponível
if ! command -v psql &> /dev/null; then
  log "ERRO: psql não está instalado. Não é possível verificar/criar o usuário admin."
  exit 1
fi

# Verificar se podemos nos conectar ao banco de dados
if ! psql -c "\conninfo" &> /dev/null; then
  log "ERRO: Não foi possível conectar ao banco de dados."
  exit 1
fi

# Verificar variáveis de ambiente ou usar valores padrão
if [ -z "$ADMIN_USERNAME" ]; then
  ADMIN_USERNAME="admin"
  log "ADMIN_USERNAME não encontrado, usando valor padrão: $ADMIN_USERNAME"
fi

if [ -z "$ADMIN_PASSWORD" ]; then
  ADMIN_PASSWORD="password"
  log "ADMIN_PASSWORD não encontrado, usando valor padrão (não recomendado para produção)"
fi

if [ -z "$ADMIN_EMAIL" ]; then
  ADMIN_EMAIL="admin@example.com"
  log "ADMIN_EMAIL não encontrado, usando valor padrão: $ADMIN_EMAIL"
fi

if [ -z "$ADMIN_FULLNAME" ]; then
  ADMIN_FULLNAME="Administrator"
  log "ADMIN_FULLNAME não encontrado, usando valor padrão: $ADMIN_FULLNAME"
fi

# Hash da senha (bcrypt)
# Já que não podemos gerar o hash bcrypt facilmente em bash,
# vamos usar um hash predefinido para a senha padrão
if [ "$ADMIN_PASSWORD" = "password" ]; then
  # Hash para "password"
  PASSWORD_HASH='$2b$12$19rnT5/blFYqPAtCWSVDeuF3kdtwxBH5ouYXN94MFJp6Vma2ghcgO'
  log "Usando hash pré-calculado para a senha padrão"
else
  log "AVISO: Usando senha personalizada. Por favor, altere a senha após o primeiro login."
  # Hash simplificado (não é bcrypt, mas permitirá o primeiro login)
  PASSWORD_HASH=$(echo -n "$ADMIN_PASSWORD" | md5sum | awk '{print $1}')
fi

# Verificar se já existe um usuário administrador
ADMIN_EXISTS=$(psql -t -c "SELECT COUNT(*) FROM users WHERE role = 'admin'" | tr -d ' ')

if [ "$ADMIN_EXISTS" -gt "0" ]; then
  log "Usuário administrador já existe, pulando criação."
  exit 0
fi

# Verificar as tabelas do banco de dados
TABLE_COUNT=$(psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" | tr -d ' ')

if [ "$TABLE_COUNT" -eq "0" ]; then
  log "Nenhuma tabela encontrada no banco de dados. Execute a inicialização do esquema primeiro."
  exit 1
fi

# Gerar um UUID para o usuário (simplificado para compatibilidade)
USER_ID="3f9d7f3e-7b0a-4e99-9c9f-b0f2fc4429e5"
CURRENT_TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S")

# Inserir o usuário administrador
log "Criando usuário administrador..."
psql -c "INSERT INTO users (id, username, password, email, full_name, role, status, active, created_at, updated_at) 
        VALUES ('$USER_ID', '$ADMIN_USERNAME', '$PASSWORD_HASH', '$ADMIN_EMAIL', '$ADMIN_FULLNAME', 'admin', 'active', true, '$CURRENT_TIMESTAMP', '$CURRENT_TIMESTAMP')
        ON CONFLICT (username) DO NOTHING;"

# Verificar se a inserção foi bem-sucedida
if [ $? -eq 0 ]; then
  log "Usuário administrador criado com sucesso!"
  log "   Username: $ADMIN_USERNAME"
  log "   Password: $ADMIN_PASSWORD"
  exit 0
else
  log "Erro ao criar usuário administrador."
  exit 1
fi
