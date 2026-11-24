# Vecinda · Modelo de negocio (documentación conceptual)

> Documento orientativo de negocio. Las cifras de `pricing.js` corresponden al escenario orientativo de fincas autogestionadas / add-ons; el tarifario B2B de gestorías y anunciantes está pendiente de definir.

## 1. Arquitectura de jerarquía de permisos (clave de rentabilidad)
En cada comunidad, la capacidad de modificar información y gestionar trámites se concentra en un núcleo muy reducido (**~5 usuarios activos con privilegios**):
- **~3 usuarios de la gestoría:** administradores / contables / tramitadores que operan cuentas, certificados, traspasos, juntas y morosidad.
- **1 presidente:** supervisión, validación de hitos y coordinación.
- **1 conserje:** gestión operativa diaria de avisos e incidencias sin acceso a datos económicos ni votación.
- **Usuarios planos (propietarios e inquilinos):** solo navegación, consulta de información, reporte simple de averías y voto (propietarios). Sin privilegios para modificar datos del sistema, lo que mantiene los **costes de infraestructura y soporte prácticamente en cero**.

---

## 2. Cuatro fuentes de ingreso

### 1. Gestorías y Administradores de Fincas (Cliente B2B principal)
Modelo híbrido por capas (estilo *Enterprise per-seat* + cartera):
- **Licencia base de gestoría:** cuota fija por tener activo el espacio de trabajo del despacho.
- **Pago por usuario gestor (*per-seat*):** se abona por cada perfil profesional de la gestoría que opera la herramienta.
- **Aditivo por comunidad administrada (con descuento al por mayor):** cada finca añadida suma un extra de mantenimiento cuyo precio unitario decrece según el volumen total de comunidades de la gestoría.

### 2. Comunidades autogestionadas (B2B secundario)
- Fincas sin gestoría donde la presidencia asume la gestión operativa.
- Tienen cabida mediante un **pricing especial** adaptado a su tamaño (referencia orientativa en [pricing.js](pricing.js): base por tramos de viviendas + servicios a la carta).

### 3. Ingreso colateral de usuarios planos (Propietarios e Inquilinos)
- Entran gratis por la comunidad que administra su gestoría (coste marginal casi nulo y sin CAC).
- Monetización opcional cuando demanden capacidades o trámites adicionales:
  - **Pay-as-you-go:** pago puntual por uso.
  - **Plan de suscripción:** cuota opcional para el usuario que quiera servicios avanzados.

### 4. Marketplace por gremios vacantes (Negocios locales)
- **Regla de exclusividad y respeto a contratos vigentes:** si una comunidad ya tiene contratado un gremio (ej. fontanería), esa empresa **no paga por estar en la app** en esa comunidad y **no se permite la entrada de competidores** de ese gremio en dicha finca.
- **Anuncios en gremios libres:** en las categorías donde la comunidad **no tiene proveedor contratado** (ej. carpintería), otros negocios sí pueden anunciarse pagando una **suscripción escalada por cantidad de anuncios y número de comunidades alcanzadas**.

---

## 3. Marco operativo, despliegue y estructura de costes
- **Contratos de la gestora:** todos los contratos y la responsabilidad legal con las comunidades pertenecen a la gestoría; Vecinda únicamente ofrece el **hub operativo** y ellos lo usan.
- **Captación orgánica inicial:** crecimiento orgánico sin inversión publicitaria de golpe, apoyado en la sencillez de uso.
- **Despliegue y desarrollo ligero:** proyecto desarrollado como **hobby / equipo propio** (sin coste salarial directo), con frontend en **Netlify**, entorno de pruebas en **Render Free** y producción en **OVH + Cloudflare R2** (ver [ARQUITECTURA.md](ARQUITECTURA.md)).
- **Costes de despliegue retroalimentativos:** la carga real de servidor solo aumenta con operaciones de modificación, las cuales son exclusivas de **suscripciones** o acciones **Pay-as-you-go**. Por tanto, los costes de infraestructura **no pueden subir sin que antes suban los ingresos**.
- **Números de pricing y pasarela:** las cifras exactas quedan abiertas para fase de validación; la pasarela (Stripe, PayPal u otra que permita cobrar como usuario independiente) se elegirá al implementar.

## 4. Pendiente de validar
- Tarifas orientativas finales para licencia base, *per-seat* de gestoría y tramos de descuento por volumen de comunidades.
- Catálogo concreto del ingreso colateral de usuarios planos (*Pay-as-you-go* vs. suscripción).
- Planes de suscripción para anunciantes del marketplace (nº de anuncios × nº de comunidades) y verificación de gremios.
- Privacidad básica de la plataforma (RGPD del hub) y elección de pasarela de pago para usuarios independientes.
