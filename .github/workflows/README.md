# CI/CD (`.github/workflows/`)

Esta carpeta **no** es para planificación ni To-Dos: contiene exclusivamente los **pipelines automáticos** que se ejecutan en GitHub en cada *push* o *Pull Request*.

---

## Pipelines previstos
- **`ci.yml` (en cada PR hacia `dev` o `main`):**
  - **Backend Rust:** `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, `cargo audit`.
  - **Frontend TS:** `tsc --noEmit`, `npm run lint`, `npm test`, `npm audit --audit-level=high`, `npm run build`.
- **`deploy-staging.yml` (rama `dev`):**
  - Dispara despliegue de pruebas en **Netlify** (frontend) y **Render Free** (backend Rust).
- **`deploy-prod.yml` (rama `main`):**
  - Publica frontend en **Netlify** y despliega contenedor Rust verificado en **OVH**.

