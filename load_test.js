import { check, sleep } from 'k6';
import http from 'k6/http';
import { Trend } from 'k6/metrics';

// Métrica personalizada para o tempo de resposta
let transactionDuration = new Trend('transaction_duration');

// Configuração de opções para o k6
export let options = {
  stages: [
    { duration: '10s', target: 50 },
    { duration: '20s', target: 100 },
    { duration: '30s', target: 500 },
    { duration: '60s', target: 800 },
    { duration: '60s', target: 1200 },
  ],
};

const types = ['withdrawal', 'deposit'];

const GO_API_URL = 'http://go-api.local:8080/transaction';

export default function () {
  const url = GO_API_URL;
  const payload = JSON.stringify({
    amount: Math.random() * 1000, // Valor aleatório entre 0 e 1000
    description: types[Math.floor(Math.random() * types.length)],
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  // Realiza a requisição POST
  let res = http.post(url, payload, params);

  // Checa se a requisição foi bem-sucedida
  check(res, {
    'status é 201': (r) => r.status === 201,
  });

  // Registra o tempo de resposta da requisição
  transactionDuration.add(res.timings.duration);

  // Atraso entre as requisições
  sleep(1);
}
