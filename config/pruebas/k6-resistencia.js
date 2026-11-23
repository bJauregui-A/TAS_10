import http from 'k6/http';
import { check, sleep } from 'k6';

// Prueba de carga y resistencia progresiva para Nodo Sur (Grupo 10)
// Ejecutar desde cliente: k6 run config/pruebas/k6-resistencia.js
// O con Docker: docker run --rm -i grafana/k6 run - < config/pruebas/k6-resistencia.js

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: '20s', target: 5 },   // Calentamiento (5 usuarios)
    { duration: '30s', target: 15 },  // Carga media (15 usuarios)
    { duration: '30s', target: 30 },  // Carga alta / resistencia (30 usuarios)
    { duration: '15s', target: 0 },   // Enfriamiento
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],       // Menos de 5% de errores
    http_req_duration: ['p(95)<3000'],    // 95% de respuestas bajo 3s
  },
};

const BASE_URL = __ENV.TARGET_URL || 'https://10.33.195.185';
const HEADERS = { Host: 'cms.tas10.local' };

export default function () {
  // 1. Portada del sitio
  const resHome = http.get(`${BASE_URL}/`, { headers: HEADERS });
  check(resHome, {
    'home status 200': (r) => r.status === 200,
  });

  sleep(0.5);

  // 2. Catalogo de la tienda WooCommerce (consulta BD)
  const resShop = http.get(`${BASE_URL}/shop/`, { headers: HEADERS });
  check(resShop, {
    'shop status 200': (r) => r.status === 200,
  });

  sleep(0.5);

  // 3. Producto individual (consulta BD + medios NFS)
  const resProd = http.get(`${BASE_URL}/product/pintura/`, { headers: HEADERS });
  check(resProd, {
    'producto status 200': (r) => r.status === 200,
  });

  sleep(1);
}
