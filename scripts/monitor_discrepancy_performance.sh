#!/bin/bash

# Script de Monitoramento de Performance do Sistema de Discrepâncias
# Este script coleta métricas e gera relatórios sobre a performance do sistema

set -e

# Configurações
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dbmanager}"
DB_USER="${DB_USER:-dbmanager}"
DB_PASSWORD="${DB_PASSWORD:-Inhaca11321}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para executar queries no PostgreSQL
execute_query() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -A -c "$1"
}

# Função para formatar números
format_number() {
    printf "%'d" $1
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Monitor de Performance - Discrepâncias${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Estatísticas Gerais
echo -e "${GREEN}📊 Estatísticas Gerais:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total_discrepancies=$(execute_query "SELECT COUNT(*) FROM sync_discrepancies")
pending_discrepancies=$(execute_query "SELECT COUNT(*) FROM sync_discrepancies WHERE status = 'pending'")
corrected_discrepancies=$(execute_query "SELECT COUNT(*) FROM sync_discrepancies WHERE status = 'corrected'")
accepted_discrepancies=$(execute_query "SELECT COUNT(*) FROM sync_discrepancies WHERE status = 'accepted'")
error_discrepancies=$(execute_query "SELECT COUNT(*) FROM sync_discrepancies WHERE status = 'error'")

echo -e "Total de Discrepâncias: ${YELLOW}$(format_number $total_discrepancies)${NC}"
echo -e "Pendentes: ${YELLOW}$(format_number $pending_discrepancies)${NC}"
echo -e "Corrigidas: ${GREEN}$(format_number $corrected_discrepancies)${NC}"
echo -e "Aceitas: ${BLUE}$(format_number $accepted_discrepancies)${NC}"
echo -e "Com Erro: ${RED}$(format_number $error_discrepancies)${NC}"
echo ""

# 2. Performance das Queries
echo -e "${GREEN}⚡ Performance das Queries:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Testar query sem paginação (antiga)
echo -n "Query sem paginação (100 registros): "
time_old=$(execute_query "
    EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT * FROM sync_discrepancies
    WHERE status = 'pending'
    ORDER BY detected_at DESC
    LIMIT 100
" | jq -r '.[0].["Execution Time"]' 2>/dev/null || echo "N/A")
echo -e "${YELLOW}${time_old} ms${NC}"

# Testar query com índice otimizado
echo -n "Query com índice otimizado: "
time_new=$(execute_query "
    EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT * FROM sync_discrepancies
    WHERE status = 'pending'
    ORDER BY detected_at DESC
    LIMIT 50 OFFSET 0
" | jq -r '.[0].["Execution Time"]' 2>/dev/null || echo "N/A")
echo -e "${GREEN}${time_new} ms${NC}"
echo ""

# 3. Distribuição por Servidor
echo -e "${GREEN}🖥️  Top 10 Servidores com Mais Discrepâncias:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

execute_query "
    SELECT
        s.name as server_name,
        COUNT(d.id) as total,
        COUNT(d.id) FILTER (WHERE d.status = 'pending') as pending
    FROM sync_discrepancies d
    JOIN servers s ON s.id = d.server_id
    GROUP BY s.name
    ORDER BY total DESC
    LIMIT 10
" | while IFS='|' read -r server total pending; do
    printf "%-30s Total: %6s  Pendentes: %6s\n" "$server" "$(format_number $total)" "$(format_number $pending)"
done
echo ""

# 4. Distribuição por Tipo
echo -e "${GREEN}📈 Distribuição por Tipo de Discrepância:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

execute_query "
    SELECT
        type,
        COUNT(*) as count,
        ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM sync_discrepancies), 2) as percentage
    FROM sync_discrepancies
    GROUP BY type
    ORDER BY count DESC
" | while IFS='|' read -r type count percentage; do
    printf "%-25s %8s (%5s%%)\n" "$type" "$(format_number $count)" "$percentage"
done
echo ""

# 5. Análise de Crescimento
echo -e "${GREEN}📅 Crescimento nos Últimos 7 Dias:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

execute_query "
    SELECT
        DATE(detected_at) as date,
        COUNT(*) as new_discrepancies
    FROM sync_discrepancies
    WHERE detected_at >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY DATE(detected_at)
    ORDER BY date DESC
" | while IFS='|' read -r date count; do
    printf "%s: %6s novas discrepâncias\n" "$date" "$(format_number $count)"
done
echo ""

# 6. Tamanho do Banco de Dados
echo -e "${GREEN}💾 Uso de Armazenamento:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

table_size=$(execute_query "
    SELECT pg_size_pretty(pg_total_relation_size('sync_discrepancies'))
")

index_size=$(execute_query "
    SELECT pg_size_pretty(SUM(pg_relation_size(indexrelid)))
    FROM pg_index
    WHERE indrelid = 'sync_discrepancies'::regclass
")

echo -e "Tamanho da Tabela: ${YELLOW}$table_size${NC}"
echo -e "Tamanho dos Índices: ${YELLOW}$index_size${NC}"
echo ""

# 7. Recomendações
echo -e "${GREEN}💡 Recomendações:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$pending_discrepancies" -gt 10000 ]; then
    echo -e "${YELLOW}⚠️  Alto número de discrepâncias pendentes!${NC}"
    echo "   Considere:"
    echo "   - Executar correção em lote"
    echo "   - Revisar políticas de sincronização"
    echo "   - Aumentar frequência de correções automáticas"
fi

if [ "$total_discrepancies" -gt 50000 ]; then
    echo -e "${YELLOW}⚠️  Volume alto de discrepâncias total!${NC}"
    echo "   Considere:"
    echo "   - Executar limpeza de discrepâncias antigas"
    echo "   - Implementar particionamento da tabela"
    echo "   - Arquivar discrepâncias resolvidas"
fi

# Verificar se índices estão sendo usados
unused_indexes=$(execute_query "
    SELECT COUNT(*)
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    AND tablename = 'sync_discrepancies'
    AND idx_scan = 0
")

if [ "$unused_indexes" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Existem $unused_indexes índices não utilizados${NC}"
    echo "   Considere remover índices desnecessários"
fi

echo ""

# 8. Executar VACUUM e ANALYZE se necessário
echo -e "${GREEN}🔧 Manutenção:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

dead_tuples=$(execute_query "
    SELECT n_dead_tup
    FROM pg_stat_user_tables
    WHERE tablename = 'sync_discrepancies'
")

if [ "$dead_tuples" -gt 1000 ]; then
    echo -e "${YELLOW}Detectadas $dead_tuples tuplas mortas${NC}"
    echo "Executando VACUUM ANALYZE..."
    execute_query "VACUUM ANALYZE sync_discrepancies"
    echo -e "${GREEN}✓ VACUUM ANALYZE concluído${NC}"
else
    echo -e "${GREEN}✓ Tabela está otimizada${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Monitoramento Concluído${NC}"
echo -e "${BLUE}========================================${NC}"

# Salvar relatório
REPORT_FILE="discrepancy_performance_$(date +%Y%m%d_%H%M%S).log"
echo "Relatório salvo em: $REPORT_FILE"