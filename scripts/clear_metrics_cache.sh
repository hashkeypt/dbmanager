#!/bin/bash
# Script para limpar o cache de métricas

echo "Limpando cache de métricas..."
docker exec -e PGPASSWORD=admin_password user-db psql -U dbmanager_admin -d dbmanager_users -c "TRUNCATE TABLE metrics_cache;"
echo "Cache limpo! As próximas requisições buscarão dados atualizados."