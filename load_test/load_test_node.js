import { check } from 'k6';
import http from 'k6/http';
import { Trend } from 'k6/metrics';

let transactionDuration = new Trend('transaction_duration');

export let options = {
  stages: [
    { duration: '10s', target: 50 },
    { duration: '20s', target: 100 },
    { duration: '30s', target: 500 },
    { duration: '60s', target: 800 },
    { duration: '2m', target: 1200 },
    { duration: '2m', target: 1500 },
    { duration: '2m', target: 2000 },
    { duration: '1m', target: 4000 },
    { duration: '1m', target: 5000 },
  ],
};
const types = ['withdrawal', 'deposit'];

const NODE_API_URL = 'http://localhost:3333/transaction';

export default function () {
  const url = NODE_API_URL;
  const payload = JSON.stringify({
    amount: Math.random() * 1000,
    description: types[Math.floor(Math.random() * types.length)],
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  let res = http.post(url, payload, params);

  check(res, {
    'status é 201': (r) => r.status === 201,
  });

  transactionDuration.add(res.timings.duration);
}
