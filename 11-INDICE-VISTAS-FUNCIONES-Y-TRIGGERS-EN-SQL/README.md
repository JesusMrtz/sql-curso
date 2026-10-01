# Indices, vistas, funciones y Triggers en SQL

## Indices en SQL y Bases de datos.
Un **indice** es una estructura de datos especial que se va a guardar dentro de nuestro servidor de base de datos que va a mejorar drasticamente la velocidad con la que podemos recuperar la información de una tabla, una buena analógia sería como el **indice de un libro**

Cuando una tabla tiene mas de 100,000 filas es altamente recomendado el usar los índices.

**No es recomendable el crear indices para todas las propiedades de una tabla** ya que ocupa espacio dentro de nuestro disco y aparte, en aquellas columnas en la que asociamos un indice, la consulta de la información es **mucho mas rápida** pero si introducimos, modificamos información es **mucho más lento**

```sql
EXPLAIN ANALYZE
SELECT * FROM bookify.libros WHERE categoria_id = 1;
```
> Analizamos la consulta select para verificar si está usando indices o está usando un análisis secuencial.


**Creación de un índice**
```sql
CREATE INDEX idx_libros_categoria_id ON bookify.libros(categoria_id);
```


## Indice B-tree en SQL
Es el índice mas común y mas versatil y se llama *B-tree* porque organiza los datos conforme a una estructura de datos conocida como *árbol balanceado*

Es el tipo de índice que se crea por defecto cuando usamos el `CREATE INDEX` y es el índice que utilizaremos como el 95% de las ocasiones.


### ¿Cuando usamos los índices B-tree?
Lo usamos en los siguientes casos de uso:
* Cuando es una columna cuando vamos a hacer muchas operacioens de igualdad.
* Cuando estamos buscando rangos dentro del `WHERE` como por ejemplo el `BETWEEN`
* Cuando hacemos ordenamientos 
* Cuando usamos los operadores de filtrado en la cláusula `WHERE`
* Cuando hacemos búsquedas con `LIKE`o `ILIKE`


## Indice Hash en SQL
Este indice se crea mediando el uso de una función **HASH** y se puede implementar en otro motor de bases de datos relacional.

Optimiza unicamente las comparaciones de igualdad exacta, es decir, que es más eficiente que *B-tree* cuando comparamos con un valor exacto dentro de una cláusula `WHERE` pero es menos eficientes cuando hacemos filtros con `BETWEEN, LIKE, ILIKE`, realizar ordenamientos con `ORDER BY`, etc.
```sql
CREATE INDEX idx_clientes_email_hash ON bookify.clientes USING HASH(email)
```

## Indices GIN y búsqueda avanzada de texto con SQL
### El problema de buscar texto
Imagina que un usuario de nuestra tienda Bookify escribe "aventuras en la sombra" en el buscador. Lo que espera es encontrar libros cuyo título o descripción contenga esas palabras, sin importar si aparecen en ese orden exacto, si el título dice "Aventura" en singular o si usa mayúsculas. Lo que no espera es que le digamos "no se encontraron resultados" porque ningún título contiene esa cadena literal.

PostgreSQL resuelve todos estos problemas con su motor de **Full-Text Search** (FTS), construido sobre dos tipos de datos fundamentales: `tsvector` y `tsquery`. Este artículo explica en detalle cómo funcionan, cómo configurarlos y cómo aplicarlos a nuestra base de datos Bookify para construir un buscador profesional.
Este indice está especializado en búsqueda de texto completo.

### Fundamentos de tsvector y tsquery
#### ¿Qué es un tsvector?
Un `tsvector` es la representación procesada y optimizada de un documento de texto, preparada para ser buscada. Cuando PostgreSQL convierte un texto a `tsvector`, realiza tres transformaciones fundamentales.

En primer lugar, **tokeniza** el texto: lo divide en palabras individuales (tokens). En segundo lugar, **normaliza** cada token aplicando un proceso de stemming (reducción a la raíz lingüística): "aventuras" se convierte en "aventur", "corriendo" en "corr", "libros" en "libr". Esto permite que una búsqueda por "aventura" encuentre también "aventuras", "aventurero" o "aventurarse". En tercer lugar, **elimina las stop words** (palabras vacías): artículos, preposiciones y conjunciones que no aportan valor semántico a la búsqueda, como "el", "de", "en", "la", "y", "que".

El resultado es un conjunto ordenado de lexemas únicos, cada uno con su posición original en el texto:
```sql
-- Convertir un texto a tsvector usando la configuración en español
SELECT to_tsvector('spanish', 'Las aventuras del caballero en la sombra oscura');
 
-- Resultado:
'aventur':2 'caball':4 'oscur':8 'sombr':7
```
Observa lo que ha ocurrido: "Las", "del", "en" y "la" han desaparecido (son stop words en español). "aventuras" se ha reducido a "aventur", "caballero" a "caball", "sombra" a "sombr" y "oscura" a "oscur". Los números junto a cada lexema indican la posición original de la palabra en el texto.

#### ¿Qué es un tsquery?
Un `tsquery` es la representación procesada de una consulta de búsqueda. Aplica el mismo proceso de normalización que el `tsvector` (stemming y eliminación de stop words), pero además permite combinar términos con operadores lógicos.
```sql
-- Consulta simple: buscar "aventura"
SELECT to_tsquery('spanish', 'aventura');
-- Resultado: 'aventur'
 
-- Consulta con AND: ambos términos deben estar presentes
SELECT to_tsquery('spanish', 'aventura & sombra');
-- Resultado: 'aventur' & 'sombr'
 
-- Consulta con OR: al menos uno de los términos
SELECT to_tsquery('spanish', 'aventura | misterio');
-- Resultado: 'aventur' | 'misteri'
 
-- Consulta con NOT: excluir un término
SELECT to_tsquery('spanish', 'aventura & !terror');
-- Resultado: 'aventur' & !'terror'
 
-- Consulta de proximidad: términos a una distancia determinada
SELECT to_tsquery('spanish', 'aventura <-> sombra');
-- Resultado: 'aventur' <-> 'sombr'
```

#### Operador de coincidencia @@
El operador `@@` es el corazón del Full-Text Search. Comprueba si un `tsvector` satisface un `tsquery`:
```sql
-- ¿El texto contiene "aventura"?
SELECT to_tsvector('spanish', 'Las aventuras del caballero en la sombra oscura')
       @@ to_tsquery('spanish', 'aventura');
-- Resultado: true (porque "aventuras" y "aventura" comparten raíz "aventur")
 
-- ¿Contiene "aventura" Y "sombra"?
SELECT to_tsvector('spanish', 'Las aventuras del caballero en la sombra oscura')
       @@ to_tsquery('spanish', 'aventura & sombra');
-- Resultado: true
 
-- ¿Contiene "dragón"?
SELECT to_tsvector('spanish', 'Las aventuras del caballero en la sombra oscura')
       @@ to_tsquery('spanish', 'dragón');
-- Resultado: false
```

### Configuraciones de idioma (Text Search Configuration)
#### ¿Porqué importa el idioma?
El primer parámetro que reciben `to_tsvector` y `to_tsquery` es la **configuración de búsqueda de texto**, que determina qué diccionario de stemming y qué lista de stop words se aplican. Elegir la configuración incorrecta produce resultados absurdos.
```sql
-- Con configuración en español: stemming correcto
SELECT to_tsvector('spanish', 'Los libros fantásticos');
-- Resultado: 'fantást':3 'libr':2
 
-- Con configuración en inglés: stemming incorrecto para español
SELECT to_tsvector('english', 'Los libros fantásticos');
-- Resultado: 'fantástico':3 'libro':2 'los':1
-- "Los" no se elimina (no es stop word en inglés)
-- El stemming no reduce correctamente las palabras españolas
```

#### Configuraciones disponibles
PostgreSQL incluye configuraciones para múltiples idiomas. Puedes ver todas las disponibles en tu instalación con:
```sql
SELECT cfgname FROM pg_ts_config ORDER BY cfgname;
```
Las más habituales son **spanish**, **english**, **french**, **german**, **italian**, **portuguese** y **simple**. La configuración **simple** no aplica stemming ni elimina stop words — simplemente convierte a minúsculas y tokeniza. Es útil para datos técnicos como códigos ISBN o identificadores donde no quieres que se modifique el texto.

#### Configuración por defecto
Puedes establecer una configuración por defecto a nivel de sesión o de base de datos para no tener que repetirla en cada llamada:
```sql
-- Establecer la configuración por defecto para la sesión actual
SET default_text_search_config = 'spanish';
 
-- Ahora puedes omitir el primer parámetro
SELECT to_tsvector('Los libros fantásticos');
-- Usa automáticamente 'spanish'
 
-- Establecer permanentemente a nivel de base de datos
ALTER DATABASE bookify SET default_text_search_config = 'spanish';
```





Un caso práctico es realizar búsqueda de nuestros autores que aparecen dentro de su biografia.

```sql
SELECT nombre || ' ' || apellidos AS autor, nacionalidad, LEFT(biografia, 100) || '...' AS biografia_preview
FROM bookify.autores
WHERE to_tsvector('spanish', biografia) @@ to_tsquery('spanish', 'premio & nobel');
```
> Recupera datos de los autores si en su **biografía** se encuentra las palabras *premio* y *nobel*

Ayuda a *normalizar el texto* y podemos crear un índice GIN con el siguiente código:
```sql
CREATE INDEX idx_autores_biografia_gin ON bookify.autores USING GIN(to_tsvector('spanish', biografia));
```

## Vistas en SQL y bases de datos
Es una tabla virtual que almacena una consulta SQL en lugar de datos, una tabla se crea con el siguiente comando:
```sql
-- Creamos o reemplazamos la view
CREATE OR REPLACE VIEW bookify.vista_libros_caros AS
SELECT titulo, precio, stock
FROM bookify.libros
WHERE precio > 25;

-- Consultamos la view
SELECT * FROM bookify.vista_libros_caros;
```
Las ventajas que nos proporciona una vista es:
1. Simplicidad para no usar queries muy extensas y complejas.
2. Reutilizamos de información que se consulta frecuentemente.
3. Seguridad para compartir ciertos datos en una vista, en vez de una tabla completa.


## Vistas avanzadas en SQL: Dashboard de pedidos.
```sql
CREATE OR REPLACE VIEW bookify.vista_dashboard_pedidos AS
SELECT p.id, p.numero_pedido, p.fecha_pedido, p.estado,
		-- Información del cliente
		CONCAT(c.nombre, ' ', c.apellidos) AS cliente,
		c.email AS email_cliente,
		c.telefono AS telefono_cliente,
		c.ciudad AS ciudad_cliente,

		-- Información de envio
		p.direccion_envio,
		p.ciudad_envio,
		p.pais_envio,

		-- Detalles del pedido
		COUNT(dp.id) AS cantidad_items,
		SUM(dp.cantidad) AS unidades_totales,
		p.subtotal,
		p.impuestos,
		p.gastos_envio,
		p.total,

		-- Análisis temporal
		EXTRACT(DAY FROM (CURRENT_TIMESTAMP - p.fecha_pedido)) AS dias_desde_pedido,
		CASE
			WHEN p.fecha_envio IS NOT NULL
			THEN EXTRACT(DAY FROM (p.fecha_envio - p.fecha_pedido))
			ELSE NULL
		END AS dias_hasta_envio,

		-- Alerta y estados
		CASE
			WHEN p.estado = 'entregado' THEN 'Completado'
			WHEN p.estado = 'cancelado' THEN 'Cancelado'
			WHEN p.estado = 'enviado' THEN 'En tránsito'
			WHEN EXTRACT(DAY FROM (CURRENT_DATE - p.fecha_pedido)) > 7
				AND p.estado IN ('pendiente', 'procesado')
			THEN 'Atención requerida'
			WHEN p.estado = 'procesando' THEN 'Procesando'
			ELSE 'Pendiente'
		END AS estado_visual,

		CASE
			WHEN p.estado IN ('entregado', 'cancelado') THEN FALSE
			WHEN EXTRACT(DAY FROM (CURRENT_DATE - p.fecha_pedido)) > 7
				AND p.estado IN ('pendiente', 'procesando')
			THEN TRUE
			ELSE FALSE
		END AS requiere_atencion
FROM bookify.pedidos AS p
JOIN bookify.clientes AS c ON p.cliente_id = c.id
LEFT JOIN bookify.detalles_pedidos AS dp ON dp.pedido_id = p.id
GROUP BY 
	p.id, p.numero_pedido, p.fecha_pedido, p.estado,
	c.nombre, c.apellidos, c.email, c.telefono, c.ciudad,
	p.direccion_envio, p.ciudad_envio, p.pais_envio,
	p.subtotal, p.impuestos, p.gastos_envio, p.total, p.fecha_envio;
```

## Vistas materializadas en SQL y Bases de datos.
Las **vistas materializadas** almacenan fisicamente los resultados, es decir, son como una fotografía de un momento dado.

Las *vistas materializadas* pueden quedar inconsistentes si la información se actualiza, pero son útiles cuando nosotros queremos querer consultas muy complejas, cuando son datos que cambian con poca frecuencia, para analisis y reportes de meses anteriores.

```sql
CREATE MATERIALIZED VIEW bookify.vista_mat_ventas_mensuales AS
SELECT 
    DATE_TRUNC('month', p.fecha_pedido) AS mes,
    COUNT(DISTINCT p.id) AS total_pedidos,
    COUNT(DISTINCT p.cliente_id) AS clientes_unicos,
    SUM(dp.cantidad) AS libros_vendidos,
    COUNT(DISTINCT dp.libro_id) AS titulos_diferentes,
    SUM(p.subtotal) AS ingresos_brutos,
    SUM(p.impuestos) AS total_impuestos,
    SUM(p.gastos_envio) AS total_envios,
    SUM(p.total) AS ingresos_totales,
    AVG(p.total) AS ticket_promedio,
    MAX(p.total) AS pedido_mas_grande,
    COUNT(CASE WHEN p.estado = 'cancelado' THEN 1 END) AS pedidos_cancelados,
    ROUND(
        COUNT(CASE WHEN p.estado = 'cancelado' THEN 1 END)::NUMERIC / 
        COUNT(*)::NUMERIC * 100, 
        2
    ) AS porcentaje_cancelacion
FROM bookify.pedidos p
JOIN bookify.detalles_pedidos dp ON p.id = dp.pedido_id
WHERE p.estado IN ('entregado', 'cancelado')
GROUP BY DATE_TRUNC('month', p.fecha_pedido)
ORDER BY mes DESC;
```
Para refrescar una vista materializada, se usa el comando:
```sql
REFRESH MATERIALIZED VIEW bookify.vista_mat_ventas_mensuales;
```

## Insertar, modificar y eliminar datos a través de una vista.
Solo se **pueden actualizar, modificar o eliminar registros** de una vista que fue creada desde una sola tabla.

## Funciones simples en SQL y Bases de datos.
Una función en SQL es un bloque de código reutilizable:
```sql
-- Creación de una función
CREATE OR REPLACE FUNCTION bookify.calcular_precio_con_iva(
	precio_base DECIMAL
)
RETURNS DECIMAL AS $$
	SELECT ROUND(precio_base * 1.16, 2); 
$$ LANGUAGE SQL
IMMUTABLE;

-- Utilización de una función
SELECT titulo, precio AS precio_sin_iva, bookify.calcular_precio_con_iva(precio) AS precio_con_iva
FROM bookify.libros;
```

## PL/SQL: Funciones avanzadas en SQL y Bases de datos.
`PL/SQL` no es estandar ya que fue creada por **ORACLE** y en *PostgreSQL* tiene `PG/SQL`

```sql
-- Creamos la función
CREATE OR REPLACE FUNCTION bookify.clasificar_libro_por_precio(
	precio DECIMAL
)
RETURNS TEXT AS $$
BEGIN
	IF precio IS NULL THEN
		RETURN 'Sin precio';
	ELSIF precio < 10 THEN
		RETURN 'Económico';
	ELSIF precio BETWEEN 10 AND 20 THEN
		RETURN 'Precio medio';
	ELSEIF precio BETWEEN 20 AND 40 THEN
	 	RETURN 'Precio alto';
	ELSE
		RETURN 'Premium';
	END IF;
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

-- Usamos la función
SELECT titulo, precio, bookify.clasificar_libro_por_precio(precio) AS clasificacion
FROM bookify.libros;
```

## Triggers en SQL y Bases de datos
