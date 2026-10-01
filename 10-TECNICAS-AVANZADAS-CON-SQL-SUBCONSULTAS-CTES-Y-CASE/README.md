# Técnicas avanzadas de SQL: Subconsultas, CTEs y CASE
## Subconsultas con SQL.
Las subconsultas es anidar una consulta dentro de otra

**Ejemplo**

Vamos a obtener todos los libros de nuestra base de datos que pertence a la categoría de "Ficción Literaria":
```sql
SELECT l.titulo
FROM bookify.libros AS l
JOIN bookify.categorias AS c ON l.categoria_id = c.id
WHERE c.nombre = 'Ficción Literaria';
```
> Resolviendo el problema con un INNER JOIN

```sql
SELECT titulo
FROM bookify.libros
WHERE categoria_id = ( SELECT id
					   FROM bookify.categorias
						WHERE nombre = 'Ficción Literaria');
```
> Resolvimos el problema con una subconsulta

### ¿para qué existen las subconsultas?
Una subconsulta tienen sentido cuando el problema se resuelve con un `JOIN` muy complejo como por, ejemplo, agregamos un WHERE dentro del JOIN, o la consulta del `JOIN` es muy poco legible.

**Ejemplo**
Obtener todos los libros de nuestra base de datos cuyo precio está por encima del precio promedio.
```sql
SELECT titulo, precio
FROM bookify.libros
WHERE precio > (
	SELECT AVG(precio) 
	FROM bookify.libros
)
ORDER BY precio DESC;
```
> Se hace una subconsulta podría haber una agregación dentro del `JOIN`

## Tablas derivadas en SQL: subconsultas en el FROM
En este ejemplo vamos a recuperar el nombre, apellido y el último pedido realizado por el cliente junto con el total de dicho pedido:
```sql
SELECT c.nombre, c.apellidos, ultimos.fecha_pedido, ultimos.total
FROM (
	SELECT cliente_id, fecha_pedido, total
	FROM bookify.pedidos
	WHERE fecha_pedido = (
		SELECT MAX(fecha_pedido)
		FROM bookify.pedidos AS p2
		WHERE p2.cliente_id = bookify.pedidos.cliente_id
	)
) AS ultimos
JOIN bookify.clientes AS c ON ultimos.cliente_id = c.id;
```
> Generamos una tabla temporal llamada `ultimo` donde recuperamos el cliente_id, fecha_pedido y total de la tabla `pedidos` donde la *fecha_pedido* sea el mayoro de cada cliente

**También se puede hacer asi**:
```sql
SELECT c.nombre || ' ' || c.apellidos AS nombre_cliente, p.fecha_pedido, p.total
FROM bookify.clientes AS c
JOIN bookify.pedidos AS p ON p.cliente_id = c.id
WHERE p.fecha_pedido = (
		SELECT MAX(fecha_pedido)
		FROM bookify.pedidos AS p2
		WHERE p2.cliente_id = c.id
);
```

**Otro Ejemplo**

Queremos determinar que categorias tienen mas ventas por libro disponible y necesitamos conocer el número de ventas por categoria y el número de libros en cada categoria
```sql
SELECT categorias.nombre_categoria,
	   categorias.total_libros,
	   ventas.total_vendidos,
	   ROUND(ventas.total_vendidos::NUMERIC / categorias.total_libros, 2) AS ratio_ventas_por_libro
FROM (
	-- Subconsulta 1: Contar libros por categorías
	SELECT c.nombre AS nombre_categoria,
	 	   c.id AS categoria_id,
			COUNT (*) as total_libros
	FROM bookify.categorias AS c
	JOIN bookify.libros AS l ON l.categoria_id = c.id
	GROUP BY c.id, c.nombre
) AS categorias
JOIN (
	-- Subconsulta 2: Contar ventas por categoria
	SELECT l.categoria_id,
		   SUM(dp.cantidad) AS total_vendidos
	FROM bookify.detalles_pedidos AS dp
	JOIN bookify.libros AS l ON dp.libro_id = l.id
	GROUP BY l.categoria_id
) AS ventas
ON categorias.categoria_id = ventas.categoria_id
ORDER BY ratio_ventas_por_libro DESC;
```
> Se pueden realizar consultas `JOIN` con tablas derivadas (tablas temporales)

## Columnas derivadas en SQL: Subconsultas en el SELECT.
También podemos generar nuevas columnas de datos con subconsultas colocando una subconsulta en la lista despues del `SELECT`, por ejemplo:

> Queremos mostrar en una tabla el titulo, su precio, el promedio del valor de lo que vale y la diferencia entre el valor del libro y su promedio.

```sql
SELECT titulo, precio,
		ROUND((SELECT AVG(precio) FROM bookify.libros), 2) AS precio_promedio,
		ROUND(precio - (SELECT AVG(precio) FROM bookify.libros), 2) AS diferencia_del_promedio
FROM bookify.libros
ORDER BY diferencia_del_promedio DESC;
```

## Expresiones de subconsultas: IN y EXISTS
También podemos utilizar subconsultas para filtrar filas evaluando si una condición es verdadera o falsa. 

```sql
SELECT nombre, apellidos
FROM bookify.autores
WHERE id IN (
	SELECT autor_id
	FROM bookify.libros_autores
);
```
> Obtenemos a los autores que han publicado al menos un libro.

`EXISTS` es otro tipo de subconsulta que devuelve **true**
```sql
SELECT nombre, apellidos, email
FROM bookify.clientes AS c
WHERE EXISTS (
	SELECT 1
	FROM bookify.pedidos AS p
	WHERE p.cliente_id = c.id
)
```
> Devuelve los clientes que han realizado al menos un pedido

## Comond Table Expressions (CTEs)
Nos permiten crear tablas temporales mediante el uso de subconsulta que luego podemos utilizar tantas veces que necesitemso en la consulta principal, y se usa con la cláusula `WITH`

```sql
-- Tabla temporal para usarlo en la consulta principal
WITH libros_caros (titulo, categoria_id, precio) AS (
	SELECT titulo, categoria_id, precio
	FROM bookify.libros
	WHERE precio > 20
)

SELECT c.nombre AS categoria, COUNT(*) AS cantidad_libros_caros
FROM libros_caros AS lc
JOIN bookify.categorias AS c ON lc.categoria_id = c.id
GROUP BY c.nombre
ORDER BY cantidad_libros_caros DESC;
```
> Determinar cuantos libros por categoría tienen un precio superior a 20

**Otro ejemplo**

```sql
WITH
	-- CTE 1: Libros por categoría
	libros_categoria (categoria_id, nombre_categoria, total_libros) AS (
		SELECT c.id, c.nombre, COUNT(*)
		FROM bookify.categorias AS c
		JOIN bookify.libros AS l ON c.id = l.categoria_id
		GROUP BY c.id, c.nombre
	),

	-- CTE 2: Ventas por categoría
	ventas_categoria (categoria_id, total_vendidos) AS (
		SELECT l.categoria_id, SUM(dp.cantidad)
		FROM bookify.detalles_pedidos AS dp
		JOIN bookify.libros AS l ON dp.libro_id = l.id
		GROUP BY l.categoria_id
	)

SELECT lc.nombre_categoria, lc.total_libros, vc.total_vendidos,
		ROUND(vc.total_vendidos::numeric / lc.total_libros, 2) AS ratio_ventas
FROM libros_categoria AS lc
JOIN ventas_categoria AS vc ON lc.categoria_id = vc.categoria_id
ORDER BY ratio_ventas DESC;
```

## Expresiones condicionales con SQL: CASE
`CASE` nos permite agregar lógica y lo habitual es utilizarlo para reclasificar valores en diferentes categorias

```sql
SELECT titulo, precio,
		CASE 
			WHEN precio >= 50 THEN 'Premium'
			WHEN precio >= 30  THEN 'Alto'
			WHEN precio >= 15 THEN 'Medio'
			WHEN precio >= 5 THEN 'Económico'
			ELSE 'Oferta'
		END AS categoria_precio
FROM bookify.libros
ORDER BY precio DESC;
```
> Vamos a clasificar los libros por rango de precio


**Otro Ejemplo**
```sql
WITH pedidos_clasificados (ciudad, estado_grupo) AS (
	SELECT ciudad_envio,
	CASE
		WHEN estado IN ('entregado') THEN 'Completado'
		WHEN estado IN ('enviado', 'procesado') THEN 'En proceso'
		WHEN estado IN ('pendiente', 'confirmado') THEN 'Pendiente'
		WHEN estado = 'cancelado' THEN 'cancelado'
		ELSE 'Desconocido'
		END
	FROM bookify.pedidos
)

SELECT ciudad, estado_grupo, COUNT(*) AS cantidad
FROM pedidos_clasificados
GROUP BY ciudad, estado_grupo
ORDER BY ciudad, cantidad DESC;
```
> Verificamos la cantidad de entrega por ciudad y el estado actual que tiene.
