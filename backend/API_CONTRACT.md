# Vecinda · Contrato de API REST, Auth, RBAC y Caché

> **Versión:** `v1` (`/api/v1`) · Fuente de verdad compartida entre `backend/` (**Rust `Axum` + `serde` + `SQLx` + `moka`**) y `frontend/` (**React + TypeScript + `Zod` + `TanStack Query`**).
> **Esquema asociado:** [SCHEMA.md](SCHEMA.md) ([0001_initial_schema.sql](migrations/0001_initial_schema.sql), 32 tablas).

---

## 1. Convenciones HTTP, JSON, Errores y Paginación

- **Prefijo base:** `/api/v1` (excepción: `GET /health` en raíz para *healthchecks* de Render/Docker/OVH).
- **Formato JSON (`camelCase`):** todos los DTOs en Rust usan `#[serde(rename_all = "camelCase")]` para coincidir 1:1 con TypeScript/Zod (`comunidadId`, `importeCentimos`, `creadoEn`).
- **Importes monetarios:** siempre enteros `i64` en **céntimos de euro** (`5500` = `55,00 €`), nunca `float`.
- **Fechas:** ISO-8601 en UTC (`2026-11-24T19:00:00Z`).
- **Paginación por cursor (obligatoria en listados):** `?limit=20&cursor=<opaque_base64>` (máximo `limit = 50`). Respuesta estándar:
  ```json
  { "items": [], "nextCursor": "string|null", "hasMore": false }
  ```
- **Formato único de error:** nunca expone trazas SQL ni mensajes internos de PostgreSQL.
  ```json
  {
    "code": "FORBIDDEN_ROLE",
    "message": "No tienes permisos para acceder a las cuentas de esta comunidad.",
    "details": null,
    "requestId": "req_01J..."
  }
  ```
  Códigos HTTP estándar: `400` (payload inválido), `401` (sesión inválida/expirada), `402` (suscripción suspendida en solo lectura), `403` (rol/tenant no autorizado), `404` (o `403` en recursos aislados para no filtrar existencia entre comunidades), `409` (conflicto: voto duplicado, traspaso activo o cupo de referidos agotado), `422` (regla de negocio o CIF inválido), `429` (rate limit).

---

## 2. Autenticación, Revocación Inmediata y Antifraude CIF/NIF

### 2.1. Sesiones y Revocación (`token_version`)
- **Access Token (JWT):** corta duración (`15 min`), enviado en cabecera `Authorization: Bearer <token>` (o cookie `HttpOnly` si se unifica dominio). Incluye `sub` (`usuario_id`) y `tv` (`token_version`).
- **Refresh Token:** `30 días`, almacenado **únicamente** en cookie `HttpOnly; Secure; SameSite=Lax; Path=/api/v1/auth` con rotación en cada `/auth/refresh`.
- **Revocación instantánea:** cualquier endpoint sensible o cambio de sesión valida `token_version` contra `usuarios.token_version` (cacheado brevemente y purgado al incrementar `token_version` cuando se revoca un inquilino o se completa una compraventa).
- **Consentimiento RGPD (Art. 7):** el registro exige `aceptoPrivacidad: true` + `versionPrivacidad` y escribe fila en `consentimientos_usuario`.

### 2.2. Antifraude CIF/NIF y Referidos (4 capas)
Para proteger el **mes de prueba gratis por referidos (`30 días`)** y el **KYBC del Marketplace (DSA art. 30)**:
1. **Dígito de control matemático (`backend/src/domain/fiscal.rs`, `0 €`):** normaliza CIF/NIF/NIE (mayúsculas, sin espacios/guiones) y valida algoritmo oficial español antes de tocar PostgreSQL (`422 INVALID_TAX_ID`).
2. **Bloqueo de emails desechables (`0 €`) + VIES opcional:** rechaza dominios temporales en registro; consulta opcional asíncrona al censo VIES UE si aplica (`cif_estado_verificacion`: `FORMATO_OK` → `VERIFICADO_VIES` o `VERIFICADO_MANUAL`).
3. **Unicidad de `CIF` + huella de método de pago (`Fase 2`):** el `TRIAL` de 30 días por referido solo se concede **1 vez por `cif`** y, al activar Stripe, se valida con `SetupIntent` a `0 €` registrando `suscripciones.payment_fingerprint` para impedir cuentas repetidas.
4. **KYBC documental para anunciantes (DSA art. 30):** un proveedor no puede activar anuncios hasta que `kybc_verificado_en IS NOT NULL` tras verificar su Modelo 036/037 o acreditación equivalente en R2.

---

## 3. Middleware RBAC Multi-Tenant y Regla de Impagos

### 3.1. Resolución de rol en servidor
Cada ruta bajo `/comunidades/:cid/...` ejecuta el extractor RBAC en Rust:
1. Verifica si el usuario es miembro activo en `gestoria_miembros` (`GESTORIA_ADMIN` | `GESTORIA_STAFF`) de la `gestoria_id` asignada a `:cid`.
2. Si no, busca membresía activa en `membresias_comunidad` para `(usuario_id, :cid)` → `PRESIDENTE`, `CONSERJE`, `PROPIETARIO` o `INQUILINO` (con su `vivienda_id`).
3. Si no pertenece a `:cid`, devuelve `403` (cero fugas entre comunidades).

### 3.2. Política de impagos (sin secuestrar datos RGPD)
| Estado en `suscripciones` | `GET` (lectura y descargas legales) | `POST` / `PATCH` / `DELETE` (escritura operativa) | Cabecera HTTP |
|---|---|---|---|
| `TRIAL` / `ACTIVA` / `CANCELADA_AL_FINAL` | Permitido según rol | Permitido según rol | — |
| `IMPAGO_GRACIA` | Permitido según rol | Permitido según rol | `X-Subscription-Status: grace_period` |
| `IMPAGO_SUSPENDIDA` / `CANCELADA` | **Permitido** *(el vecino/gestor no pierde acceso a sus actas ni cuentas históricas)* | **Bloqueado (`402 SUBSCRIPTION_READ_ONLY`)** *(salvo `/billing/*` y `/auth/*`)* | `X-Subscription-Status: suspended_read_only` |

---

## 4. Catálogo de Endpoints por Módulo y Permisos

Leyenda de roles: **GA/GS** = Gestoría Admin/Staff · **PR** = Presidente · **CO** = Conserje · **PP** = Propietario · **IN** = Inquilino · **AN** = Anunciante.

### 4.1. Sistema, Auth y Referidos (máx. 3 invitaciones / 30 días trial)
| Método y Ruta | Acceso | Descripción / Reglas clave |
|---|---|---|
| `GET /health` | Público | Verifica conexión `SQLx` a PostgreSQL (`200 OK` / `503`). |
| `POST /api/v1/auth/register` | Público | Alta de usuario con validación RGPD (`consentimientos_usuario`). |
| `POST /api/v1/auth/register-gestoria` | Público | Crea gestoría + primer `GESTORIA_ADMIN`. Valida CIF matemático, email no desechable y `codigoReferido` opcional (si es válido, activa `TRIAL` de 30 días en `suscripciones` y marca `invitaciones_referido` como `CANJEADA`). |
| `POST /api/v1/auth/login` | Público | Verifica Argon2; emite Access JWT + cookie Refresh `HttpOnly`. |
| `POST /api/v1/auth/refresh` | Cookie | Rota Refresh Token; rechaza si `token_version` cambió. |
| `POST /api/v1/auth/logout` | Autenticado | Limpia cookie Refresh. |
| `GET /api/v1/auth/me` | Autenticado | Perfil, `gestorias` y `comunidades` con rol efectivo en cada una. |
| `POST /api/v1/auth/invitaciones/canjear` | Autenticado | Canjea código `INQ-XXXX` no caducado/revocado → crea membresía `INQUILINO`. |
| `GET /api/v1/referidos/mis-invitaciones` | Autenticado | Devuelve cupos usados (`0..3`), códigos generados y estado. |
| `POST /api/v1/referidos/invitaciones` | Autenticado | Genera código `REF-XXXX-YYYY` (30 días trial). Devuelve `409 REFERRAL_LIMIT_REACHED` si ya tiene 3 invitaciones activas o canjeadas. |

### 4.2. Hub de Gestoría (`desktop`) y Comunidad / Censo
| Método y Ruta | Roles permitidos | Caché / Notas |
|---|---|---|
| `GET /api/v1/gestorias/me` | GA, GS | Cartera de comunidades, asientos activos vs. `max_asientos` y resumen de estado de suscripción. |
| `POST /api/v1/gestorias/:gid/comunidades` | GA, GS | Crea comunidad (`codigo_acceso` único, `dpa_aceptado_en`). |
| `GET /api/v1/gestorias/:gid/equipo` | GA, GS | Lista miembros activos (*per-seat*). |
| `POST /api/v1/gestorias/:gid/equipo` | GA | Añade gestor si `activos < max_asientos` (`422 SEAT_LIMIT_REACHED`). |
| `GET /api/v1/comunidades/:cid/resumen` | GA, GS, PR, CO, PP, IN | **Cacheado `moka` + `ETag`**. Si rol = `CO`, **omite saldo y votaciones** (`saldoCentimos: null`). |
| `GET /api/v1/comunidades/:cid/viviendas` | GA, GS, PR | Censo de viviendas y coeficientes (`moka`). |
| `POST /api/v1/comunidades/:cid/viviendas` | GA, GS, PR | Alta/edición de vivienda y coeficiente. |
| `GET /api/v1/comunidades/:cid/invitaciones-inquilino` | PP (solo su vivienda), GA, GS, PR | Lista códigos `INQ-XXXX` propios. |
| `POST /api/v1/comunidades/:cid/invitaciones-inquilino` | PP (su vivienda) | Genera código `INQ-XXXX` de un solo uso con caducidad. |
| `DELETE /api/v1/comunidades/:cid/invitaciones-inquilino/:invId` | PP (su vivienda), GA, GS, PR | Revoca invitación, desactiva membresía del inquilino e incrementa `usuarios.token_version`. |

### 4.3. Cuentas (públicas) y Deudas / Morosidad (aisladas AEPD)
| Método y Ruta | Roles permitidos | Prohibido a (`403`) | Caché / Seguridad |
|---|---|---|---|
| `GET /api/v1/comunidades/:cid/cuentas/movimientos` | GA, GS, PR, PP, IN | **CO, AN** | `moka` + `ETag` (`304`), paginado (`limit <= 50`). |
| `POST /api/v1/comunidades/:cid/cuentas/movimientos` | GA, GS, PR | CO, PP, IN, AN | Invalida `cuentas_*:{cid}` + registra `auditoria_eventos`. |
| `GET /api/v1/comunidades/:cid/deudas` | GA, GS, PR | **CO, PP, IN, AN** | **`Cache-Control: no-store`**. Nunca se mezcla en caché pública. |
| `PUT /api/v1/comunidades/:cid/deudas/:vid` | GA, GS, PR | CO, PP, IN, AN | Actualiza deuda + `desglose_anual_json` (año + 3 anteriores) + auditoría. |
| `GET /api/v1/comunidades/:cid/deudas/mia` | PP, PR (solo su `vivienda_id`) | CO, IN, AN | **`Cache-Control: no-store`**. |

### 4.4. Avisos, Incidencias y Sondeos (Consultivos LPH)
| Método y Ruta | Lectura | Escritura | Notas |
|---|---|---|---|
| `GET/POST /api/v1/comunidades/:cid/avisos` | GA, GS, PR, CO, PP, IN | GA, GS, PR, CO | `moka` + `ETag` en `GET`. |
| `GET/POST /api/v1/comunidades/:cid/incidencias` | GA, GS, PR, CO, PP, IN | GA, GS, PR, CO, PP, IN | `moka` + `ETag`. Permite adjuntar hasta 3 `documentoId` de `FOTO_INCIDENCIA`. |
| `PATCH /api/v1/comunidades/:cid/incidencias/:iid` | — | GA, GS, PR, CO | Cambia estado (`ABIERTA -> EN_CURSO -> RESUELTA`) y asigna `gremioId`. |
| `POST /api/v1/comunidades/:cid/incidencias/:iid/comentarios` | *(en detalle)* | GA, GS, PR, CO, PP (autor), IN (autor) | Hilo operativo de la avería. |
| `GET/POST /api/v1/comunidades/:cid/sondeos` | GA, GS, PR, PP, IN | GA, GS, PR | **Bloqueado a `CO` (`403`)**. Incluye aviso legal consultivo LPH. |
| `POST /api/v1/comunidades/:cid/sondeos/:sid/votar` | — | PR, PP, IN *(solo si `abiertaInquilinos = true`)* | `409 ALREADY_VOTED` por `(sondeo_id, vivienda_id, es_inquilino)`. Congela `coeficiente_snapshot`. |

### 4.5. Traspasos y Documentos en Cloudflare R2
| Método y Ruta | Roles permitidos | Reglas de seguridad y LPH |
|---|---|---|
| `GET /api/v1/comunidades/:cid/traspasos` | GA, GS, PR, PP (solo los suyos) | **`Cache-Control: no-store`**. Bloqueado a `CO` e `IN`. |
| `POST /api/v1/comunidades/:cid/traspasos` | PP, PR (su vivienda) | Crea solicitud (`uq_traspaso_activo_por_vivienda` impide duplicados). |
| `POST /api/v1/comunidades/:cid/traspasos/:tid/certificar` | GA, GS, PR | Fija `deudaCentimos` (regla 3 años LPH), genera PDF certificado en R2 y pasa a `CERTIFICADO`. |
| `POST /api/v1/comunidades/:cid/traspasos/:tid/completar` | GA, GS, PR | Transacción SQL: cierra membresía vendedor, vincula nuevo titular (si ya existe) o emite alta, revoca inquilino si `accionInquilino = 'BAJA'`, incrementa `token_version` y audita. |
| `POST /api/v1/comunidades/:cid/documentos/presign-upload` | GA, GS, PR, CO/PP/IN *(solo `FOTO_INCIDENCIA`)* | Verifica cuota `limite_storage_bytes`, tamaño máx. (`5 MiB`) y devuelve URL firmada R2 (`comunidades/{cid}/{uuid}`). |
| `POST /api/v1/comunidades/:cid/documentos/confirmar` | Igual que upload | Descarga cabecera R2 para validar **magic bytes** reales (PDF/JPEG/PNG/WEBP) y guarda `sha256_hex`. |
| `GET /api/v1/comunidades/:cid/documentos/:did/download-url` | Según `visibilidad` y rol | Genera URL firmada R2 de 60 s con `ResponseContentDisposition: attachment`. |

### 4.6. Marketplace por Gremios Vacantes (DSA) y Billing
| Método y Ruta | Roles permitidos | Notas |
|---|---|---|
| `GET /api/v1/comunidades/:cid/gremios` | GA, GS, PR, PP, IN | Devuelve gremios con contrato (`0 €`, `esAnuncio: false`) y anuncios visibles solo en gremios vacantes (`esAnuncio: true`, `anuncianteRazonSocial` según Art. 26 DSA). |
| `PUT /api/v1/comunidades/:cid/gremios/:gremioId` | GA, GS, PR | Marca gremio como contratado (`tieneContratoVigente: true`) bloqueando competidores al instante. |
| `GET/POST /api/v1/marketplace/anunciante/anuncios` | AN (con `kybc_verificado_en IS NOT NULL`) | Solo puede seleccionar comunidades de su zona donde ese gremio esté libre. |
| `POST /api/v1/marketplace/anuncios/:aid/reportar` | Autenticado | Canal obligatorio de denuncia DSA (`anuncio_reportes`). |
| `GET/POST /api/v1/billing/suscripcion` | GA, PR (autogestionada), AN | Consulta estado/antigüedad/facturas o inicia Checkout/Portal de Stripe. |
| `POST /api/v1/webhooks/stripe` | Firma Stripe-Signature | Verifica HMAC e idempotencia en `webhook_eventos_procesados`; actualiza `suscripciones` y `pagos_transacciones`. |

---

## 5. Estrategia de Caché (`moka` + `ETag`) y *Rate Limiting*

### 5.1. Caché en 2 niveles en servidor
- **Rutas con `moka` + `ETag` (`304 Not Modified`):** `resumen`, `viviendas`, `cuentas/movimientos`, `avisos`, `incidencias`, `sondeos`, `gremios`. TTL corto de respaldo (`10 min`) + **invalidación inmediata** por `comunidad_id` tras cualquier escritura.
- **Rutas con `Cache-Control: no-store` (sin caché pública):** `/auth/*`, `/deudas*`, `/traspasos*`, `/documentos/*/download-url`, `/billing/*`.

### 5.2. Límites `tower-governor` (por IP / usuario)
| Grupo de rutas | Límite | Objetivo |
|---|---|---|
| `/auth/login`, `/auth/register*`, `/auth/invitaciones/canjear` | `5 req / min` por IP | Frenar fuerza bruta sobre contraseñas y códigos `INQ-XXXX` / `REF-*`. |
| Escrituras (`POST`, `PUT`, `PATCH`, `DELETE`) | `30 req / min` por usuario | Evitar spam de incidencias, comentarios o reportes. |
| Subidas R2 (`presign-upload`) | `10 req / min` por usuario | Proteger cuota de escritura en Cloudflare R2. |
| Lecturas (`GET`) | `120 req / min` por IP | Mitigar scraping respetando navegación rápida (`304` apenas consume CPU). |

---

## 6. Checklist obligatorio de tests negativos (`backend/tests/`)

Ninguna fase se dará por cerrada sin tests automatizados en Rust verificando que la API devuelve `403`, `402`, `409` o `422` en todos estos casos:
1. **Aislamiento multi-tenant (IDOR):** usuario de Comunidad A intentando leer o modificar rutas de Comunidad B → `403`.
2. **Aislamiento de Conserje:** `CONSERJE` llamando a `/cuentas/movimientos`, `/deudas`, `/sondeos` o `/traspasos` → `403`.
3. **Aislamiento de morosidad (AEPD):** `PROPIETARIO` llamando a `/deudas` (lista global) o `/deudas/mia` con otra vivienda → `403`.
4. **Copropietarios y voto único:** dos copropietarios del `2ºC` intentando votar el mismo sondeo → el segundo recibe `409 ALREADY_VOTED`.
5. **Revocación inmediata (`token_version`):** inquilino revocado o vendedor tras traspaso intentando reutilizar su JWT activo → `401`.
6. **Impago en solo lectura:** comunidad en `IMPAGO_SUSPENDIDA` puede hacer `GET /cuentas/movimientos` y descargar actas (`200`), pero `POST /avisos` devuelve `402`.
7. **Exclusividad Marketplace:** anunciante intentando vincular anuncio a comunidad con `tiene_contrato_vigente = true` en ese gremio → `422`.
8. **Antifraude referidos y CIF:** intentar generar un 4.º código en `/referidos/invitaciones` → `409`; registrar gestoría con CIF de dígito inválido → `422`.
