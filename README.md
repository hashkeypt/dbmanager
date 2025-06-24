# DB-Manager - Sistema de Gerenciamento de Permissões de Banco de Dados

## 📋 Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Requisitos do Sistema](#requisitos-do-sistema)
- [Pré-requisitos de Instalação](#pré-requisitos-de-instalação)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Segurança](#segurança)
- [Pós-Configuração](#pós-configuração)
- [Administração](#administração)
- [Monitoramento](#monitoramento)
- [Backup e Recuperação](#backup-e-recuperação)
- [Solução de Problemas](#solução-de-problemas)
- [Suporte](#suporte)

## 🎯 Visão Geral

O DB-Manager é uma plataforma enterprise para gerenciamento centralizado de permissões de banco de dados, projetada para ambientes corporativos que necessitam de controle, segurança e conformidade em ambientes heterogêneos de banco de dados.

### Principais Características

- **Suporte Multi-Database**: PostgreSQL, MySQL, MariaDB, SQL Server e Oracle
- **Gerenciamento Centralizado**: Interface única para gerenciar permissões em múltiplos servidores
- **Segurança Avançada**: Criptografia AES-256, autenticação multi-fator, integração SSO
- **Auditoria Completa**: Logs detalhados para conformidade com SOX, PCI-DSS, LGPD
- **API RESTful**: Integração com pipelines CI/CD e sistemas externos
- **Sincronização Automática**: Detecção e correção de divergências de permissões

## 🏗️ Arquitetura

### Componentes do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    Nginx (Reverse Proxy)                     │
│                        Porto 80/443                          │
└─────────────────────┬────────────────┬──────────────────────┘
                      │                │
┌─────────────────────▼────────────────▼──────────────────────┐
│   Frontend (React)    │    API Backend (Go)                 │
│   Porto 3000         │    Porto 8082                        │
└──────────────────────┴───────────┬──────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────┐
│              PostgreSQL 17        │        Redis 7           │
│              Porto 5432           │        Porto 6379        │
└──────────────────────────────────┴──────────────────────────┘
```

### Tecnologias Utilizadas

- **Backend**: Go 1.21+ (binário compilado)
- **Frontend**: React 18 com TypeScript
- **Banco de Dados**: PostgreSQL 17 Alpine
- **Cache/Sessões**: Redis 7 Alpine
- **Proxy Reverso**: Nginx Alpine
- **Containerização**: Docker e Docker Compose
- **Segurança**: TLS 1.3, AES-256-GCM

## 💻 Requisitos do Sistema

### Requisitos Mínimos de Hardware

| Componente | Desenvolvimento | Produção |
|------------|----------------|----------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Armazenamento | 20 GB | 50+ GB SSD |
| Rede | 100 Mbps | 1+ Gbps |

### Requisitos de Software

| Software | Versão Mínima | Versão Recomendada |
|----------|---------------|-------------------|
| Sistema Operacional | Ubuntu 20.04 LTS, RHEL 8, Debian 11 | Ubuntu 22.04 LTS |
| Docker | 20.10.0 | 24.0.0+ |
| Docker Compose | 2.0.0 | 2.20.0+ |
| OpenSSL | 1.1.1 | 3.0.0+ |

### Portas Necessárias

| Porta | Serviço | Descrição |
|-------|---------|-----------|
| 80 | HTTP | Tráfego web (redireciona para HTTPS em produção) |
| 443 | HTTPS | Tráfego web seguro (produção) |
| 5432 | PostgreSQL | Banco de dados (opcional, apenas se acesso externo) |
| 8082 | API | Backend API (interno) |

## 📦 Pré-requisitos de Instalação

### 1. Instalar Docker

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# RHEL/CentOS
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 2. Configurar Docker

```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Iniciar e habilitar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verificar instalação
docker --version
docker compose version
```

### 3. Instalar Ferramentas Adicionais

```bash
# OpenSSL (para gerar chaves)
sudo apt-get install -y openssl  # Ubuntu/Debian
sudo yum install -y openssl       # RHEL/CentOS

# Git (para clonar repositório)
sudo apt-get install -y git       # Ubuntu/Debian
sudo yum install -y git           # RHEL/CentOS

# htpasswd (opcional, para autenticação básica)
sudo apt-get install -y apache2-utils  # Ubuntu/Debian
sudo yum install -y httpd-tools        # RHEL/CentOS
```

## 🚀 Instalação

### 1. Clonar o Repositório

```bash
# Via HTTPS
git clone https://github.com/sua-organizacao/dbmanager.git

# Via SSH
git clone git@github.com:sua-organizacao/dbmanager.git

cd dbmanager
```

### 2. Preparar Ambiente

```bash
# Criar estrutura de diretórios
mkdir -p data logs upload

# Definir permissões corretas
chmod 755 data logs upload

# Copiar arquivo de configuração
cp .env.example .env
```

### 3. Gerar Chaves de Segurança

**IMPORTANTE**: Em produção, você DEVE gerar novas chaves de segurança. Nunca use as chaves padrão do `.env.example`.

```bash
# Gerar ENCRYPTION_KEY (32 bytes em base64)
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)"

# Gerar SESSION_SECRET (64 caracteres hexadecimais)
echo "SESSION_SECRET=$(openssl rand -hex 32)"

# Gerar DB_MANAGER_SECRET_KEY (64 caracteres hexadecimais)
echo "DB_MANAGER_SECRET_KEY=$(openssl rand -hex 32)"
```

### 4. Configurar Variáveis de Ambiente

Edite o arquivo `.env` com as chaves geradas e suas configurações:

```bash
nano .env
```

## ⚙️ Configuração

### Variáveis de Ambiente Essenciais

#### Banco de Dados

```env
# PostgreSQL - Banco de dados principal
DBMANAGER_DB_HOST=dbmanager-postgres
DBMANAGER_DB_PORT=5432
DBMANAGER_DB_NAME=dbmanager
DBMANAGER_DB_USER=dbmanager
DBMANAGER_DB_PASSWORD=SuaSenhaSeguraAqui  # ALTERE ESTA SENHA!
```

#### Redis

```env
# Redis - Cache e gerenciamento de sessões
REDIS_HOST=dbmanager-redis
REDIS_PORT=6379
REDIS_PASSWORD=SuaSenhaRedisAqui  # ALTERE ESTA SENHA!
```

#### Segurança

```env
# Chave de criptografia para dados sensíveis (GERE UMA NOVA!)
ENCRYPTION_KEY=ColeSuaChaveGeradaAqui

# Segredo para sessões (GERE UM NOVO!)
SESSION_SECRET=ColeSeuSegredoGeradoAqui

# Chave secreta adicional (GERE UMA NOVA!)
DB_MANAGER_SECRET_KEY=ColeSuaChaveSecretaGeradaAqui

# Tempo máximo de sessão em segundos (8 horas)
SESSION_MAX_AGE=28800

# Cookies seguros (SEMPRE true em produção com HTTPS)
SECURE_COOKIES=true

# Nível de log (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL=INFO
```

#### Aplicação

```env
# Configurações da aplicação
API_PORT=8082
ENVIRONMENT=production
SYSTEM_BASE_URL=https://seu-dominio.com  # ALTERE PARA SEU DOMÍNIO!

# Portas do frontend
FRONTEND_PORT=3000
```

#### Nginx (Opcional)

```env
# Portas do Nginx
NGINX_PORT=80
NGINX_SSL_PORT=443
```

### Configuração para Produção

Para ambientes de produção, também considere:

```env
# Habilitar HTTPS
SECURE_COOKIES=true

# Configurar URL base com HTTPS
SYSTEM_BASE_URL=https://dbmanager.suaempresa.com

# Ajustar nível de log
LOG_LEVEL=WARN

# Definir ambiente
ENVIRONMENT=production
```

## 🔐 Segurança

### 1. Certificados SSL/TLS

Para produção, configure HTTPS:

```bash
# Criar diretório para certificados
mkdir -p ssl

# Opção 1: Usar Let's Encrypt (recomendado)
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d dbmanager.suaempresa.com

# Copiar certificados
sudo cp /etc/letsencrypt/live/dbmanager.suaempresa.com/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/dbmanager.suaempresa.com/privkey.pem ssl/

# Opção 2: Certificado auto-assinado (apenas desenvolvimento)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/privkey.pem \
  -out ssl/fullchain.pem \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=SuaEmpresa/CN=dbmanager.local"
```

### 2. Configurar Nginx para HTTPS

Edite `nginx.conf` e descomente as linhas SSL:

```nginx
server {
    listen 443 ssl http2;
    server_name dbmanager.suaempresa.com;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # ... resto da configuração
}
```

### 3. Firewall

Configure o firewall para permitir apenas as portas necessárias:

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp  # SSH
sudo ufw enable

# Firewalld (RHEL/CentOS)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

### 4. Hardening Adicional

```bash
# Desabilitar acesso externo ao PostgreSQL (se não necessário)
# Comentar a porta no docker-compose.yml:
# ports:
#   - "5432:5432"

# Configurar SELinux (RHEL/CentOS)
sudo setsebool -P httpd_can_network_connect 1

# Limitar recursos do Docker
# Adicionar ao docker-compose.yml:
# deploy:
#   resources:
#     limits:
#       cpus: '2.0'
#       memory: 4G
```

## 🏃 Iniciando o Sistema

### 1. Build das Imagens

```bash
# Construir todas as imagens
docker compose build

# Ou construir com no-cache para garantir versões mais recentes
docker compose build --no-cache
```

### 2. Iniciar Serviços
## Criar Estrutura do banco e criar o usuario admin inicial:
# Mova o arquivo .env de exemplo e edite ele com as chaves de produção
mv .env.example .env

# Aplique o Schema inicial do banco de dados
./apply-schema-from-env.sh

# O script acima vai listar as variáveis que precisa do banco de dados e criar o usuario admin inicial para poder configurar o sistema e subir a licença, depois de criar seu novo usuario ou configurar o SSO, eleimine o usuario admin ou gere uma senha forte e guarde em um cofre de senha.

```bash
# Iniciar todos os serviços
docker compose up -d

# Verificar status dos containers
docker compose ps

# Verificar logs
docker compose logs -f

# Verificar logs de um serviço específico
docker compose logs -f api
docker compose logs -f nginx
```

### 3. Verificar Saúde dos Serviços

```bash
# Verificar health checks
docker compose ps --format "table {{.Service}}\t{{.Status}}"

# Testar conectividade da API
curl -f http://localhost:8082/health

# Testar Nginx
curl -f http://localhost/health
```

## 🔧 Pós-Configuração
### 1. Configurar Sincronização
Acesse o sistema via navegador:
- URL: `http://localhost` (desenvolvimento) ou `https://seu-dominio.com` (produção)
- Faça login com o usuário administrador criado

Configure os servidores de banco de dados:
1. Navegue para **Configurações** → **Servidores**
2. Adicione cada servidor de banco de dados
3. Configure as credenciais de acesso
4. Teste a conexão
5. Ative a sincronização automática

### 2. Configurar Notificações

Configure notificações por email:
1. Navegue para **Configurações** → **Configuração SMTP**
2. Configure servidor SMTP:
   - Host SMTP
   - Porta (587 para TLS, 465 para SSL)
   - Usuário e senha
   - Remetente padrão
3. Teste o envio de email

### 3. Configurar API Keys (se necessário)

Para integração com CI/CD:
1. Navegue para **Configurações** → **Chaves de API**
2. Clique em **Nova API Key**
3. Defina nome e permissões
4. Copie a chave gerada (não será mostrada novamente)

### 4. Configurar Backup Automático

1. Navegue para **Configurações** → **Backup do sistema**
2. habilite o botão de Backups Automáticos
3. habilite o S3 AWS para armazenamento (recomendável)
4. Escolha o que quer fazer backup e clique em salvar.

# Executar comandos no container
docker compose exec api sh
docker compose exec postgres psql -U dbmanager

## 📈 Monitoramento

### 1. Logs do Sistema

```bash
# Logs em tempo real
docker compose logs -f

# Logs com timestamp
docker compose logs -t

# Filtrar logs por serviço
docker compose logs -f api | grep ERROR

# Salvar logs
docker compose logs > dbmanager_logs_$(date +%Y%m%d).txt
```

### 2. Métricas do Docker

```bash
# Status dos containers
docker stats

# Uso de disco
docker system df

# Informações detalhadas
docker compose ps --format json | jq
```

### 3. Monitoramento de Saúde

```bash
# Script de monitoramento
cat > /opt/dbmanager/health-check.sh << 'EOF'
#!/bin/bash
# Verificar API
if ! curl -sf http://localhost:8082/health > /dev/null; then
    echo "API está offline!"
    # Enviar alerta (configure seu método)
fi

# Verificar PostgreSQL
if ! docker compose exec -T postgres pg_isready > /dev/null; then
    echo "PostgreSQL está offline!"
    # Enviar alerta
fi

# Verificar Redis
if ! docker compose exec -T redis redis-cli ping > /dev/null; then
    echo "Redis está offline!"
    # Enviar alerta
fi
EOF

chmod +x /opt/dbmanager/health-check.sh

# Agendar verificação a cada 5 minutos
echo "*/5 * * * * /opt/dbmanager/health-check.sh" | crontab -
```
### 4. Integração com Prometheus (Opcional)
Você opode integrar o sistema para enviar logs para o elasticsearch via configurações
1. Navegue para **Configurações** → **ElasticSearch**
2. Ative o botão e insira os dados de conexão e credenciais de acesso.

### 5. Integração com Prometheus (Opcional)

```yaml
# Adicionar ao docker-compose.yml
prometheus:
  image: prom/prometheus
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
  ports:
    - "9090:9090"
```

## 💾 Backup e Recuperação

### Estratégia de Backup

1. **Banco de Dados**: Backup diário com retenção de 30 dias
2. **Volumes Docker**: Backup semanal
3. **Configurações**: Versionamento com Git
4. **Logs**: Rotação automática com retenção de 90 dias

## 🔧 Solução de Problemas

### Problemas Comuns

#### 1. Container não inicia

```bash
# Verificar logs
docker compose logs api

# Verificar configuração
docker compose config

# Limpar e reconstruir
docker compose down
docker system prune -f
docker compose build --no-cache
docker compose up -d
```

#### 2. Erro de conexão com banco de dados

```bash
# Verificar se PostgreSQL está rodando
docker compose ps postgres

# Testar conexão
docker compose exec postgres pg_isready -U dbmanager

# Verificar credenciais
docker compose exec postgres psql -U dbmanager -c "SELECT 1;"
```

#### 3. Problemas de permissão

```bash
# Corrigir permissões de diretórios
sudo chown -R $USER:$USER data logs upload
chmod -R 755 data logs upload

# Verificar SELinux (RHEL/CentOS)
getenforce
sudo setenforce 0  # Temporário
```

#### 4. Alto uso de memória

```bash
# Verificar consumo
docker stats

# Limitar memória no docker-compose.yml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 2G
```

### Logs de Debug

Para ativar logs detalhados:

```bash
# Editar .env
LOG_LEVEL=DEBUG

# Reiniciar serviços
docker compose restart api

# Verificar logs detalhados
docker compose logs -f api | grep -E "(DEBUG|ERROR)"
```

## 📞 Suporte

### Contatos

- **Suporte Técnico**: suport@hashkey.pt

## 📄 Licença

DB-Manager é um software proprietário. Para informações sobre licenciamento:
- Email: sales@hashkey.pt | Site: www.hashkey.pt
---
© 2024 DB-Manager. Todos os direitos reservados.
