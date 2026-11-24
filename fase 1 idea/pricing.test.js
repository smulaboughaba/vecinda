// Ejecutar con: node pricing.test.js
const assert = require("node:assert/strict");
const { VECINDA_CONFIG, normalizarViviendas, cuotaMensual, cuotaAnual, resumenPrecio } = require("./pricing.js");

// Tramos del modelo escalonado
assert.equal(cuotaMensual(1), 40);
assert.equal(cuotaMensual(19), 40);
assert.equal(cuotaMensual(20), 40);   // borde: la 20 sigue en la cuota base
assert.equal(cuotaMensual(21), 41);   // borde: la 21 paga +1 €
assert.equal(cuotaMensual(50), 70);
assert.equal(cuotaMensual(80), 100);

// Pago anual = 10 mensualidades (2 gratis)
assert.equal(cuotaAnual(20), 400);
assert.equal(cuotaAnual(50), 700);
assert.equal(cuotaAnual(80), 1000);
assert.equal(resumenPrecio(50, "anual").ahorroAnual, 140);

// Desglose por vivienda
assert.equal(resumenPrecio(20).porVivienda, 2);
assert.equal(resumenPrecio(40).porVivienda, 1.5);
assert.equal(resumenPrecio(80).porVivienda, 1.25);
assert.ok(Math.abs(resumenPrecio(50, "anual").porVivienda - 700 / 12 / 50) < 1e-9);
assert.equal(resumenPrecio(50, "anual").totalPeriodo, 700);
assert.equal(resumenPrecio(50, "mensual").totalPeriodo, 70);

// Entradas raras: vacío, negativo, decimal, texto, enorme
assert.equal(normalizarViviendas(""), 1);
assert.equal(normalizarViviendas(-5), 1);
assert.equal(normalizarViviendas(0), 1);
assert.equal(normalizarViviendas("abc"), 1);
assert.equal(normalizarViviendas(undefined), 1);
assert.equal(normalizarViviendas(20.9), 20);
assert.equal(normalizarViviendas(99999), VECINDA_CONFIG.suscripcion.maxViviendas);
assert.equal(cuotaMensual("50"), 70);

// El catálogo tiene lo acordado
const precios = Object.fromEntries(VECINDA_CONFIG.servicios.map(s => [s.id, s.precio]));
assert.deepEqual(precios, { junta: 45, morosos: 25, onboarding: 60 });
assert.equal(VECINDA_CONFIG.marketplace.costeParaComunidad, 0);
assert.equal(VECINDA_CONFIG.marketplace.presupuestosPorSolicitud, 3);

console.log("pricing.js: todos los tests OK");
