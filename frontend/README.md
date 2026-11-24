# Vecinda · Frontend (`Vite + React + TypeScript`)

Interfaz web de Vecinda desplegada en **Netlify** (Deploy Previews en PRs/ramas de prueba y `main` en producción).

> Guía visual y wireframes por cajas: ver [DESIGN.md](DESIGN.md).

---

## Estructura de carpetas
- [src/app/](src/app/) — Configuración de rutas, proveedores (`QueryClientProvider`) y layouts por rol.
- [src/components/](src/components/) — Componentes UI base (Tailwind CSS + shadcn/ui).
- [src/features/](src/features/) — Módulos funcionales: `auth`, `gestoria`, `cuentas`, `avisos`, `incidencias`, `votaciones`, `traspasos`, `marketplace`.
- [src/hooks/](src/hooks/) — Hooks de TanStack Query con `staleTime` optimizado para usuarios planos.
- [src/lib/](src/lib/) — Cliente HTTP hacia la API Rust, esquemas **Zod** y formateadores.
- [src/types/](src/types/) — Contratos de tipos TypeScript sincronizados con la API.

---

## Plan de implementación por fases
- **Fase 0 · Base y conexión:**
  - [ ] Inicializar `Vite + React + TypeScript + Tailwind CSS`.
  - [ ] Configurar `TanStack Query` y cliente HTTP (`VITE_API_URL`) contra `GET /health`.
  - [ ] Configurar cabecera **CSP** estricta y despliegue automático en **Netlify**.
- **Fase 1 · Hub y Jerarquía de Permisos:**
  - [ ] Pantallas de login/registro e invitación por código (`INQ-XXXX`).
  - [ ] Vista multi-comunidad para perfiles de **Gestoría** (~3 perfiles/finca).
  - [ ] Vistas operativas para **Presidente** y **Conserje**, y vistas de solo lectura/consulta para **Propietarios** e **Inquilinos**.
- **Fase 2 · Trámites y Monetización:**
  - [ ] Módulo de traspasos y carga de documentos de la gestora hacia **Cloudflare R2** (URLs firmadas).
  - [ ] Flujo de suscripción de gestorías (*per-seat* + cartera), autogestionadas y *Pay-as-you-go* de vecinos.
- **Fase 3 · Marketplace por gremios vacantes:**
  - [ ] Gestión de gremios ya contratados por la finca (ocultando competidores).
  - [ ] Portal de anunciantes para categorías libres.

