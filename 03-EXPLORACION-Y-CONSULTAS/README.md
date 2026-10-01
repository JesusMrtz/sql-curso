## Consultar valores

### Consultar valores distintos
Para que no se repitan los valores al momento de recuperarlos podemos usar el comando `DISCTINCT`, por ejemplo:
```sql
SELECT DISTINCT rating
FROM film;
```
> Recuperará los valores de la propiedad  *rating* sin repetirlos.

otro ejemplo:
```sql
SELECT DISTINCT rating, title
FROM film;
```
> Recuperará los valores de las propiedades *rating* y *title*, si se repiten los valores de esas propiedades en conjunto, entonces recuperará un único valor.


### Ordenar resultados
Podemos ordenar los resultados del `SELECT` con el comando `ORDER BY`, por ejemplo:
```sql
SELECT title, length
FROM films
ORDER BY length ASC;
```
> Recuperamos los atributos de **title** y **length** de la tabla *films* y lo ordenamos los resultados gracias al atributo **length** de manera ascedente (*de menor a mayor*)

Otro ejemplo:
```sql
SELECT title, length
FROM films
ORDER BY length DESC;
```
> Recuperamos los atributos de **title** y **length** de la tabla *films* y lo ordenamos los resultados gracias al atributo **length** de manera desendentes (*de mayor a menor*)

Otro ejemplo
```sql
SELECT title, rating 
FROM film
ORDER BY rating ASC, title ASC;
```
> Recuperamos los atributos de **title** y **rating** de la tabla *films* y primero lo ordenamos por el *rating* de manera ascedente, después de haberlo ordenado entonces lo ordenamos por el *title* de namera ascendente.


### Limitando resultados
Para filtrar los resultados usamos el comando `limit`, por ejemplo:
```sql
SELECT title, length
FROM film
ORDER BY length DESC
LIMIT 10;
```
> Recuperamos el atributo **title** y **length** de la tabla *film* ordenados por *length* de manera descendente pero limitando los resultado a 10.


### Filtrando filas.
Para filtrar resultados en nuestras consultas, utilizamos el comando `WHERE`, por ejemplo:
```sql
SELECT title, rating
FROM film
WHERE rating = 'G';
```
> Recuperamos el atributo **title** y **rating** de la tabla *film* solo cuando rating es igual a 'G'


#### Operadores aritméticos para usar en el `where`
* Comparación númerica:
  * `=` es igual a.
  * `>` es mayor a.
  * `<` es menor a.
  * `<>` o `!=` es distinto a.
  * `>=` mayor o igual a.
  * `<=` menor o igual a. 
* Uso de rangos.
  * `between`. se usa para hacer búsquedas por rangos, por ejemplo:
```sql
SELECT title, rating
FROM film
WHERE length BETWEEN 80 AND 100
ORDER BY title DESC
LIMIT 10;
``` 
> Recuperamos el atributo **title** y **rating** de la tabla *film* solo cuando **length** esté entre 80 a 100, ordenalos por **title** de manera descendente y limitalos a unicamente 10 resultados.

* `IN` filtra los valores dentro de una lista, por ejemplo:
```sql
SELECT title, rating
FROM film
WHERE rating IN ('G', 'PG')
ORDER BY rating, title;
```
> Recuperamos el atributo **title** y **rating** de la tabla *film* solo cuando **rating** tenga los valores 'G' o 'PG', después ordenar los resultado por **rating** de manera ascendente y luego por **title** de manera ascendente.

* `LIKE`. Filtramos por secciones una cadena de texto, por ejemplo:
```sql
SELECT title
FROM film
WHERE title LIKE 'B%'
ORDER BY title;
```
> recuperamos el atributo **title** de la tabla *film* donde los valores de **title** inicien con la 'B' mayúscula para después ordernarlos por la propiedad **title** de manera ascedente.
> 
> **NOTA:** el operador `LIKE` es case sensitive, o sea que es sensible a mayúsculas y minúsculas.

Otro ejemplo:
```sql
SELECT title
FROM film
WHERE title LIKE '%LOVE%'
ORDER BY title;
```
> recuperamos el atributo **title** de la tabla *film* donde los valores de **title** tengan en alguna parte la palabra 'LOVE' para después ordernarlos por la propiedad **title** de manera ascedente.

Otro ejemplo:
```sql
SELECT title
FROM film
WHERE title LIKE '%_LOVE%'
ORDER BY title;
```
> recuperamos el atributo **title** de la tabla *film* donde los valores de **title**  tengan en alguna parte la palabra una letra cualquiera seguido de 'LOVE' para después ordernarlos por la propiedad **title** de manera ascedente.

* `ILIKE`. tiene la misma funcionalidad del filtrado que `LIKE` pero con la diferencia de que `ILIKE` case insensitive, por ejemplo:
```sql
SELECT title
FROM film
WHERE title ILIKE 'B%'
ORDER BY title;
```
> recuperamos el atributo **title** de la tabla *film* donde los valores de **title** inicien con la 'B' minúsculas o mayúscula para después ordernarlos por la propiedad **title** de manera ascedente.
> 
> **NOTA:** el operador `ILIKE` es case insensitive, o sea que es no distingue de mayúsculas y minúsculas.

otro ejemplo
```sql
SELECT title, rating
FROM film
WHERE rating = 'G'
ORDER BY title DESC
LIMIT 10;
```

### Combinando operadores: AND y OR
Con los operadores `AND` y `OR` podemos usarlo para hacer mas robustas nuestras condiciones de búsqueda por ejemplo:
```sql
SELECT address_id, address, address2, district, postal_code
FROM address
WHERE (address2 IS NULL OR address2 = '') OR (postal_code IS NULL OR postal_code = '');
```
> Recuperamos los atributos **address_id, address, address2, ditrict y postal_code** de la tabla *film* donde **address2** tenga valores nulos o contenga valores vacíos o postal_code contenga valores nulos o contengan valores vacios

Otro ejemplo
```sql
SELECT title, length, rating, rental_rate
FROM film
WHERE (length < 90 AND rating IN ('G', 'PG')) 
AND rental_rate <= 0.99
ORDER BY length;
```
> Recuperamos los atributos **title, length, rating y rental_rate** de la tabla *film* donde **length** sea menores de 90 y **rating** contenga los valores 'G' y 'PG', también que rental_rate sea menor o igual de 0.99 y que el resultado sea ordenado por la propiedad **length** de manera ascendente
