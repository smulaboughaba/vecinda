/* Vecinda · configuración centralizada de precios y servicios.
   Única fuente de verdad: ningún otro archivo debe contener cifras de precio.
   TODAS las tarifas son hipótesis orientativas (práctica académica / MVP), sin validar con presidentes reales. */

const VECINDA_CONFIG = Object.freeze({
  notaValidacion: "Tarifa orientativa, sujeta a validación.",

  // Modelo 1 · Suscripción escalonada por tamaño de finca. La paga la comunidad, nunca el vecino.
  suscripcion: Object.freeze({
    cuotaBaseMensual: 40,        // € / mes hasta `viviendasIncluidas`
    viviendasIncluidas: 20,
    extraPorVivienda: 1,         // € / mes por cada vivienda a partir de la siguiente a `viviendasIncluidas`
    mesesGratisAnual: 2,         // pago anual = (12 - 2) mensualidades ≈ 16,7 % de descuento
    rangoObjetivo: Object.freeze([20, 80]),
    minViviendas: 1,
    maxViviendas: 500,
  }),

  // Modelo 2 · Servicios a la carta, contratados por el presidente con cargo a la comunidad.
  servicios: Object.freeze([
    Object.freeze({ id: "junta", icono: "🗳️", nombre: "Pack Junta General Online", precio: 45, unidad: "pago único",
      descripcion: "Convocatoria legal, voto telemático certificado, control de coeficientes y acta automática según la LPH." }),
    Object.freeze({ id: "morosos", icono: "⚖️", nombre: "Reclamación de morosos", precio: 25, unidad: "por expediente",
      descripcion: "Certificado de deuda y envío de burofax legal integrado." }),
    Object.freeze({ id: "onboarding", icono: "🚀", nombre: "Puesta en marcha asistida", precio: 60, unidad: "pago único",
      descripcion: "Digitalización de estatutos, carga de censo y configuración inicial en 24 h." }),
  ]),

  // Modelo 3 · Marketplace de gremios (B2B2C): gratis para la comunidad, lo financian los proveedores.
  marketplace: Object.freeze({
    presupuestosPorSolicitud: 3,
    costeParaComunidad: 0,
    comisionObraCerrada: Object.freeze([0.05, 0.08]),   // 5 %-8 % sobre obra cerrada (fase de expansión)
  }),
});

function normalizarViviendas(n, cfg = VECINDA_CONFIG.suscripcion) {
  const v = Math.floor(Number(n));
  if (!Number.isFinite(v) || v < cfg.minViviendas) return cfg.minViviendas;
  return Math.min(v, cfg.maxViviendas);
}

function cuotaMensual(viviendas, cfg = VECINDA_CONFIG.suscripcion) {
  const n = normalizarViviendas(viviendas, cfg);
  return cfg.cuotaBaseMensual + Math.max(0, n - cfg.viviendasIncluidas) * cfg.extraPorVivienda;
}

function cuotaAnual(viviendas, cfg = VECINDA_CONFIG.suscripcion) {
  return cuotaMensual(viviendas, cfg) * (12 - cfg.mesesGratisAnual);
}

/* Resumen listo para pintar. `ciclo`: "mensual" | "anual". */
function resumenPrecio(viviendas, ciclo = "mensual", cfg = VECINDA_CONFIG.suscripcion) {
  const n = normalizarViviendas(viviendas, cfg);
  const mensual = cuotaMensual(n, cfg), anual = cuotaAnual(n, cfg);
  const esAnual = ciclo === "anual";
  const equivMensual = esAnual ? anual / 12 : mensual;
  return {
    viviendas: n, ciclo: esAnual ? "anual" : "mensual",
    mensual, anual,
    ahorroAnual: mensual * 12 - anual,
    totalPeriodo: esAnual ? anual : mensual,    // lo que se cobra en cada pago
    equivMensual,                               // coste mensual equivalente para la comunidad
    porVivienda: equivMensual / n,              // € / vivienda / mes
  };
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { VECINDA_CONFIG, normalizarViviendas, cuotaMensual, cuotaAnual, resumenPrecio };
}
