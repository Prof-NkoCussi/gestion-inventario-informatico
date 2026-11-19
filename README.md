# gestion-inventario-informatico

Sistema web para llevar el inventario del equipamiento informático de
una institución: qué equipos hay, en qué estado están, dónde están y a
cargo de quién, y qué mantenimientos se les hicieron.

> **En desarrollo.** Por ahora está lista la base de datos. Las
> capturas, el GIF del flujo completo y el link a la versión publicada
> se suman cuando la aplicación esté terminada.

## Stack

PHP 8.1+ con PDO · JavaScript vanilla · MySQL 8 / MariaDB 10.4+ ·
Bootstrap 5.3 · Apache

Todo está hecho en PHP y JavaScript, sin frameworks:

- **PHP** arma cada página del lado del servidor y se ocupa de la
  lógica, la seguridad y el acceso a la base. Todo funciona aunque el
  JavaScript no cargue.
- **JavaScript vanilla** suma la interacción en el navegador: filtros y
  búsqueda en vivo con `fetch()`, selects que dependen de otros,
  validación de formularios y confirmaciones. PHP le pasa los datos
  escribiéndolos en el HTML (`data-*`, `json_encode()`).

Sin frameworks ni Composer, a propósito: el pliego del concurso pide
amplio manejo de PHP y JavaScript, no de un framework. Además, el
hosting de destino (InfinityFree) no da acceso a shell ni a Composer.

## Qué va a hacer

- Login con dos roles: admin (todo, incluidos usuarios y eliminaciones)
  y operador (carga, edición, consulta y export).
- ABM de equipos, ubicaciones (sedes, aulas, oficinas) y responsables.
- Asignación de cada equipo a una ubicación y a un responsable, con
  historial.
- Registro de mantenimientos, con historial por equipo.
- Listado con filtros (tipo, estado, ubicación) y búsqueda por marca,
  modelo o número de serie.
- Dashboard con totales por estado y por tipo.
- Export a CSV del listado filtrado.

## Base de datos

[`database/schema.sql`](database/schema.sql) tiene el esquema
completo, comentado tabla por tabla: claves foráneas con `ON DELETE` /
`ON UPDATE` explícitos, índices y constraints con nombre, y `CHECK`.
Entre otras cosas, la base garantiza que cada equipo tenga como mucho
una asignación vigente (un `UNIQUE` sobre una columna generada; el
archivo explica cómo funciona).

Requiere MySQL 8.0.16+ o MariaDB 10.4+. Se importa con phpMyAdmin en
una base vacía: pestaña **Importar** → elegir `schema.sql`.
