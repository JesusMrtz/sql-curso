# Operadores, agrupadores y agregaciones en SQL.

## Operadores aritméticos
Los operadores aritméticos se calculan fila por fila

### Suma, resta y multiplicación con SQL
Para poder sumar atributos de una tabla en una nueva propiedad que existirá cuando se haga la operación, podemos usar:
```sql
SELECT id, subtotal, impuestos, gastos_envio, subtotal + impuestos + gastos_envio AS total
FROM bookify.pedidos;
```
> Creará una nueva propiedad llamada **total** que no existe explicitamente en la tabla de *pedidos*

Para la resta se usa identicamente como la *suma*, imaginemos que queremos reponer los libros de la estantería que se han vendido y nuestro stock máximo es de 20:
```sql
SELECT id, titulo, stock, (20 - stock) AS unidades_a_reponer
FROM bookify.libros
WHERE (20 - stock) > 0;
```
> NOTA: **NO se puede usar los alias como *unidades_a_reponer* en los WHERE**

Si nos piden calcular el importe bruto de los pedidos realizados, podemos usar la multiplicación:
```sql
SELECT pedido_id, libro_id, cantidad, precio_unitario, precio_unitario * cantidad AS importe_bruto_predido
FROM bookify.detalles_pedidos;
```


### División y módulo con SQL
Son operadores similares a la multiplicación:
```sql
SELECT pedido_id, libro_id, cantidad, precio_unitario, precio_unitario / cantidad AS importe_bruto_predido
FROM bookify.detalles_pedidos;
```

El módulo devuelve el resto de una división:
```sql
SELECT pedido_id, cantidad, cantidad % 2 AS sobrante_si_caja_12
FROM bookify.detalles_pedidos;
```

## Agregación con SQL: SUM, COUNT, AVG
A diferencia de los operadores aritméticos que hemos visto antes (que calculan fila por fila), las funciones de agregación reducen todas las filas a un único valor.

### COUNT
Si nos pide el total de pedidos realizados a partir de una fecha determinada, podemos usar el `COUNT` que nos dará una unica fila con el resultado:
```sql
SELECT COUNT(id) as total_pedidos
FROM bookify.detalles_pedidos
WHERE created_at > '2026-01-01';
```

### SUM
Si nos piden el número total de pedidos a partir una fecha determinada, podemos usar la función `SUM` que nos dará una única fila con el resultado:
```sql
SELECT SUM(cantidad) as total_libros_vendidos
FROM bookify.detalles_pedidos
WHERE created_at > '2026-01-01';
````

### AVG
con `AVG` nos permite calcular la media y podemos calcular el precio medio actual de todos nuestros libros:
```sql
SELECT AVG(precio) as media_venta
FROM bookify.libros;
```

### MIN y MAX
con `MIN` nos dará el valor minimos de una tabla de valores y el `MAX` nos devolverá el valor máximo de una tabla de valor, y nos puede ayudar para saber, por ejemplo, cual es el número minimo y maximo de páginas de un libro:
```sql
SELECT MIN(paginas) as paginas_minimas, MAX(paginas) AS paginas_maximas
FROM bookify.libros;
```
> Nos devuelve las páginas minimas y páginas maximas que contiene un libro

## Agrupación con SQL: GROUP BY
`GROUP BY` es un cláusula de SQL muy interesante que nos permite resolver problemas en los que queremos calcular agregaciones de ciertos subconjuntos dentro de nuestra tabla:
```sql
SELECT pedido_id, SUM(cantidad) AS unidades_totales_en_el_pedido
FROM bookify.detalles_pedidos
GROUP BY pedido_id;
```
> Nos permite sumar las cantidades totales agrupados por **pedidos_id**

## Filtrar valores agrupados con SQL: HAVING
HAVING sirve para filtrar grupos de resultados después de usar GROUP BY. La diferencia clave es que WHERE filtra filas individuales antes de agrupar, mientras que HAVING filtra los grupos ya creados con funciones de agregación como `COUNT`, `SUM`, `AVG`, etc. Por ejemplo, si nos solicita que nos muestre todas las categorias que tienen mas de 3 libros:
```sql
SELECT categoria_id, COUNT(categoria_id) AS total_categorias
FROM bookify.libros
GROUP BY categoria_id
HAVING COUNT(categoria_id) >= 3;
```

## Funciones complementarias

### ROUND
Redondea hacia arriba si pasa desde .5 los decimales y muestra el error númerico, por ejemplo:
* si un valor tiene 21.89 -> lo subirá a 22
* Si un valor tiene 21.03 -> Lo dejará a 21
```sql
SELECT pedido_id, libro_id, cantidad, precio_unitario, descuento,
ROUND((precio_unitario * cantidad) * (1 - descuento / 100.0)) AS precio_neto
FROM bookify.detalles_pedidos;
```

También podemos redondear nuestros decimales con el `ROUND`, por ejemplo:
```sql
SELECT pedido_id, libro_id, cantidad, precio_unitario, descuento,
ROUND((precio_unitario * cantidad) * (1 - descuento / 100.0), 2) AS precio_neto
FROM bookify.detalles_pedidos;
```
> Redondeamos el resultado `precio_neto` a dos decimales



### TRUNC
Trunca los decimales de los valores númericos, por ejemplo:
* si un valor tiene 21.89 -> lo matendrá  a 21
* Si un valor tiene 21.03 -> Lo matendrá a 21

```sql
SELECT pedido_id, libro_id, cantidad, precio_unitario, descuento,
TRUNC((precio_unitario * cantidad) * (1 - descuento / 100.0)) AS precio_neto
FROM bookify.detalles_pedidos;
```

También podemos truncar los decimales como el `ROUND`:
```sql
SELECT pedido_id, libro_id, cantidad, precio_unitario, descuento,
TRUNC((precio_unitario * cantidad) * (1 - descuento / 100.0), 2) AS precio_neto
FROM bookify.detalles_pedidos;
```

### CEIL
Redondea siempre hacia arriba  y nos dá un valor sin decimales, por ejemplo:

```sql
SELECT CEIL(COUNT(id) / 9.0) AS numero_cajas
FROM bookify.libros;
```
> Simulamos que vamos a guardar los libros en cajas en donde cada caja solo caben 9 libros, si nos dá un resultado de 11.01, entonces `CEIL` lo redondeará a 12

## FLOOR
Redondea siempre hacia abajo y nos dá un valor sin decimales, por ejemplo:

```sql
SELECT FLOOR(COUNT(id) / 9.0) AS numero_cajas
FROM bookify.libros;
```
> Simulamos que vamos a guardar los libros en cajas en donde cada caja solo caben 9 libros, si nos dá un resultado de 11.01, entonces `CEIL` lo redondeará a 11

## CASTING
El **casting** es forzar la conversión de un tipo de dato a otro, por ejemplo:
```sql
SELECT CAST(COUNT(id) AS NUMERIC) / 9 AS numero_cajas
FROM bookify.libros;
```
> Casteamos el resultado del contador a valor con punto decimal.

También podemos usar la nueva forma de usar el `casting`, por ejemplo:
```sql
SELECT COUNT(id)::NUMERIC / 9 AS numero_cajas
FROM bookify.libros;
```

## Exponentes y raices.

### Exponentes
```sql
SELECT id, titulo, stock, POWER((40 - stock), 3) AS score_reposicion
FROM bookify.libros
WHERE stock < 40
ORDER BY score_reposicion DESC;
```

### Raices
```sql
SELECT id, titulo, stock, SQRT(40 - stock) AS score_reposicion
FROM bookify.libros
WHERE stock < 40
ORDER BY score_reposicion DESC;
```

## Concatenación de texto con SQL
PAra concatenar textos en PostgreSQL, podemos usar:
```sql
SELECT titulo || ' (' || idioma || ')' AS libro_idioma
FROM bookify.libros;
```

Pero si queremos mantener la retrocompatibilidad con otros sistemas gestores de base de datos, usamos la función `CONCAT`, por ejemplo:
```sql
SELECT CONCAT(titulo,' (', idioma, ')') AS libro_idioma
FROM bookify.libros;
```

## Funciones de procesamiento de texto con SQL

### Poner en mayúsculas

```sql
SELECT UPPER(titulo) AS titulo, LENGTH(titulo) AS longitud
FROM bookify.libros;
```
> Con `UPPER` pasamos el título a mayúsculas

### Obtener la longitud

```sql
SELECT UPPER(titulo) AS titulo, LENGTH(titulo) AS longitud
FROM bookify.libros;
```
> Con `LENGTH()` podemos obtener la longitud del titulo

### Poner en minúsculas
```sql
SELECT LOWER(titulo) AS titulo, LENGTH(titulo) AS longitud
FROM bookify.libros;
```
> Con `LOWER` pasamos el título a minusculas

### Obtener los primeros 'N' caracteres
```sql
SELECT LEFT(titulo, 20) || '...' AS titulo, LENGTH(titulo) AS longitud, precio
FROM bookify.libros
WHERE LENGTH(titulo) > 20;
```
> Obtenemos los primeros 20 caracteres del título con la función `LEFT()` de la tabla de libros y despues le concatenamos los `...` pero solo a los libros que tengan el título con una longitud mayor a 20