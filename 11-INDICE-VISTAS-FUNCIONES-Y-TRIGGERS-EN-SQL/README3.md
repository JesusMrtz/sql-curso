# Lectura: Índices avanzados de PostgreSQL
Los índices son estructuras de datos que PostgreSQL mantiene de forma automática para acelerar las lecturas. Sin ellos, cada consulta con WHERE, JOIN u ORDER BY obliga al motor a recorrer la tabla completa (Sequential Scan), algo inviable en tablas grandes.

PostgreSQL ofrece seis tipos de índice nativos: B-tree, Hash, GIN, GiST, SP-GiST y BRIN. Ya hemos presentado los tres primeros en lecciones anteriores. Este artículo repasa su funcionamiento y luego profundiza en los tres restantes, siempre con ejemplos sobre nuestra base de datos Bookify.

## Índices estándar SQL vs. propios de PostgreSQL
El estándar SQL define CREATE INDEX pero no especifica qué estructura interna debe usar el motor. En la práctica, todos los SGBD implementan al menos el B-tree, que es el único índice verdaderamente "estándar" (lo encontrarás en MySQL, Oracle, SQL Server y PostgreSQL).

El Hash también existe en otros motores (MySQL lo ofrece para tablas MEMORY, Oracle tiene una variante limitada), pero su implementación varía mucho.

Los índices GIN, GiST, SP-GiST y BRIN son exclusivos de PostgreSQL y representan una de sus mayores ventajas frente a la competencia, especialmente para datos no triviales como texto libre, coordenadas geográficas, rangos o tablas masivas.

En resumen: B-tree es universal, Hash es común pero irregular, y los cuatro restantes son patrimonio exclusivo de PostgreSQL.

## Repaso de los índices ya presentados
### B-tree (Balanced Tree)
Cómo funciona: es un árbol balanceado donde todas las hojas están a la misma profundidad. Cada nodo contiene claves ordenadas y punteros a sus hijos. Para buscar un valor, PostgreSQL desciende desde la raíz comparando claves hasta llegar a la hoja correspondiente. Para rangos, localiza un extremo y recorre las hojas secuencialmente. Coste de búsqueda: O(log n).

Cuándo usarlo: es el índice por defecto y la elección correcta en la gran mayoría de casos. Soporta igualdad (=), rangos (<, >, BETWEEN), ordenación (ORDER BY) y agrupación (GROUP BY) sobre tipos escalares.

```sql
-- Índice B-tree sobre el precio (consultas de rango y ordenación)
CREATE INDEX idx_libros_precio ON libros (precio);
 
-- SELECT * FROM libros WHERE precio BETWEEN 10 AND 25;
-- SELECT * FROM libros ORDER BY precio DESC;
 
-- Índice B-tree sobre fecha de pedido (filtros temporales)
CREATE INDEX idx_pedidos_fecha ON pedidos (fecha_pedido);
 
-- SELECT * FROM pedidos WHERE fecha_pedido >= '2024-01-01';
```


💡 Regla: si no estás seguro de qué índice usar, B-tree es casi siempre la respuesta correcta.



### Hash
Cómo funciona: aplica una función de hash al valor de la columna para obtener un código numérico que determina en qué bucket se almacena el puntero a la fila. La búsqueda es O(1) — tiempo constante. Sin embargo, el hash destruye la información de orden, por lo que solo sirve para igualdad exacta (=).

Cuándo usarlo: en columnas donde exclusivamente buscamos por igualdad y nunca necesitamos rangos, ordenación ni LIKE. Desde PostgreSQL 10 es seguro ante caídas, pero su ventaja sobre B-tree sigue siendo marginal.

```sql
-- Hash sobre ISBN (siempre se busca por igualdad exacta)
CREATE INDEX idx_libros_isbn_hash ON libros USING hash (isbn);
 
-- SELECT * FROM libros WHERE isbn = '9788408258759';
 
-- Hash sobre email de clientes
CREATE INDEX idx_clientes_email_hash ON clientes USING hash (email);
 
-- SELECT * FROM clientes WHERE email = 'maria@ejemplo.com';
```


⚠️ Limitación: no soporta rangos, ORDER BY ni LIKE. Si necesitas cualquiera de ellos, usa B-tree.



### GIN (Generalized Inverted Index)
Cómo funciona: es un índice invertido. En lugar de mapear "fila → valor", invierte la relación: "valor → lista de filas que lo contienen". Internamente tiene un B-tree de claves individuales (lexemas, elementos de array, claves JSON) donde cada clave apunta a una lista de TIDs.

Cuándo usarlo: para buscar dentro de valores compuestos: full-text search (tsvector/tsquery), operaciones sobre arrays (@>, &&), búsqueda en JSONB (@>, ?, ?|), y trigramas (pg_trgm).

```sql
-- Full-text search en títulos de libros
ALTER TABLE libros ADD COLUMN titulo_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('spanish', titulo)) STORED;
 
CREATE INDEX idx_libros_titulo_gin ON libros USING gin (titulo_tsv);
 
-- SELECT * FROM libros WHERE titulo_tsv @@ to_tsquery('spanish', 'sombra & viento');
```


💡 Regla: si necesitas buscar dentro de arrays, JSONB o texto completo, GIN es tu índice.



## GiST (Generalized Search Tree)
Cómo funciona
GiST es un árbol de búsqueda balanceado que trabaja con regiones contenedoras. Cada nodo interno define una región que "envuelve" todos los datos de sus hijos. Al buscar, PostgreSQL desciende podando las ramas cuyas regiones no intersectan con el criterio de búsqueda.

La diferencia clave con B-tree es que GiST no ordena los datos linealmente, sino que organiza espacios que pueden solaparse. Esto lo hace ideal para datos donde la noción de "contención" o "proximidad" importa más que el orden.

Cuándo usarlo
GiST es la elección correcta para datos geoespaciales (puntos, cajas, polígonos), rangos nativos de PostgreSQL (daterange, int4range), búsqueda de vecinos más cercanos (KNN con el operador <->), y búsquedas difusas con trigramas cuando las escrituras son frecuentes.

Ejemplos con Bookify
Búsqueda por proximidad geográfica. Imaginemos que añadimos la ubicación de los clientes:

```sql
ALTER TABLE clientes ADD COLUMN ubicacion point;
 
CREATE INDEX idx_clientes_ubicacion_gist
  ON clientes USING gist (ubicacion);
 
-- Los 5 clientes más cercanos a Madrid centro
SELECT nombre, apellidos
FROM clientes
ORDER BY ubicacion <-> point '(40.4168, -3.7038)'
LIMIT 5;
```


Búsqueda por solapamiento de rangos de fechas. Si tenemos una tabla de promociones con período de vigencia:

```sql
CREATE TABLE promociones (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descuento DECIMAL(5,2),
    vigencia daterange NOT NULL
);
 
CREATE INDEX idx_promociones_vigencia_gist
  ON promociones USING gist (vigencia);
 
-- Promociones activas hoy
SELECT * FROM promociones
WHERE vigencia @> CURRENT_DATE;
 
-- Promociones que se solapan con la próxima semana
SELECT * FROM promociones
WHERE vigencia && daterange('2024-12-16', '2024-12-22');
```


Búsqueda difusa con trigramas. Combinando GiST con pg_trgm para tolerar errores ortográficos en nombres de autores:

```sqñ
CREATE EXTENSION IF NOT EXISTS pg_trgm;
 
CREATE INDEX idx_autores_nombre_trgm
  ON autores USING gist (nombre gist_trgm_ops);
 
-- Buscar "Garsia" (error ortográfico) y encontrar "García"
SELECT nombre, apellidos, similarity(nombre, 'Garsia') AS sim
FROM autores
WHERE nombre % 'Garsia'
ORDER BY sim DESC;
```


GiST vs. GIN
Es habitual dudar entre ambos, especialmente para full-text y trigramas. La diferencia principal: GIN es más rápido leyendo (acceso directo por clave) pero más lento escribiendo (actualizar la lista invertida es costoso). GiST es más rápido escribiendo pero más lento en consultas exactas, y además es el único que soporta búsquedas KNN (<->).

💡 Regla: si necesitas KNN, geodatos o rangos, usa GiST. Si necesitas búsquedas de contención en arrays, JSONB o full-text con muchas lecturas, usa GIN.


## SP-GiST (Space-Partitioned Generalized Search Tree)
### Cómo funciona
SP-GiST es una variante de GiST que particiona el espacio en regiones disjuntas (que no se superponen). Mientras que en GiST las regiones de los nodos pueden solaparse, en SP-GiST cada punto del espacio pertenece a exactamente un nodo. Esto se consigue con estructuras como Quadtrees (dividen el plano en 4 cuadrantes), k-d trees (alternan divisiones por eje) y Radix trees (dividen cadenas de texto por prefijo común).

**La ventaja**: al no haber solapamiento, las búsquedas puntuales solo necesitan explorar una rama del árbol. La desventaja: si los datos están muy concentrados en una zona, el árbol se desbalancea y pierde eficiencia.

### Cuándo usarlo
SP-GiST brilla en dos escenarios concretos: búsquedas por prefijo sobre texto (autocompletado, filtrado jerárquico) y búsquedas geoespaciales sobre datos distribuidos uniformemente.

Ejemplos con Bookify

Autocompletado de títulos. SP-GiST con Radix tree es muy eficiente para LIKE 'prefijo%' y el operador ^@:

```sql
CREATE INDEX idx_libros_titulo_spgist
  ON libros USING spgist (titulo);
 
-- Libros cuyo título empieza por "El"
SELECT titulo FROM libros
WHERE titulo ^@ 'El'
ORDER BY titulo
LIMIT 10;
 
-- Equivalente con LIKE
SELECT titulo FROM libros
WHERE titulo LIKE 'El%';
```


Filtrado por código postal. Los códigos postales españoles son jerárquicos (los dos primeros dígitos indican la provincia), lo que encaja perfectamente con un Radix tree:

```sql
CREATE INDEX idx_clientes_cp_spgist
  ON clientes USING spgist (codigo_postal);
 
-- Todos los clientes de Madrid (CP empieza por '28')
SELECT nombre, apellidos, codigo_postal
FROM clientes
WHERE codigo_postal ^@ '28';
 
-- Clientes de Barcelona (CP empieza por '08')
SELECT nombre, apellidos, codigo_postal
FROM clientes
WHERE codigo_postal ^@ '08';
```


GiST vs. SP-GiST
GiST es más versátil y maduro: soporta KNN nativo, maneja bien datos desbalanceados y tiene más extensiones. SP-GiST es más eficiente en búsquedas por prefijo sobre texto y en datos espaciales bien distribuidos, pero no soporta KNN de forma madura y puede degradarse con datos asimétricos.

💡 Regla: si tu consulta principal es LIKE 'algo%' o ^@ sobre texto, SP-GiST es la mejor opción. Para geodatos generales y KNN, quédate con GiST.



## BRIN (Block Range Index)
### Cómo funciona

BRIN es fundamentalmente diferente a los demás índices. En lugar de indexar cada fila, divide la tabla en bloques de páginas contiguas (por defecto 128 páginas, ~1 MB) y almacena solo el valor mínimo y máximo de la columna indexada dentro de cada bloque.

Cuando ejecutas una consulta, PostgreSQL consulta el BRIN para descartar bloques enteros que no pueden contener resultados. Los bloques que podrían contener coincidencias se escanean completos. Es un filtro grosero pero extraordinariamente compacto.

### El requisito fundamental: correlación física
La eficacia de BRIN depende de que los datos estén físicamente ordenados en disco por la columna indexada. Si los datos están ordenados, cada bloque tiene un rango estrecho de valores y BRIN descarta la mayoría. Si están desordenados, los rangos se solapan y BRIN no puede descartar nada.

Puedes verificar la correlación con:

```sql
SELECT attname, correlation
FROM pg_stats
WHERE schemaname = 'bookify'
  AND tablename = 'pedidos'
  AND attname = 'fecha_pedido';
 
-- Cercana a 1.0 o -1.0 → BRIN será eficaz
-- Cercana a 0.0 → BRIN será inútil, usa B-tree
```


Cuándo usarlo
BRIN es ideal para tablas muy grandes (millones de filas) donde la columna indexada tiene alta correlación con el orden de inserción: fechas de creación, IDs secuenciales, timestamps. El caso típico son tablas de tipo log, series temporales o transacciones históricas.

Ejemplos con Bookify
Pedidos por fecha. Los pedidos se insertan cronológicamente, así que fecha_pedido tiene correlación natural casi perfecta:

```sql
CREATE INDEX idx_pedidos_fecha_brin
  ON pedidos USING brin (fecha_pedido);
 
-- Pedidos del último mes (BRIN descarta todos los bloques anteriores)
SELECT * FROM pedidos
WHERE fecha_pedido >= CURRENT_DATE - INTERVAL '1 month';
 
-- Pedidos de un año concreto
SELECT COUNT(*), SUM(total)
FROM pedidos
WHERE fecha_pedido BETWEEN '2024-01-01' AND '2024-12-31';
```


Detalles de pedido por pedido_id. Las líneas de detalle también se insertan en orden de pedido_id:

```sql
CREATE INDEX idx_detalles_pedido_brin
  ON detalles_pedido USING brin (pedido_id);
 
-- Detalles de los pedidos más recientes
SELECT dp.*, l.titulo
FROM detalles_pedido dp
JOIN libros l ON l.id = dp.libro_id
WHERE dp.pedido_id > 100000;
```


## BRIN vs. B-tree

La ventaja más espectacular de BRIN es su tamaño. Para una tabla de 10 millones de filas, un B-tree puede ocupar cientos de megabytes mientras que un BRIN equivalente ocupa decenas de kilobytes. A cambio, BRIN es menos preciso (descarta bloques, no localiza filas) y requiere correlación física.

💡 Regla: usa BRIN en tablas masivas con datos ordenados cronológicamente. Si la tabla es pequeña (< 1M filas) o los datos no están ordenados, B-tree será siempre mejor.

⚠️ Atención: si actualizas o borras filas frecuentemente de forma desordenada, la correlación se degradará. Ejecutar CLUSTER periódicamente puede restaurar el orden, pero es una operación pesada que bloquea la tabla.



## Guía de decisión rápida
Ante la duda, sigue este flujo:

1. ¿Columna escalar con igualdad, rangos u ORDER BY? → B-tree

2. ¿Solo igualdad exacta, nunca rangos ni orden? → Hash (aunque B-tree también sirve)

3. ¿Buscar dentro de valores compuestos (full-text, JSONB, arrays)? → GIN

4. ¿Datos geoespaciales, rangos nativos o vecinos más cercanos (KNN)? → GiST

5. ¿Autocompletado por prefijo o particionamiento jerárquico de texto? → SP-GiST

6. ¿Tabla masiva con columna físicamente ordenada (fecha, ID secuencial)? → BRIN



## Sintaxis común
```sql
-- Sintaxis general
CREATE INDEX [nombre]
  ON [esquema.]tabla
  USING [btree | hash | gin | gist | spgist | brin]
  (columna [clase_operadores])
  [WITH (parametro = valor)]
  [WHERE condicion];  -- índice parcial
 
-- Si omites USING, PostgreSQL usa btree por defecto
CREATE INDEX idx_ejemplo ON tabla (columna);
 
-- Índice parcial: solo indexa filas que cumplen la condición
CREATE INDEX idx_pedidos_pendientes
  ON pedidos (fecha_pedido)
  WHERE estado = 'pendiente';
 
-- Índice sobre expresión
CREATE INDEX idx_clientes_email_lower
  ON clientes (LOWER(email));
```


💡 Consejo final: no indexes todo. Cada índice consume espacio y ralentiza las escrituras (INSERT, UPDATE, DELETE). Crea índices solo sobre columnas frecuentes en WHERE, JOIN y ORDER BY, y usa EXPLAIN ANALYZE para verificar que PostgreSQL realmente los utiliza.