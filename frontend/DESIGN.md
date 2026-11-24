# Vecinda · Diseño UI y Estructura de Pantallas (Wireframes)

> Documento de referencia visual antes de implementar `frontend/`. Define la identidad visual (evitando el *AI slop* genérico) y la estructura exacta en cajas (*boxes*) para los dos entornos de uso: **App Móvil Vecinal** y **Hub Escritorio de Gestoría**.

---

## 1. Principios visuales (Anti-*AI slop*)

- **Claridad editorial sobre adorno:** superficies blancas limpias (`#FFFFFF`) sobre fondo gris-verde muy suave (`#F4F6F5`), bordes nítidos de `1px solid #DCE5E3` en lugar de sombras pesadas o tarjetas flotantes exageradas.
- **Color con función:** verde editorial `#0F766E` para acciones principales y marca; verde/ámbar/rojo reservados estrictamente para estados reales (al corriente / pendiente / deuda o abierta / en curso / resuelta). Cero gradientes neón ni morados genéricos.
- **Tipografía y cifras:** sans limpia + **`font-variant-numeric: tabular-nums`** obligatorio en todos los importes, cuotas, deudas y recuentos de votos.
- **Densidad adaptada al rol:**
  - **Vecino (móvil):** tarjetas amplias, máximo 2–3 datos por fila, cero ruido técnico.
  - **Gestoría (escritorio):** tablas y paneles compactos para operar 20–80 comunidades sin hacer *scroll* infinito.

---

## 2. Vista Móvil · Comunidad (Propietario, Inquilino, Presidente, Conserje)

Pensada para resolverse en **< 1 minuto** desde el móvil (`max-width: 440px` centrado en escritorio).

### 2.1. Shell común de la App Vecinal
```text
+------------------------------------------+
|  🏘️ Vecinda · C/ Ejemplo 12    [Rol] [⎋] |  <- Header fijo (56px)
+------------------------------------------+
|                                          |
|   [ Área de contenido scrollable ]       |  <- Padding 14px, gap 12px
|   (Cajas / tarjetas de la pestaña)       |
|                                          |
+------------------------------------------+
|  Inicio | Cuentas | Avisos | Inc. | Votar|  <- Bottom Nav (5 items máx.)
+------------------------------------------+
```

### 2.2. Pantalla de Acceso (Onboarding rápido)
```text
+------------------------------------------+
|            🏘️ Vecinda                    |
|     Cuentas claras en tu comunidad       |
+------------------------------------------+
|  [ Propietario ] [ Inquilino ] [ Otros ] |  <- Selector de perfil
|                                          |
|  Nombre:          [___________________]  |
|  Vivienda / Cód.: [___________________]  |
|  [x] Acepto privacidad del Hub (RGPD)    |
|                                          |
|  [        Entrar a mi comunidad       ]  |  <- Botón primario full-width
+------------------------------------------+
```

### 2.3. Pestaña `Inicio` (varía según Rol)
```text
+------------------------------------------+
|  Hola, Ana (Propietario · 2ºC)           |
|  Saldo de la comunidad                   |
|  2.418,60 €                              |  <- Cifra grande tabular-nums
+------------------------------------------+
|  PENDIENTE                               |
|  • Votaciones sin tu voto          [ 1 ] |
|  • Incidencias abiertas            [ 2 ] |
|  • Último aviso: Corte de agua...        |
+------------------------------------------+
|  MI VIVIENDA · 2ºC                       |  <- Solo Propietario
|  Cuota mensual: 55 € · [ Al corriente ]  |
|  Inquilino: Ninguno    [ Invitar (cód) ] |
|  [ Solicitar venta / traspaso ]          |
+------------------------------------------+
```
*(Si el rol es **Conserje**, la caja de Saldo/Votaciones se oculta y prioriza **Incidencias abiertas** y **Publicar aviso**).*

### 2.4. Pestaña `Cuentas`
```text
+------------------------------------------+
|  RESUMEN DEL MES                         |
|  Saldo: 2.418,60 €                       |
|  + Ingresos: 1.980 €   - Gastos: 701,40 €|
+------------------------------------------+
|  [+ Añadir movimiento] (Solo Gestoría)   |
+------------------------------------------+
|  MOVIMIENTOS (Solo lectura vecinos)      |
|  Limpieza escaleras    01 nov   -420,00€ |
|  Ascensor · mant.      05 nov   -185,00€ |
|  Luz zonas comunes     10 nov    -96,40€ |
|  Cuotas noviembre      12 nov +1.980,00€ |
|  [ Cargar más (paginado de 20 en 20) ]   |
+------------------------------------------+
```

### 2.5. Pestaña `Incidencias` + Regla de Gremios
```text
+------------------------------------------+
|  REPORTAR AVERÍA                         |
|  [ Ej.: Gotera en el garaje...        ]  |
|  [ Enviar incidencia ]                   |
+------------------------------------------+
|  Luz del portal parpadea     [ Abierta ] |
|  Por 3ºB · 13 nov                        |
|  Proveedor habitual: Electricidad López  |  <- Gremio con contrato (0 €)
+------------------------------------------+
|  Puerta del garaje atascada  [En curso ] |
|  Por 1ºA · 09 nov                        |
|  [ Gremio libre: ver 3 presupuestos ]    |  <- Solo si no hay contrato
+------------------------------------------+
```

### 2.6. Pestaña `Votar`
```text
+------------------------------------------+
|  Cambiar luces del portal a LED          |
|  Presupuesto: 1.200 €. Ahorro: 25 €/mes  |
|  [██████████░░░░░] 74% Sí (14 / 5)       |
|  [ 👍 A favor ]   [ 👎 En contra ]       |  <- Bloqueado para Conserje
+------------------------------------------+
```

---

## 3. Vista Escritorio · Hub de Gestoría (~3 perfiles gestores)

Diseñada para pantalla ancha (`>= 1024px`) donde una gestoría administra múltiples comunidades desde un único espacio de trabajo.

### 3.1. Shell de Escritorio (Sidebar + Topbar + Workspace)
```text
+-------------------+---------------------------------------------------+
| 🏘️ Vecinda HUB    |  C/ Ejemplo 12 (40 viv.) · [ Presidente: Luis ]   |
| Gestoría López    |  [ Buscar comunidad... ]          [ + Nueva ] [⚙] |
+-------------------+---------------------------------------------------+
| MIS COMUNIDADES   |                                                   |
| > C/ Ejemplo 12   |  [Resumen] [Cuentas] [Traspasos] [Gremios] [Equipo]|
|   Av. América 45  |  -----------------------------------------------  |
|   Pza. Mayor 8    |                                                   |
|   C/ Velázquez 21 |   [ Área de trabajo de la comunidad activa ]      |
|                   |                                                   |
| ----------------- |                                                   |
| Plan: 4 fincas    |                                                   |
| Asientos: 3/3     |                                                   |
+-------------------+---------------------------------------------------+
```

### 3.2. Vista `Resumen de Cartera` (todas las fincas de la gestoría)
```text
+-----------------------------------------------------------------------+
|  CARTERA DE COMUNIDADES (4 activas · 3 perfiles gestores)             |
+-----------------------------------------------------------------------+
| Comunidad       | Viviendas | Saldo     | Incid. | Traspasos | Estado |
|-----------------|-----------|-----------|--------|-----------|--------|
| C/ Ejemplo 12   | 40        | 2.418,60€ | 2 ab.  | 1 solic.  | Activa |
| Av. América 45  | 64        | 5.110,00€ | 0 ab.  | 0         | Activa |
| Pza. Mayor 8    | 18        |   890,20€ | 1 ab.  | 0         | Activa |
+-----------------------------------------------------------------------+
```

### 3.3. Vista `Gremios y Contratos` (Exclusividad del Marketplace)
```text
+-----------------------------------------------------------------------+
|  GREMIOS DE C/ EJEMPLO 12                                             |
+-----------------------------------------------------------------------+
|  Gremio        | Estado en la finca  | Empresa / Regla                |
|----------------|---------------------|--------------------------------|
|  Fontanería    | 🔒 Con contrato     | Fontanería Pérez (0 €, sin ads)|
|  Ascensores    | 🔒 Con contrato     | Elevadores Sur (0 €, sin ads)  |
|  Carpintería   | 🟢 Gremio vacante   | Abierto a anunciantes locales  |
|  Pintura       | 🟢 Gremio vacante   | Abierto a anunciantes locales  |
+-----------------------------------------------------------------------+
```

---

## 4. Portal de Anunciantes (Negocios en gremios vacantes)

```text
+-----------------------------------------------------------------------+
|  VECINDA ANUNCIANTES · Tu visibilidad en gremios libres               |
+-----------------------------------------------------------------------+
|  Plan actual: 2 anuncios · Hasta 10 comunidades libres                |
+----------------------------------+------------------------------------+
|  GREMIOS DISPONIBLES             |  TUS ANUNCIOS ACTIVOS              |
|  [x] Carpintería (12 fincas lib.)|  1. Puertas y carpintería rápida   |
|  [ ] Fontanería (2 fincas lib.)  |     Comunidades: 8 asignadas       |
|  *(Ocultas fincas con contrato)* |  [ + Crear anuncio ]               |
+----------------------------------+------------------------------------+
```

---

## 5. Matriz rápida de visibilidad por Rol

| Caja / Módulo | Gestoría | Presidente | Conserje | Propietario | Inquilino | Anunciante |
|---|---|---|---|---|---|---|
| **Cartera multi-comunidad** | ✅ Editar | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Cuentas (lectura)** | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| **Cuentas (añadir/editar)** | ✅ | 🟡 Validar | ❌ | ❌ | ❌ | ❌ |
| **Avisos** | ✅ Crear | ✅ Crear | ✅ Crear | 👁️ Ver | 👁️ Ver | ❌ |
| **Incidencias (cambiar estado)** | ✅ | ✅ | ✅ | ➕ Reportar | ➕ Reportar | ❌ |
| **Votaciones** | ✅ Gestionar | ✅ Abrir/Votar | ❌ | ✅ Votar | 🟡 Consultiva | ❌ |
| **Traspasos y Certificados** | ✅ Emitir | ✅ Validar | ❌ | ✅ Solicitar | ❌ | ❌ |
| **Gremios contratados vs. libres** | ✅ Configurar | ✅ Ver/Editar | ❌ | 👁️ Ver | 👁️ Ver | 🎯 Solo libres |

