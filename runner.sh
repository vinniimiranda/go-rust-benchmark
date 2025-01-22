monitor_docker_stats() {
  CONTAINER_FILTER=$1
  OUTPUT_FILE=$2
  CONTAINER_NAME=$(docker ps --filter "name=$CONTAINER_FILTER" --format "{{.Names}}" | head -n 1)

  if [ -z "$CONTAINER_NAME" ]; then
    echo "Erro: Nenhum container encontrado para '$CONTAINER_FILTER'."
    exit 1
  fi

  DURATION=600
  INTERVAL=10
  echo "Gerando estatísticas do container $CONTAINER_NAME em formato Markdown..."

  # Cabeçalho da tabela
  echo -e "| Timestamp           | CPU %  | Mem Usage / Limit      | Mem % | Net I/O        | Block I/O       |\n|---------------------|--------|------------------------|-------|----------------|-----------------|" > "$OUTPUT_FILE"

  END_TIME=$((SECONDS + DURATION))
  while [ $SECONDS -lt $END_TIME ]; do
    docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}" "$CONTAINER_NAME" | while IFS="|" read -r cpu mem_usage mem_perc net_io block_io; do
      timestamp=$(date +'%Y-%m-%d %H:%M:%S')
      echo "| $timestamp | $cpu | $mem_usage | $mem_perc | $net_io | $block_io |" >> "$OUTPUT_FILE"
    done
    sleep $INTERVAL
  done
  echo "Estatísticas capturadas em $OUTPUT_FILE"
}


DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
wait
echo "DATE: $DATE"
mkdir -p "./results/$DATE"


# RUST k6 load test
echo "STARTING RUST LOAD TEST"
monitor_docker_stats "rust-api" "./results/${DATE}/rust_docker_stats.md" &
k6 run load_test/load_test_rust.js >> ./results/${DATE}/rust_k6_results.txt
awk '/status é/,/running/' ./results/${DATE}/rust_k6_results.txt > ./results/${DATE}/rust_k6_results_metrics.txt
wait
echo "FINISHED RUST LOAD TEST"
sleep 10


# GO k6 load test
echo "STARTING GO LOAD TEST"
monitor_docker_stats "go-api" "./results/${DATE}/go_docker_stats.md" &
k6 run load_test/load_test_go.js >> ./results/${DATE}/go_k6_results.txt
awk '/status é/,/running/' ./results/${DATE}/go_k6_results.txt > ./results/${DATE}/go_k6_results_metrics.txt
wait
echo "FINISHED GO LOAD TEST"

sleep 10


# NODE k6 load test
# echo "STARTING NODE LOAD TEST"
# monitor_docker_stats "node-api" "./results/node_docker_stats.md" &
# k6 run load_test/load_test_node.js >> ./results/node_k6_results.txt
# awk '/status é/,/running/' ./results/node_k6_results.txt > ./results/node_k6_results_metrics.txt
# wait
# echo "FINISHED NODE LOAD TEST"


# Write final results file
echo "# Final Results for execution" > ./results/${DATE}/final_results.md
echo "## RUST" >> ./results/${DATE}/final_results.md
echo '### K6' >> ./results/${DATE}/final_results.md
echo "\`\`\`rust" >> ./results/${DATE}/final_results.md
cat ./results/${DATE}/rust_k6_results_metrics.txt >> ./results/${DATE}/final_results.md
echo "\`\`\`" >> ./results/${DATE}/final_results.md
echo '### Metrics' >> ./results/${DATE}/final_results.md
cat ./results/${DATE}/rust_docker_stats.md >> ./results/${DATE}/final_results.md
echo "\n\n\n" >> ./results/${DATE}/final_results.md

echo "## GO" >> ./results/${DATE}/final_results.md
echo '### K6' >> ./results/${DATE}/final_results.md
echo "\`\`\`go" >> ./results/${DATE}/final_results.md
cat ./results/${DATE}/go_k6_results_metrics.txt >> ./results/${DATE}/final_results.md
echo "\`\`\`" >> ./results/${DATE}/final_results.md
echo '### Metrics' >> ./results/${DATE}/final_results.md
cat ./results/${DATE}/go_docker_stats.md >> ./results/${DATE}/final_results.md
echo "\n\n"

echo '## Database results' >> ./results/${DATE}/final_results.md
PGPASSWORD=B3pfzQDJhFgKM6B4XTJ9bs1RPlPLsrD9RJZkVphBdsjlCapR29OAgIEZ7MuYc3bu psql -h localhost -p 5432 -d app -U app -c "select distinct source, count(source) from transactions group by source;" >> ./results/${DATE}/final_results.md

echo "FINISHED"

echo "##  AI Analysis" >> ./results/${DATE}/final_results.md

cat ./results/${DATE}/final_results.md | ollama run llama3.2  "Crie uma breve análise dos principais resultados do Benchmark entre Golang e Rust" >> ./results/${DATE}/final_results.md
