-- Vecinda · Suite de pruebas negativas SQL (Plan A · Auditoría de 0001_initial_schema.sql)
-- Verifica el conteo de 32 tablas y que PostgreSQL rechaza cruces multi-tenant y violaciones LPH/RGPD.

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    tbl_count INTEGER;
    u1 UUID := gen_random_uuid();
    u2 UUID := gen_random_uuid();
    g1 UUID := gen_random_uuid();
    c_a UUID := gen_random_uuid();
    c_b UUID := gen_random_uuid();
    v_a UUID := gen_random_uuid();
    v_b UUID := gen_random_uuid();
    s_a UUID := gen_random_uuid();
    failed BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO tbl_count
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

    IF tbl_count <> 32 THEN
        RAISE EXCEPTION 'Se esperaban 32 tablas en public y hay %', tbl_count;
    END IF;

    INSERT INTO usuarios (id, email, password_hash, nombre) VALUES
        (u1, 'copropietario1@vecinda.test', 'argon2_dummy_1', 'Ana Uno'),
        (u2, 'copropietario2@vecinda.test', 'argon2_dummy_2', 'Luis Dos');

    INSERT INTO gestorias (id, nombre, cif, email_contacto) VALUES
        (g1, 'Gestoria Demo', 'B12345674', 'contacto@gestoria.test');

    INSERT INTO comunidades (id, gestoria_id, nombre, direccion, ciudad, codigo_acceso, num_viviendas_declaradas) VALUES
        (c_a, g1, 'Comunidad A', 'C/ Mayor 1', 'Madrid', 'VEC-AAAA', 20),
        (c_b, g1, 'Comunidad B', 'C/ Menor 2', 'Madrid', 'VEC-BBBB', 20);

    INSERT INTO viviendas (id, comunidad_id, etiqueta, coeficiente_participacion, cuota_mensual_centimos) VALUES
        (v_a, c_a, '1ºA', 5.0000, 5500),
        (v_b, c_b, '1ºB', 5.0000, 5500);

    INSERT INTO sondeos (id, comunidad_id, titulo, creado_por) VALUES
        (s_a, c_a, 'Sondeo LED portal', u1);

    -- 1. Cruce multi-tenant en incidencias (vivienda de B dentro de Comunidad A)
    failed := FALSE;
    BEGIN
        INSERT INTO incidencias (comunidad_id, vivienda_id, reportado_por, titulo)
        VALUES (c_a, v_b, u1, 'Cruce ilegal');
    EXCEPTION WHEN foreign_key_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 1: permitió cruzar vivienda_id de B en incidencias de A'; END IF;

    -- 2. Cruce multi-tenant en deudas_vivienda
    failed := FALSE;
    BEGIN
        INSERT INTO deudas_vivienda (comunidad_id, vivienda_id, importe_pendiente_centimos, actualizado_por)
        VALUES (c_a, v_b, 10000, u1);
    EXCEPTION WHEN foreign_key_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 2: permitió cruzar vivienda_id de B en deudas_vivienda de A'; END IF;

    -- 3. Cruce multi-tenant en traspasos_vivienda
    failed := FALSE;
    BEGIN
        INSERT INTO traspasos_vivienda (comunidad_id, vivienda_id, vendedor_id)
        VALUES (c_a, v_b, u1);
    EXCEPTION WHEN foreign_key_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 3: permitió cruzar vivienda_id de B en traspasos_vivienda de A'; END IF;

    -- 4. Dos presidentes activos simultáneos en la misma comunidad
    INSERT INTO membresias_comunidad (usuario_id, comunidad_id, vivienda_id, rol)
    VALUES (u1, c_a, v_a, 'PRESIDENTE');

    failed := FALSE;
    BEGIN
        INSERT INTO membresias_comunidad (usuario_id, comunidad_id, vivienda_id, rol)
        VALUES (u2, c_a, v_a, 'PRESIDENTE');
    EXCEPTION WHEN unique_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 4: permitió 2 presidentes activos en Comunidad A'; END IF;

    -- 5a. Conserje con vivienda_id asignado (viola CHECK LPH)
    failed := FALSE;
    BEGIN
        INSERT INTO membresias_comunidad (usuario_id, comunidad_id, vivienda_id, rol)
        VALUES (u2, c_a, v_a, 'CONSERJE');
    EXCEPTION WHEN check_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 5a: permitió CONSERJE con vivienda_id'; END IF;

    -- 5b. Presidente sin vivienda_id (viola CHECK LPH art. 13.2)
    failed := FALSE;
    BEGIN
        INSERT INTO membresias_comunidad (usuario_id, comunidad_id, vivienda_id, rol)
        VALUES (u2, c_b, NULL, 'PRESIDENTE');
    EXCEPTION WHEN check_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 5b: permitió PRESIDENTE sin vivienda_id'; END IF;

    -- 6. Doble fila activa del mismo usuario en la misma vivienda (u1 ya es PRESIDENTE en v_a)
    failed := FALSE;
    BEGIN
        INSERT INTO membresias_comunidad (usuario_id, comunidad_id, vivienda_id, rol)
        VALUES (u1, c_a, v_a, 'PROPIETARIO');
    EXCEPTION WHEN unique_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 6: permitió doble membresía activa del mismo usuario en v_a'; END IF;

    -- 7. Dos copropietarios distintos votando sobre la misma vivienda en el mismo sondeo
    INSERT INTO sondeo_votos (sondeo_id, comunidad_id, vivienda_id, usuario_id, opcion, es_inquilino, coeficiente_snapshot)
    VALUES (s_a, c_a, v_a, u1, 'A_FAVOR', FALSE, 5.0000);

    failed := FALSE;
    BEGIN
        INSERT INTO sondeo_votos (sondeo_id, comunidad_id, vivienda_id, usuario_id, opcion, es_inquilino, coeficiente_snapshot)
        VALUES (s_a, c_a, v_a, u2, 'EN_CONTRA', FALSE, 5.0000);
    EXCEPTION WHEN unique_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 7: permitió 2 votos de copropietarios en la misma vivienda'; END IF;

    -- 8a. Dos traspasos activos simultáneos sobre la misma vivienda
    INSERT INTO traspasos_vivienda (comunidad_id, vivienda_id, vendedor_id, estado)
    VALUES (c_a, v_a, u1, 'SOLICITADO');

    failed := FALSE;
    BEGIN
        INSERT INTO traspasos_vivienda (comunidad_id, vivienda_id, vendedor_id, estado)
        VALUES (c_a, v_a, u1, 'CERTIFICADO');
    EXCEPTION WHEN unique_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 8a: permitió 2 traspasos activos simultáneos en v_a'; END IF;

    -- 8b. Suscripción con 2 titulares a la vez (gestoria_id + comunidad_id)
    failed := FALSE;
    BEGIN
        INSERT INTO suscripciones (via_ingreso, gestoria_id, comunidad_id, periodo_actual_fin)
        VALUES ('GESTORIA', g1, c_a, now() + interval '30 days');
    EXCEPTION WHEN check_violation THEN
        failed := TRUE;
    END;
    IF NOT failed THEN RAISE EXCEPTION 'FALLO 8b: permitió suscripción con doble titular'; END IF;

    RAISE NOTICE 'ALL SQL NEGATIVE CHECKS PASSED (32 tablas + 8 reglas blindadas)';
END
$$;

ROLLBACK;
