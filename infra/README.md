# Vecinda · Infraestructura y Operaciones

Configuración de entornos para mantener **0 €/mes en pruebas** y un coste fijo mínimo/retroalimentativo en producción.

---

## Estructura de carpetas
- [docker/](docker/) — `docker-compose.yml` para PostgreSQL local y `Dockerfile` del backend Rust (*non-root*, `read_only`).
- [ovh/](ovh/) — Configuración del VPS de producción en OVH (reverse proxy HTTPS, firewall `80/443`, SSH solo por clave pública, `fail2ban`).
- [backups/](backups/) — Scripts automáticos de volcado cifrado de PostgreSQL hacia **Cloudflare R2** con retención inmutable (*Object Lock* anti-ransomware).

---

## Plan de implementación por fases
- **Fase 0 · Local y Staging (0 €):**
  - [ ] Crear `docker/docker-compose.yml` con PostgreSQL 16 local (usuario de app sin `SUPERUSER`).
  - [ ] Crear `docker/Dockerfile` multi-stage para el binario Rust (imagen mínima final + usuario `non-root`).
  - [ ] Conectar despliegue de pruebas en **Render Free** + PostgreSQL Free (Neon/Supabase).
- **Fase 1 · Producción y Hardening en OVH:**
  - [ ] Configurar VPS OVH con HTTPS (Caddy/Nginx + Cloudflare delante), firewall cerrado y acceso SSH restringido.
  - [ ] Configurar bucket **Cloudflare R2** para documentos (0 € *egress*) y bucket separado inmutable para backups diarios cifrados.
  - [ ] Probar restauración completa de backup antes de pasar a producción real.

