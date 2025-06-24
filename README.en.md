# DB-Manager - Database Permission Management System

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [System Requirements](#system-requirements)
- [Installation Prerequisites](#installation-prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Security](#security)
- [Post-Configuration](#post-configuration)
- [Administration](#administration)
- [Monitoring](#monitoring)
- [Backup and Recovery](#backup-and-recovery)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## 🎯 Overview

DB-Manager is an enterprise platform for centralized database permission management, designed for corporate environments requiring control, security, and compliance across heterogeneous database environments.

### Key Features

- **Multi-Database Support**: PostgreSQL, MySQL, MariaDB, SQL Server, and Oracle
- **Centralized Management**: Single interface to manage permissions across multiple servers
- **Advanced Security**: AES-256 encryption, multi-factor authentication, SSO integration
- **Complete Auditing**: Detailed logs for SOX, PCI-DSS, GDPR compliance
- **RESTful API**: Integration with CI/CD pipelines and external systems
- **Automatic Synchronization**: Detection and correction of permission discrepancies

## 🏗️ Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Nginx (Reverse Proxy)                     │
│                        Port 80/443                           │
└─────────────────────┬────────────────┬──────────────────────┘
                      │                │
┌─────────────────────▼────────────────▼──────────────────────┐
│   Frontend (React)    │    API Backend (Go)                 │
│   Port 3000          │    Port 8082                         │
└──────────────────────┴───────────┬──────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────┐
│              PostgreSQL 17        │        Redis 7           │
│              Port 5432            │        Port 6379         │
└──────────────────────────────────┴──────────────────────────┘
```

### Technology Stack

- **Backend**: Go 1.21+ (compiled binary)
- **Frontend**: React 18 with TypeScript
- **Database**: PostgreSQL 17 Alpine
- **Cache/Sessions**: Redis 7 Alpine
- **Reverse Proxy**: Nginx Alpine
- **Containerization**: Docker and Docker Compose
- **Security**: TLS 1.3, AES-256-GCM

## 💻 System Requirements

### Minimum Hardware Requirements

| Component | Development | Production |
|-----------|-------------|------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 20 GB | 50+ GB SSD |
| Network | 100 Mbps | 1+ Gbps |

### Software Requirements

| Software | Minimum Version | Recommended Version |
|----------|----------------|-------------------|
| Operating System | Ubuntu 20.04 LTS, RHEL 8, Debian 11 | Ubuntu 22.04 LTS |
| Docker | 20.10.0 | 24.0.0+ |
| Docker Compose | 2.0.0 | 2.20.0+ |
| OpenSSL | 1.1.1 | 3.0.0+ |

### Required Ports

| Port | Service | Description |
|------|---------|-------------|
| 80 | HTTP | Web traffic (redirects to HTTPS in production) |
| 443 | HTTPS | Secure web traffic (production) |
| 5432 | PostgreSQL | Database (optional, only for external access) |
| 8082 | API | Backend API (internal) |

## 📦 Installation Prerequisites

### 1. Install Docker

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

### 2. Configure Docker

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
docker compose version
```

### 3. Install Additional Tools

```bash
# OpenSSL (for key generation)
sudo apt-get install -y openssl  # Ubuntu/Debian
sudo yum install -y openssl       # RHEL/CentOS

# Git (to clone repository)
sudo apt-get install -y git       # Ubuntu/Debian
sudo yum install -y git           # RHEL/CentOS

# htpasswd (optional, for basic authentication)
sudo apt-get install -y apache2-utils  # Ubuntu/Debian
sudo yum install -y httpd-tools        # RHEL/CentOS
```

## 🚀 Installation

### 1. Clone the Repository

```bash
# Via HTTPS
git clone https://github.com/your-organization/dbmanager.git

# Via SSH
git clone git@github.com:your-organization/dbmanager.git

cd dbmanager
```

### 2. Prepare Environment

```bash
# Create directory structure
mkdir -p data logs upload

# Set correct permissions
chmod 755 data logs upload

# Copy configuration file
cp .env.example .env
```

### 3. Generate Security Keys

**IMPORTANT**: In production, you MUST generate new security keys. Never use the default keys from `.env.example`.

```bash
# Generate ENCRYPTION_KEY (32 bytes in base64)
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)"

# Generate SESSION_SECRET (64 hexadecimal characters)
echo "SESSION_SECRET=$(openssl rand -hex 32)"

# Generate DB_MANAGER_SECRET_KEY (64 hexadecimal characters)
echo "DB_MANAGER_SECRET_KEY=$(openssl rand -hex 32)"
```

### 4. Configure Environment Variables

Edit the `.env` file with the generated keys and your settings:

```bash
nano .env
```

## ⚙️ Configuration

### Essential Environment Variables

#### Database

```env
# PostgreSQL - Main database
DBMANAGER_DB_HOST=dbmanager-postgres
DBMANAGER_DB_PORT=5432
DBMANAGER_DB_NAME=dbmanager
DBMANAGER_DB_USER=dbmanager
DBMANAGER_DB_PASSWORD=YourSecurePasswordHere  # CHANGE THIS PASSWORD!
```

#### Redis

```env
# Redis - Cache and session management
REDIS_HOST=dbmanager-redis
REDIS_PORT=6379
REDIS_PASSWORD=YourRedisPasswordHere  # CHANGE THIS PASSWORD!
```

#### Security

```env
# Encryption key for sensitive data (GENERATE A NEW ONE!)
ENCRYPTION_KEY=PasteYourGeneratedKeyHere

# Session secret (GENERATE A NEW ONE!)
SESSION_SECRET=PasteYourGeneratedSecretHere

# Additional secret key (GENERATE A NEW ONE!)
DB_MANAGER_SECRET_KEY=PasteYourSecretKeyHere

# Maximum session time in seconds (8 hours)
SESSION_MAX_AGE=28800

# Secure cookies (ALWAYS true in production with HTTPS)
SECURE_COOKIES=true

# Log level (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL=INFO
```

#### Application

```env
# Application settings
API_PORT=8082
ENVIRONMENT=production
SYSTEM_BASE_URL=https://your-domain.com  # CHANGE TO YOUR DOMAIN!

# Frontend ports
FRONTEND_PORT=3000
```

#### Nginx (Optional)

```env
# Nginx ports
NGINX_PORT=80
NGINX_SSL_PORT=443
```

### Production Configuration

For production environments, also consider:

```env
# Enable HTTPS
SECURE_COOKIES=true

# Configure base URL with HTTPS
SYSTEM_BASE_URL=https://dbmanager.yourcompany.com

# Adjust log level
LOG_LEVEL=WARN

# Set environment
ENVIRONMENT=production
```

## 🔐 Security

### 1. SSL/TLS Certificates

For production, configure HTTPS:

```bash
# Create directory for certificates
mkdir -p ssl

# Option 1: Use Let's Encrypt (recommended)
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d dbmanager.yourcompany.com

# Copy certificates
sudo cp /etc/letsencrypt/live/dbmanager.yourcompany.com/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/dbmanager.yourcompany.com/privkey.pem ssl/

# Option 2: Self-signed certificate (development only)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/privkey.pem \
  -out ssl/fullchain.pem \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=dbmanager.local"
```

### 2. Configure Nginx for HTTPS

Edit `nginx.conf` and uncomment the SSL lines:

```nginx
server {
    listen 443 ssl http2;
    server_name dbmanager.yourcompany.com;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # ... rest of configuration
}
```

### 3. Firewall

Configure the firewall to allow only necessary ports:

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

### 4. Additional Hardening

```bash
# Disable external PostgreSQL access (if not needed)
# Comment out the port in docker-compose.yml:
# ports:
#   - "5432:5432"

# Configure SELinux (RHEL/CentOS)
sudo setsebool -P httpd_can_network_connect 1

# Limit Docker resources
# Add to docker-compose.yml:
# deploy:
#   resources:
#     limits:
#       cpus: '2.0'
#       memory: 4G
```

## 🏃 Starting the System

### 1. Build Images

```bash
# Build all images
docker compose build

# Or build with no-cache to ensure latest versions
docker compose build --no-cache
```

### 2. Start Services

```bash
# Start all services
docker compose up -d

# Check container status
docker compose ps

# Check logs
docker compose logs -f

# Check logs for a specific service
docker compose logs -f api
docker compose logs -f nginx
```

### 3. Verify Service Health

```bash
# Check health checks
docker compose ps --format "table {{.Service}}\t{{.Status}}"

# Test API connectivity
curl -f http://localhost:8082/health

# Test Nginx
curl -f http://localhost/health
```

## 🔧 Post-Configuration

### 1. Create Administrator User

```bash
# Access API container
docker compose exec api sh

# Create admin user (inside container)
./dbmanager-api create-admin \
  --username admin \
  --email admin@yourcompany.com \
  --password YourSecurePassword

# Exit container
exit
```

### 2. Configure Synchronization

Access the system via browser:
- URL: `http://localhost` (development) or `https://your-domain.com` (production)
- Login with the created administrator user

Configure database servers:
1. Navigate to **Settings** → **Servers**
2. Add each database server
3. Configure access credentials
4. Test connection
5. Enable automatic synchronization

### 3. Configure Notifications

Configure email notifications:
1. Navigate to **Settings** → **Notifications**
2. Configure SMTP server:
   - SMTP Host
   - Port (587 for TLS, 465 for SSL)
   - Username and password
   - Default sender
3. Test email sending

### 4. Configure API Keys

For CI/CD integration:
1. Navigate to **Settings** → **API Keys**
2. Click **New API Key**
3. Set name and permissions
4. Copy the generated key (won't be shown again)

### 5. Configure Automatic Backup

```bash
# Create backup script
cat > /opt/dbmanager/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/dbmanager/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Database backup
docker compose exec -T postgres pg_dump -U dbmanager dbmanager | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Volume backup
docker run --rm -v dbmanager_postgres_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/postgres_data_$DATE.tar.gz -C /data .

# Keep only last 7 days
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
EOF

chmod +x /opt/dbmanager/backup.sh

# Schedule in cron
echo "0 2 * * * /opt/dbmanager/backup.sh" | crontab -
```

## 📊 Administration

### Useful Commands

```bash
# Stop all services
docker compose down

# Stop and remove volumes (CAUTION: removes data!)
docker compose down -v

# Restart a specific service
docker compose restart api

# Scale services (if configured)
docker compose up -d --scale api=3

# Execute commands in container
docker compose exec api sh
docker compose exec postgres psql -U dbmanager

# Manual database backup
docker compose exec postgres pg_dump -U dbmanager dbmanager > backup.sql

# Restore backup
docker compose exec -T postgres psql -U dbmanager dbmanager < backup.sql
```

### Database Maintenance

```bash
# Access PostgreSQL
docker compose exec postgres psql -U dbmanager -d dbmanager

# Useful SQL commands
-- Check database size
SELECT pg_database_size('dbmanager');

-- List large tables
SELECT schemaname,tablename,pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;

-- Check active connections
SELECT pid, usename, application_name, client_addr, state 
FROM pg_stat_activity WHERE datname = 'dbmanager';

-- Vacuum and analyze
VACUUM ANALYZE;
```

## 📈 Monitoring

### 1. System Logs

```bash
# Real-time logs
docker compose logs -f

# Logs with timestamp
docker compose logs -t

# Filter logs by service
docker compose logs -f api | grep ERROR

# Save logs
docker compose logs > dbmanager_logs_$(date +%Y%m%d).txt
```

### 2. Docker Metrics

```bash
# Container status
docker stats

# Disk usage
docker system df

# Detailed information
docker compose ps --format json | jq
```

### 3. Health Monitoring

```bash
# Monitoring script
cat > /opt/dbmanager/health-check.sh << 'EOF'
#!/bin/bash
# Check API
if ! curl -sf http://localhost:8082/health > /dev/null; then
    echo "API is offline!"
    # Send alert (configure your method)
fi

# Check PostgreSQL
if ! docker compose exec -T postgres pg_isready > /dev/null; then
    echo "PostgreSQL is offline!"
    # Send alert
fi

# Check Redis
if ! docker compose exec -T redis redis-cli ping > /dev/null; then
    echo "Redis is offline!"
    # Send alert
fi
EOF

chmod +x /opt/dbmanager/health-check.sh

# Schedule check every 5 minutes
echo "*/5 * * * * /opt/dbmanager/health-check.sh" | crontab -
```

### 4. Prometheus Integration (Optional)

```yaml
# Add to docker-compose.yml
prometheus:
  image: prom/prometheus
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
  ports:
    - "9090:9090"
```

## 💾 Backup and Recovery

### Backup Strategy

1. **Database**: Daily backup with 30-day retention
2. **Docker Volumes**: Weekly backup
3. **Configuration**: Version control with Git
4. **Logs**: Automatic rotation with 90-day retention

### Recovery Procedure

```bash
# 1. Stop services
docker compose down

# 2. Restore database
docker compose up -d postgres
docker compose exec -T postgres psql -U dbmanager -c "DROP DATABASE IF EXISTS dbmanager;"
docker compose exec -T postgres psql -U dbmanager -c "CREATE DATABASE dbmanager;"
gunzip -c backup_20240115.sql.gz | docker compose exec -T postgres psql -U dbmanager dbmanager

# 3. Restore volumes (if needed)
docker run --rm -v dbmanager_postgres_data:/data -v /opt/dbmanager/backups:/backup alpine tar xzf /backup/postgres_data_20240115.tar.gz -C /data

# 4. Restart all services
docker compose up -d

# 5. Verify integrity
docker compose exec api ./dbmanager-api verify-db
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Container won't start

```bash
# Check logs
docker compose logs api

# Check configuration
docker compose config

# Clean and rebuild
docker compose down
docker system prune -f
docker compose build --no-cache
docker compose up -d
```

#### 2. Database connection error

```bash
# Check if PostgreSQL is running
docker compose ps postgres

# Test connection
docker compose exec postgres pg_isready -U dbmanager

# Verify credentials
docker compose exec postgres psql -U dbmanager -c "SELECT 1;"
```

#### 3. Permission issues

```bash
# Fix directory permissions
sudo chown -R $USER:$USER data logs upload
chmod -R 755 data logs upload

# Check SELinux (RHEL/CentOS)
getenforce
sudo setenforce 0  # Temporary
```

#### 4. High memory usage

```bash
# Check consumption
docker stats

# Limit memory in docker-compose.yml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 2G
```

### Debug Logs

To enable detailed logs:

```bash
# Edit .env
LOG_LEVEL=DEBUG

# Restart services
docker compose restart api

# Check detailed logs
docker compose logs -f api | grep -E "(DEBUG|ERROR)"
```

## 📞 Support

### Documentation

- User Manual: `/docs/user-manual.pdf`
- API Reference: `http://localhost:8082/swagger`
- Wiki: `https://wiki.yourcompany.com/dbmanager`

### Contacts

- **Technical Support**: support@yourcompany.com
- **Emergencies**: +1 555-123-4567 (24/7 for Enterprise customers)
- **Issues**: https://github.com/your-organization/dbmanager/issues

### Support Information

When contacting support, provide:

```bash
# Generate diagnostic report
cat > /tmp/dbmanager-report.txt << EOF
=== DB-Manager Diagnostic Report ===
Date: $(date)
Version: $(docker compose exec api ./dbmanager-api --version)

=== Environment ===
$(uname -a)
$(docker --version)
$(docker compose version)

=== Container Status ===
$(docker compose ps)

=== Recent Logs ===
$(docker compose logs --tail=50)

=== Disk Usage ===
$(df -h)
$(docker system df)
EOF

# Compress and send
tar czf dbmanager-report-$(date +%Y%m%d).tar.gz /tmp/dbmanager-report.txt
```

## 📄 License

DB-Manager is proprietary software. For licensing information:
- Email: sales@yourcompany.com
- Phone: +1 555-888-9999

---

© 2024 DB-Manager. All rights reserved.