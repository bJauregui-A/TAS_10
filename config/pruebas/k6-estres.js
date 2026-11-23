import http from 'k6/http';
import { check, sleep } from 'k6';

// Prueba de estres (busqueda de limite maximo de usuarios) - Nodo Sur Grupo 10
// Se detiene automaticamente si la tasa de error supera 15% para proteger las VMs.

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: '20s', target: 30 },
    { duration: '25s', target: 60 },
    { duration: '25s', target: 100 },
    { duration: '25s', target: 150 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    http_req_failed: [
      { threshold: 'rate<0.15', abortOnFail: true, delayAbortEval: '20s' },
    ],
  },
};

const BASE_URL = __ENV.TARGET_URL || 'https://10.33.195.185';
const HEADERS = { Host: 'cms.tas10.local' };

export default function () {
  const resHome = http.get(`${BASE_URL}/`, { headers: HEADERS, timeout: '15s' });
  check(resHome, { 'home 200': (r) => r.status === 200 });

  sleep(0.3);

  const resShop = http.get(`${BASE_URL}/shop/`, { headers: HEADERS, timeout: '15s' });
  check(resShop, { 'shop 200': (r) => r.status === 200 });

  sleep(0.3);

  const resProd = http.get(`${BASE_URL}/product/pintura/`, { headers: HEADERS, timeout: '15s' });
  check(resProd, { 'producto 200': (r) => r.status === 200 });

  sleep(0.5);
}
