# To-Do · Evolución del proyecto Vecinda

> **Contexto:** Los archivos actuales (`vecinda.html`, `canvas.html`, `pricing.js`, `MODELO_DE_NEGOCIO.md`) son **material meramente orientativo** para visualizar la propuesta de valor y validar el modelo de negocio. La aplicación real **no** se construirá en HTML/CSS/JS plano, sino con **Vite + React (TypeScript)** en Frontend y **Rust (`Axum` + `SQLx`)** en Backend (ver [ARQUITECTURA.md](ARQUITECTURA.md)).

---

## 1. Modelo de negocio y validación con el mercado
- [ ] **Definir el tarifario B2B para Gestorías:** fijar importes de **licencia base**, precio por **usuario gestor (*per-seat*)** y tramos de **descuento al por mayor** por número de comunidades administradas.
- [ ] **Validar con gestorías / administradores de fincas reales:** contrastar el ahorro de horas, la estructura de ~3 usuarios gestores por finca y la aceptación del cobro por asiento + cartera.
- [ ] **Cerrar el pricing especial de comunidades autogestionadas:** ajustar la tarifa diferenciada para fincas sin gestoría y validar que el soporte al presidente no erosione el margen.
- [ ] **Definir el catálogo de ingreso colateral (usuarios planos):** concretar qué servicios se ofrecen en modalidad **Pay-as-you-go** y qué incluiría un **plan de suscripción** opcional para propietarios/inquilinos.
- [ ] **Diseñar los planes del Marketplace por gremios vacantes:** definir la suscripción para negocios anunciantes según **cantidad de anuncios** y **número de comunidades**, junto con la regla de exclusividad (0 € y bloqueo de competidores en gremios ya contratados por la finca).
- [ ] **Validar el rol de Conserje:** entrevistar a conserjes/porteros reales para confirmar permisos operativos de avisos e incidencias sin acceso económico ni voto.

## 2. Marco del Hub, privacidad y cobros
- [ ] **Definir marco del Hub (contratos de la gestora):** dejar claro en términos de uso que los contratos con las comunidades son de la gestoría y Vecinda provee el hub operativo.
- [ ] **Protección de datos básica del Hub (RGPD):** términos de privacidad y uso de la plataforma como herramienta.
- [ ] **Estudiar pasarela de cobro para usuarios independientes:** evaluar Stripe, PayPal u otra alternativa que permita cobrar sin requerir constituir empresa desde el primer día.
- [ ] **Ajustar números del pricing en fase de validación:** las cifras exactas se cerrarán tras validar el modelo, manteniendo la estructura de 4 vías.

## 3. Operación, despliegue y costes ligeros
- [ ] **Entorno de Pruebas (0 €/mes):** desplegar Frontend (**Vite + React**) en **Netlify** (*Deploy Previews*), Backend (**Rust Axum**) en **Render Free** y PostgreSQL de pruebas separado.
- [ ] **Entorno de Producción (OVH):** desplegar Backend Rust + PostgreSQL en **VPS OVH** con **Cloudflare R2** para documentos/backups y escalado retroalimentativo ligado a suscripciones y *Pay-as-you-go*.
- [ ] **Captación orgánica inicial:** presentar la app a primeras gestorías y comunidades cercanas apoyándose en su sencillez, sin gasto publicitario inicial.
- [ ] **Control de contratos vigentes en el Marketplace:** flujo para que gestoría o presidencia marquen qué gremios tiene ya cubiertos la finca (ej. fontanería) y cuáles quedan abiertos a anuncios (ej. carpintería).

## 4. Migración a Web App real (Arquitectura definitiva)
- [ ] **Montar arquitectura separada:** Frontend en **Vite + React + TypeScript + Tailwind + TanStack Query** y Backend en **Rust (`Axum` + `SQLx` + `Tokio`)**.
- [ ] **Jerarquía estricta de permisos en Rust (RBAC):** implementar en servidor los 3 niveles (Gestoría con escritura multi-finca, Presidente/Conserje con operativa local acotada, y Usuarios planos en solo lectura/navegación + acciones puntuales).
- [ ] **Caché en 3 capas:** configurar TanStack Query en cliente, caché en memoria `moka` + `ETag` (`304`) en Rust con invalidación por `comunidad_id`, y CDN en Netlify/R2.
- [ ] **Seguridad y anti-ransomware:** consultas parametrizadas `SQLx`, validación Zod/Serde, *rate limiting* (`tower-governor`), contenedor Rust *non-root*, SSH por clave pública y backups cifrados inmutables fuera de OVH (R2 *Object Lock*).
- [ ] **Motor de tarifas y facturación centralizado:** unificar en el dominio Rust los cálculos de gestorías, autogestionadas, usuarios colaterales y anunciantes con tests automatizados (`cargo test` + `cargo audit`).
- [ ] **Notificaciones y custodia documental:** envío real de avisos y generación de actas/certificados en PDF almacenados en Cloudflare R2 con URLs firmadas.
