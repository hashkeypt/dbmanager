# DB-Manager API v1 Documentation

## Overview

The DB-Manager API v1 provides programmatic access to database permission management, allowing automation of service user creation and permission management for CI/CD pipelines and other integrations.

## Authentication

All API v1 endpoints require authentication via API Key.

### API Key Authentication

Include your API key in the request header:

```
X-Api-Key: dbf_your_api_key_here
```

### Creating an API Key

API keys must be created through the DB-Manager web interface:
1. Login to DB-Manager
2. Navigate to Settings → API Keys
3. Click "Create API Key"
4. Set appropriate permissions
5. Save the generated key securely

### API Key Permissions

Available permissions:
- `*` - Full access (admin only)
- `service_users:create` - Create service users
- `permissions:read` - View permissions
- `requests:create` - Create access requests
- `servers:read` - List servers

## Base URL

```
https://your-dbmanager-instance/api/v1
```

## Endpoints

### 1. List Servers

Get a list of available database servers.

**Endpoint:** `GET /api/v1/servers`

**Required Permission:** None (authenticated users)

**Request Example:**
```bash
curl -X GET \
  -H "X-Api-Key: dbf_your_api_key_here" \
  https://your-instance/api/v1/servers
```

**Response Example:**
```json
{
  "count": 2,
  "servers": [
    {
      "id": "966a78a9-b9d5-41e3-9d5b-06ab8375dab6",
      "name": "Production PostgreSQL",
      "type": "postgres",
      "host": "db.example.com",
      "port": 5432,
      "description": "Main production database",
      "status": "connected",
      "databases": [
        {
          "name": "app_db"
        },
        {
          "name": "analytics_db"
        }
      ],
      "schemas": {
        "app_db": ["public", "audit"],
        "analytics_db": ["public"]
      },
      "tables": {
        "app_db": {
          "public": ["users", "orders", "products"],
          "audit": ["logs", "changes"]
        },
        "analytics_db": {
          "public": ["events", "metrics"]
        }
      }
    },
    {
      "id": "a1f299ed-c1ed-4d7e-9cdc-eacda1c7316b",
      "name": "MySQL Production",
      "type": "mysql",
      "host": "mysql.example.com",
      "port": 3306,
      "description": "E-commerce database",
      "status": "connected",
      "databases": [
        {
          "name": "ecommerce_db"
        }
      ],
      "tables": {
        "ecommerce_db": ["customers", "orders", "products"]
      }
    }
  ]
}
```

**Note:** Non-admin users will receive filtered information without sensitive details like host/port.

### 2. Create Service User

Create a new service user with specific database permissions. This endpoint is ideal for CI/CD pipelines that need temporary or permanent database access.

**Endpoint:** `POST /api/v1/service-users`

**Required Permission:** `service_users:create`

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | Yes | Username for the service user (must be unique) |
| `description` | string | No | Description of the service user's purpose |
| `server_id` | string | Yes | UUID of the target database server |
| `database` | string | Yes | Name of the database |
| `schema` | string | No | Schema name (for PostgreSQL/Oracle) |
| `tables` | array[string] | Yes | List of table names to grant access |
| `operations` | array[string] | Yes | List of operations: `SELECT`, `INSERT`, `UPDATE`, `DELETE` |
| `is_permanent` | boolean | Yes | Whether the access is permanent |
| `expires_at` | string | No | ISO 8601 datetime for temporary access (ignored if is_permanent=true) |

**Request Example:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: dbf_your_api_key_here" \
  -d '{
    "username": "ci_pipeline_user",
    "description": "GitHub Actions pipeline for data validation",
    "server_id": "a1f299ed-c1ed-4d7e-9cdc-eacda1c7316b",
    "database": "ecommerce_db",
    "tables": ["orders", "customers"],
    "operations": ["SELECT"],
    "is_permanent": false,
    "expires_at": "2024-12-31T23:59:59Z"
  }' \
  https://your-instance/api/v1/service-users
```

**Success Response (with AWS Secrets Manager):**
```json
{
  "service_user_id": "6e9a2171-8fb2-45b0-8b8b-713971357211",
  "username": "ci_pipeline_user",
  "server_id": "a1f299ed-c1ed-4d7e-9cdc-eacda1c7316b",
  "database": "ecommerce_db",
  "tables": ["orders", "customers"],
  "operations": ["SELECT"],
  "is_permanent": false,
  "secret_path": "dbmanager/service-users/service-user-ci_pipeline_user-6e9a2171-8fb2-45b0-8b8b-713971357211",
  "secret_provider": "aws",
  "message": "Service user created successfully"
}
```

**Success Response (without Secrets Manager):**
```json
{
  "service_user_id": "6e9a2171-8fb2-45b0-8b8b-713971357211",
  "username": "ci_pipeline_user",
  "server_id": "a1f299ed-c1ed-4d7e-9cdc-eacda1c7316b",
  "database": "ecommerce_db",
  "tables": ["orders", "customers"],
  "operations": ["SELECT"],
  "is_permanent": false,
  "password": "GeneratedSecurePassword123!",
  "message": "Service user created successfully"
}
```

**Error Responses:**

| Status Code | Description | Example |
|-------------|-------------|---------|
| 400 | Missing required fields | `{"error": "Missing required fields"}` |
| 401 | Invalid API key | `{"error": "Invalid API key"}` |
| 403 | Insufficient permissions | `{"error": "Insufficient permissions"}` |
| 409 | Username already exists | `{"error": "Username already exists"}` |
| 500 | Internal server error | `{"error": "Failed to create service user"}` |

### 3. Create Access Request

Create an access request for a regular user (requires approval workflow).

**Endpoint:** `POST /api/v1/access-requests`

**Required Permission:** `requests:create`

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `server_id` | string | Yes | UUID of the target database server |
| `database` | string | Yes | Name of the database |
| `tables` | array[string] | Yes | List of table names |
| `operations` | array[string] | Yes | List of operations: `SELECT`, `INSERT`, `UPDATE`, `DELETE` |
| `reason` | string | Yes | Justification for the access request |
| `duration_days` | integer | No | Duration in days (0 or omit for permanent) |

**Request Example:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: dbf_your_api_key_here" \
  -d '{
    "server_id": "966a78a9-b9d5-41e3-9d5b-06ab8375dab6",
    "database": "app_db",
    "tables": ["users", "orders"],
    "operations": ["SELECT", "UPDATE"],
    "reason": "Need to update user data for GDPR compliance",
    "duration_days": 7
  }' \
  https://your-instance/api/v1/access-requests
```

**Response Example:**
```json
{
  "request_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "status": "pending",
  "message": "Access request created successfully"
}
```

### 4. List User Permissions

Get current permissions for the authenticated user.

**Endpoint:** `GET /api/v1/permissions`

**Required Permission:** `permissions:read`

**Request Example:**
```bash
curl -X GET \
  -H "X-Api-Key: dbf_your_api_key_here" \
  https://your-instance/api/v1/permissions
```

**Response Example:**
```json
{
  "user_id": "24624096-3d44-4bf9-ae36-aa00cb992091",
  "count": 3,
  "permissions": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "server_id": "966a78a9-b9d5-41e3-9d5b-06ab8375dab6",
      "database": "app_db",
      "schema": "public",
      "table": "users",
      "operations": ["SELECT", "INSERT", "UPDATE"],
      "level": "table",
      "is_permanent": true
    },
    {
      "id": "456e7890-e89b-12d3-a456-426614174001",
      "server_id": "966a78a9-b9d5-41e3-9d5b-06ab8375dab6",
      "database": "app_db",
      "schema": "public",
      "table": "orders",
      "operations": ["SELECT"],
      "level": "table",
      "is_permanent": false,
      "expires_at": "2024-12-31T23:59:59Z",
      "expires_in_days": 45
    }
  ]
}
```

### 5. System Status

Check API availability and system health.

**Endpoint:** `GET /api/v1/status`

**Required Permission:** None (API key required)

**Request Example:**
```bash
curl -X GET \
  -H "X-Api-Key: dbf_your_api_key_here" \
  https://your-instance/api/v1/status
```

**Response Example:**
```json
{
  "status": "healthy",
  "api_key_authenticated": true,
  "stats": {
    "uptime": "healthy",
    "version": "1.0.0",
    "details": "system monitoring active"
  }
}
```

## CI/CD Integration Examples

### GitHub Actions Example

```yaml
name: Database Integration Test

on:
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Create Service User
      id: create_user
      run: |
        RESPONSE=$(curl -s -X POST \
          -H "Content-Type: application/json" \
          -H "X-Api-Key: ${{ secrets.DBMANAGER_API_KEY }}" \
          -d '{
            "username": "gh_action_${{ github.run_id }}",
            "description": "GitHub Action PR #${{ github.event.pull_request.number }}",
            "server_id": "${{ vars.DB_SERVER_ID }}",
            "database": "test_db",
            "tables": ["users", "orders"],
            "operations": ["SELECT"],
            "is_permanent": false,
            "expires_at": "'$(date -u -d "+1 hour" '+%Y-%m-%dT%H:%M:%SZ')'"
          }' \
          ${{ vars.DBMANAGER_URL }}/api/v1/service-users)
        
        echo "response=$RESPONSE" >> $GITHUB_OUTPUT
        SECRET_PATH=$(echo $RESPONSE | jq -r .secret_path)
        echo "secret_path=$SECRET_PATH" >> $GITHUB_OUTPUT
    
    - name: Get Database Credentials
      if: steps.create_user.outputs.secret_path != 'null'
      run: |
        aws secretsmanager get-secret-value \
          --secret-id "${{ steps.create_user.outputs.secret_path }}" \
          --query SecretString \
          --output text > db_credentials.json
    
    - name: Run Database Tests
      run: |
        # Extract credentials
        DB_USER=$(jq -r .username db_credentials.json)
        DB_PASS=$(jq -r .password db_credentials.json)
        DB_HOST=$(jq -r .host db_credentials.json)
        DB_PORT=$(jq -r .port db_credentials.json)
        DB_NAME=$(jq -r .database db_credentials.json)
        
        # Run your tests
        npm test -- --db-user=$DB_USER --db-pass=$DB_PASS
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    environment {
        DBMANAGER_API_KEY = credentials('dbmanager-api-key')
        DBMANAGER_URL = 'https://dbmanager.company.com'
    }
    
    stages {
        stage('Setup Database Access') {
            steps {
                script {
                    def response = sh(
                        script: """
                            curl -s -X POST \
                              -H "Content-Type: application/json" \
                              -H "X-Api-Key: ${DBMANAGER_API_KEY}" \
                              -d '{
                                "username": "jenkins_${BUILD_ID}",
                                "description": "Jenkins Job ${JOB_NAME} Build ${BUILD_NUMBER}",
                                "server_id": "${params.DB_SERVER_ID}",
                                "database": "${params.DATABASE}",
                                "tables": ["customers", "orders"],
                                "operations": ["SELECT"],
                                "is_permanent": false,
                                "expires_at": "2024-12-31T23:59:59Z"
                              }' \
                              ${DBMANAGER_URL}/api/v1/service-users
                        """,
                        returnStdout: true
                    )
                    
                    def jsonResponse = readJSON text: response
                    env.SECRET_PATH = jsonResponse.secret_path
                    env.DB_USERNAME = jsonResponse.username
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    if (env.SECRET_PATH) {
                        // Get credentials from AWS Secrets Manager
                        sh """
                            aws secretsmanager get-secret-value \
                              --secret-id ${SECRET_PATH} \
                              --query SecretString \
                              --output text > credentials.json
                        """
                        
                        def creds = readJSON file: 'credentials.json'
                        
                        withEnv([
                            "DB_HOST=${creds.host}",
                            "DB_PORT=${creds.port}",
                            "DB_USER=${creds.username}",
                            "DB_PASS=${creds.password}",
                            "DB_NAME=${creds.database}"
                        ]) {
                            sh 'npm test'
                        }
                    }
                }
            }
        }
    }
}
```

### GitLab CI Example

```yaml
variables:
  DBMANAGER_URL: "https://dbmanager.company.com"

stages:
  - setup
  - test
  - cleanup

create_db_user:
  stage: setup
  script:
    - |
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $DBMANAGER_API_KEY" \
        -d '{
          "username": "gitlab_'$CI_PIPELINE_ID'",
          "description": "GitLab Pipeline '$CI_PIPELINE_URL'",
          "server_id": "'$DB_SERVER_ID'",
          "database": "production_db",
          "tables": ["users", "orders", "products"],
          "operations": ["SELECT"],
          "is_permanent": false,
          "expires_at": "'$(date -u -d "+2 hours" '+%Y-%m-%dT%H:%M:%SZ')'"
        }' \
        $DBMANAGER_URL/api/v1/service-users)
    
    - echo "$RESPONSE" > user_response.json
    - SECRET_PATH=$(jq -r .secret_path user_response.json)
    - echo "SECRET_PATH=$SECRET_PATH" >> build.env
  artifacts:
    reports:
      dotenv: build.env

run_tests:
  stage: test
  dependencies:
    - create_db_user
  script:
    - |
      if [ ! -z "$SECRET_PATH" ]; then
        aws secretsmanager get-secret-value \
          --secret-id "$SECRET_PATH" \
          --query SecretString \
          --output text > db_creds.json
        
        export DB_HOST=$(jq -r .host db_creds.json)
        export DB_PORT=$(jq -r .port db_creds.json)
        export DB_USER=$(jq -r .username db_creds.json)
        export DB_PASS=$(jq -r .password db_creds.json)
        export DB_NAME=$(jq -r .database db_creds.json)
      fi
    
    - npm install
    - npm test
```

## Best Practices

### 1. Service User Naming Convention

Use descriptive names that include:
- Environment: `prod_`, `staging_`, `dev_`
- Purpose: `ci_`, `backup_`, `analytics_`
- Unique identifier: timestamp, run ID, etc.

Examples:
- `ci_github_action_12345`
- `staging_backup_20240615`
- `prod_analytics_daily`

### 2. Security Recommendations

1. **API Key Management**
   - Store API keys in secure secret management systems
   - Rotate API keys regularly
   - Use minimal required permissions
   - Set IP whitelists when possible

2. **Service User Lifecycle**
   - Always use temporary access when possible
   - Set appropriate expiration times
   - Clean up unused service users
   - Monitor service user activity

3. **Network Security**
   - Always use HTTPS
   - Implement IP whitelisting
   - Use VPN or private networks when possible

### 3. Error Handling

Always implement proper error handling:

```bash
#!/bin/bash
set -e

# Create service user
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $API_KEY" \
  -d "$REQUEST_BODY" \
  $DBMANAGER_URL/api/v1/service-users)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 201 ]; then
  echo "Failed to create service user: $BODY"
  exit 1
fi

# Extract secret path
SECRET_PATH=$(echo "$BODY" | jq -r .secret_path)
if [ "$SECRET_PATH" == "null" ]; then
  # No secrets manager, use password
  PASSWORD=$(echo "$BODY" | jq -r .password)
  # Use password directly
else
  # Fetch from secrets manager
  aws secretsmanager get-secret-value --secret-id "$SECRET_PATH"
fi
```

### 4. Cleanup Strategies

#### Automatic Cleanup (Recommended)
Use expiration times to automatically clean up:
```json
{
  "is_permanent": false,
  "expires_at": "2024-06-20T15:00:00Z"
}
```

#### Manual Cleanup
For long-running service users, implement cleanup in your pipeline:
```bash
# Store service user ID
SERVICE_USER_ID=$(echo $RESPONSE | jq -r .service_user_id)

# After tests complete
curl -X DELETE \
  -H "X-Api-Key: $API_KEY" \
  $DBMANAGER_URL/api/v1/service-users/$SERVICE_USER_ID
```

## Rate Limiting

API endpoints are rate-limited to prevent abuse:
- Default: 100 requests per minute per API key
- Burst: 200 requests
- Response headers include rate limit information:
  - `X-RateLimit-Limit`: Maximum requests per window
  - `X-RateLimit-Remaining`: Requests remaining
  - `X-RateLimit-Reset`: Unix timestamp when limit resets

## Troubleshooting

### Common Issues

1. **"API key required" Error**
   - Ensure the `X-Api-Key` header is present
   - Check for typos in the header name
   - Verify the API key format starts with `dbf_`

2. **"Invalid API key" Error**
   - Verify the API key is active
   - Check if the API key has expired
   - Ensure IP whitelist includes your IP

3. **"Insufficient permissions" Error**
   - Verify API key has required permissions
   - Contact administrator to update permissions

4. **"Authentication error" (User ID not found)**
   - API key may be corrupted or invalid
   - Regenerate the API key

5. **Connection Timeouts**
   - Check network connectivity
   - Verify firewall rules
   - Ensure DB-Manager is accessible

### Debug Mode

Enable debug information by adding the `X-Debug: true` header:
```bash
curl -X GET \
  -H "X-Api-Key: dbf_your_api_key_here" \
  -H "X-Debug: true" \
  https://your-instance/api/v1/servers
```

## Support

For additional support:
- Documentation: https://docs.db-manager.com
- API Status: https://status.db-manager.com
- Support: support@db-manager.com

## Changelog

### v1.0.0 (2024-06-24)
- Initial API v1 release
- Service user management endpoints
- Access request creation
- Server and permission listing
- AWS Secrets Manager integration