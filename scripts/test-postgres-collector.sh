#!/bin/bash

# Script para testar manualmente o coletor PostgreSQL

SERVER_ID="1760c88a-e71f-403b-a59d-d0ab9e609835"
SESSION_ID="57b554da-b526-4a93-a380-6fa62879aaf5"

echo "=== Testando Query Audit para PostgreSQL ==="
echo

echo "1. Verificando status do coletor:"
curl -s "http://localhost/api/query-audit/collection/status" \
  -H "Cookie: dbmanager_session=$SESSION_ID" | jq '.servers[] | select(.id == "'$SERVER_ID'")'

echo
echo "2. Verificando configuração:"
curl -s "http://localhost/api/query-audit/config/$SERVER_ID" \
  -H "Cookie: dbmanager_session=$SESSION_ID" | jq .

echo
echo "3. Verificando prerequisites:"
curl -s "http://localhost/api/query-audit/prerequisites/$SERVER_ID" \
  -H "Cookie: dbmanager_session=$SESSION_ID" | jq .

echo
echo "4. Forçando coleta manual:"
curl -X POST "http://localhost/api/query-audit/collection/trigger/$SERVER_ID" \
  -H "Cookie: dbmanager_session=$SESSION_ID" \
  -H "Content-Type: application/json" | jq .

echo
echo "5. Aguardando 5 segundos..."
sleep 5

echo
echo "6. Verificando estatísticas:"
curl -s "http://localhost/api/query-audit/summary/$SERVER_ID?hours=1" \
  -H "Cookie: dbmanager_session=$SESSION_ID" | jq .

echo
echo "7. Verificando logs recentes:"
curl -s "http://localhost/api/query-audit/logs?server_id=$SERVER_ID&limit=5" \
  -H "Cookie: dbmanager_session=$SESSION_ID" | jq .