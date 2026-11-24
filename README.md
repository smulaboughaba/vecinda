# Vecinda

Plataforma B2B para gestorías y comunidades de propietarios (hub operativo con jerarquía de permisos, transparencia vecinal y marketplace por gremios vacantes).

---

## Organización del proyecto

```text
Vecinda/
├── .github/
│   └── workflows/          # Pipelines CI/CD (tests, clippy, cargo audit, npm audit)
├── frontend/               # App Web (Vite + React + TypeScript + Tailwind + TanStack Query) -> Netlify
│   └── src/
│       ├── app/            # Rutas, layouts y configuración global
│       ├── components/     # Componentes UI reutilizables
│       ├── features/       # Módulos de negocio (cuentas, avisos, incidencias, traspasos, marketplace)
│       ├── hooks/          # Hooks personalizados y queries cacheadas
│       ├── lib/            # Cliente API, validación Zod y utilidades
│       └── types/          # Tipos e interfaces del contrato API
├── backend/                # API en Rust (Axum + Tokio + SQLx + moka) -> Render Free (staging) / OVH (prod)
│   ├── migrations/         # Migraciones SQL versionadas (PostgreSQL)
│   ├── src/
│   │   ├── api/            # Handlers HTTP, rutas, middlewares (RBAC, rate limit, ETag)
│   │   ├── auth/           # Autenticación, cookies/JWT y verificación de membresías
│   │   ├── cache/          # Caché en memoria (moka) e invalidación por comunidad_id
│   │   ├── domain/         # Reglas puras (tarifas, permisos, exclusividad marketplace) + tests
│   │   └── infra/          # Acceso a PostgreSQL (SQLx), Cloudflare R2 y pasarela de pagos
│   └── tests/              # Tests de integración
├── infra/                  # Despliegue y operaciones
│   ├── docker/             # Dockerfiles (Rust non-root read-only) y docker-compose local
│   ├── ovh/                # Configuración de VPS (firewall, reverse proxy, systemd/Coolify)
│   └── backups/            # Scripts de backup cifrado de PostgreSQL -> Cloudflare R2 (Object Lock)
└── fase 1 idea/            # Documentación inicial, Canvas y prototipo orientativo
    ├── ARQUITECTURA.md     # Diseño técnico, despliegue, caché y hardening de seguridad
    ├── MARCO_NORMATIVO_Y_FUNCIONAL.md # Funcionamiento v1/v2, normativas ES/UE y plugins
    ├── MODELO_DE_NEGOCIO.md# Modelo de ingresos (gestorías, autogestionadas, colateral, marketplace)
    ├── TODO.md             # Hoja de ruta de validación, negocio y desarrollo
    ├── canvas.html         # Business Model Canvas interactivo (entregable)
    ├── vecinda.html        # Prototipo visual orientativo (demo inicial)
    ├── pricing.js          # Lógica orientativa de precios para el prototipo/canvas
    └── pricing.test.js     # Tests unitarios de pricing.js
```

---

## Documentación y planes por módulo
- **Estrategia y arquitectura global (`fase 1 idea/`):**
  - [ARQUITECTURA.md](fase%201%20idea/ARQUITECTURA.md) — Stack (`Vite + React` + `Rust`), entornos (`Netlify`, `Render Free`, `OVH`), caché y seguridad.
  - [MARCO_NORMATIVO_Y_FUNCIONAL.md](fase%201%20idea/MARCO_NORMATIVO_Y_FUNCIONAL.md) — Funcionamiento v1/v2, normativas (RGPD, LPH, AI Act, eIDAS 2.0, DSA, Verifactu) y plugins.
  - [MODELO_DE_NEGOCIO.md](fase%201%20idea/MODELO_DE_NEGOCIO.md) — Las 4 fuentes de ingreso, jerarquía de ~5 usuarios activos y costes retroalimentativos.
  - [TODO.md](fase%201%20idea/TODO.md) — Hoja de ruta general de negocio, marco del Hub y desarrollo.
- **Planes técnicos por carpeta:**
  - [frontend/README.md](frontend/README.md) — Plan por fases del cliente Vite + React + TS.
  - [backend/README.md](backend/README.md) — Plan por fases de la API en Rust (`Axum` + `SQLx` + `moka`).
  - [infra/README.md](infra/README.md) — Plan de Docker local, Render Free, OVH y backups anti-ransomware.
  - [.github/workflows/README.md](.github/workflows/README.md) — Pipelines de CI/CD (tests, auditorías de seguridad y despliegues).
