-- Vecinda · Migración inicial v2 · PostgreSQL 16 (SQLx / Supabase / Docker)
-- Convenciones:
--   * Claves primarias UUID (gen_random_uuid()) para evitar enumeración / IDOR.
--   * Importes monetarios siempre en BIGINT (céntimos de euro, sin punto flotante).
--   * Fechas en TIMESTAMPTZ (UTC).
--   * Estados con TEXT CHECK (...) para evolucionar migraciones sin bloqueos de ENUM.
--   * Aislamiento multi-tenant estricto mediante FKs compuestas (entidad_id, comunidad_id).

-- ============================================================================
-- BLOQUE 1 · IDENTIDAD, CONSENTIMIENTOS RGPD Y MULTI-TENANT
-- ============================================================================

CREATE TABLE usuarios (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                     TEXT NOT NULL,
    password_hash             TEXT NOT NULL,
    nombre                    TEXT NOT NULL,
    token_version             INTEGER NOT NULL DEFAULT 1 CHECK (token_version >= 1),
    preferencias_notificacion JSONB NOT NULL DEFAULT '{"avisos_urgentes": true}'::jsonb,
    activo                    BOOLEAN NOT NULL DEFAULT TRUE,
    ultimo_acceso_en          TIMESTAMPTZ,
    eliminado_en              TIMESTAMPTZ,
    creado_en                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_usuarios_email_lower ON usuarios (LOWER(email));

-- Prueba de consentimiento RGPD (Art. 7) y preferencias LSSI-CE por versión de texto legal
CREATE TABLE consentimientos_usuario (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id        UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo              TEXT NOT NULL CHECK (tipo IN ('PRIVACIDAD', 'TERMINOS', 'COMUNICACIONES')),
    version_documento TEXT NOT NULL,
    aceptado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    revocado_en       TIMESTAMPTZ
);

CREATE INDEX idx_consentimientos_usuario ON consentimientos_usuario (usuario_id, tipo, aceptado_en DESC);

CREATE TABLE gestorias (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre                  TEXT NOT NULL,
    cif                     TEXT NOT NULL UNIQUE,
    cif_estado_verificacion TEXT NOT NULL DEFAULT 'FORMATO_OK'
                            CHECK (cif_estado_verificacion IN ('FORMATO_OK', 'VERIFICADO_VIES', 'VERIFICADO_MANUAL', 'RECHAZADO')),
    email_contacto          TEXT NOT NULL,
    plan_estado             TEXT NOT NULL DEFAULT 'TRIAL'
                            CHECK (plan_estado IN ('TRIAL', 'ACTIVA', 'IMPAGO_GRACIA', 'SUSPENDIDA', 'CANCELADA')),
    max_asientos            INTEGER NOT NULL DEFAULT 3 CHECK (max_asientos >= 1),
    origen_captacion        TEXT NOT NULL DEFAULT 'ORGANICO',
    referido_por_usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    dpa_aceptado_en         TIMESTAMPTZ,
    eliminado_en            TIMESTAMPTZ,
    creado_en               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE gestoria_miembros (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gestoria_id     UUID NOT NULL REFERENCES gestorias(id) ON DELETE CASCADE,
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol             TEXT NOT NULL CHECK (rol IN ('GESTORIA_ADMIN', 'GESTORIA_STAFF')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (gestoria_id, usuario_id)
);

CREATE INDEX idx_gestoria_miembros_usuario ON gestoria_miembros (usuario_id) WHERE activo = TRUE;

CREATE TABLE comunidades (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gestoria_id             UUID REFERENCES gestorias(id) ON DELETE SET NULL,
    nombre                  TEXT NOT NULL,
    direccion               TEXT NOT NULL,
    ciudad                  TEXT NOT NULL,
    codigo_postal           TEXT NOT NULL DEFAULT '',
    provincia               TEXT NOT NULL DEFAULT '',
    codigo_acceso           TEXT NOT NULL UNIQUE,
    num_viviendas_declaradas INTEGER NOT NULL CHECK (num_viviendas_declaradas >= 1 AND num_viviendas_declaradas <= 500),
    limite_storage_bytes    BIGINT NOT NULL DEFAULT 524288000 CHECK (limite_storage_bytes > 0),
    plan_estado             TEXT NOT NULL DEFAULT 'BASE'
                            CHECK (plan_estado IN ('BASE', 'SUSCRITA', 'IMPAGO_GRACIA', 'SUSPENDIDA')),
    origen_captacion        TEXT NOT NULL DEFAULT 'ORGANICO',
    dpa_aceptado_en         TIMESTAMPTZ,
    eliminado_en            TIMESTAMPTZ,
    creado_en               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_comunidades_gestoria ON comunidades (gestoria_id) WHERE gestoria_id IS NOT NULL AND eliminado_en IS NULL;
CREATE INDEX idx_comunidades_zona ON comunidades (provincia, codigo_postal) WHERE eliminado_en IS NULL;

-- ============================================================================
-- BLOQUE 2 · CENSO, ROLES (RBAC) E INVITACIONES
-- ============================================================================

CREATE TABLE viviendas (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id              UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    etiqueta                  TEXT NOT NULL,
    coeficiente_participacion NUMERIC(7,4) NOT NULL DEFAULT 0.0000
                              CHECK (coeficiente_participacion >= 0 AND coeficiente_participacion <= 100),
    cuota_mensual_centimos    BIGINT NOT NULL DEFAULT 0 CHECK (cuota_mensual_centimos >= 0),
    creado_en                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (comunidad_id, etiqueta),
    UNIQUE (id, comunidad_id)
);

CREATE INDEX idx_viviendas_comunidad ON viviendas (comunidad_id);

-- LPH art. 13.2: El presidente siempre debe ser propietario de una vivienda.
-- Múltiples copropietarios pueden estar activos sobre la misma vivienda,
-- pero un mismo usuario no puede duplicar fila activa en esa misma vivienda.
CREATE TABLE membresias_comunidad (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    vivienda_id     UUID,
    rol             TEXT NOT NULL CHECK (rol IN ('PRESIDENTE', 'CONSERJE', 'PROPIETARIO', 'INQUILINO')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    desde           TIMESTAMPTZ NOT NULL DEFAULT now(),
    hasta           TIMESTAMPTZ,
    CONSTRAINT fk_membresias_vivienda_comunidad
        FOREIGN KEY (vivienda_id, comunidad_id)
        REFERENCES viviendas(id, comunidad_id)
        ON DELETE CASCADE,
    CHECK (
        (rol = 'CONSERJE' AND vivienda_id IS NULL)
        OR (rol IN ('PRESIDENTE', 'PROPIETARIO', 'INQUILINO') AND vivienda_id IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_membresias_un_presidente_activo
    ON membresias_comunidad (comunidad_id)
    WHERE rol = 'PRESIDENTE' AND activo = TRUE;

CREATE UNIQUE INDEX uq_membresias_activas_usuario_vivienda
    ON membresias_comunidad (
        usuario_id,
        comunidad_id,
        COALESCE(vivienda_id, '00000000-0000-0000-0000-000000000000'::uuid)
    )
    WHERE activo = TRUE;

CREATE INDEX idx_membresias_rbac_lookup
    ON membresias_comunidad (usuario_id, comunidad_id)
    WHERE activo = TRUE;

CREATE INDEX idx_membresias_comunidad_vivienda
    ON membresias_comunidad (comunidad_id, vivienda_id)
    WHERE activo = TRUE;

CREATE TABLE invitaciones_inquilino (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    vivienda_id     UUID NOT NULL,
    propietario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    codigo          TEXT NOT NULL UNIQUE,
    inquilino_id    UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    expira_en       TIMESTAMPTZ NOT NULL,
    revocado_en     TIMESTAMPTZ,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_invitaciones_vivienda_comunidad
        FOREIGN KEY (vivienda_id, comunidad_id)
        REFERENCES viviendas(id, comunidad_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_invitaciones_vivienda ON invitaciones_inquilino (comunidad_id, vivienda_id);

-- ============================================================================
-- BLOQUE 3 · DOCUMENTOS EN CLOUDFLARE R2 (CON BORRADO LÓGICO ANTI-HUÉRFANOS)
-- ============================================================================

CREATE TABLE documentos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    tipo            TEXT NOT NULL CHECK (tipo IN ('ACTA', 'CERTIFICADO_DEUDA', 'ESTATUTOS', 'FACTURA', 'FOTO_INCIDENCIA', 'OTRO')),
    nombre_archivo  TEXT NOT NULL,
    r2_object_key   TEXT NOT NULL UNIQUE,
    mime_type       TEXT NOT NULL,
    tamano_bytes    BIGINT NOT NULL CHECK (tamano_bytes > 0 AND tamano_bytes <= 10485760),
    sha256_hex      CHAR(64) NOT NULL,
    visibilidad     TEXT NOT NULL DEFAULT 'SOLO_GESTION'
                    CHECK (visibilidad IN ('SOLO_GESTION', 'PROPIETARIOS', 'TODOS_VECINOS')),
    subido_por      UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    eliminado_en    TIMESTAMPTZ,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id, comunidad_id)
);

CREATE INDEX idx_documentos_comunidad_tipo ON documentos (comunidad_id, tipo, creado_en DESC) WHERE eliminado_en IS NULL;

-- ============================================================================
-- BLOQUE 4 · MARKETPLACE POR GREMIOS VACANTES Y MODERACIÓN DSA
-- ============================================================================

CREATE TABLE gremios_catalogo (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            TEXT NOT NULL UNIQUE,
    nombre          TEXT NOT NULL
);

INSERT INTO gremios_catalogo (slug, nombre) VALUES
    ('fontaneria', 'Fontanería'),
    ('electricidad', 'Electricidad'),
    ('ascensores', 'Ascensores'),
    ('limpieza', 'Limpieza'),
    ('cerrajeria', 'Cerrajería'),
    ('carpinteria', 'Carpintería'),
    ('pintura', 'Pintura'),
    ('climatizacion', 'Climatización'),
    ('albanileria', 'Albañilería'),
    ('telecomunicaciones', 'Telecomunicaciones')
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE proveedores (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id              UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    razon_social            TEXT NOT NULL,
    nif_cif                 TEXT NOT NULL UNIQUE,
    cif_estado_verificacion TEXT NOT NULL DEFAULT 'FORMATO_OK'
                            CHECK (cif_estado_verificacion IN ('FORMATO_OK', 'VERIFICADO_VIES', 'VERIFICADO_MANUAL', 'RECHAZADO')),
    email                   TEXT NOT NULL,
    telefono                TEXT NOT NULL,
    codigo_postal           TEXT NOT NULL DEFAULT '',
    provincia               TEXT NOT NULL DEFAULT '',
    kybc_verificado_en      TIMESTAMPTZ,
    creado_en               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Si existe fila con tiene_contrato_vigente = TRUE, el proveedor está gratis (0 €)
-- en esa finca y bloquea anuncios de competidores de ese mismo gremio.
CREATE TABLE gremios_comunidad (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id            UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    gremio_id               UUID NOT NULL REFERENCES gremios_catalogo(id) ON DELETE RESTRICT,
    proveedor_id            UUID REFERENCES proveedores(id) ON DELETE SET NULL,
    tiene_contrato_vigente  BOOLEAN NOT NULL DEFAULT TRUE,
    actualizado_en          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (comunidad_id, gremio_id)
);

CREATE INDEX idx_gremios_comunidad_lookup ON gremios_comunidad (comunidad_id, gremio_id);

CREATE TABLE anuncios_marketplace (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proveedor_id    UUID NOT NULL REFERENCES proveedores(id) ON DELETE CASCADE,
    gremio_id       UUID NOT NULL REFERENCES gremios_catalogo(id) ON DELETE RESTRICT,
    titulo          TEXT NOT NULL,
    descripcion     TEXT NOT NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_anuncios_gremio_activo ON anuncios_marketplace (gremio_id) WHERE activo = TRUE;

CREATE TABLE anuncio_comunidades (
    anuncio_id      UUID NOT NULL REFERENCES anuncios_marketplace(id) ON DELETE CASCADE,
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (anuncio_id, comunidad_id)
);

CREATE INDEX idx_anuncio_comunidades_comunidad ON anuncio_comunidades (comunidad_id);

-- Mecanismo obligatorio de notificación y retirada de contenidos ilícitos (DSA)
CREATE TABLE anuncio_reportes (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anuncio_id        UUID NOT NULL REFERENCES anuncios_marketplace(id) ON DELETE CASCADE,
    reportado_por     UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    motivo            TEXT NOT NULL,
    estado            TEXT NOT NULL DEFAULT 'ABIERTA'
                      CHECK (estado IN ('ABIERTA', 'RETIRADO', 'DESCARTADO')),
    resolucion_motivo TEXT,
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    resuelto_en       TIMESTAMPTZ
);

CREATE INDEX idx_anuncio_reportes_estado ON anuncio_reportes (estado, creado_en DESC);

-- ============================================================================
-- BLOQUE 5 · OPERATIVA DIARIA (CON FKS COMPUESTAS Y AISLAMIENTO AEPD)
-- ============================================================================

CREATE TABLE movimientos_cuentas (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id      UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    categoria         TEXT NOT NULL DEFAULT 'OTROS'
                      CHECK (categoria IN ('CUOTAS', 'LIMPIEZA', 'ASCENSOR', 'SUMINISTROS', 'MANTENIMIENTO', 'SEGURO', 'HONORARIOS', 'OTROS')),
    concepto          TEXT NOT NULL,
    importe_centimos  BIGINT NOT NULL CHECK (importe_centimos <> 0),
    fecha_operacion   DATE NOT NULL,
    documento_id      UUID,
    creado_por        UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_movimientos_documento_comunidad
        FOREIGN KEY (documento_id, comunidad_id)
        REFERENCES documentos(id, comunidad_id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_movimientos_comunidad_fecha
    ON movimientos_cuentas (comunidad_id, fecha_operacion DESC, id DESC);

-- Tabla separada por RGPD/AEPD: nunca se mezcla con cuentas públicas ni avisos.
-- desglose_anual_json respalda la afección real LPH (año en curso + 3 años anteriores).
CREATE TABLE deudas_vivienda (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id               UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    vivienda_id                UUID NOT NULL UNIQUE,
    importe_pendiente_centimos BIGINT NOT NULL DEFAULT 0 CHECK (importe_pendiente_centimos >= 0),
    desglose_anual_json        JSONB NOT NULL DEFAULT '{}'::jsonb,
    actualizado_por            UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_en             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_deudas_vivienda_comunidad
        FOREIGN KEY (vivienda_id, comunidad_id)
        REFERENCES viviendas(id, comunidad_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_deudas_comunidad ON deudas_vivienda (comunidad_id);

CREATE TABLE avisos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    titulo          TEXT NOT NULL,
    cuerpo          TEXT NOT NULL,
    creado_por      UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_avisos_comunidad_fecha ON avisos (comunidad_id, creado_en DESC);

CREATE TABLE incidencias (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    vivienda_id     UUID,
    reportado_por   UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    gremio_id       UUID REFERENCES gremios_catalogo(id) ON DELETE SET NULL,
    titulo          TEXT NOT NULL,
    descripcion     TEXT NOT NULL DEFAULT '',
    estado          TEXT NOT NULL DEFAULT 'ABIERTA'
                    CHECK (estado IN ('ABIERTA', 'EN_CURSO', 'RESUELTA')),
    resuelta_en     TIMESTAMPTZ,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id, comunidad_id),
    CONSTRAINT fk_incidencias_vivienda_comunidad
        FOREIGN KEY (vivienda_id, comunidad_id)
        REFERENCES viviendas(id, comunidad_id)
        ON DELETE SET NULL (vivienda_id)
);

CREATE INDEX idx_incidencias_comunidad_estado
    ON incidencias (comunidad_id, estado, creado_en DESC);

CREATE TABLE incidencia_comentarios (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incidencia_id   UUID NOT NULL,
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    mensaje         TEXT NOT NULL,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_comentarios_incidencia_comunidad
        FOREIGN KEY (incidencia_id, comunidad_id)
        REFERENCES incidencias(id, comunidad_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_incidencia_comentarios_lookup ON incidencia_comentarios (incidencia_id, creado_en ASC);

CREATE TABLE incidencia_adjuntos (
    incidencia_id   UUID NOT NULL,
    comunidad_id    UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    documento_id    UUID NOT NULL,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (incidencia_id, documento_id),
    CONSTRAINT fk_adjuntos_incidencia_comunidad
        FOREIGN KEY (incidencia_id, comunidad_id)
        REFERENCES incidencias(id, comunidad_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_adjuntos_documento_comunidad
        FOREIGN KEY (documento_id, comunidad_id)
        REFERENCES documentos(id, comunidad_id)
        ON DELETE RESTRICT
);

CREATE TABLE sondeos (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id        UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    titulo              TEXT NOT NULL,
    detalle             TEXT NOT NULL DEFAULT '',
    tipo                TEXT NOT NULL DEFAULT 'CONSULTIVO'
                        CHECK (tipo IN ('CONSULTIVO', 'JUNTA_APOYO')),
    abierta_inquilinos  BOOLEAN NOT NULL DEFAULT FALSE,
    cierra_en           TIMESTAMPTZ,
    creado_por          UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id, comunidad_id)
);

CREATE INDEX idx_sondeos_comunidad_fecha ON sondeos (comunidad_id, creado_en DESC);

-- Garantiza 1 solo voto por vivienda (aunque haya múltiples copropietarios)
-- y congela coeficiente_snapshot en el momento del voto.
CREATE TABLE sondeo_votos (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sondeo_id            UUID NOT NULL,
    comunidad_id         UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    vivienda_id          UUID NOT NULL,
    usuario_id           UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    opcion               TEXT NOT NULL CHECK (opcion IN ('A_FAVOR', 'EN_CONTRA', 'ABSTENCION')),
    es_inquilino         BOOLEAN NOT NULL DEFAULT FALSE,
    coeficiente_snapshot NUMERIC(7,4) NOT NULL DEFAULT 0.0000
                         CHECK (coeficiente_snapshot >= 0 AND coeficiente_snapshot <= 100),
    creado_en            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (sondeo_id, vivienda_id, es_inquilino),
    CONSTRAINT fk_sondeo_votos_sondeo_comunidad
        FOREIGN KEY (sondeo_id, comunidad_id)
        REFERENCES sondeos(id, comunidad_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sondeo_votos_vivienda_comunidad
        FOREIGN KEY (vivienda_id, comunidad_id)
        REFERENCES viviendas(id, comunidad_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_sondeo_votos_comunidad ON sondeo_votos (comunidad_id, sondeo_id);

-- ============================================================================
-- BLOQUE 6 · TRASPASOS Y AUDITORÍA LEGAL
-- ============================================================================

CREATE TABLE traspasos_vivienda (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comunidad_id               UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    vivienda_id                UUID NOT NULL,
    vendedor_id                UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    comprador_nombre           TEXT NOT NULL DEFAULT '',
    comprador_email            TEXT,
    fecha_escritura_prevista   DATE,
    accion_inquilino           TEXT NOT NULL DEFAULT 'SIGUE'
                               CHECK (accion_inquilino IN ('SIGUE', 'BAJA')),
    estado                     TEXT NOT NULL DEFAULT 'SOLICITADO'
                               CHECK (estado IN ('SOLICITADO', 'CERTIFICADO', 'COMPLETADO', 'CANCELADO')),
    deuda_certificada_centimos BIGINT CHECK (deuda_certificada_centimos >= 0),
    certificado_doc_id         UUID,
    creado_en                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    cerrado_en                 TIMESTAMPTZ,
    CONSTRAINT fk_traspasos_vivienda_comunidad
        FOREIGN KEY (vivienda_id, comunidad_id)
        REFERENCES viviendas(id, comunidad_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_traspasos_documento_comunidad
        FOREIGN KEY (certificado_doc_id, comunidad_id)
        REFERENCES documentos(id, comunidad_id)
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_traspaso_activo_por_vivienda
    ON traspasos_vivienda (vivienda_id)
    WHERE estado IN ('SOLICITADO', 'CERTIFICADO');

CREATE INDEX idx_traspasos_comunidad_estado ON traspasos_vivienda (comunidad_id, estado);

CREATE TABLE auditoria_eventos (
    id              BIGSERIAL PRIMARY KEY,
    comunidad_id    UUID REFERENCES comunidades(id) ON DELETE SET NULL,
    usuario_id      UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    accion          TEXT NOT NULL,
    entidad         TEXT NOT NULL,
    entidad_id      UUID,
    detalle_json    JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_auditoria_comunidad_fecha ON auditoria_eventos (comunidad_id, creado_en DESC);

-- ============================================================================
-- BLOQUE 7 · SUSCRIPCIONES, IMPAGOS, PAGOS, WEBHOOKS Y MÉTRICAS (FINOPS)
-- ============================================================================

-- Cubre las 4 fuentes de ingreso con control de impagos, antigüedad y churn.
CREATE TABLE suscripciones (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    via_ingreso                TEXT NOT NULL CHECK (via_ingreso IN (
                                   'GESTORIA', 'COMUNIDAD_AUTOGESTIONADA', 'USUARIO_COLATERAL', 'PROVEEDOR_MARKETPLACE'
                               )),
    gestoria_id                UUID REFERENCES gestorias(id) ON DELETE CASCADE,
    comunidad_id               UUID REFERENCES comunidades(id) ON DELETE CASCADE,
    usuario_id                 UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    proveedor_id               UUID REFERENCES proveedores(id) ON DELETE CASCADE,
    estado                     TEXT NOT NULL DEFAULT 'TRIAL' CHECK (estado IN (
                                   'TRIAL', 'ACTIVA', 'IMPAGO_GRACIA', 'IMPAGO_SUSPENDIDA', 'CANCELADA_AL_FINAL', 'CANCELADA'
                               )),
    ciclo                      TEXT NOT NULL DEFAULT 'MENSUAL' CHECK (ciclo IN ('MENSUAL', 'ANUAL')),
    importe_periodico_centimos BIGINT NOT NULL DEFAULT 0 CHECK (importe_periodico_centimos >= 0),
    asientos_contratados       INTEGER NOT NULL DEFAULT 0 CHECK (asientos_contratados >= 0),
    comunidades_contratadas    INTEGER NOT NULL DEFAULT 0 CHECK (comunidades_contratadas >= 0),
    anuncios_contratados       INTEGER NOT NULL DEFAULT 0 CHECK (anuncios_contratados >= 0),
    inicio_suscripcion_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    periodo_actual_inicio      TIMESTAMPTZ NOT NULL DEFAULT now(),
    periodo_actual_fin         TIMESTAMPTZ NOT NULL,
    impago_desde               TIMESTAMPTZ,
    gracia_hasta               TIMESTAMPTZ,
    cancelada_en               TIMESTAMPTZ,
    motivo_cancelacion         TEXT,
    proveedor_pago             TEXT NOT NULL DEFAULT 'MANUAL' CHECK (proveedor_pago IN ('STRIPE', 'PAYPAL', 'MANUAL')),
    external_customer_id       TEXT,
    external_subscription_id   TEXT UNIQUE,
    payment_fingerprint        TEXT,
    creado_en                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (
        (via_ingreso = 'GESTORIA' AND gestoria_id IS NOT NULL AND comunidad_id IS NULL AND usuario_id IS NULL AND proveedor_id IS NULL)
        OR (via_ingreso = 'COMUNIDAD_AUTOGESTIONADA' AND comunidad_id IS NOT NULL AND gestoria_id IS NULL AND usuario_id IS NULL AND proveedor_id IS NULL)
        OR (via_ingreso = 'USUARIO_COLATERAL' AND usuario_id IS NOT NULL AND gestoria_id IS NULL AND comunidad_id IS NULL AND proveedor_id IS NULL)
        OR (via_ingreso = 'PROVEEDOR_MARKETPLACE' AND proveedor_id IS NOT NULL AND gestoria_id IS NULL AND comunidad_id IS NULL AND usuario_id IS NULL)
    )
);

CREATE INDEX idx_suscripciones_estado ON suscripciones (estado, periodo_actual_fin);
CREATE INDEX idx_suscripciones_impagos ON suscripciones (estado, gracia_hasta)
    WHERE estado IN ('IMPAGO_GRACIA', 'IMPAGO_SUSPENDIDA');

CREATE TABLE pagos_transacciones (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    suscripcion_id      UUID REFERENCES suscripciones(id) ON DELETE SET NULL,
    via_ingreso         TEXT NOT NULL CHECK (via_ingreso IN (
                            'GESTORIA', 'COMUNIDAD_AUTOGESTIONADA', 'USUARIO_COLATERAL', 'PROVEEDOR_MARKETPLACE'
                        )),
    concepto_tipo       TEXT NOT NULL CHECK (concepto_tipo IN ('SUSCRIPCION', 'PAY_AS_YOU_GO', 'ADDON')),
    importe_centimos    BIGINT NOT NULL CHECK (importe_centimos >= 0),
    estado              TEXT NOT NULL CHECK (estado IN ('PENDIENTE', 'PAGADO', 'FALLIDO', 'REEMBOLSADO')),
    codigo_error_pago   TEXT,
    proveedor_pago      TEXT NOT NULL CHECK (proveedor_pago IN ('STRIPE', 'PAYPAL', 'MANUAL')),
    external_payment_id TEXT UNIQUE,
    pagado_en           TIMESTAMPTZ,
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pagos_suscripcion_fecha ON pagos_transacciones (suscripcion_id, creado_en DESC);
CREATE INDEX idx_pagos_estado_fecha ON pagos_transacciones (estado, creado_en DESC);

CREATE TABLE webhook_eventos_procesados (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proveedor_pago    TEXT NOT NULL CHECK (proveedor_pago IN ('STRIPE', 'PAYPAL')),
    external_event_id TEXT NOT NULL,
    tipo_evento       TEXT NOT NULL,
    procesado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (proveedor_pago, external_event_id)
);

-- Agregado diario por comunidad (actualizado en lote desde RAM en Rust cada 5-10 min)
CREATE TABLE metricas_comunidad_diarias (
    comunidad_id            UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    fecha                   DATE NOT NULL,
    escrituras_activos      INTEGER NOT NULL DEFAULT 0 CHECK (escrituras_activos >= 0),
    lecturas_vecinos        INTEGER NOT NULL DEFAULT 0 CHECK (lecturas_vecinos >= 0),
    cache_hits              INTEGER NOT NULL DEFAULT 0 CHECK (cache_hits >= 0),
    cache_misses            INTEGER NOT NULL DEFAULT 0 CHECK (cache_misses >= 0),
    storage_r2_bytes        BIGINT NOT NULL DEFAULT 0 CHECK (storage_r2_bytes >= 0),
    vecinos_activos_unicos  INTEGER NOT NULL DEFAULT 0 CHECK (vecinos_activos_unicos >= 0),
    incidencias_creadas     INTEGER NOT NULL DEFAULT 0 CHECK (incidencias_creadas >= 0),
    incidencias_resueltas   INTEGER NOT NULL DEFAULT 0 CHECK (incidencias_resueltas >= 0),
    PRIMARY KEY (comunidad_id, fecha)
);

-- Métricas agregadas de Marketplace sin rastrear vecinos individuales (RGPD/DSA)
CREATE TABLE metricas_anuncio_diarias (
    anuncio_id    UUID NOT NULL REFERENCES anuncios_marketplace(id) ON DELETE CASCADE,
    comunidad_id  UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
    fecha         DATE NOT NULL,
    impresiones   INTEGER NOT NULL DEFAULT 0 CHECK (impresiones >= 0),
    clics         INTEGER NOT NULL DEFAULT 0 CHECK (clics >= 0),
    PRIMARY KEY (anuncio_id, comunidad_id, fecha)
);

-- Embudos de adopción de producto sin PII (retención sugerida: 90 días)
CREATE TABLE eventos_producto (
    id            BIGSERIAL PRIMARY KEY,
    comunidad_id  UUID REFERENCES comunidades(id) ON DELETE SET NULL,
    rol           TEXT,
    evento        TEXT NOT NULL,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_eventos_producto_tipo_fecha ON eventos_producto (evento, creado_en DESC);

-- Invitaciones de referido acotadas (máx. 3 por usuario en API + 30 días trial por CIF único)
CREATE TABLE invitaciones_referido (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invitador_usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo_destino          TEXT NOT NULL DEFAULT 'GESTORIA'
                          CHECK (tipo_destino IN ('GESTORIA', 'COMUNIDAD_AUTOGESTIONADA')),
    codigo                TEXT NOT NULL UNIQUE,
    email_invitado        TEXT,
    dias_prueba_gratis    INTEGER NOT NULL DEFAULT 30 CHECK (dias_prueba_gratis >= 1 AND dias_prueba_gratis <= 90),
    estado                TEXT NOT NULL DEFAULT 'PENDIENTE'
                          CHECK (estado IN ('PENDIENTE', 'CANJEADA', 'EXPIRADA', 'REVOCADA')),
    gestoria_canjeada_id  UUID REFERENCES gestorias(id) ON DELETE SET NULL,
    comunidad_canjeada_id UUID REFERENCES comunidades(id) ON DELETE SET NULL,
    expira_en             TIMESTAMPTZ NOT NULL,
    canjeada_en           TIMESTAMPTZ,
    creado_en             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invitaciones_referido_invitador ON invitaciones_referido (invitador_usuario_id, estado);
