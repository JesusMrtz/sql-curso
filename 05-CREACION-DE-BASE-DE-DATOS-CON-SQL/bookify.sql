CREATE SCHEMA IF NOT EXISTS bookify;

-- DROP SCHEMA bookify CASCADE;

-- Creación de la tabla categorias
CREATE TABLE bookify.categorias(
	id BIGSERIAL PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL UNIQUE,
	descripcion TEXT,
	activa BOOL DEFAULT TRUE,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Creación de la tabla autores
CREATE TABLE bookify.autores(
	id BIGSERIAL PRIMARY KEY,
	nombre VARCHAR(100) NOT NULL,
	apellidos VARCHAR(100),
	nacionalidad VARCHAR(50),
	fecha_nacimiento DATE,
	biografia TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_DATE,

	CONSTRAINT unique_autor UNIQUE(nombre, apellidos, created_at)
);

-- Creación de la tabla libros
CREATE TABLE IF NOT EXISTS bookify.libros(
	id BIGSERIAL PRIMARY KEY,
	titulo VARCHAR(200) NOT NULL,
	isbn VARCHAR(13) UNIQUE,
	precio DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
	stock INTEGER DEFAULT 0 CHECK (stock >= 0),
	paginas INTEGER DEFAULT 0 CHECK (paginas >= 0),
	idioma VARCHAR(50) DEFAULT 'Español',
	fecha_publicacion DATE,
	categorias_id BIGINT REFERENCES bookify.categorias(id)
);

-- Creación de la tabla libros_autores
CREATE TABLE IF NOT EXISTS bookify.libros_autores(
	libro_id BIGINT REFERENCES bookify.libros(id) ON DELETE CASCADE,
	autor_id BIGINT REFERENCES bookify.autores(id) ON DELETE CASCADE,
	rol VARCHAR(50) DEFAULT 'Autor',
	created_at TIMESTAMP DEFAULT CURRENT_DATE,

	PRIMARY KEY(libro_id, autor_id),
	
	CONSTRAINT roles_validos 
	CHECK (rol in ('Autor', 'Editor', 'Coautor', 'Traductor', 'Ilustrador'))
);

-- Creación de la tabla cliente
CREATE TABLE IF NOT EXISTS bookify.clientes(
	id BIGSERIAL PRIMARY KEY,
	nombre VARCHAR(100) NOT NULL,
	apellidos VARCHAR(100) NOT NULL,
	email VARCHAR(150) NOT NULL UNIQUE,
	telefono VARCHAR(20),
	direccion TEXT,
	ciudad VARCHAR(100),
	codigo_postal VARCHAR(10),
	pais VARCHAR(50) DEFAULT 'España',
	fecha_registro DATE DEFAULT CURRENT_DATE,
	created_at TIMESTAMP DEFAULT CURRENT_DATE,

	CONSTRAINT email_valido 
	CHECK (
    	email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
	)
);

-- Creación de la tabla pedidos
CREATE TABLE IF NOT EXISTS bookify.pedidos(
	id BIGSERIAL PRIMARY KEY,
	numero_pedido VARCHAR(20) UNIQUE,
	cliente_id BIGINT REFERENCES bookify.clientes(id) ON DELETE RESTRICT,
	fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	estado VARCHAR(20) DEFAULT 'pendiente',
	direccion_envio VARCHAR(200) NOT NULL,
	ciudad_envio VARCHAR(100) NOT NULL,
	pais_envio VARCHAR(50) DEFAULT 'España',
	importe DECIMAL(10, 2) DEFAULT 0 CHECK (importe >= 0),
	subtotal DECIMAL(10, 2) DEFAULT 0,
	impuestos DECIMAL(10, 2) DEFAULT 0,
	gastos_envio DECIMAL(10, 2) DEFAULT 0,
	total DECIMAL(10, 2) DEFAULT 0,
	notas TEXT,
	fecha_envio TIMESTAMP,
	fecha_entrega TIMESTAMP,
	created_at TIMESTAMP DEFAULT CURRENT_DATE,

	CONSTRAINT roles_validos 
	CHECK (estado in ('pendiente', 'confirmado', 'procesando', 'enviado', 'entregado', 'cancelado'))
);


-- Creación de la tabla detalle_pedidos
CREATE TABLE IF NOT EXISTS bookify.detalles_pedidos(
	id BIGSERIAL PRIMARY KEY,
	pedido_id BIGINT REFERENCES bookify.pedidos(id) ON DELETE CASCADE,
	libro_id BIGINT REFERENCES bookify.libros(id) ON DELETE RESTRICT,
	cantidad INTEGER NOT NULL CHECK (cantidad > 0),
	precio_unitario DECIMAL(10, 2) NOT NULL CHECK (precio_unitario >= 0),
	descuento DECIMAL(5, 2) DEFAULT 0 CHECK (descuento BETWEEN 0 AND 100),
	subtotal_linea DECIMAL(10, 2) NOT NULL CHECK (subtotal_linea >= 0),
	created_at TIMESTAMP DEFAULT CURRENT_DATE,

	CONSTRAINT pedido_unico UNIQUE(pedido_id, libro_id)
);

ALTER TABLE bookify.libros
RENAME COLUMN categorias_id TO categoria_id;

ALTER TABLE bookify.pedidos
ADD COLUMN codigo_postal_envio  VARCHAR(10);

