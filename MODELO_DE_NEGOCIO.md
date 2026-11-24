# Vecinda · Modelo de ingresos (documentación interna)

> Todas las cifras son **hipótesis orientativas** para una práctica académica / MVP. Ninguna está validada con presidentes reales.
> Fuente de verdad en código: [pricing.js](pricing.js). Tests: `node pricing.test.js`.

## Regla fundamental
- **Paga la comunidad como entidad** (aprobado por presidente y vecinos). Se publica en *Cuentas*, visible para todos.
- **El vecino es 100 % gratuito.** Nunca ve un muro de pago ni se le pide tarjeta.

## Modelo 1 · Suscripción escalonada (SaaS B2B)
| Viviendas | Mensual | Anual (2 meses gratis) | €/vivienda/mes (mensual) |
|---|---|---|---|
| 20 | 40 € | 400 € | 2,00 € |
| 50 | 70 € | 700 € | 1,40 € |
| 80 | 100 € | 1.000 € | 1,25 € |

Fórmula: `40 + max(0, viviendas − 20) × 1`. Anual = 10 × mensual (≈ 16,7 % de descuento).
Rango objetivo: 20–80 viviendas. Momento de venta: tras la Junta Ordinaria.

## Modelo 2 · Freemium + servicios a la carta
- **Plan Base (gratis):** comunicación, tablón de avisos, reporte básico de incidencias.
- **Add-ons** (los contrata el presidente, cargo a la comunidad):
  - Pack Junta General Online: 45 € (pago único).
  - Reclamación de morosos: 25 € por expediente.
  - Puesta en marcha asistida: 60 € (pago único).

## Modelo 3 · Marketplace de gremios (B2B2C)
- **Gratis para la comunidad.** Lo financian los proveedores homologados.
- Flujo: incidencia → presidente pulsa *Solicitar 3 presupuestos homologados*.
- Monetización (fase de expansión, meses 5-6): *pay-per-lead* o **comisión del 5 %-8 %** sobre obra cerrada.
- Pendiente de validar: captación de proveedores, homologación, conflicto de interés percibido.

## Qué está simulado en el prototipo
- No hay cobros reales ni servidor: contratar solo añade un cargo en *Cuentas*.
- El reparto de funciones Plan Base vs. Suscripción **no se aplica** en la app.
- Pack Junta: simula la opción de Junta y descarga un acta `.txt` sin validez legal. No hay control de coeficientes ni voto certificado.
- Morosos: solo registra el expediente; no genera certificado ni burofax.
- Presupuestos: solo registra la solicitud; no hay proveedores ni respuestas.
- Por verificar: validez legal de la votación online y de las actas según la LPH; texto RGPD.
