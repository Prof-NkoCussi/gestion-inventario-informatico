-- =====================================================================
-- Gestión de inventario informático · Datos de ejemplo
-- =====================================================================
--
-- Qué es
--   Datos ficticios para probar y mostrar el sistema. Nada de esto
--   es real: nombres, direcciones, números de serie y teléfonos
--   están inventados, y los correos usan example.com, un dominio
--   reservado para ejemplos (RFC 2606).
--
-- Cómo importarlo
--   Después de schema.sql y en la misma base, con phpMyAdmin
--   (pestaña "Importar") o por consola:
--     mysql -u USUARIO -p NOMBRE_BASE < seed.sql
--   Espera las tablas vacías, como las deja schema.sql. Para
--   empezar de cero se importan los dos de nuevo, en ese orden.
--
--   Va todo en una transacción: si algo falla, no queda nada a
--   medio cargar. No apaga FOREIGN_KEY_CHECKS: inserta en orden de
--   dependencias, así la base valida cada referencia.
--
-- Usuarios de demo
--   usuario    contraseña     rol
--   admin      admin1234      admin
--   operador   operador1234   operador
--   Las contraseñas están guardadas con password_hash() de PHP
--   (bcrypt), igual que las guarda la app. Son solo para la demo:
--   en una instalación real hay que cambiarlas o no importar este
--   archivo.
--
-- Qué casos cubre
--   - Equipos en los cuatro estados, para el dashboard.
--   - Historial de asignaciones: equipos que cambiaron de lugar,
--     dados de baja sin asignación vigente y uno recién llegado que
--     todavía no se asignó.
--   - Bajas lógicas: un usuario, una ubicación y un responsable con
--     activo = 0 que siguen apareciendo en el historial.
--   - Un tipo de equipo sin equipos (total 0 en el dashboard).
--   - "Aula 1" en las dos sedes (el UNIQUE es por sede).
--   - Mantenimientos hechos por un técnico externo y por personal
--     propio.
--
-- Los id van explícitos para poder seguir las referencias a simple
-- vista. AUTO_INCREMENT sigue después del id más alto, así que lo
-- que cargue la app no choca con estos datos.

SET NAMES utf8mb4;
START TRANSACTION;


-- =====================================================================
-- usuarios
-- =====================================================================
-- El 3 es un operador que ya no trabaja en el sistema: activo = 0
-- le bloquea el login, pero sigue figurando como quien cargó los
-- datos más viejos. Su contraseña es aleatoria y no se usa.

INSERT INTO usuarios (id, nombre, usuario, password_hash, rol, activo)
VALUES
    (1, 'Admin Demo', 'admin',
        '$2y$10$k0vTKV/6AjMIsySp1868Ven6O87C0MslklvaR/0PuWQ6w8soh5WBe',
        'admin', 1),
    (2, 'Operador Demo', 'operador',
        '$2y$10$oJZ.TOOq9.hh7leeCKUFrO62dFPDhS5lXR4z2epNtqosq0stH8ela',
        'operador', 1),
    (3, 'Operador Anterior', 'operador_anterior',
        '$2y$10$dEwaRrAsectrTziW8jHdW./ED8kzfnAZcqhHlBXFTCiRnGAe4LV3O',
        'operador', 0);


-- =====================================================================
-- sedes y ubicaciones
-- =====================================================================
-- La ubicación 10 (Aula 3) está fuera de uso (activo = 0): no se
-- ofrece para nuevas asignaciones, pero un proyector estuvo ahí y
-- queda en su historial.

INSERT INTO sedes (id, nombre, direccion)
VALUES
    (1, 'Sede Central', 'Av. Principal 1000'),
    (2, 'Anexo Norte',  'Calle Secundaria 250');

INSERT INTO ubicaciones (id, sede_id, nombre, tipo, activo)
VALUES
    ( 1, 1, 'Aula 1',                     'aula',        1),
    ( 2, 1, 'Aula 2',                     'aula',        1),
    ( 3, 1, 'Laboratorio de Informática', 'laboratorio', 1),
    ( 4, 1, 'Secretaría',                 'oficina',     1),
    ( 5, 1, 'Dirección',                  'oficina',     1),
    ( 6, 1, 'Depósito',                   'deposito',    1),
    ( 7, 2, 'Aula 1',                     'aula',        1),
    ( 8, 2, 'Biblioteca',                 'otro',        1),
    ( 9, 2, 'Preceptoría',                'oficina',     1),
    (10, 1, 'Aula 3',                     'aula',        0);


-- =====================================================================
-- responsables
-- =====================================================================
-- El 6 ya no está en la institución (activo = 0): tuvo una notebook
-- a cargo y sigue en ese historial. Cargo, email y teléfono son
-- opcionales; hay filas sin alguno de ellos.

INSERT INTO responsables
    (id, apellido, nombre, cargo, email, telefono, activo)
VALUES
    (1, 'Gómez', 'Laura', 'Directora',
        'lgomez@example.com', '2901 000-0001', 1),
    (2, 'Fernández', 'Martín', 'Secretario',
        'mfernandez@example.com', NULL, 1),
    (3, 'Sosa', 'Carolina', 'Docente de Informática',
        'csosa@example.com', '2901 000-0003', 1),
    (4, 'Ruiz', 'Diego', 'Preceptor',
        NULL, NULL, 1),
    (5, 'Herrera', 'Paula', 'Bibliotecaria',
        'pherrera@example.com', NULL, 1),
    (6, 'Acosta', 'Jorge', 'Docente',
        NULL, NULL, 0);


-- =====================================================================
-- tipos_equipo
-- =====================================================================
-- Tablet (8) no tiene equipos: sirve para ver un total en 0.

INSERT INTO tipos_equipo (id, nombre)
VALUES
    (1, 'PC de escritorio'),
    (2, 'Notebook'),
    (3, 'Monitor'),
    (4, 'Impresora'),
    (5, 'Proyector'),
    (6, 'Switch'),
    (7, 'Access point'),
    (8, 'Tablet');


-- =====================================================================
-- equipos
-- =====================================================================
-- 20 equipos: 14 operativos, 2 en reparación, 2 en depósito y 2 de
-- baja. codigo_inventario queda en NULL en los que no tienen
-- etiqueta. creado_por: lo cargado antes de abril de 2025 lo cargó
-- el operador anterior (3); lo demás, el operador actual (2).

INSERT INTO equipos
    (id, tipo_id, marca, modelo, numero_serie, codigo_inventario,
     estado, fecha_alta, observaciones, creado_por)
VALUES
    -- PC de escritorio
    ( 1, 1, 'Lenovo', 'ThinkCentre M70q', 'SN-LNV-0001', 'INV-0001',
      'operativo', '2025-03-10', NULL, 3),
    ( 2, 1, 'Lenovo', 'ThinkCentre M70q', 'SN-LNV-0002', 'INV-0002',
      'operativo', '2025-03-10', NULL, 3),
    ( 3, 1, 'Lenovo', 'ThinkCentre M70q', 'SN-LNV-0003', 'INV-0003',
      'en_reparacion', '2025-03-10',
      'En el servicio técnico desde el 05/11/2026.', 3),
    ( 4, 1, 'HP', 'ProDesk 400 G7', 'SN-HP-0004', 'INV-0004',
      'operativo', '2024-08-05', NULL, 3),
    ( 5, 1, 'HP', 'ProDesk 400 G7', 'SN-HP-0005', 'INV-0005',
      'operativo', '2024-08-05', NULL, 3),
    ( 6, 1, 'Dell', 'OptiPlex 3080', 'SN-DELL-0006', NULL,
      'de_baja', '2021-04-12',
      'Baja: placa madre dañada, no conviene repararla.', 3),

    -- Notebook
    ( 7, 2, 'Lenovo', 'IdeaPad 3', 'SN-LNV-0007', 'INV-0007',
      'operativo', '2025-06-02', NULL, 2),
    ( 8, 2, 'Lenovo', 'IdeaPad 3', 'SN-LNV-0008', 'INV-0008',
      'en_deposito', '2025-06-02', NULL, 2),
    ( 9, 2, 'HP', '250 G8', 'SN-HP-0009', NULL,
      'operativo', '2026-10-20', 'Recién llegada, falta asignarla.', 2),

    -- Monitor
    (10, 3, 'Samsung', 'S24R350', 'SN-SAM-0010', 'INV-0010',
      'operativo', '2025-03-10', NULL, 3),
    (11, 3, 'Samsung', 'S24R350', 'SN-SAM-0011', 'INV-0011',
      'operativo', '2025-03-10', NULL, 3),
    (12, 3, 'LG', '22MK400H', 'SN-LG-0012', NULL,
      'en_deposito', '2023-02-15', NULL, 3),

    -- Impresora
    (13, 4, 'HP', 'LaserJet Pro M404dn', 'SN-HP-0013', 'INV-0013',
      'operativo', '2024-08-05', NULL, 3),
    (14, 4, 'Epson', 'EcoTank L3250', 'SN-EPS-0014', 'INV-0014',
      'en_reparacion', '2025-05-20', NULL, 2),

    -- Proyector
    (15, 5, 'Epson', 'PowerLite E20', 'SN-EPS-0015', 'INV-0015',
      'operativo', '2025-04-01', NULL, 2),
    (16, 5, 'Epson', 'PowerLite E20', 'SN-EPS-0016', 'INV-0016',
      'operativo', '2025-04-01', NULL, 2),
    (17, 5, 'BenQ', 'MS560', 'SN-BNQ-0017', NULL,
      'de_baja', '2020-03-01',
      'Baja: reemplazado por el proyector 15.', 3),

    -- Switch y access points
    (18, 6, 'TP-Link', 'TL-SG1024', 'SN-TPL-0018', 'INV-0018',
      'operativo', '2024-02-10', NULL, 3),
    (19, 7, 'Ubiquiti', 'UniFi U6 Lite', 'SN-UBQ-0019', 'INV-0019',
      'operativo', '2025-09-15', NULL, 2),
    (20, 7, 'TP-Link', 'EAP225', 'SN-TPL-0020', 'INV-0020',
      'operativo', '2025-09-15', NULL, 2);


-- =====================================================================
-- asignaciones
-- =====================================================================
-- Ordenadas por equipo. Cuando un equipo se mueve, el período viejo
-- se cierra el mismo día en que empieza el nuevo, como lo hace la
-- app. Casos a mirar:
--   - Equipo 5: pasó de Secretaría a Dirección.
--   - Equipos 6 y 17: de baja, sin asignación vigente.
--   - Equipo 8: la tenía un docente que se fue (responsable 6) y
--     volvió al depósito.
--   - Equipo 9: recién llegado, sin ninguna asignación.
--   - Equipo 16: estaba en el Aula 3, hoy fuera de uso.

INSERT INTO asignaciones
    (id, equipo_id, ubicacion_id, responsable_id, fecha_desde,
     fecha_hasta, observaciones, registrado_por)
VALUES
    ( 1,  1,  3,    3, '2025-03-12', NULL,         NULL, 3),
    ( 2,  2,  3,    3, '2025-03-12', NULL,         NULL, 3),
    ( 3,  3,  3,    3, '2025-03-12', NULL,         NULL, 3),
    ( 4,  4,  4,    2, '2024-08-06', NULL,         NULL, 3),
    ( 5,  5,  4,    2, '2024-08-06', '2025-07-31',
      'Pasa a Dirección.', 3),
    ( 6,  5,  5,    1, '2025-07-31', NULL,         NULL, 2),
    ( 7,  6,  4, NULL, '2021-04-13', '2024-08-06',
      'Reemplazada por una PC nueva.', 3),
    ( 8,  6,  6, NULL, '2024-08-06', '2026-03-02',
      'Se cierra por la baja del equipo.', 2),
    ( 9,  7,  1,    3, '2025-06-03', NULL,         NULL, 2),
    (10,  8,  2,    6, '2025-06-03', '2026-07-10',
      'El docente deja la institución.', 2),
    (11,  8,  6, NULL, '2026-07-10', NULL,         NULL, 2),
    (12, 10,  3,    3, '2025-03-12', NULL,         NULL, 3),
    (13, 11,  3,    3, '2025-03-12', NULL,         NULL, 3),
    (14, 12,  4, NULL, '2023-02-16', '2025-03-12',
      'Reemplazado por un monitor nuevo.', 3),
    (15, 12,  6, NULL, '2025-03-12', NULL,         NULL, 3),
    (16, 13,  4,    2, '2024-08-06', NULL,         NULL, 3),
    (17, 14,  9,    4, '2025-05-21', NULL,         NULL, 2),
    (18, 15,  2, NULL, '2025-04-02', NULL,         NULL, 2),
    (19, 16, 10, NULL, '2025-04-02', '2026-02-27',
      'El aula se cierra por obra.', 2),
    (20, 16,  7, NULL, '2026-02-27', NULL,         NULL, 2),
    (21, 17,  2, NULL, '2020-03-02', '2025-04-02',
      'Reemplazado por el proyector 15.', 3),
    (22, 18,  3, NULL, '2024-02-12', NULL,         NULL, 3),
    (23, 19,  8,    5, '2025-09-16', NULL,         NULL, 2),
    (24, 20,  4,    2, '2025-09-16', NULL,         NULL, 2);


-- =====================================================================
-- mantenimientos
-- =====================================================================
-- Ordenados por fecha. realizado_por mezcla un servicio técnico
-- externo, el proveedor por garantía y el referente informático de
-- la institución. Los dos equipos en reparación (3 y 14) tienen un
-- correctivo reciente.

INSERT INTO mantenimientos
    (id, equipo_id, fecha, tipo, descripcion, realizado_por,
     registrado_por)
VALUES
    ( 1, 17, '2024-11-05', 'correctivo',
      'Lámpara quemada: se reemplaza.',
      'Servicio técnico externo', 3),
    ( 2,  4, '2025-02-18', 'preventivo',
      'Limpieza interna y cambio de pasta térmica.',
      'Referente informático', 3),
    ( 3, 13, '2025-11-12', 'correctivo',
      'Atasco de papel recurrente: se cambia el rodillo de arrastre.',
      'Proveedor (garantía)', 2),
    ( 4,  1, '2025-12-15', 'preventivo',
      'Limpieza interna y actualización del sistema operativo.',
      'Referente informático', 2),
    ( 5,  2, '2025-12-15', 'preventivo',
      'Limpieza interna y actualización del sistema operativo.',
      'Referente informático', 2),
    ( 6,  3, '2025-12-15', 'preventivo',
      'Limpieza interna y actualización del sistema operativo.',
      'Referente informático', 2),
    ( 7,  6, '2026-02-20', 'correctivo',
      'No enciende. Placa madre dañada; no conviene repararla.',
      'Servicio técnico externo', 2),
    ( 8, 15, '2026-06-01', 'preventivo',
      'Limpieza de filtro y lente.',
      'Referente informático', 2),
    ( 9,  3, '2026-11-05', 'correctivo',
      'No enciende. Se envía a revisar la fuente.',
      'Servicio técnico externo', 2),
    (10, 14, '2026-11-10', 'correctivo',
      'Mancha las hojas. Se pidió un cabezal de repuesto.',
      'Servicio técnico externo', 2);


COMMIT;
