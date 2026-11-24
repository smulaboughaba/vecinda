# Vecinda · Funcionamiento y Marco Normativo (España y UE)

> Documento de referencia funcional y legal previo al desarrollo de la aplicación definitiva (`Vite + React` + `Rust Axum + SQLx`). Reúne el análisis de funcionamiento (prototipo actual vs. producto v2), las normativas aplicables de España y la Unión Europea, sus requisitos técnicos y el directorio oficial de consulta.

---

## 1. Funcionamiento de la aplicación: Prototipo v1 vs. Producto v2

### 1.1. Qué hace hoy el prototipo (`fase 1 idea/vecinda.html`)
El prototipo actual funciona 100 % en el navegador mediante `localStorage` (sin servidor ni cobros reales) y cubre 6 flujos básicos:
1. **Acceso por rol** (`Propietario`, `Inquilino`, `Presidente`, `Conserje`): validación simulada con código de comunidad (`VEC-4821`) o invitación de inquilino (`INQ-2048`) y casilla RGPD.
2. **Cuentas:** muestra saldo total, ingresos y gastos visibles para la comunidad; el presidente puede añadir movimientos.
3. **Avisos e Incidencias:** cualquier vecino reporta averías; Presidente y Conserje publican avisos y cambian estados (`Abierta → En curso → Resuelta`). Desde una incidencia, el presidente puede simular la petición de *"3 presupuestos homologados"*.
4. **Votaciones:** 1 voto por vivienda; el presidente puede abrir la votación de forma consultiva a inquilinos y, si activa el *Pack Junta* (`45 €`), descargar un acta `.txt` sin validez legal.
5. **Inquilinos y Traspasos:** el propietario genera/anula códigos `INQ-XXXX` (expulsando al inquilino al recargar si se anula) y puede iniciar una compraventa; el presidente fija la deuda, emite un certificado `.txt` y registra al nuevo titular.
6. **Plan y calculadora (`pricing.js`):** calcula cuotas mensuales/anuales y añade add-ons simulados (*Junta 45 €*, *Morosos 25 €*, *Onboarding 60 €*) anotando el cargo en *Cuentas*.

### 1.2. Qué cambia en el producto real v2 (`DESIGN.md` y `ARQUITECTURA.md`)
Para pasar a producción con el modelo B2B consolidado se incorporan tres cambios estructurales:
- **Hub de Escritorio para Gestorías (`>= 1024px`):** gestión multi-comunidad (cartera de 20–80 fincas), control de asientos (*per-seat*, ~3 perfiles gestores por finca), emisión de certificados/actas y expedientes privados de morosos.
- **Exclusividad del Marketplace por gremios vacantes:** si la finca marca un gremio como *Con contrato vigente* (ej. fontanería), ese proveedor figura a `0 €` y bloquea anuncios de competidores; únicamente los *Gremios vacantes* (ej. carpintería) quedan abiertos a anunciantes locales de pago.
- **Aislamiento estricto por RBAC en servidor (`Rust`):**
  - El **Conserje** solo opera avisos e incidencias; **nunca** accede a cuentas, saldo, morosidad ni votaciones.
  - Los **Anunciantes** acceden exclusivamente a su portal de campañas en gremios libres, con cero visibilidad de vecinos o cuentas.

### 1.3. Correcciones detectadas sobre el prototipo actual
Antes de trasladar reglas del prototipo al backend Rust, deben corregirse tres desfases legales y funcionales:
1. **Plazo de afección de deudas en compraventa (LPH art. 9.1.e):** el texto de `vecinda.html` indica erróneamente que el comprador responde *"del año en curso y del anterior"*. La Ley de Propiedad Horizontal vigente establece la responsabilidad por la anualidad corriente y los **tres años naturales anteriores**.
2. **Visibilidad de Cuentas por el Conserje:** en `vecinda.html` el conserje todavía visualiza la tarjeta de saldo y la pestaña *Cuentas*; en v2 debe bloquearse por completo en backend y UI (`DESIGN.md`).
3. **Votaciones simples vs. Junta LPH:** el prototipo aplica `1 vivienda = 1 voto` sin ponderar coeficientes de participación ni privar del voto a propietarios morosos (arts. 15.2 y 17 LPH).

---

## 2. Normativas de España y la Unión Europea aplicables

### 2.1. Protección de Datos (RGPD + LOPDGDD + Criterios AEPD)
- **Normas:** Reglamento (UE) 2016/679 (**RGPD**), Ley Orgánica 3/2018 (**LOPDGDD**) y *Guía de Protección de Datos y Administración de Fincas* de la **AEPD**.
- **Cadena de responsabilidades (Art. 28 RGPD):**
  - **Comunidad de Propietarios:** siempre es la **Responsable del Tratamiento**.
  - **Con Gestoría:** la Gestoría es **Encargada del Tratamiento** y **Vecinda actúa como Subencargada** (requiere contrato DPA entre Gestoría y Vecinda + autorización previa de subcontratación por parte de la comunidad).
  - **Comunidad Autogestionada:** **Vecinda actúa como Encargada del Tratamiento** directa (requiere DPA específico aceptado por la comunidad).
- **Subencargados cloud y transferencias internacionales (Cap. V RGPD):**
  - Toda infraestructura externa (Netlify, Render, Cloudflare R2, pasarela de pago o APIs) debe constar en un listado público de subencargados con su ubicación y garantías (*EU-US Data Privacy Framework* o Cláusulas Contractuales Tipo — SCC).
  - Alojar el backend y PostgreSQL en **OVH Europa** refuerza el cumplimiento de residencia de datos en el EEE.
- **Prohibición de exponer morosos (criterio estricto AEPD):**
  - Está **prohibido** publicar listas abiertas de vecinos morosos en tablones generales, ascensores o chats comunitarios.
  - **Únicas excepciones legales:**
    1. Relación de deudores incluida dentro de la **convocatoria individualizada de Junta** (art. 16.2 LPH, base legal art. 6.1.c RGPD) para advertir de la privación de voto.
    2. **Notificación subsidiaria** en el tablón de anuncios (art. 9.1.h LPH) únicamente cuando conste intento fallido fehaciente en el domicilio designado, acompañada de diligencia firmada con fecha y motivos, y durante el tiempo indispensable.
  - **Requisito técnico:** los expedientes de morosos deben vivir en endpoints y claves de caché aisladas; nunca deben ser visibles para inquilinos, conserjes, anunciantes ni en tablones públicos.
- **Bajas y minimización:** al revocar un código `INQ-XXXX` o completar un traspaso, los tokens/sesiones del usuario saliente deben invalidarse de inmediato en el servidor, conservando solo el histórico mínimo legal.

### 2.2. Propiedad Horizontal, Juntas, Actas y Certificados (LPH)
- **Norma:** **Ley 49/1960, de 21 de julio, sobre Propiedad Horizontal (LPH)** (texto consolidado en BOE).
- **Juntas online y voto telemático (Arts. 15 y 16 LPH):**
  - Las medidas excepcionales del RD-ley 8/2021 caducaron el **31 de diciembre de 2021**.
  - Mientras no se publique en el BOE la reforma parlamentaria para regular juntas telemáticas ordinarias, celebrar una junta 100 % online o por voto electrónico asíncrono sin que esté previsto en los **estatutos** o aprobado por **unanimidad** expone los acuerdos a impugnación judicial.
  - **Cómo enfocarlo en Vecinda:** diferenciar claramente entre **consultas/sondeos vecinales orientativos** (uso diario sin valor de Junta formal) y el soporte documental a Juntas reales (asistencia + **delegación de voto por escrito firmada**, art. 15.1 LPH).
- **Quórum, doble mayoría y morosos (Arts. 15.2 y 17 LPH):**
  - Los acuerdos formales requieren doble mayoría (**propietarios + coeficientes de participación**).
  - Los propietarios con deudas vencidas al inicio de la Junta (no impugnadas ni consignadas judicial/notarialmente) están **privados de derecho a voto**.
- **Libro de Actas (Art. 19 LPH):** el acta generada desde la app es un **borrador / respaldo operativo** para agilizar el trabajo del secretario-administrador; no sustituye al Libro de Actas diligenciado por el Registrador de la Propiedad mientras la LPH no habilite soporte digital oficial.
- **Certificado de deuda en compraventas (Arts. 9.1.e y 21 LPH):** debe emitirse por quien ejerza la secretaría con el visto bueno de la presidencia (o administrador-secretario), reflejando la deuda exacta; el adquirente responde de las cuotas del año en curso y los **tres años naturales anteriores**.

### 2.3. Uso de Inteligencia Artificial (EU AI Act + AESIA + AEPD)
- **Normas:** **Reglamento (UE) 2024/1689 (EU AI Act)** (ajustado por el *Digital Omnibus*, Reglamento UE 2026/1744), supervisión nacional por la **AESIA**, y *Guía de adecuación al RGPD de tratamientos que incorporan IA* de la **AEPD**.
- **Calendario vigente (referencia noviembre 2026):**
  - **2 feb 2025 (en vigor):** prohibición de prácticas de riesgo inaceptable y obligación de **alfabetización en IA (Art. 4)** para el equipo que opere herramientas de IA.
  - **2 ago 2025 (en vigor):** reglas de gobernanza para modelos de uso general (GPAI).
  - **2 ago 2026 (en vigor):** **obligaciones de transparencia (Art. 50)** para sistemas que interactúan con personas o generan contenido sintético.
  - **2 dic 2026:** fin del periodo transitorio de marcado técnico legible por máquina para sistemas generativos previos.
  - **2 dic 2027 / 2 ago 2028:** aplicación de obligaciones estrictas para sistemas de **Alto Riesgo** (Anexo III y Anexo I respectivamente).
- **Reglas de diseño si Vecinda incorpora IA** (p. ej., OCR de facturas/estatutos, clasificación de incidencias, asistente vecinal o redacción de borradores):
  1. **Transparencia obligatoria (Art. 50):** avisar de forma clara cuando el usuario interactúe con un asistente IA y marcar los borradores/textos generados automáticamente, exigiendo **revisión y validación humana** antes de emitir avisos oficiales, actas o certificados.
  2. **Prohibido el *scoring* o decisiones automatizadas (Anexo III AI Act + Art. 22 RGPD):** **no** emplear IA para puntuar solvencia financiera de vecinos/inquilinos ni para tomar decisiones automatizadas con efectos jurídicos sin intervención humana.
  3. **Privacidad en proveedores LLM (AEPD Art. 28):** no enviar PII (DNI, nombres completos, datos bancarios o de morosidad) a modelos externos sin DPA firmado, **cláusula contractual *No-Train*** (prohibición de entrenar modelos con los datos enviados) y seudonimización/minimización previa en el backend Rust.

### 2.4. Firma Electrónica, Custodia Documental y Valor Probatorio
- **Normas:** **Reglamento eIDAS (UE) 910/2014**, reforma **eIDAS 2.0 (Reglamento UE 2024/1183)**, **Ley 6/2020** reguladora de determinados aspectos de los servicios electrónicos de confianza y **Ley de Enjuiciamiento Civil (LEC)**.
- **Niveles recomendados en Vecinda:**
  - *Nivel operativo interno:* PDF generado en servidor, huella criptográfica `SHA-256`, log de auditoría inmutable y descarga mediante URLs firmadas desde Cloudflare R2.
  - *Nivel con valor probatorio legal:* para certificados de deuda, delegaciones de voto, notificaciones fehacientes (burofax electrónico) y custodia a largo plazo, integrar un **Prestador Cualificado de Servicios de Confianza (QTSP)** (firma electrónica avanzada/cualificada, sellado de tiempo, entrega electrónica certificada y, bajo **eIDAS 2.0**, el **Servicio de Archivo Electrónico Cualificado**).

### 2.5. Marketplace de Gremios, Anuncios y Comercio Electrónico (DSA + LSSI-CE)
- **Normas:** **Reglamento de Servicios Digitales (DSA — Reglamento UE 2022/2065)** supervisado en España por la **CNMC**, y **Ley 34/2002 (LSSI-CE)**.
- **Obligaciones para el Marketplace por gremios vacantes:**
  - **Trazabilidad KYBC (*Know Your Business Customer*, Art. 30 DSA):** verificar y almacenar identidad fiscal (NIF/CIF), datos de contacto y actividad de cada negocio anunciante antes de publicar anuncios.
  - **Transparencia publicitaria (Art. 26 DSA):** distinguir de forma inequívoca en la interfaz entre el **"Proveedor habitual contratado por la comunidad (0 €)"** y un **"Anuncio patrocinado en gremio libre"** (mostrando quién financia el anuncio).
  - **Prohibición de *dark patterns*** (ej. ocultar el botón de cancelación de suscripciones) y habilitación de un **canal de denuncia y retirada** rápida de anuncios ilícitos o engañosos.
  - **LSSI-CE:** aviso legal completo, política de cookies (si se usa analítica no estrictamente necesaria), confirmación electrónica de contratación y control de comunicaciones comerciales.

### 2.6. Facturación y Fiscalidad del Software (Ley Antifraude / Verifactu + Crea y Crece)
- **Normas:** **Ley 11/2021 (Ley Antifraude)** + **RD 1007/2023 (Reglamento SIF / Verifactu)** y **Ley 18/2022 (Crea y Crece — Factura electrónica B2B)**.
- **Impacto real:**
  - **Comunidades de propietarios residenciales:** al girar cuotas ordinarias o derramas a sus vecinos **no** realizan actividad económica ni emiten facturas comerciales, por lo que **no están obligadas a Verifactu** (salvo si explotan comercialmente elementos comunes con IVA, p. ej. alquiler de local, portería o antena).
  - **Vecinda y las Gestorías:** al facturar suscripciones B2B (Vecinda) u honorarios profesionales (gestorías), sí entran en el ámbito de los Sistemas Informáticos de Facturación (inalterabilidad, encadenamiento *hash*, código QR y modalidad Verifactu/No-Verifactu). Fechas oficiales vigentes en BOE: **1 de enero de 2027** (sociedades) y **1 de julio de 2027** (autónomos).
  - **Decisión de arquitectura recomendada:** delegar la emisión fiscal de facturas de suscripción de Vecinda en **Stripe Billing** o un facturador certificado externo, evitando convertir el backend de Vecinda en un software de facturación fiscal (SIF) sujeto a certificación.

---

## 3. Matriz resumen: Módulo → Normativa → Requisito técnico

| Módulo de Vecinda | Normativas aplicables | Requisito técnico en Rust / React / Infra |
|---|---|---|
| **Auth, Roles y Censos** | RGPD (Arts. 5, 28, 32), LOPDGDD | RBAC estricto en Rust `(usuario_id, comunidad_id) -> rol`; revocación inmediata de sesión al dar de baja inquilinos o cerrar ventas; DPA con gestorías. |
| **Cuentas y Morosos** | AEPD (Administración de Fincas), LPH (Art. 16.2) | Endpoints y cachés `moka` separados para morosidad; **prohibido** exponer deudores en tablón público, a conserjes o a inquilinos. |
| **Votaciones y Juntas** | LPH (Arts. 15, 16, 17, 19) | Separar **sondeos consultivos** de actas/juntas formales; añadir soporte de coeficientes de participación y estado de deuda si se habilita Junta. |
| **Traspasos y Certificados** | LPH (Arts. 9.1.e, 21), eIDAS 2.0, Ley 6/2020 | Corregir regla a **año en curso + 3 años anteriores**; PDF con hash + auditoría en BD (y QTSP opcional para validez legal). |
| **Documentos y Backups** | RGPD (Cap. V, Art. 32), INCIBE | Archivos validados por *magic bytes* en R2 con URLs firmadas y `Content-Disposition: attachment`; backups cifrados inmutables (*Object Lock*). |
| **Marketplace Gremios** | DSA (Arts. 26, 30), LSSI-CE | Flujo KYBC (NIF/CIF) para anunciantes; etiqueta clara *"Anuncio"* vs. *"Proveedor contratado"*; botón de reporte de anuncio; sin *dark patterns*. |
| **Funciones IA (futuras)** | EU AI Act (Arts. 4, 50), AEPD IA | Aviso explícito de IA y revisión humana obligatoria; cero *scoring* de morosos/vecinos; DPA *No-Train* + seudonimización de PII en Rust. |
| **Cobros y Suscripciones** | RD 1007/2023 (Verifactu), Crea y Crece, LSSI-CE | Externalizar facturación fiscal en Stripe Billing / facturador certificado; webhooks idempotentes verificados en Rust. |

---

## 4. Directorio de fuentes oficiales primarias

| Área | Organismo / Portal oficial | Qué consultar |
|---|---|---|
| **Leyes españolas** (LPH, LOPDGDD, Ley 6/2020, LSSI-CE, RD 1007/2023) | **BOE — Legislación Consolidada** (`boe.es`) | Pestaña *"Texto consolidado"* vigente (Ley 49/1960, LO 3/2018, Ley 6/2020, Ley 34/2002). |
| **Reglamentos UE** (RGPD, AI Act, eIDAS 2.0, DSA) | **EUR-Lex** (`eur-lex.europa.eu`) | Textos oficiales en español: `2016/679`, `2024/1689` + `2026/1744`, `2024/1183` y `2022/2065`. |
| **Protección de datos en fincas e IA** | **AEPD** (`aepd.es`) y **EDPB** (`edpb.europa.eu`) | *Guía de Protección de Datos y Administración de Fincas*, *Guía Responsable–Encargado*, *Guía de tratamientos con IA*, Facilita RGPD. |
| **Cumplimiento IA en España** | **AESIA** (`aesia.digital.gob.es`) y **AI Office UE** (`digital-strategy.ec.europa.eu`) | Guías prácticas de transparencia (Art. 50), alfabetización (Art. 4) y códigos de buenas prácticas. |
| **Marketplace y plataformas** | **CNMC** (`cnmc.es`) | Supervisión DSA en España, trazabilidad de comerciantes y transparencia publicitaria. |
| **Facturación y Verifactu** | **AEAT** (`sede.agenciatributaria.gob.es`) | FAQs y especificaciones técnicas de Sistemas Informáticos de Facturación (SIF). |
| **Ciberseguridad SaaS** | **INCIBE** (`incibe.es`) y **CCN-CERT** (`ccn-cert.cni.es`) | Guías de hardening, notificación de brechas (72 h) y protección anti-ransomware. |

---

## 5. Ecosistema de plugins recomendados para el desarrollo

Plugins de Antigravity alineados con las fases de [ARQUITECTURA.md](ARQUITECTURA.md):
- **Instalados en el entorno:**
  - **CodeRabbit:** revisión automática de PRs, calidad y vulnerabilidades.
  - **Netlify:** despliegue continuo, *Deploy Previews* y caché CDN del frontend `Vite + React`.
  - **Cloudflare:** configuración de **R2** (PDFs firmados y backups inmutables con *Object Lock*) y WAF delante de OVH.
  - **Supabase:** PostgreSQL de pruebas (*staging*), inspección de esquema y migraciones.
  - **Figma:** diseño visual de pantallas a partir de `DESIGN.md` y mapeo a componentes React/Tailwind.
  - **Sentry:** monitorización de errores en producción (React + Rust, región UE). *(Pendiente conectar cuenta en Fase 2).*
- **Complementos opcionales / Fase 2–3:**
  - **Modern Web Guidance / Chrome DevTools** *(Google)*: buenas prácticas web y depuración en Chrome real.
  - **Stripe** *(Fase 2)*: cobros B2B (*per-seat* + cartera), *Pay-as-you-go*, webhooks y delegación de facturación fiscal.
  - **Firma electrónica y burofax (QTSP europeos):** Docusign queda **descartado**; si en Fase 2/3 se integra firma cualificada o entrega certificada, valorar prestadores cualificados bajo **eIDAS 2.0** (p. ej. Signaturit, Viafirma o Lleida.net).
