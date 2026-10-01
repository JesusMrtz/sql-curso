# Uniendo y consultado varias tablas con SQL

## Unir tablas con SQL: Join
Para recuperar información de varias tablas, aplicamos el `JOIN` sobre una tabla que tenga una clave foránea, por ejemplo:

```sql
SELECT libros.titulo, libros.precio, categorias.nombre as categorias
FROM bookify.libros
JOIN bookify.categorias ON libros.categoria_id = categorias.id
WHERE libros.precio < 20;
```

Examina cada fila de la tabla que aparece, en este ejemplo seria la tabla `libros`, va a ir recorriendo cada una de las filas de la tabla libros, va a buscar coincidencias en la segunda tabla según la condición que se haya puesto en el `ON` y solo recuperará aquellos libros que tengan un precio inferior a 20


## INNER JOIN
Se caracterizan porque solo devuelve filas que contengan coincidencias en ambas tablas y es el tipo mas común que vamos a estar utilizando en la gran mayoria de ocasiones, Sin embargo, tiene algunas sutilezas que convienen entender bien para no cometer errores graves.

## LEFT JOIN / LEFT OUTER JOIN
Se caracteriza porque devuelve todas las filas de la tabla de la izquierda y las coincidencias con la tabla de la derecha (la tabla principal).

Es muy útil cuando queremos conservar todos los registros de nuestra tabla principal aunque no tengan una relación con la tabla secundaria que estamos poniendo dentro de nuestra consulta

```sql
SELECT libros.titulo, libros.precio, categorias.nombre as categorias
FROM bookify.libros
LEFT JOIN bookify.categorias ON libros.categoria_id = categorias.id
ORDER BY libros.precio DESC;
```
> Recupera todas las filas que conciden entre las tablas relacionadas, ademas recupera toda las filas de la tabla `bookify.libros`

## RIGHT JOIN / RIGHT OUTER JOIN
Se caracteriza porque devuelve todas las filas de la tabla de la derecha (la tabla secundaria) y las coincidencias con la tabla de la izquierda (la tabla principal)

```sql
SELECT libros.titulo, libros.precio, categorias.nombre as categorias
FROM bookify.libros
RIGHT JOIN bookify.categorias ON libros.categoria_id = categorias.id
ORDER BY libros.precio DESC;

```
> Recupera todas las filas que conciden entre las tablas relacionadas, ademas recupera toda las filas de la tabla `bookify.categorias`.

> Veremos todas las categorias, incluso las que no tienen libros asignados

## FULL OUTER JOIN
Esto sería la conbinación entre un **INNER JOIN**, **LEFT JOIN** y **RIGHT JOIN** ya que el resultado serán todos los registros que que coinciden entre las tablas, además los registros de la tabla de la izquierda y los registros de la tabla de la derecha
```sql
SELECT libros.titulo, libros.precio, categorias.nombre as categorias
FROM bookify.libros
FULL OUTER JOIN bookify.categorias ON libros.categoria_id = categorias.id
ORDER BY libros.precio DESC;
```
> Recupera todos registros de la tabla libros y categorias, además, los registros que coinciden en ambas tablas.


## Unir mas de dos tablas en SQL
Vamos a suponer que queremos ver los detalles de los pedidos, incluyendo el nombre del cliente y los titulos de los libros que ha pedido dicho cliente.
```sql
SELECT p.numero_pedido, 
		c.nombre || ' ' || c.apellidos AS cliente, 
		p.fecha_pedido, 
		l.titulo, 
		dp.cantidad, 
		dp.precio_unitario, 
		dp.subtotal_linea
FROM bookify.pedidos AS p
JOIN bookify.clientes AS c ON p.cliente_id = c.id
JOIN bookify.detalles_pedidos AS dp ON p.id = dp.pedido_id
JOIN bookify.libros AS l ON dp.libro_id = l.id
ORDER BY p.numero_pedido, l.titulo;
```
Dentro de la tabla pedidos recuperamos:
* numero_pedido.
* fecha_pedido

Dentro de la tabla clientes recuperamos:
* nombre
* apellidos

Renombrando la concatenación como **cliente**

Dentro de la tabla de libros recuperamos:
* titulo

Dentro del la tabla detalles_pedido recuperamos:
* precio_unitario
* subtotal_linea

## Operaciones y agregaciones con JOIN
Aqui podemos usar las funciones de agrupación y los JOIN para recuperar información específica, por ejemplo:
Saber que categorias de libros han vendido mas:
```sql
SELECT 	c.nombre AS categoria, 
		COUNT(dp.id) as total_ventas, 
		SUM(dp.cantidad) AS unidades_vendidas,
		SUM(dp.subtotal_linea) AS ingresos_totales,
		ROUND(AVG(dp.precio_unitario), 2) AS precio_promedio
FROM bookify.categorias AS c
JOIN bookify.libros AS l ON l.categoria_id = c.id
JOIN bookify.detalles_pedidos AS dp ON dp.libro_id = l.id
GROUP BY c.nombre
ORDER BY ingresos_totales DESC;
```
> Recuperamos el nombre de la categoria, contamos el total de ventas, obtenemos las unidades vendidas, los ingresos totales y obtenemos un pomedio del precio_unitariio por categoria

## UNION: Operaciones de conjuntos con SQL
LA diferencia entre `JOIN` y `UNION`, es que `JOIN` conbina tablas horizontalmente, o sea que añade columnas y `UNION` añade filas verticalmente y las columnas se mantienen igual.

`UNION` las columnas debe corresponder a los tipos de datos compatibles, y los nombres de la columnas del resultado debe venir y por defecto `UNION` va a eliminar las filas duplicadas del resultado.

```sql
SELECT nombre, apellidos, 'Autor' as tipo
FROM bookify.autores
UNION
SELECT nombre, apellidos, 'Cliente' as tipo
FROM bookify.clientes
ORDER BY tipo, apellidos;
```
Recuperamos el nombre y apellidos de las tablas de `autores` y `clientes` y agregar un nuevo tipo para poder diferencialos entre clientes y autores.

Aunque `UNION` consume mas proceso de computo porque ordena y después elimina los registros duplicados y `UNION ALL` no los elimina y muestra datos repetitivos.

## INTERSECT y EXCEPT con SQL
Son operaciones sobre conjuntos, por ejemplo `INTERSECT` recupera aquellos registros que entrelazadas entre tablas, por ejemplo:
```sql
SELECT ciudad
FROM bookify.clientes
INTERSECT
SELECT ciudad_envio
FROM bookify.pedidos;
```
> Recuperamos la ciudad de los clientes donde se han realizado pedidos


el `EXCEPT` recupera aquellos registros que NO estan entrelazadas entre tablas, por ejemplo:
```sql
SELECT ciudad
FROM bookify.clientes
EXCEPT
SELECT ciudad_envio
FROM bookify.pedidos;
```
> Recuperamos las cuidades de los clientes donde no se han realizado pedidos.