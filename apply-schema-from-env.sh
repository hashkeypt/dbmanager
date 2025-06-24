#!/bin/bash

# DB-Manager - Quick Schema Application Script
# Reads .env file and applies the database schema

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}DB-Manager - Database Schema Setup${NC}"
echo -e "${GREEN}==================================${NC}"
echo ""

# Check for .env file
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo ""
    echo "Please create a .env file with your database configuration:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your database credentials"
    exit 1
fi

# Load .env file
echo -e "${YELLOW}Loading configuration from .env...${NC}"
export $(grep -v '^#' .env | xargs)

# Get database variables (support both DB_ and DBMANAGER_DB_ prefixes)
DB_HOST=${DB_HOST:-${DBMANAGER_DB_HOST:-localhost}}
DB_PORT=${DB_PORT:-${DBMANAGER_DB_PORT:-5432}}
DB_NAME=${DB_NAME:-${DBMANAGER_DB_NAME:-dbmanager_users}}
DB_USER=${DB_USER:-${DBMANAGER_DB_USER:-dbmanager_admin}}
DB_PASSWORD=${DB_PASSWORD:-${DBMANAGER_DB_PASSWORD}}

# Find schema file
SCHEMA_FILE=""
for path in "scripts/db/complete-schema.sql" "complete-schema.sql" "../scripts/db/complete-schema.sql"; do
    if [ -f "$path" ]; then
        SCHEMA_FILE="$path"
        break
    fi
done

if [ -z "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: Schema file not found!${NC}"
    echo "Expected locations:"
    echo "  - scripts/db/complete-schema.sql"
    echo "  - complete-schema.sql"
    exit 1
fi

# Check password
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Database password not set in .env!${NC}"
    exit 1
fi

# Show configuration
echo ""
echo "Database Configuration:"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Schema: $SCHEMA_FILE"
echo ""

# Check psql
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql not installed!${NC}"
    echo "Please install PostgreSQL client tools."
    exit 1
fi

# Confirm
read -p "Apply schema to database? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Test connection and apply schema
echo ""
echo -e "${YELLOW}Testing database connection...${NC}"
export PGPASSWORD="$DB_PASSWORD"

# Function to test connection
test_connection() {
    psql -h "$1" -p "$2" -U "$DB_USER" -d "postgres" -c '\q' 2>/dev/null
}

# Try original host first
if test_connection "$DB_HOST" "$DB_PORT"; then
    echo -e "${GREEN}✓ Connected to $DB_HOST:$DB_PORT${NC}"
elif [[ "$DB_HOST" == *"dbmanager"* ]] || [[ "$DB_HOST" == *"postgres"* ]]; then
    # Fallback to localhost with mapped port
    echo -e "${YELLOW}Container hostname failed, trying localhost:5432...${NC}"
    if test_connection "localhost" "5432"; then
        DB_HOST="localhost"
        DB_PORT="5432"
        echo -e "${GREEN}✓ Connected via localhost:5432${NC}"
    else
        echo -e "${RED}Error: Could not connect to database${NC}"
        echo "Make sure PostgreSQL container is running:"
        echo "  docker ps | grep postgres"
        exit 1
    fi
else
    echo -e "${RED}Error: Could not connect to database at $DB_HOST:$DB_PORT${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Applying database schema...${NC}"

if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCHEMA_FILE"; then
    echo ""
    echo -e "${GREEN}✓ Schema applied successfully!${NC}"
    
    # Show statistics
    echo ""
    echo "Database statistics:"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
    SELECT 'Tables: ' || COUNT(*) FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"
    
    echo ""
    echo -e "${GREEN}Database is ready!${NC}"
    
    # Create admin user
    echo ""
    echo -e "${YELLOW}Creating default admin user...${NC}"
    
    # Check if admin already exists
    ADMIN_EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM users WHERE username = 'admin';" | tr -d ' ')
    
    if [ "$ADMIN_EXISTS" -eq "0" ]; then
        # Hash for password "password" using bcrypt
        PASSWORD_HASH='$2b$12$19rnT5/blFYqPAtCWSVDeuF3kdtwxBH5ouYXN94MFJp6Vma2ghcgO'
        
        # Create admin user
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        INSERT INTO users (id, username, password, email, full_name, role, active, created_at, updated_at)
        VALUES (
            gen_random_uuid(),
            'admin',
            '$PASSWORD_HASH',
            'admin@db-manager.com',
            'Administrator',
            'Admin',
            true,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        );"
        
        echo -e "${GREEN}✓ Admin user created successfully!${NC}"
        echo ""
        echo "Default credentials:"
        echo "  Username: admin"
        echo "  Password: password"
        echo ""
        echo -e "${YELLOW}IMPORTANT: Change the password after first login!${NC}"
    else
        echo -e "${GREEN}✓ Admin user already exists${NC}"
    fi
    
    echo ""
    echo "You can now start the DB-Manager application."
else
    echo ""
    echo -e "${RED}Error applying schema!${NC}"
    echo "Please check the error messages above."
    exit 1
fi

unset PGPASSWORD