-- =====================================================================
-- Gestión de inventario informático · Esquema de la base de datos
-- =====================================================================
--
-- Qué es
--   Sistema web para el inventario del equipamiento informático de
--   una institución educativa: qué equipos hay, en qué estado están,
--   dónde están y a cargo de quién, y qué mantenimientos se les
--   hicieron. Este archivo crea todas las tablas (solo estructura;
--   los datos de ejemplo están en seed.sql).
--
-- Compatibilidad
--   MySQL 8.0.16+ o MariaDB 10.4+. El piso de MySQL lo marcan los
--   CHECK: versiones anteriores los aceptan pero no los hacen
--   cumplir. Probado en MariaDB 10.4 (la que trae XAMPP).
--
-- Cómo importarlo con phpMyAdmin
--   1. Crear una base vacía. En InfinityFree se crea desde el panel
--      de control; en XAMPP, desde phpMyAdmin con "Nueva".
--   2. Seleccionarla en el panel izquierdo de phpMyAdmin.
--   3. Pestaña "Importar" > elegir este archivo > formato "SQL" >
--      botón "Importar" (o "Continuar", según la versión).
--   Por consola:  mysql -u USUARIO -p NOMBRE_BASE < schema.sql
--
--   No trae CREATE DATABASE ni USE: se importa en la base que esté
--   seleccionada, se llame como se llame (en InfinityFree el nombre
--   lo pone el hosting).
--
--   Se puede reimportar las veces que haga falta: borra las tablas y
--   las crea de nuevo. Ojo: también borra los datos que tengan.
--
-- Orden de creación (cada tabla, después de las que referencia)
--   1. usuarios
--   2. sedes
--   3. ubicaciones     -> sedes
--   4. responsables
--   5. tipos_equipo
--   6. equipos         -> tipos_equipo, usuarios
--   7. asignaciones    -> equipos, ubicaciones, responsables,
--                         usuarios
--   8. mantenimientos  -> equipos, usuarios
--
-- Convenciones
--   - Nombres en español y snake_case; tablas en plural.
--   - PK: id INT UNSIGNED AUTO_INCREMENT en todas. Cada FK usa el
--     mismo tipo exacto que la PK a la que apunta.
--   - Constraints con nombre, para que los errores digan qué regla
--     se rompió:
--       fk_<tabla>_<campo>    clave foránea
--       uq_<tabla>_<campo>    UNIQUE
--       idx_<tabla>_<campo>   índice común
--       chk_<tabla>_<campo>   CHECK
--     La PK no lleva nombre: en MySQL siempre se llama PRIMARY.
--   - Toda FK tiene un índice declarado acá, propio o compartido
--     (un índice compuesto sirve si la FK es su primera columna).
--     Si faltara, InnoDB crearía uno por su cuenta.
--   - Booleanos: TINYINT(1) con un CHECK que solo admite 0 y 1.
--     BOOLEAN es un alias de TINYINT(1) y aceptaría cualquier
--     entero.
--   - Fechas sin hora en DATE. Marcas de tiempo en DATETIME y no
--     TIMESTAMP: sin límite en 2038 ni conversión de zona horaria.
--   - ENUM para listas cerradas de las que depende el código; tabla
--     catálogo para listas que crecen (ver tipos_equipo y
--     equipos.estado). Un valor fuera de la lista da error solo con
--     STRICT_TRANS_TABLES en el sql_mode; sin él (XAMPP lo trae
--     apagado) se guarda '' con un warning. Por eso la app valida
--     los valores antes de escribir.
--   - Sin triggers ni procedimientos almacenados: la lógica vive en
--     PHP. La base cuida la integridad de los datos.
--
-- Criterio de claves foráneas
--   ON DELETE RESTRICT  En las FK a equipos, ubicaciones,
--                       responsables y catálogos (sedes,
--                       tipos_equipo). No se borra nada que tenga
--                       historial: la baja es lógica (el equipo
--                       pasa a 'de_baja'; ubicaciones y
--                       responsables, a activo = 0). Si igual se
--                       intenta el DELETE, la base lo rechaza.
--   ON DELETE SET NULL  En creado_por y registrado_por, que son de
--                       auditoría. Borrar un usuario no tiene que
--                       bloquear ni arrastrar el inventario: el
--                       registro queda y solo se pierde quién lo
--                       cargó. Por eso esas columnas admiten NULL.
--                       Lo recomendado igual es desactivarlo.
--   ON UPDATE CASCADE   En todas. Los id son AUTO_INCREMENT y no
--                       cambian en el uso normal; si alguna vez se
--                       renumeran, las referencias acompañan.
--   No hay ningún ON DELETE CASCADE: borrar un equipo nunca debería
--   llevarse su historial sin avisar.
--   En InnoDB, RESTRICT y NO ACTION hacen lo mismo (se verifica en
--   el acto). Se escribe RESTRICT porque deja clara la intención.


-- =====================================================================
-- Preparación
-- =====================================================================
-- SET NAMES: el archivo está en UTF-8; así los acentos de los
-- COMMENT llegan bien sin importar cómo esté configurado el cliente.
-- FOREIGN_KEY_CHECKS = 0: deja borrar y recrear las tablas aunque la
-- base tenga una versión anterior del esquema con otras relaciones.
-- Vale solo para esta sesión y se vuelve a 1 al final.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Orden inverso al de creación: primero las tablas que referencian,
-- después las referenciadas.
DROP TABLE IF EXISTS mantenimientos;
DROP TABLE IF EXISTS asignaciones;
DROP TABLE IF EXISTS equipos;
DROP TABLE IF EXISTS tipos_equipo;
DROP TABLE IF EXISTS responsables;
DROP TABLE IF EXISTS ubicaciones;
DROP TABLE IF EXISTS sedes;
DROP TABLE IF EXISTS usuarios;


-- =====================================================================
-- 1. usuarios
-- =====================================================================
-- Cuentas que entran al sistema, con dos roles: admin (todo,
-- incluidos los usuarios y las eliminaciones) y operador (carga y
-- consulta).
--
-- - usuario: UNIQUE. Con la collation _ci (no distingue mayúsculas)
--   "Admin" y "admin" chocan, que es lo que se quiere en un login.
-- - password_hash: VARCHAR(255). password_hash() de PHP con
--   PASSWORD_DEFAULT hoy devuelve 60 caracteres (bcrypt), pero el
--   algoritmo puede cambiar y PHP recomienda dejar lugar hasta 255.
-- - rol: ENUM. Son dos valores fijos que el código chequea en cada
--   página.
-- - activo = 0 bloquea el login sin borrar la cuenta, que puede
--   figurar como autora de registros.

CREATE TABLE usuarios (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre            VARCHAR(100)  NOT NULL,
    usuario           VARCHAR(50)   NOT NULL,
    password_hash     VARCHAR(255)  NOT NULL,
    rol               ENUM('admin', 'operador')
                                    NOT NULL DEFAULT 'operador',
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    creado_en         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_usuarios_usuario (usuario),
    CONSTRAINT chk_usuarios_activo CHECK (activo IN (0, 1))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Cuentas de acceso al sistema (admin / operador)';


-- =====================================================================
-- 2. sedes
-- =====================================================================
-- Edificios de la institución. Primer nivel de la ubicación física:
-- sede > ubicación (aula, laboratorio, oficina...).
--
-- - nombre: UNIQUE, es lo que se muestra en listados y selects.
-- - Sin columna activo: una sede casi nunca se da de baja. Si no
--   tiene ubicaciones se puede borrar; si las tiene, el RESTRICT de
--   ubicaciones lo impide.

CREATE TABLE sedes (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre            VARCHAR(100)  NOT NULL,
    direccion         VARCHAR(255)  NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_sedes_nombre (nombre)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Sedes o edificios de la institución';


-- =====================================================================
-- 3. ubicaciones
-- =====================================================================
-- Lugares concretos, dentro de una sede, donde puede estar un equipo.
--
-- - UNIQUE (sede_id, nombre): "Aula 1" puede existir en dos sedes,
--   pero no dos veces en la misma. Como empieza por sede_id, también
--   es el índice de la FK; no hace falta otro.
-- - tipo: ENUM. Es una clasificación chica y estable, con 'otro'
--   para lo que no encaje; no justifica una tabla aparte.
-- - activo = 0 la saca de los selects de carga sin perder el
--   historial de asignaciones que la referencian.

CREATE TABLE ubicaciones (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    sede_id           INT UNSIGNED  NOT NULL,
    nombre            VARCHAR(100)  NOT NULL,
    tipo              ENUM('aula', 'laboratorio', 'oficina',
                           'deposito', 'otro')
                                    NOT NULL DEFAULT 'aula',
    activo            TINYINT(1)    NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_ubicaciones_sede_nombre (sede_id, nombre),
    CONSTRAINT chk_ubicaciones_activo CHECK (activo IN (0, 1)),
    CONSTRAINT fk_ubicaciones_sede
        FOREIGN KEY (sede_id) REFERENCES sedes (id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Aulas, laboratorios, oficinas y depósitos de cada sede';


-- =====================================================================
-- 4. responsables
-- =====================================================================
-- Personas a cargo de un equipo asignado (por ejemplo, docentes o
-- personal administrativo). No son usuarios del sistema: no tienen
-- login ni relación con la tabla usuarios.
--
-- - cargo, email y telefono son opcionales: no todos los tienen.
-- - email: 254 es el largo máximo de una dirección válida
--   (RFC 5321).
-- - telefono: texto y no número. Lleva +, guiones, espacios y ceros
--   adelante, y nunca se hacen cuentas con él.
-- - Índice (apellido, nombre): es el orden de listados y selects.
-- - activo = 0 para quien ya no está en la institución: deja de
--   ofrecerse para asignar, pero sigue en el historial.

CREATE TABLE responsables (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    apellido          VARCHAR(100)  NOT NULL,
    nombre            VARCHAR(100)  NOT NULL,
    cargo             VARCHAR(100)  NULL,
    email             VARCHAR(254)  NULL,
    telefono          VARCHAR(30)   NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    INDEX idx_responsables_apellido_nombre (apellido, nombre),
    CONSTRAINT chk_responsables_activo CHECK (activo IN (0, 1))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Personas a cargo de equipos (no son usuarios)';


-- =====================================================================
-- 5. tipos_equipo
-- =====================================================================
-- Catálogo de tipos de equipo (PC de escritorio, notebook,
-- impresora, proyector...).
--
-- Tabla y no ENUM, a propósito: la lista de tipos crece con el
-- tiempo (llega un equipo de un tipo nuevo y hay que poder
-- cargarlo). Con ENUM, sumar un tipo es un ALTER TABLE sobre
-- equipos: un cambio de estructura, con permisos de DDL y un
-- deploy. Con tabla es un INSERT y no se toca nada más.
-- Es el caso contrario a equipos.estado (ver tabla 6).
--
-- - nombre: UNIQUE. Con _ci evita "Notebook" y "notebook" a la vez.
-- - El RESTRICT de equipos impide borrar un tipo que esté en uso.

CREATE TABLE tipos_equipo (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre            VARCHAR(50)   NOT NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_tipos_equipo_nombre (nombre)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Catálogo de tipos de equipo';


-- =====================================================================
-- 6. equipos
-- =====================================================================
-- Tabla central: una fila por equipo físico.
--
-- - numero_serie: obligatorio y UNIQUE, identifica al equipo. Por la
--   collation _ci, "abc123" y "ABC123" cuentan como el mismo.
-- - codigo_inventario: UNIQUE pero opcional. Un UNIQUE admite
--   muchos NULL, así que los equipos sin código no chocan entre sí.
--   Por eso la app guarda NULL y nunca '': dos '' sí chocan.
-- - estado: ENUM, al revés que el tipo. Los estados son fijos y el
--   sistema depende de ellos (badges, filtros, totales del
--   dashboard). Un estado nuevo obliga a cambiar código, así que el
--   ALTER TABLE viaja junto con ese cambio. Ocupa 1 byte.
--   Ojo: ORDER BY estado ordena por la posición en la lista, no
--   alfabéticamente. La lista está en el orden en que se muestra.
-- - 'de_baja' es la baja lógica: el equipo y su historial quedan.
--   Un DELETE solo pasa si no tiene asignaciones ni mantenimientos
--   (los RESTRICT lo frenan), o sea, para corregir una carga
--   errónea.
-- - creado_por: auditoría. Queda NULL si se borra el usuario.
-- - Índices: estado y tipo_id, para filtros y totales del
--   dashboard (idx_equipos_tipo además sirve a la FK); (marca,
--   modelo), para filtrar y ordenar por marca y modelo. La búsqueda
--   libre con LIKE '%texto%' no usa índices; para el volumen de una
--   institución no hace falta más.

CREATE TABLE equipos (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    tipo_id           INT UNSIGNED  NOT NULL,
    marca             VARCHAR(100)  NOT NULL,
    modelo            VARCHAR(100)  NOT NULL,
    numero_serie      VARCHAR(100)  NOT NULL,
    codigo_inventario VARCHAR(50)   NULL,
    estado            ENUM('operativo', 'en_reparacion',
                           'en_deposito', 'de_baja')
                                    NOT NULL DEFAULT 'operativo',
    fecha_alta        DATE          NOT NULL,
    observaciones     TEXT          NULL,
    creado_por        INT UNSIGNED  NULL,
    creado_en         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_equipos_numero_serie (numero_serie),
    UNIQUE KEY uq_equipos_codigo_inventario (codigo_inventario),
    INDEX idx_equipos_estado (estado),
    INDEX idx_equipos_tipo (tipo_id),
    INDEX idx_equipos_marca_modelo (marca, modelo),
    INDEX idx_equipos_creado_por (creado_por),
    CONSTRAINT fk_equipos_tipo
        FOREIGN KEY (tipo_id) REFERENCES tipos_equipo (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_equipos_creado_por
        FOREIGN KEY (creado_por) REFERENCES usuarios (id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Equipos informáticos inventariados';


-- =====================================================================
-- 7. asignaciones
-- =====================================================================
-- Dónde está cada equipo y a cargo de quién, con historial. Cada fila
-- es un período, de fecha_desde a fecha_hasta. La vigente es la que
-- tiene fecha_hasta en NULL.
-- Mover un equipo = cerrar la vigente (fecha_hasta = hoy) e insertar
-- la nueva, en ese orden y en la misma transacción.
--
-- - responsable_id: opcional. Un equipo puede estar en un aula sin
--   nadie puntual a cargo. Es RESTRICT igual: no se borra una
--   persona que figure en el historial.
-- - chk_asignaciones_fechas: un período no puede terminar antes de
--   empezar. Es >= y no >, para poder cerrarlo el mismo día en que
--   se abrió.
-- - Lo que la base no controla: que los períodos cerrados de un
--   mismo equipo no se superpongan. Eso lo valida PHP.
--
-- Una sola asignación vigente por equipo
--   La regla es "a lo sumo una fila con fecha_hasta NULL por
--   equipo". Un UNIQUE (equipo_id, fecha_hasta) no alcanza: en un
--   UNIQUE dos NULL nunca son iguales entre sí, así que dejaría
--   pasar varias vigentes. Y MySQL no tiene índices parciales
--   (UNIQUE ... WHERE) como PostgreSQL.
--
--   El truco: la columna generada vigente vale 1 si la fila está
--   vigente y NULL si está cerrada. Con UNIQUE (equipo_id, vigente):
--     - dos filas (equipo 7, 1)    -> chocan: error 1062
--     - muchas filas (equipo 7, NULL) -> no chocan, porque los NULL
--       no se comparan; el historial cerrado crece sin límite.
--   Al cerrar una asignación (fecha_hasta = hoy), vigente pasa sola
--   a NULL y libera el lugar para la siguiente.
--
--   Es STORED: se calcula al escribir la fila y queda guardada
--   (1 byte), así que el UNIQUE es un índice común. Indexar
--   columnas VIRTUAL también se puede, pero con restricciones que
--   cambian entre MySQL y MariaDB. La calcula el motor; la app
--   nunca la escribe.
--   Como empieza por equipo_id, este UNIQUE es además el índice de
--   la FK equipo_id y el que encuentra la vigente de un equipo.

CREATE TABLE asignaciones (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    equipo_id         INT UNSIGNED  NOT NULL,
    ubicacion_id      INT UNSIGNED  NOT NULL,
    responsable_id    INT UNSIGNED  NULL,
    fecha_desde       DATE          NOT NULL,
    fecha_hasta       DATE          NULL,
    vigente           TINYINT(1)    GENERATED ALWAYS AS
                                    (IF(fecha_hasta IS NULL, 1, NULL))
                                    STORED
                                    COMMENT '1 vigente, NULL cerrada',
    observaciones     TEXT          NULL,
    registrado_por    INT UNSIGNED  NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_asignaciones_vigente (equipo_id, vigente),
    INDEX idx_asignaciones_ubicacion (ubicacion_id),
    INDEX idx_asignaciones_responsable (responsable_id),
    INDEX idx_asignaciones_registrado_por (registrado_por),
    CONSTRAINT chk_asignaciones_fechas
        CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde),
    CONSTRAINT fk_asignaciones_equipo
        FOREIGN KEY (equipo_id) REFERENCES equipos (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_asignaciones_ubicacion
        FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_asignaciones_responsable
        FOREIGN KEY (responsable_id) REFERENCES responsables (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_asignaciones_registrado_por
        FOREIGN KEY (registrado_por) REFERENCES usuarios (id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Historial de ubicación y responsable de cada equipo';


-- =====================================================================
-- 8. mantenimientos
-- =====================================================================
-- Historial de intervenciones técnicas sobre cada equipo.
--
-- - realizado_por: texto libre y no FK. Puede ser un técnico
--   externo o una empresa que no está en ninguna tabla; lo que
--   importa es dejar constancia de quién hizo el trabajo.
-- - registrado_por: el usuario que lo cargó en el sistema. Son dos
--   datos distintos: uno hace el trabajo y otro lo registra.
-- - Índice (equipo_id, fecha): el historial de un equipo filtra por
--   equipo y ordena por fecha, y el índice resuelve las dos cosas.
--   Como empieza por equipo_id, también sirve a la FK.

CREATE TABLE mantenimientos (
    id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    equipo_id         INT UNSIGNED  NOT NULL,
    fecha             DATE          NOT NULL,
    tipo              ENUM('preventivo', 'correctivo') NOT NULL,
    descripcion       TEXT          NOT NULL,
    realizado_por     VARCHAR(150)  NOT NULL,
    registrado_por    INT UNSIGNED  NULL,

    PRIMARY KEY (id),
    INDEX idx_mantenimientos_equipo_fecha (equipo_id, fecha),
    INDEX idx_mantenimientos_registrado_por (registrado_por),
    CONSTRAINT fk_mantenimientos_equipo
        FOREIGN KEY (equipo_id) REFERENCES equipos (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_mantenimientos_registrado_por
        FOREIGN KEY (registrado_por) REFERENCES usuarios (id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Mantenimientos preventivos y correctivos por equipo';


-- =====================================================================
-- Cierre
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- Consultas de referencia
-- =====================================================================
-- Ejemplos de uso del esquema. Están dentro de un comentario /* */,
-- así que no se ejecutan al importar. En la app van como sentencias
-- preparadas de PDO; los ? son los parámetros.

/*

-- 1. Totales por estado (tarjetas del dashboard).
--    ORDER BY estado sigue el orden del ENUM, no el alfabético.
SELECT estado, COUNT(*) AS total
FROM equipos
GROUP BY estado
ORDER BY estado;

-- 2. Totales por tipo. El LEFT JOIN incluye los tipos sin equipos
--    (total 0); COUNT(e.id) no cuenta las filas sin equipo.
SELECT t.nombre AS tipo, COUNT(e.id) AS total
FROM tipos_equipo AS t
LEFT JOIN equipos AS e ON e.tipo_id = t.id
GROUP BY t.id, t.nombre
ORDER BY total DESC, t.nombre;

-- 3. Equipos con su ubicación y responsable vigentes. Los LEFT JOIN
--    dejan en la lista a los equipos sin asignación (columnas en
--    NULL). a.vigente = 1 usa el índice uq_asignaciones_vigente.
SELECT e.numero_serie, t.nombre AS tipo, e.marca, e.modelo,
       e.estado, s.nombre AS sede, u.nombre AS ubicacion,
       CONCAT(r.apellido, ', ', r.nombre) AS responsable
FROM equipos AS e
JOIN tipos_equipo AS t ON t.id = e.tipo_id
LEFT JOIN asignaciones AS a
       ON a.equipo_id = e.id AND a.vigente = 1
LEFT JOIN ubicaciones AS u ON u.id = a.ubicacion_id
LEFT JOIN sedes AS s ON s.id = u.sede_id
LEFT JOIN responsables AS r ON r.id = a.responsable_id
ORDER BY t.nombre, e.marca, e.modelo;

-- 4. Historial de un equipo: asignaciones y mantenimientos en una
--    sola línea de tiempo, de lo más nuevo a lo más viejo.
SELECT 'asignacion' AS evento, a.fecha_desde AS fecha,
       CONCAT(s.nombre, ' / ', u.nombre) AS detalle
FROM asignaciones AS a
JOIN ubicaciones AS u ON u.id = a.ubicacion_id
JOIN sedes AS s ON s.id = u.sede_id
WHERE a.equipo_id = ?
UNION ALL
SELECT CONCAT('mantenimiento ', m.tipo), m.fecha, m.descripcion
FROM mantenimientos AS m
WHERE m.equipo_id = ?
ORDER BY fecha DESC;

*/
