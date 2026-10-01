# Transacciones, modificaciones y actualización de datos con SQL
## Modificar datos con SQL: UPDATE
Para actualizar datos en una tabla usamos el comando `UPDATE`, por ejemplo:
```sql
UPDATE bookify.libros
SET precio = 34.99
WHERE id = 1;
```
> Actualizamos el precio del libro con el id igual a 1

Para actualizar múltiples propiedades, usamos:
```sql
UPDATE bookify.clientes
SET direccion = 'Calle Nueva 123', ciudad = 'Barcelona', codigo_postal = '09001', telefono = '9991010203'
WHERE id = 5;
```
> Actualizamos los datos del cliente con el ID igual a 5

## Copias de seguridad (backups) con SQL
Es importante que cuando se haga alguna modificación dentro de una tabla, tener una copia de seguridad porque si accidentalmente destruimos o modificamos datos, con esa copia los podemos recuperar.
```sql
CREATE TABLE bookify.libros_backup AS
SELECT * FROM bookify.libros;
```
> Creamos una nueva tabla llamada `libros_backup` donde se guarda todos los datos de la tabla `libros`

Para poder recuperar algún valor de una propiedad desde el backup hecho podemos hacer:
```sql
UPDATE bookify.libros AS l
SET precio = backup.precio
FROM bookify.libros_backup AS backup;
```
> Recuperamos los valores del `precio` desde el backup realizado con anterioridad.

### Sacar copia de seguridad de una columna específica.
Esto es viable cuando la tabla **pesa demasiado**, por endé, puede tardar mucho tiempo en realizar la copia de seguridad.

1.
```sql
ALTER TABLE bookify.libros
ADD COLUMN precio_backup DECIMAL(10, 2);
```
> Creamos una nueva propiedad llamada `precio_backup` dentro de la **misma tabla** donde se hará el backup de la columna `precio`.

2.
```sql
UPDATE bookify.libros
SET precio_backup = precio;
``` 
> Recuperamos los valores de la propiedad `precio` dentro de la nueva propiedad `precio_backup`

3. 
```sql
UPDATE bookify.libros
SET precio = precio_backup;
```
> Si por un giro del destino, la propiedad `precio`, modificaron sus datos de manera erronéa, entonces, podemos recuperar los valores desde la propiedad backup `precio_backup`.

4. Tenemos que eliminar la propiedad backup una vez de que su utilización haya terminado.

## Uso práctico de UPDATE: JOIN, operaciones, filtros:
1. 
```sql
UPDATE bookify.libros
SET isbn = '978' || isbn
WHERE LENGTH(isbn) = 10;
```
> Estandarizar el isb para aquellos que les falten el '978' al inicio

2. 
```sql
UPDATE bookify.categorias
SET nombre = 'Ciencia Ficción'
WHERE LOWER(nombre) LIKE '%ciencia%ficcion%' OR LOWER(nombre) LIKE '%ciencia%ficción%';
```
> Estandarizar la categoría a "Ciencia Ficción" para aquellos que están mal escrito

3.
```sql
UPDATE bookify.libros AS l
SET precio = precio * 1.05
FROM bookify.libros_autores AS la
JOIN bookify.autores AS a ON la.autor_id = a.id
WHERE la.libro_id  = l.id AND a.nacionalidad = 'Española';
```
> Subimos el precio para aquellos libros que tiene los autores de nacionalidad 'Española' en una relación de muchos a muchos, por eso utilizamos la cláusula JOIN.

## RETURNING: Devolver modificaciones de UPDATE
Es útil para cuando hacemos `UPDATE` de la información y no queremos hacer otra consulta `SELECT` extra.
```sql
UPDATE bookify.libros AS l
SET precio = precio * 1.15
FROM bookify.libros_autores AS la
JOIN bookify.autores AS a ON la.autor_id = a.id
WHERE la.libro_id  = l.id AND a.nacionalidad = 'Española'
RETURNING l.id, l.titulo, l.precio AS nuevo_precio;
```
> Subimos el precio para aquellos libros que tiene los autores de nacionalidad 'Española' en una relación de muchos a muchos, por eso utilizamos la cláusula JOIN, y además, retornamos el ID, titulo y el nuevo precio del libro.


## Eliminar filas de datos con SQL: DELETE
Podemos hacer eliminaciones fisicas básicas, como por ejemplo:
```sql
DELETE FROM bookify.libros
WHERE LOWER(titulo) = 'niebla'
RETURNING id, titulo;
```
> Eliminamos todos los libros que tengan como título 'niebla' y devolvemos el id y el título de los elementos eliminados.

También podemos hacer una eliminación con JOINS:
```sql
DELETE FROM bookify.libros AS l
USING bookify.libros_autores AS la
JOIN bookify.autores AS a ON la.autor_id = a.id
WHERE la.libro_id  = l.id AND a.nacionalidad = 'Española'
RETURNING l.id, l.titulo;
```
> Eliminamos todos los libros que tiene los autores la nacionalidad 'Española' en una relación de muchos a muchos, por eso usamos la cláusula JOIN, y además, retornamos el ID y el título de los registros eliminados.

## Eliminar todas las filas de una tabla: TRUNCATE
Usamos el comando `TRUNCATE` par eliminar todos los registros de una tabla, por ejemplo:

```sql
TRUNCATE TABLE bookify.libros;
```
> Eliminamos todos los registros de la tabla libros

## Trasacciones con SQL
Una transacción es un bloque de operaciones SQL que se ejecutan como una **unidad indivisible**. O se ejecutan **todas** correctamente, o **ninguna** se aplica. No hay punto intermedio. Los cuatro comandos fundamentales son:

* **BEGIN** — Inicia la transacción.
* **COMMIT** — Confirma todos los cambios realizados.
* **ROLLBACK** — Deshace todos los cambios realizados.
* **SAVEPOINT** — Crea un punto de guardado intermedio dentro de la transacción.

### Caso 1
Este es el caso más clásico. El cliente Nº 3 compra dos libros: el libro Nº 5 (2 unidades) y el libro Nº 8 (1 unidad). Necesitamos hacer varias operaciones que **deben ocurrir juntas o no ocurrir en absoluto**.
```sql
BEGIN;
 
-- Paso 1: Crear el pedido
INSERT INTO pedidos (numero_pedido, cliente_id, direccion_envio, ciudad_envio, estado)
VALUES ('P-2025-00042', 3, 'Calle Mayor 15', 'Madrid', 'pendiente');
 
-- Paso 2: Añadir los libros al detalle del pedido
INSERT INTO detalles_pedido (pedido_id, libro_id, cantidad, precio_unitario, subtotal_linea)
VALUES (currval('pedidos_id_seq'), 5, 2, 19.99, 39.98);
 
INSERT INTO detalles_pedido (pedido_id, libro_id, cantidad, precio_unitario, subtotal_linea)
VALUES (currval('pedidos_id_seq'), 8, 1, 24.50, 24.50);
 
-- Paso 3: Descontar el stock de cada libro
UPDATE libros SET stock = stock - 2 WHERE id = 5;
UPDATE libros SET stock = stock - 1 WHERE id = 8;
 
-- Paso 4: Actualizar el total del pedido
UPDATE pedidos 
SET subtotal = 64.48, impuestos = 13.54, total = 78.02
WHERE id = currval('pedidos_id_seq');
 
-- Todo ha ido bien, confirmamos
COMMIT;
```
**¿Por qué necesitamos una transacción aquí?** Porque si el sistema falla después de descontar el stock pero antes de registrar el detalle del pedido, habríamos perdido unidades de inventario sin rastro. Con la transacción, si algo falla en cualquier paso, **nada se aplica**.


### Caso 2.
Ahora imaginemos que el cliente quiere comprar 3 unidades del libro Nº 5, pero al comprobar el stock vemos que solo quedan 2. En ese caso queremos cancelar toda la operación.

```sql
BEGIN;
 
-- Creamos el pedido
INSERT INTO pedidos (numero_pedido, cliente_id, direccion_envio, ciudad_envio, estado)
VALUES ('P-2025-00043', 3, 'Calle Mayor 15', 'Madrid', 'pendiente');
 
-- Insertamos el detalle
INSERT INTO detalles_pedido (pedido_id, libro_id, cantidad, precio_unitario, subtotal_linea)
VALUES (currval('pedidos_id_seq'), 5, 3, 19.99, 59.97);
 
-- Intentamos descontar el stock
-- Pero el libro 5 solo tiene 2 unidades... el CHECK (stock >= 0) fallaría
UPDATE libros SET stock = stock - 3 WHERE id = 5;
 
-- Algo ha salido mal, cancelamos todo
ROLLBACK;
```
**¿Qué ha pasado?** Al hacer ROLLBACK, todo desaparece: el pedido, el detalle y el intento de descontar stock. La base de datos queda exactamente como estaba antes del BEGIN. Es como si nunca hubiéramos hecho nada.

**¿Para qué sirve esto?** Imagina que este proceso lo gestiona una aplicación web. El backend detecta el error, ejecuta el ROLLBACK y le muestra al usuario un mensaje: *"Lo sentimos, no hay suficiente stock"*. La base de datos permanece limpia y consistente.

### Caso 3
Nos ha llegado un lote de 4 libros nuevos de una editorial. Queremos registrarlos todos, pero si uno falla (por ejemplo, ISBN duplicado), **no queremos perder los que sí se insertaron correctamente**.

Sin SAVEPOINT, un error nos obligaría a hacer ROLLBACK de todo. Con SAVEPOINT, podemos volver solo al punto anterior al error y continuar.

```sql
BEGIN;
 
-- Libro 1: se inserta bien
SAVEPOINT antes_libro_1;
INSERT INTO libros (titulo, isbn, precio, stock, categoria_id)
VALUES ('El Quijote', '9788420412146', 15.99, 20, 1);
 
-- Libro 2: se inserta bien
SAVEPOINT antes_libro_2;
INSERT INTO libros (titulo, isbn, precio, stock, categoria_id)
VALUES ('Cien Años de Soledad', '9780307474728', 18.50, 15, 1);
 
-- Libro 3: ¡ERROR! El ISBN ya existe en la base de datos
SAVEPOINT antes_libro_3;
INSERT INTO libros (titulo, isbn, precio, stock, categoria_id)
VALUES ('La Sombra del Viento', '9788408043645', 21.00, 10, 2);
-- ERROR: duplicate key value violates unique constraint "libros_isbn_key"
 
-- Volvemos al savepoint anterior al libro 3
ROLLBACK TO antes_libro_3;
 
-- Libro 4: se inserta bien, la transacción sigue viva
SAVEPOINT antes_libro_4;
INSERT INTO libros (titulo, isbn, precio, stock, categoria_id)
VALUES ('Rayuela', '9788437604572', 16.75, 12, 1);
 
-- Confirmamos: se guardan los libros 1, 2 y 4. El 3 se omitió.
COMMIT;
```

**¿Qué ha pasado?** El libro 3 falló por ISBN duplicado, pero gracias al SAVEPOINT pudimos volver al estado justo antes de ese INSERT, ignorar el error y seguir con el libro 4. Al final, se guardaron 3 de los 4 libros.

**¿Para qué sirve?** Esto es muy útil en importaciones masivas de datos. Si cargas 500 libros desde un CSV y 3 tienen errores, puedes saltarte esos 3 sin perder los otros 497.


### Caso 4
En PostgreSQL, cuando ocurre un error dentro de una transacción, esta queda en un estado "abortado". Esto significa que cualquier comando que intentes ejecutar después del error será rechazado con el mensaje:
>ERROR: current transaction is aborted, commands ignored until end of transaction block.

Veamos un ejemplo:
```sql
BEGIN;
 
-- Esto funciona bien
INSERT INTO categorias (nombre, descripcion)
VALUES ('Romance', 'Novelas románticas');
 
-- Esto falla: la categoría "Romance" ya existe (nombre es UNIQUE)
INSERT INTO categorias (nombre, descripcion)
VALUES ('Romance', 'Duplicado que falla');
-- ERROR: duplicate key value violates unique constraint
 
-- Intentamos hacer otra cosa... pero no podemos
INSERT INTO categorias (nombre, descripcion)
VALUES ('Aventura', 'Novelas de aventura');
-- ERROR: current transaction is aborted
```
La transacción está "rota". En este punto solo tenemos dos opciones:

**Opción A:** Cancelar todo con ROLLBACK. Perdemos la primera inserción de "Romance" también.
```sql
ROLLBACK;
-- Volvemos al estado inicial. "Romance" NO se insertó.
```

**Opción B:** **Usar SAVEPOINT para protegernos**. Si hubiéramos anticipado el posible error, podríamos haber puesto un SAVEPOINT:
```sql
BEGIN;
 
INSERT INTO categorias (nombre, descripcion)
VALUES ('Romance', 'Novelas románticas');
 
SAVEPOINT antes_del_posible_error;
 
-- Esto falla
INSERT INTO categorias (nombre, descripcion)
VALUES ('Romance', 'Duplicado que falla');
-- ERROR
 
-- Volvemos al savepoint: la transacción sigue viva
ROLLBACK TO antes_del_posible_error;
 
-- Ahora sí podemos continuar
INSERT INTO categorias (nombre, descripcion)
VALUES ('Aventura', 'Novelas de aventura');
 
COMMIT;
-- Resultado: "Romance" y "Aventura" se insertaron correctamente
```
**Esta es la clave del SAVEPOINT:** permite recuperar una transacción que de otra forma estaría muerta. Sin él, un solo error te obliga a descartar todo el trabajo previo.

### Caso 5: Dar de alta un cliente con su primer pedido
Un cliente nuevo llega, se registra y hace su primer pedido en el mismo momento. Son operaciones en diferentes tablas que deben ir juntas.
```sql
BEGIN;
 
-- Paso 1: Registrar al cliente
INSERT INTO clientes (nombre, apellidos, email, telefono, direccion, ciudad, codigo_postal)
VALUES ('Laura', 'Martínez', 'laura@email.com', '612345678', 'Av. Libertad 42', 'Barcelona', '08001');
 
-- Paso 2: Crear su pedido
SAVEPOINT antes_pedido;
INSERT INTO pedidos (numero_pedido, cliente_id, direccion_envio, ciudad_envio, estado)
VALUES ('P-2025-00050', currval('clientes_id_seq'), 'Av. Libertad 42', 'Barcelona', 'pendiente');
 
-- Paso 3: Añadir el libro al pedido
INSERT INTO detalles_pedido (pedido_id, libro_id, cantidad, precio_unitario, subtotal_linea)
VALUES (currval('pedidos_id_seq'), 12, 1, 22.00, 22.00);
 
-- Paso 4: Descontar stock
UPDATE libros SET stock = stock - 1 WHERE id = 12;
 
-- Paso 5: Actualizar total
UPDATE pedidos 
SET subtotal = 22.00, impuestos = 4.62, total = 26.62
WHERE id = currval('pedidos_id_seq');
 
COMMIT;
```

**¿Y si el libro 12 no tuviera stock?** El UPDATE fallaría por el CHECK `stock >= 0`. Gracias al SAVEPOINT, podríamos volver a `antes_pedido`, mantener el registro del cliente (que sí es válido) y comunicar al usuario que el libro no está disponible.

```sql
-- Si falla el stock:
ROLLBACK TO antes_pedido;
 
-- El cliente sigue registrado, pero sin pedido
COMMIT;
```

## Resume: ¿Cuándo usar cada comando?
**BEGIN** — Siempre que vayas a hacer más de una operación que debe ser atómica. Compras, cancelaciones, transferencias, actualizaciones masivas.

**COMMIT** — Cuando todo ha ido bien y quieres guardar los cambios de forma permanente.

**ROLLBACK** — Cuando algo ha fallado y quieres deshacer todo como si nada hubiera pasado.

**SAVEPOINT** — Cuando dentro de una transacción larga hay partes que podrían fallar y no quieres perder el trabajo de las partes que sí funcionaron. Especialmente útil en importaciones masivas, operaciones en múltiples pasos y cualquier situación donde un error parcial no debería destruir todo el progreso.

## Conclusión
Las transacciones son el cinturón de seguridad de tu base de datos. En una aplicación real como Bookify, **cada compra, cada cancelación y cada actualización de inventario debería estar envuelta en una transacción**. Sin ellas, un simple fallo de red o un error inesperado podría dejar tu base de datos en un estado inconsistente: pedidos sin stock descontado, clientes sin pedidos, o libros con cantidades incorrectas.

La combinación de `BEGIN`, `COMMIT`, `ROLLBACK` y `SAVEPOINT` te da el control total sobre qué se guarda, qué se deshace y hasta dónde puedes recuperarte cuando algo sale mal. No es una cuestión de si algo va a fallar, sino de cuándo. Y cuando falle, las transacciones serán tu mejor aliado.