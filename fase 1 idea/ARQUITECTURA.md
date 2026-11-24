# Vecinda · Arquitectura de Software y Estrategia de Despliegue

> **Objetivo:** Definir una arquitectura profesional, segura y escalable para llevar Vecinda a producción sobre un stack moderno, optimizando al máximo el consumo de recursos para **mantenerse en planes gratuitos (0 €/mes) durante la fase inicial** y activar costes únicamente cuando existan ingresos (*costes retroalimentativos*).

---

## 1. Principios arquitectónicos (alineados al modelo de negocio)

1. **Asimetría lectura / escritura como motor de ahorro:**
   - Solo **~5 usuarios activos por comunidad** (~3 de la gestoría + 1 presidente + 1 conserje) tienen permisos de modificación en el sistema.
   - Los **usuarios planos** (propietarios e inquilinos) operan en modo **solo lectura/consulta** y acciones puntuales acotadas (reportar incidencia, votar).
   - **Implicación técnica:** las escrituras en base de datos son muy bajas y las lecturas de los vecinos pueden servirse cacheadas desde CDN/Edge sin golpear la base de datos.
2. **Costes retroalimentativos por diseño (*Pay-for-Growth*):**
   - Toda operación que consume cómputo, almacenamiento documental o escrituras intensivas está vinculada a perfiles con **suscripción** o acciones **Pay-as-you-go**.
   - El sistema evita procesos en segundo plano constantes, WebSockets abiertos 24/7 o *polling* automático.
3. **Aislamiento estricto Multi-Tenant (Hub para gestorías):**
   - Los contratos y documentos pertenecen a cada gestoría/comunidad.
   - Ningún usuario puede ver ni modificar datos fuera de las comunidades asignadas a su membresía, validado tanto en la capa de aplicación como en base de datos.

---

## 2. Arquitectura: Monolito Modular vs. Frontend + Backend separado (Rust)

Antes de elegir herramientas concretas, conviene decidir si el backend vive junto al frontend o como servicio independiente:

### Opción A · Full-Stack unificado (Next.js + TypeScript)
- **Cómo funciona:** un único repositorio con interfaz React, Server Actions/API Routes y acceso a PostgreSQL.
- **Ventaja principal:** **velocidad máxima de desarrollo** y despliegue **0 €/mes** inmediato en Vercel/Netlify sin mantener ningún servidor Rust/Node encendido 24/7.
- **Cuándo elegirla:** si la prioridad absoluta es sacar el MVP funcionando lo más rápido posible con un solo lenguaje (TypeScript) y sin administrar contenedores al principio.

### Opción B · Frontend separado (Vite + React) + Backend en Rust (`Axum` + `SQLx`)
- **Cómo funciona:**
  - **Frontend SPA (Vite + React + TypeScript):** compilado a archivos estáticos y alojado **100 % gratis** en Vercel, Netlify o Cloudflare Pages (CDN global con ancho de banda muy generoso).
  - **Backend API en Rust (`Axum` + `Tokio` + `SQLx` + `Serde`):** servicio independiente conectado a PostgreSQL y Cloudflare R2.
- **Por qué Rust encaja especialmente bien con el objetivo de coste mínimo:**
  - **Consumo mínimo de RAM y CPU:** un binario Rust compilado consume ~15–30 MB de RAM en reposo y atiende miles de peticiones por segundo. Donde un backend pesado requeriría ampliar servidor, **Rust permite operar decenas o cientos de comunidades en un contenedor mínimo o un VPS básico de OVH (~4–6 €/mes)** sin despeinarse.
  - **Robustez en reglas críticas:** `SQLx` valida las consultas SQL contra PostgreSQL en tiempo de compilación, y el sistema de tipos de Rust aporta gran seguridad en permisos RBAC, contabilidad comunitaria y cálculos de tarifas.
  - **Arranque casi instantáneo:** si en fase gratuita se despliega en plataformas que duermen el contenedor por inactividad (como Render Free o Koyeb), un binario Rust despierta mucho más rápido que runtimes pesados.
- **Peaje a tener en cuenta:**
  - **Iteración inicial más lenta** que en TypeScript (auth, webhooks de pago y CRUDs requieren más código y no se comparten tipos automáticamente con React salvo generando contrato OpenAPI / `ts-rs`).
  - **Despliegue del backend:** Vercel/Netlify alojan el frontend gratis, pero el binario Rust necesita un alojamiento de contenedores (capas gratuitas de **Koyeb / Render / Fly.io** para pruebas, o un **VPS económico en OVH / Railway** en producción).

---

## 3. Stack Tecnológico Recomendado (según opción elegida)

| Capa | Opción A (Unificado rápido) | Opción B (Separado con Rust) | Justificación de coste y calidad |
|---|---|---|---|
| **Frontend** | Next.js (App Router) + TS | **Vite + React + TypeScript** | En Opción B el frontend es estático: **0 €/mes** en Vercel, Netlify o Cloudflare Pages sin límites de funciones *serverless*. |
| **Backend / API** | Next.js Server Actions / Routes | **Rust (`Axum` + `Tokio` + `Serde`)** | En Opción B, binario único ultrarrápido, consumo mínimo de memoria y separación limpia de dominio. |
| **Estilos y UI** | Tailwind CSS + shadcn/ui | Tailwind CSS + shadcn/ui | Misma experiencia de interfaz en ambas opciones. |
| **Validación / Contrato** | Zod (compartido) | Zod (front) + `validator`/tipos Rust + OpenAPI | Contrato tipado entre API y cliente. |
| **Base de Datos** | PostgreSQL (Neon o Supabase) | PostgreSQL (Neon, Supabase o local en VPS) | Estándar relacional ACID para cuentas, censos, permisos y traspasos. |
| **Acceso a datos** | Drizzle ORM | **`SQLx`** (queries verificadas al compilar) | Cero sobrecarga de ORM pesado en Rust; migraciones SQL puras y portables. |
| **Autenticación y RBAC** | Better Auth / Supabase Auth | JWT (`jsonwebtoken`) + Argon2 o Supabase Auth | Evitar proveedores con cobro alto por MAU debido al volumen de vecinos gratuitos. |
| **Almacenamiento (PDFs)** | Cloudflare R2 | Cloudflare R2 (`aws-sdk-s3` / URLs firmadas) | **10 GB gratis y 0 € por transferencia de salida (egress)** para actas y contratos. |
| **Pagos (cuando se active)** | Stripe o PayPal | Stripe o PayPal (webhooks verificados en Rust) | Integración por *Checkout* alojado; adaptable a usuario independiente al inicio. |

---

## 4. Análisis de Plataformas de Despliegue (0 € inicial → Escalado)

| Plataforma | Rol ideal en Vecinda | Ventajas en Free Tier | Límites / Riesgos a vigilar | Veredicto |
|---|---|---|---|---|
| **Vercel / Netlify** | Frontend + API (Opción A) o **Frontend estático Vite+React** (Opción B) | Despliegue automático por Git, CDN global, HTTPS y caché nativa. | En Opción A el plan *Hobby* limita uso comercial y ejecución *serverless*. En Opción B (solo estático), casi no tiene fricción de límites. | **Ideal para el frontend** (y para todo si vas con Next.js). |
| **Koyeb / Render (Free)** | Backend Rust en fase hobby/pruebas | Despliegan contenedores Docker de Rust gratis para validar sin pagar servidor. | Se duermen tras inactividad (pequeño retardo en la primera petición). | **Útil en fase 0** para probar el backend Rust a 0 €. |
| **Railway** | Backend Rust + PostgreSQL | Despliegue Docker en minutos, BD integrada, sin *sleep* en plan pago. | Sin capa gratuita permanente; cobro por uso desde ~5 $/mes. | **Cómodo en fase 2** si no quieres administrar un VPS. |
| **OVH (VPS básico)** | Backend Rust + PostgreSQL (con Coolify/Docker) | Precio fijo muy bajo (~4–6 €/mes), **sin límites por usuario ni de tráfico**, datos en Europa (RGPD) y **Rust exprime al máximo un VPS mínimo**. | Requiere configurar el VPS una vez (muy simplificado con **Coolify**). | **La mejor opción calidad/precio** en cuanto haya ingresos o para producción real sin sorpresas. |

### Estrategia de entornos: Pruebas (0 €) + Producción (OVH)
- **Entorno de Pruebas / Staging (0 €/mes):**
  - **Frontend:** **Netlify** (*Deploy Previews* por rama/PR o rama `dev`) alojando Vite + React.
  - **Backend Rust:** **Render Free** (contenedor Docker de pruebas; aunque se duerma por inactividad, sirve perfectamente para validar cambios sin coste).
  - **Base de datos de pruebas:** PostgreSQL gratuita separada (Neon o Supabase Free) con datos ficticios/seed.
- **Entorno de Producción:**
  - **Frontend:** **Netlify** (rama `main`, CDN global gratuita).
  - **Backend Rust + PostgreSQL:** **VPS básico de OVH** (~4–6 €/mes, gestionado con Docker / Coolify), sin *cold starts* y con datos en Europa.
  - **Documentos:** **Cloudflare R2** (10 GB gratis y 0 € de transferencia).

#### Por qué es clave mantener un despliegue de pruebas separado
1. **Proteger cuentas y permisos reales:** probar cambios de RBAC, cálculos de deudas o reglas del marketplace sin riesgo de romper o exponer datos de gestorías y comunidades reales.
2. **Validar migraciones de base de datos:** comprobar que los cambios de esquema en PostgreSQL (`SQLx` migrations) funcionan antes de tocar producción.
3. **Detectar fallos que no aparecen en `localhost`:** probar HTTPS real, CORS entre Netlify y el backend Rust, cookies/JWT, webhooks de pago en modo *sandbox* y uso desde móviles reales.
4. **Demos seguras:** enseñar avances a una gestoría usando el entorno de pruebas sin ensuciar la base de datos de producción.

---

## 5. Arquitectura Lógica y Modelo de Datos

### 5.1. Jerarquía de Permisos (RBAC + Aislamiento Multi-Tenant)
Todas las peticiones pasan por un middleware de autorización que resuelve `(usuario_id, comunidad_id) -> rol` y verifica permisos explícitos:

1. **`GESTORIA_ADMIN / GESTORIA_STAFF`** *(asientos de pago de la gestoría)*:
   - Acceso multi-comunidad dentro de su `gestoria_id`.
   - Lectura y **escritura** en cuentas, traspasos, certificados, juntas, morosos (privado) y configuración de gremios contratados.
2. **`PRESIDENTE`** *(1 por comunidad)*:
   - Lectura y **escritura acotada** en su comunidad: aprobar hitos, publicar avisos, cambiar estado de incidencias, abrir votaciones y gestionar contratos de gremios.
3. **`CONSERJE`** *(0–1 por comunidad)*:
   - Lectura de avisos e incidencias + **escritura solo operativa** (publicar avisos generales y actualizar estado de incidencias). Sin acceso a cuentas, morosidad ni votaciones.
4. **`PROPIETARIO`** *(usuario plano gratuito)*:
   - **Solo lectura** en cuentas, avisos, incidencias y documentos de su comunidad; puede reportar incidencias, emitir voto y gestionar código de su inquilino.
5. **`INQUILINO`** *(usuario plano gratuito invitado)*:
   - **Solo lectura** de avisos/cuentas públicas y reporte de incidencias; vota únicamente si la votación se abre de forma consultiva a inquilinos.
6. **`ANUNCIANTE_MARKETPLACE`** *(negocios locales)*:
   - Acceso aislado exclusivamente a su panel de campañas/anuncios y a las categorías vacantes donde paga por visibilidad; **cero acceso** a datos personales de vecinos o cuentas.

### 5.2. Modelo de Datos Principal (PostgreSQL)
- **Organización:** `gestorias` → `gestoria_miembros` (controla *per-seat* de pago) → `comunidades` (`gestoria_id` nullable para autogestionadas, `plan_estado`).
- **Censo y Roles:** `viviendas` (`comunidad_id`, `cuota`, `deuda`, `coeficiente`) → `membresias` (`usuario_id`, `comunidad_id`, `vivienda_id`, `rol`, `activo`).
- **Operativa diaria:** `movimientos_cuentas`, `avisos`, `incidencias`, `votaciones` + `votos` (unicidad por `votacion_id + vivienda_id`), `traspasos`.
- **Marketplace por huecos:**
  - `gremios_catalogo` (fontanería, carpintería, electricidad, ascensores...).
  - `gremios_comunidad` (`comunidad_id`, `gremio_id`, `proveedor_id`, `tiene_contrato_vigente`: si es `true`, ese proveedor está gratis en esa finca y **bloquea** anuncios de competidores en ese gremio).
  - `anuncios_marketplace` (`proveedor_id`, `gremio_id`, `plan_anuncios`, `alcance_comunidades`).

---

## 6. Gestión de Recursos y Caché (3 Capas sin Redis externo)

Para que cientos de vecinos consultando la app **no** disparen lecturas de base de datos ni consumo de servidor:

1. **Capa 1 · Caché en Cliente (TanStack Query):**
   - Evita peticiones repetidas al cambiar entre pestañas (*Cuentas*, *Avisos*, *Incidencias*), usando un `staleTime` de varios minutos que solo se invalida localmente cuando el propio usuario realiza una acción.
2. **Capa 2 · Caché en memoria dentro de Rust (`moka` + `ETag` HTTP):**
   - Al ser un servidor Rust continuo, se usa el crate **`moka`** en RAM (pocos MB, sin pagar Redis) con claves aisladas por comunidad (`cuentas_publicas:{id}`, `avisos:{id}`, `incidencias:{id}`).
   - **Invalidación al escribir:** solo cuando escribe alguno de los ~5 usuarios activos con permiso, se invalidan las claves de **esa** comunidad.
   - **Cabecera `ETag` / `304 Not Modified`:** si nada cambió en la finca, Rust responde `304` en microsegundos sin consultar PostgreSQL ni reenviar JSON.
3. **Capa 3 · CDN para estáticos y documentos (Netlify + Cloudflare R2):**
   - Los *assets* con hash de Vite se cachean 1 año (`immutable`) en Netlify.
   - Los PDFs cerrados (actas, certificados) se sirven desde R2 por URL firmada sin pasar por el servidor Rust. *(Regla: nunca cachear datos privados de comunidad en CDN pública).*
4. **Sin tiempo real innecesario y consultas ligeras:**
   - Sin WebSockets 24/7; listados siempre paginados y con columnas explícitas.

---

## 7. Seguridad y Endurecimiento (*Hardening*)

### 7.1. Contra Inyecciones (SQLi, XSS, Entrada maliciosa)
- **SQL Injection:** consultas 100 % parametrizadas con **`SQLx`** (`query!` / `bind`) verificadas en tiempo de compilación; prohibido construir SQL concatenando cadenas.
- **XSS e Inyección en Frontend:** React escapa el DOM por defecto (prohibido `dangerouslySetInnerHTML`); cabecera **CSP (*Content Security Policy*)** estricta, `X-Content-Type-Options: nosniff` y validación de entrada doble (**Zod** en cliente + **`serde` / `validator`** en Rust).

### 7.2. Contra Exploits de Lógica, Auth y RBAC (IDOR / Escalada de Privilegios)
- **Autorización en servidor, nunca en cliente:** cada endpoint en Rust extrae el usuario del token firmado (cookie `HttpOnly`, `Secure`, `SameSite=Lax` o JWT de corta duración + refresh rotation) y valida en BD su rol real para esa `comunidad_id`.
- **Aislamiento de privacidad:** los expedientes de morosos y datos de gestoría tienen endpoints y claves de caché separadas; nunca se filtran en respuestas dirigidas a usuarios planos o anunciantes.
- **Subida segura de archivos:** validación por *magic bytes* (no solo extensión), límite estricto de tamaño (p. ej. 2–5 MB), renombrado a UUID y almacenamiento aislado en **Cloudflare R2** con `Content-Disposition: attachment` (nunca se ejecutan ni renderizan en el dominio de la app).
- **Rate Limiting y protección de red:** `tower-governor` en `Axum` (freno a fuerza bruta en login, códigos `INQ-XXXX` y creación de incidencias) + **Cloudflare** delante de OVH para mitigar tráfico abusivo/DDoS.
- **Auditoría continua:** `cargo audit` (Rust) y `npm audit` (Frontend) en CI para detectar vulnerabilidades (CVEs) en dependencias.

### 7.3. Contra Ransomware (especialmente en VPS OVH)
- **Backups externos e inmutables (Regla 3-2-1):** volcados diarios cifrados de PostgreSQL enviados fuera de OVH hacia un bucket separado en **Cloudflare R2 con bloqueo/retención inmutable (*Object Lock*)** y credenciales con permiso mínimo (sin borrado desde el VPS). Si el VPS se viera comprometido, el atacante **no puede cifrar ni borrar las copias históricas**.
- **Mínimo privilegio en servidor y BD:**
  - Usuario PostgreSQL de la app sin `SUPERUSER` ni permisos de sistema de archivos.
  - Contenedor Rust corriendo como usuario **non-root** con sistema de archivos de solo lectura (`read_only`).
  - Acceso SSH a OVH **exclusivo por clave pública** (contraseñas deshabilitadas), firewall cerrado (solo `80/443` públicos; SSH restringido por IP o VPN tipo WireGuard/Tailscale), `fail2ban` y actualizaciones automáticas de seguridad.

### 7.4. Contra Ingeniería Inversa y Manipulación
- **Lógica sensible 100 % en el backend Rust compilado:** reglas de permisos, cálculos de tarifas, validación de exclusividad por gremios y verificación de pagos residen exclusivamente en el binario Rust del servidor, nunca en el JavaScript descargado al navegador.

---

## 8. Estándares de Ingeniería y Calidad

- **Separación limpia de dominios:**
  - **Backend Rust:** módulos separados para `domain` (reglas puras de tarifas, RBAC y exclusividad de gremios con tests unitarios `cargo test`), `infra` (`SQLx`, R2, pasarela) y `api` (handlers `Axum` + validación).
  - **Frontend Vite + React:** componentes tipados, capa de cliente API y validación de formularios con Zod.
- **CI/CD en GitHub Actions:** en cada *pull request* se ejecutan `cargo test`, `cargo clippy`, `cargo audit`, `tsc --noEmit` y tests de frontend antes de desplegar en **Netlify + Render Free**.
- **Portabilidad total:** PostgreSQL estándar + S3-compatible (R2) + contenedor Docker Rust permiten migrar de proveedor en horas sin *vendor lock-in*.

---

## 9. Hoja de ruta técnica por fases

1. **Fase 0 · Cimientos y Pruebas (Coste 0 €):** repo Frontend (Vite + React + TS) en **Netlify** + repo/módulo Backend (**Rust Axum + SQLx**) en **Render Free** + PostgreSQL de pruebas (Neon/Supabase) + CI/CD con `cargo audit` y tests.
2. **Fase 1 · Core del Hub y Jerarquía de Permisos:** implementar los ~5 usuarios activos vs. usuarios planos, panel multi-comunidad para gestoría, caché `moka` + `ETag` por `comunidad_id` y módulos de Cuentas, Avisos, Incidencias y Traspasos.
3. **Fase 2 · Producción en OVH y Monetización:** desplegar Backend Rust + PostgreSQL en **OVH** con backups inmutables en R2, activar pasarela de cobro (Stripe/PayPal), asientos de gestoría (*per-seat*), autogestionadas y catálogo *Pay-as-you-go*.
4. **Fase 3 · Marketplace por gremios libres:** módulo de gremios contratados por comunidad (exclusividad a 0 €) y portal de anunciantes para categorías vacantes.

