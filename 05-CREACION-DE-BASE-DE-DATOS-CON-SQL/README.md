# Creación de base de datos con SQL

## Taxonomia de SQL.
![alt text](./assets/img/1.png)

## Crear base de datos con SQL.
Podemos crear una base de datos con el siguiente comando:

```sql
CREATE DATABASE prueba_base_de_datos;
```

## Listar y eliminar una base de datos
Para eliminar una base de datos, podemos usar el siguiente comando:
```SQL
DROP DATABASE prueba_base_de_datos;
```
> **NOTA**: Puede marcar errores de que la base de datos tiene conexiones abiertas, para eso necesitamos eliminarla de manera forzada.

Para eliminar una base de datos de **manera forzada**, usamos el siguiente comando
```sql
DROP DATABASE prueba_base_de_datos
WITH (FORCE);
```

Podemos verificar si la base de datos existe antes de eliminarla con el siguiente comando:
```sql
DROP IF EXISTS prueba_base_de_datos
WITH (FORCE);
```

## Crear Schemas con SQL.
Para crear un *schema* o *namespace* en PostgreSQL, se usa el siguiente comando:
```sql
CREATE SCHEMA stocktaking;
```

## Crear y eliminar tablas con SQL.
Para la creación de las tablas en nuestra base de datos, hay convensiones estandares que se deben seguir, como:
* Usar Snake Case
* El nombre de las tablas DEBEN ir en plural.

Para los atributos, las conversiones son:
* Usar Snake Case.
* El nombre DEBE ir en singular.

```sql
CREATE TABLE categories (
	id SERIAL,
	name VARCHAR(100),
	decription TEXT,
	active BOOL
);
```
> **NOTA**: Está tabla de *categories* se creará en el schema público de PgAdmin.


Si queremos crear la tabla en el schema *stocktaking*, usamos el comando:
```sql
CREATE TABLE stocktaking.categories (
	id SERIAL,
	name VARCHAR(100),
	decription TEXT,
	active BOOL
);
```

Para eliminar una tabla, usamos el comando:
```sql
DROP TABLE IF EXISTS categories;
```


## Gestión de permisos en Schemas y tablas con SQL.
Para crear un **schema** con un **rol** asginado por ejemplo el rol de *frontend_dev*, podemos usar el comando:

```sql
CREATE SCHEMA test_schema
AUTHORIZATION frontend_dev;
```

Para darle permisos a un **rol** para consultar los datos de las tablas que se encuentran en un **schema** específico, se usa el siguiento comando
```sql
GRANT USAGE ON SCHEMA stocktaking
TO frontend_dev;
```

Para darle permisos a un **rol** para crear tablas en un **schema** específico, se usal el siguiente comando
```sql
GRANT CREATE ON SCHEMA stocktaking
TO frontend_dev;
```

Para darles permisos unicamente de **consultar** en una tabla especifica con el **rol** *frontend_dev*, usamos el siguiente comando:
```sql
GRANT SELECT ON SCHEMA stocktaking.categories
TO frontend_dev;
```

Para **quitar los permisos** usamos la palabra clave **REVOKE** en vez de la palabra clave **GRANT**


## Insertar registros en las tablas.
Para insertar registros en una tabla usamos el comando `INSERT INTO` seguido de la nombre de la tabla, los atributos y valores a insertar, por ejemplo:

```sql
INSERT INTO stocktaking.categories (
	name,
	description,
	active
) VALUES (
	'Ficción',
	'Novelas y cuentos de ficción',
	TRUE
);
```
> Insertamos un registro para en la tabla categories

## Restricciones de columnas SQL
Vamos a crear una nueva tabla llamada **categories** para explicar el código:

```sql
CREATE TABLE categories (
	id SERIAL NOT NULL UNIQUE,
	name VARCHAR(100) NOT NULL UNIQUE,
	description TEXT,
	active BOOL DEFAULT TRUE
);
```
Donde:
* **id**. Es de tipo `SERIAL`, no debe de aceptar valores nulos y debe ser *único*.
* **name**. Es de tipo `VARCHAR` de hasta 100 caracteres, no debe aceptar valores nulos y debe ser *único*.
* **description**. Es de tipo `text` y puede aceptar valores nulos y repetidos.
* **active**. es de tipo `BOOLEAN` que por defecto es *True*


## Crear claves primarias en SQL
Para crear **claves primarias** en SQL usamos el palabra reservada `PRIMARY KEY`, como por ejemplo:
```sql
CREATE TABLE categories (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL UNIQUE,
	description TEXT,
	active BOOL DEFAULT TRUE
);
```
> Usamos el atributo *id* como llave primaria

También podemos crear **claves primarias compuestas**, como por ejemplo:
```sql
CREATE TABLE categories (
	id SERIAL NOT NULL UNIQUE,
	name VARCHAR(100) NOT NULL UNIQUE,
	description TEXT,
	active BOOL DEFAULT TRUE,
	PRIMARY KEY (description, name)
);
```
> Usamoso los atributos *name* y *description* como llave primaria.

## Crear claves foraneas:
Si un libro contiene una categoría y una categoria tiene muchos libros, hay una relación de 1 a N donde se le debe agregar una propiedad *category_id* a la tabla de libros:
```sql
CREATE TABLE books (
	id BIGSERIAL PRIMARY KEY,
	title VARCHAR (200) NOT NULL,
	isbn VARCHAR(13) UNIQUE,
	price DECIMAL (10, 2),
	stock INTEGER DEFAULT 0,
	pages INTEGER,
	publish_date DATE,
	register_date DATE DEFAULT CURRENT_DATE,
	language VARCHAR(30) NOT NULL DEFAULT 'Español',
	category_id REFERENCES categories(id)
);
```
> Se crea una referencia en la propiedad `category_id` dentro de *libros* con el atributo `id` de la tabla *categories

También podemos hacerlo asi:
```sql
CREATE TABLE books (
	id BIGSERIAL PRIMARY KEY,
	title VARCHAR (200) NOT NULL,
	isbn VARCHAR(13) UNIQUE,
	price DECIMAL (10, 2),
	stock INTEGER DEFAULT 0,
	pages INTEGER,
	publish_date DATE,
	register_date DATE DEFAULT CURRENT_DATE,
	language VARCHAR(30) NOT NULL DEFAULT 'Español',
	category_id BIGSERIAL,
	FOREIGN KEY(category_id) REFERENCES categories(id)	
);
```

### Relación de muchos a muchos entre la tabla libros y la tabla categorias.
Para eso necesitamos una tabla intermedia llamada `books_categories`:

```sql
CREATE TABLE books_categories (
	id BIGSERIAL PRIMARY KEY,
	book_id REFERENCES books(id),
	category_id REFERENCES categories(id),
);
```
ó

```sql
CREATE TABLE books_categories (
	id BIGSERIAL PRIMARY KEY,
	book_id BIGINT,
	category_id BIGINT,
	FOREIGN KEY (book_id) REFERENCES books(id),
	FOREIGN KEY (category_id) REFERENCES categories(id)
);
```

## Eliminar y modificar columnas/atributos referenciados.
Podemos usar `RESTRICT` impide una operación de eliminación o actualización si la fila que se está eliminando o actualizando es referenciada por otro atributo como *clave foranea de otra tabla*.

```sql
CREATE TABLE books_categories (
 id BIGSERIAL PRIMARY KEY,
 book_id BIGINT,
 category_id BIGINT,

 FOREIGN KEY (book_id) REFERENCES books(id)
 ON DELETE RESTRICT
 ON UPDATE RESTRICT,

 FOREIGN KEY (category_id) REFERENCES categories(id)
 ON DELETE RESTRICT
 ON UPDATE RESTRICT
);
```
> Restringimos las actualizaciones y las eliminaciones de las tablas books y categories si hay una relación con la tabla books_categories.


Podemos usar `CASCADE`si eliminamos o actualizamos un registro de una tabla que contiene una relación foranea con otra, entonces, se eliminan o actualizan todos los registros de la tabla que la referencian.
```sql
CREATE TABLE books_categories (
 id BIGSERIAL PRIMARY KEY,
 book_id BIGINT,
 category_id BIGINT,

 FOREIGN KEY (book_id) REFERENCES books(id)
 ON DELETE RESTRICT
 ON UPDATE CASCADE,

 FOREIGN KEY (category_id) REFERENCES categories(id)
 ON DELETE CASCADE
 ON UPDATE RESTRICT
);
```
> Restringimos la eliminación de la tabla books y la actualización de la tabla categories si hay una relación con la tabla books_categories.
> 
> Pero dejamos en cascada las actualización de la tabla books y la eliminación de la tabla categories, por ende si se podran actualizar registros de la tabla books y se actualizaran los registros de books_categories y la eliminación de los registros books_categories si la tabla books elimina un registro referenciado.

Podemos usar `SET NULL` para dejar como nulos las propiedades foraneas si se llegan a actualizar o eliminar registros de las tablas a las que hace referencia.

Podemos usar `DEFAULT` para dejar un valor nulo cuando las propiedades foraneas se llegan a actualizar o eliminar registros de las tablas a las que hace referencias.

### Mejores prácticas.
La mejor practica es dejar las eliminaciones dejarlos como `RESTRICT` y las actualizaciones como `cascade`, por ejemplo:
```sql
CREATE TABLE books_categories (
	id BIGSERIAL PRIMARY KEY,
	book_id BIGSERIAL,
	category_id BIGSERIAL,
	
	FOREIGN KEY (book_id) REFERENCES books(id)
	ON DELETE RESTRICT
	ON UPDATE CASCADE,
	
	FOREIGN KEY (category_id) REFERENCES categories(id)
	ON DELETE RESTRICT
	ON UPDATE CASCADE
);
```

## Restricciones personalizadas
podemos usar `CHECK` para realizar restricciones personalizadas de múltiples tipos, por ejemplo, crear una tabla `books` donde **price** sea mayor a 0:
```sql
CREATE TABLE books (
	id BIGSERIAL PRIMARY KEY,
	title VARCHAR(200) NOT NULL,
	isbn VARCHAR(13) UNIQUE,
	price DECIMAL(10, 2) NOT NULL,
	stock INTEGER DEFAULT 0,
	pages INTEGER,
	publication_date DATE,
	registration_date DATE DEFAULT CURRENT_DATE,
	language VARCHAR(30) NOT NULL DEFAULT 'Español',

	-- Validaciones de negocio
	CONSTRAINT positive_price CHECK (price > 0)
);
```

Si la tabla ya existe y queremos agregar un nuevo `CONSTRAINT` para que el stock sea meyor o igual a cero, usamos:
```sql
ALTER TABLE books
ADD CONSTRAINT not_stock_negative CHECK (stock >= 0);
```

## Modificar tablas y columnas con SQL
Con la sentencia `ALTER` podemos modificar nuestras tablas y podemos hacer un sinfin de cosas, por ejemplo:

### Agregar una columna
```sql
ALTER TABLE books
ADD COLUMN editorial VARCHAR(100) NOT NULL;
```

### Eliminar una columna
```sql
ALTER TABLE books
DROP COLUMN editorial;
```

### Renombrar una columna
```sql
ALTER TABLE books
RENAME editorial TO editorial_2;
```

### Cambiar un tipo de dato
```sql
ALTER TABLE books
ALTER COLUMN stock TYPE SMALLINT;
```

### Agregar constraint
```sql
ALTER TABLE books
ADD CONSTRAINT not_stock_negative CHECK (stock >= 0);
```

### Eliminar constraint
```sql
ALTER TABLE libros
DROP CONSTRAINT not_stock_negative;
```

Podemos hacer un sinfin de cosas además de las utilizadas y tambien podemos agregar o eliminar restricciones `NOT NULL`, `UNIQUE`, `DEFAULT`