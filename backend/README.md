# Vecinda · Backend (`Rust + Axum + SQLx`)

API central de Vecinda. Se despliega en **Render Free** para pruebas (`staging`) y en **OVH VPS** para producción. Toda la lógica sensible (RBAC, tarifas, exclusividad del marketplace y pagos) vive aquí compilada.

---

## Estructura de carpetas
- [src/domain/](src/domain/) — Reglas puras de negocio (cálculos de tarifas, permisos RBAC, exclusividad de gremios) con tests unitarios (`cargo test`).
- [src/api/](src/api/) — Routers `Axum`, handlers HTTP, validación de entrada, `ETag` (`304 Not Modified`) y `tower-governor` (*rate limiting*).
- [src/auth/](src/auth/) — Hashing Argon2, tokens/cookies `HttpOnly`, y resolución de rol `(usuario_id, comunidad_id) -> rol`.
- [src/cache/](src/cache/) — Caché en memoria con **`moka`** por `comunidad_id` e invalidación inmediata tras escrituras.
- [src/infra/](src/infra/) — Pool PostgreSQL (`SQLx`), cliente S3 para **Cloudflare R2** y webhooks de pago.
- [migrations/](migrations/) — Migraciones SQL versionadas para PostgreSQL.
- [tests/](tests/) — Tests de integración de endpoints y aislamiento *multi-tenant*.

---

## Plan de implementación por fases
- **Fase 0 · Base y BD:**
  - [ ] Inicializar `Cargo.toml` (`axum`, `tokio`, `sqlx`, `moka`, `serde`, `tower-http`, `tower-governor`).
  - [ ] Endpoint `GET /health` verificando conexión a PostgreSQL.
  - [ ] Primeras migraciones en [migrations/](migrations/): `gestorias`, `comunidades`, `viviendas`, `membresias`.
- **Fase 1 · RBAC, Caché y Hub:**
  - [ ] Middleware RBAC estricto en servidor (~5 activos con escritura vs. usuarios planos de solo lectura).
  - [ ] Caché `moka` + `ETag` para `Cuentas`, `Avisos` e `Incidencias` con invalidación por `comunidad_id`.
  - [ ] Endpoints de traspasos, códigos de inquilino y URLs firmadas hacia Cloudflare R2.
- **Fase 2 · Monetización y Pagos:**
  - [ ] Control de asientos de gestoría (*per-seat*) y volumen de comunidades.
  - [ ] Webhooks idempotentes para Stripe/PayPal.
- **Fase 3 · Marketplace:**
  - [ ] Regla de exclusividad en `gremios_comunidad` (0 € si ya hay contrato vigente, bloqueo de competidores) y anuncios en gremios libres.

