import http from 'k6/http';
import { check, sleep } from 'k6';

// Prueba exigente realista de e-commerce (lectura + NFS + escritura en MariaDB/sesiones)
// Flujo por usuario: Portada -> Catalogo -> Imagen NFS -> Producto -> Agregar al carrito (POST) -> Carrito -> Checkout

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: '15s', target: 15 },
    { duration: '20s', target: 35 },
    { duration: '25s', target: 60 },
    { duration: '25s', target: 80 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    http_req_failed: [
      { threshold: 'rate<0.15', abortOnFail: true, delayAbortEval: '20s' },
    ],
  },
};

const BASE_URL = __ENV.TARGET_URL || 'https://cms.tas10.local';
const HEADERS = { Host: 'cms.tas10.local' };

export default function () {
  // 1. Portada
  const r1 = http.get(`${BASE_URL}/`, { headers: HEADERS, timeout: '15s' });
  check(r1, { 'home 200': (r) => r.status === 200 });
  sleep(0.3);

  // 2. Catalogo + imagen servida desde NFS
  const r2 = http.get(`${BASE_URL}/shop/`, { headers: HEADERS, timeout: '15s' });
  check(r2, { 'shop 200': (r) => r.status === 200 });

  const rImg = http.get(
    `${BASE_URL}/wp-content/uploads/woocommerce-placeholder-1024x1024.webp`,
    { headers: HEADERS, timeout: '15s' }
  );
  check(rImg, { 'nfs img 200': (r) => r.status === 200 });
  sleep(0.3);

  // 3. Ficha de producto
  const r3 = http.get(`${BASE_URL}/product/pintura/`, { headers: HEADERS, timeout: '15s' });
  check(r3, { 'producto 200': (r) => r.status === 200 });
  sleep(0.3);

  // 4. Escritura real en MariaDB: agregar producto ID 33 al carrito (crea sesion WooCommerce)
  const rAdd = http.post(
    `${BASE_URL}/?wc-ajax=add_to_cart`,
    { product_id: '33', quantity: '1' },
    {
      headers: {
        Host: 'cms.tas10.local',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      timeout: '15s',
    }
  );
  check(rAdd, { 'add_to_cart 200': (r) => r.status === 200 });
  sleep(0.3);

  // 5. Ver carrito con sesion activa
  const rCart = http.get(`${BASE_URL}/cart/`, { headers: HEADERS, timeout: '15s' });
  check(rCart, { 'cart 200': (r) => r.status === 200 });
  sleep(0.3);

  // 6. Ir a checkout con sesion activa
  const rChk = http.get(`${BASE_URL}/checkout/`, { headers: HEADERS, timeout: '15s' });
  check(rChk, { 'checkout 200': (r) => r.status === 200 });
  sleep(0.5);
}
