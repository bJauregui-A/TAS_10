import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// =============================================================================
// PRUEBA DE ATAQUE Y SATURACIÓN EXTREMA (PUNTO DE QUIEBRE) - NODO SUR GRUPO 10
// =============================================================================
// Simula una ráfaga agresiva de tráfico y saturación de peticiones concurrentes
// para medir el límite de atención simultánea, la estabilidad de los workers
// Apache/PHP en CMS1 y CMS2, y la concurrencia del pool de MariaDB.
// =============================================================================

export const exitoCounter = new Counter('peticiones_exitosas');
export const fallasCounter = new Counter('peticiones_fallidas');
export const tasaFallas = new Rate('tasa_fallas');
export const latenciaDinamica = new Trend('latencia_dinamica_ms');

const BASE_URL = __ENV.TARGET_URL || 'https://10.33.195.185';
const HOST_HEADER = __ENV.HOST_HEADER || 'cms.tas10.local';
const MODO = __ENV.MODO || 'estandar'; // 'rapido', 'estandar', 'extremo'

let stagesConfig = [
  { duration: '15s', target: 30 },  // Calentamiento rápido
  { duration: '25s', target: 80 },  // Saturación de workers
  { duration: '30s', target: 150 }, // Ataque masivo / estrés alto
  { duration: '20s', target: 200 }, // Pico extremo (búsqueda de quiebre)
  { duration: '15s', target: 0 },   // Enfriamiento
];

if (MODO === 'rapido') {
  stagesConfig = [
    { duration: '10s', target: 25 },
    { duration: '20s', target: 70 },
    { duration: '20s', target: 120 },
    { duration: '10s', target: 0 },
  ];
} else if (MODO === 'extremo') {
  stagesConfig = [
    { duration: '15s', target: 50 },
    { duration: '30s', target: 120 },
    { duration: '35s', target: 220 },
    { duration: '35s', target: 300 },
    { duration: '15s', target: 0 },
  ];
}

export const options = {
  insecureSkipTLSVerify: true,
  stages: stagesConfig,
  thresholds: {
    // Si la tasa de falla supera 25%, k6 notifica el punto crítico
    tasa_fallas: ['rate<0.25'],
  },
};

const HEADERS = {
  Host: HOST_HEADER,
  'User-Agent': 'k6-AttackSimulation/1.0 (NodoSur Stress Test)',
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'es-CL,es;q=0.9',
};

const TERMINOS_BUSQUEDA = [
  'pintura',
  'tornillo',
  'martillo',
  'brocha',
  'oferta',
  'madera',
  'tubo',
  'cemento',
  'adhesivo',
  'nodo',
  'sur',
  'tas10',
];

export default function () {
  const vuId = __VU;
  const iterId = __ITER;
  const termino = TERMINOS_BUSQUEDA[(vuId + iterId) % TERMINOS_BUSQUEDA.length];

  // 1. Portada del sitio
  const resHome = http.get(`${BASE_URL}/`, { headers: HEADERS, timeout: '10s' });
  registrarRespuesta(resHome, 'Home');

  sleep(0.1 + Math.random() * 0.2);

  // 2. Búsqueda dinámica en WooCommerce (fuerza consulta SQL LIKE en MariaDB)
  const resSearch = http.get(`${BASE_URL}/?s=${termino}&post_type=product`, {
    headers: HEADERS,
    timeout: '12s',
  });
  registrarRespuesta(resSearch, 'Búsqueda');

  sleep(0.1 + Math.random() * 0.2);

  // 3. Catálogo con ordenamiento dinámico
  const orden = (vuId % 2 === 0) ? 'price-desc' : 'date';
  const resShop = http.get(`${BASE_URL}/shop/?orderby=${orden}`, {
    headers: HEADERS,
    timeout: '10s',
  });
  registrarRespuesta(resShop, 'Catálogo');

  sleep(0.1 + Math.random() * 0.2);

  // 4. Detalle de Producto
  const resProd = http.get(`${BASE_URL}/product/pintura/`, {
    headers: HEADERS,
    timeout: '10s',
  });
  registrarRespuesta(resProd, 'Producto');

  sleep(0.2);
}

function registrarRespuesta(res, nombrePaso) {
  const ok = res.status >= 200 && res.status < 400;
  latenciaDinamica.add(res.timings.duration);

  if (ok) {
    exitoCounter.add(1);
    tasaFallas.add(0);
  } else {
    fallasCounter.add(1);
    tasaFallas.add(1);
  }

  check(res, {
    [`${nombrePaso} OK (2xx/3xx)`]: (r) => r.status >= 200 && r.status < 400,
  });
}

export function handleSummary(data) {
  function safeVal(metric, field, decimals = 2, fallback = '0.00') {
    if (metric && metric.values && metric.values[field] !== undefined && metric.values[field] !== null) {
      return Number(metric.values[field]).toFixed(decimals);
    }
    return fallback;
  }

  const totalReqs = data.metrics.http_reqs ? (data.metrics.http_reqs.values.count || 0) : 0;
  const rateReqs = safeVal(data.metrics.http_reqs, 'rate');
  const fallas = data.metrics.peticiones_fallidas ? (data.metrics.peticiones_fallidas.values.count || 0) : 0;
  const exitos = data.metrics.peticiones_exitosas ? (data.metrics.peticiones_exitosas.values.count || 0) : 0;
  const tasaFallaPct = totalReqs > 0 ? ((fallas / totalReqs) * 100).toFixed(2) : '0.00';
  const avgDur = safeVal(data.metrics.http_req_duration, 'avg');
  const medDur = safeVal(data.metrics.http_req_duration, 'med');
  const p95Dur = safeVal(data.metrics.http_req_duration, 'p(95)');
  const p99Dur = safeVal(data.metrics.http_req_duration, 'p(99)');
  const maxVUs = data.metrics.vus_max ? (data.metrics.vus_max.values.max || 'N/A') : 'N/A';

  let diagnostico = '';
  if (parseFloat(tasaFallaPct) < 2.0) {
    diagnostico = `[EXCELENTE] El clúster absorbió la carga máxima (${maxVUs} VUs concurrentes) sin degradación significativa.`;
  } else if (parseFloat(tasaFallaPct) < 10.0) {
    diagnostico = `[RESILIENTE] Se observó saturación controlada (${tasaFallaPct}% fallos) bajo estrés extremo (${maxVUs} VUs). HAProxy mantuvo el clúster activo.`;
  } else {
    diagnostico = `[PUNTO DE QUIEBRE ALCANZADO] El tráfico saturó los pools de workers PHP/Apache a ${maxVUs} VUs. HAProxy protegió el backend encolando peticiones.`;
  }

  const resumen = `
================================================================================
   RESULTADOS DE PRUEBA DE ATAQUE Y SATURACIÓN - CLÚSTER NODO SUR (GRUPO 10)
================================================================================
Objetivo Evaluado:            ${BASE_URL} (Host: ${HOST_HEADER})
Modo de Carga:                ${MODO.toUpperCase()}
Usuarios Concurrentes Pico:   ${maxVUs} VUs
Peticiones Totales:           ${totalReqs} (${rateReqs} req/segundo)
Peticiones Exitosas (2xx/3xx): ${exitos} (${(100 - parseFloat(tasaFallaPct)).toFixed(2)}%)
Peticiones Fallidas (5xx/Err): ${fallas} (${tasaFallaPct}%)
Latencia Promedio:            ${avgDur} ms
Latencia Mediana:             ${medDur} ms
Latencia Percentil 95 (p95):   ${p95Dur} ms
Latencia Percentil 99 (p99):   ${p99Dur} ms
--------------------------------------------------------------------------------
DIAGNÓSTICO:
${diagnostico}
================================================================================
`;

  return {
    stdout: resumen,
  };
}
