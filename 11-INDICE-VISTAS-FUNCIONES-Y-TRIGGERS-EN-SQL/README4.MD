# Guía avanzada de PL/pgSQL
## ¿Qué es PL/pgSQL?
PL/pgSQL es el lenguaje procedural nativo de PostgreSQL. Permite escribir funciones y procedimientos directamente dentro de la base de datos, combinando la potencia de SQL con estructuras de control clásicas de programación: variables, condicionales, bucles y manejo de errores.

La ventaja principal frente a ejecutar lógica desde la aplicación es el rendimiento: el código se ejecuta dentro del servidor de base de datos, evitando múltiples viajes de red entre la aplicación y PostgreSQL.

📖 Referencia: PL/pgSQL Overview — PostgreSQL Docs



## Estructura básica de una función
Toda función PL/pgSQL sigue esta estructura:

```sql
CREATE OR REPLACE FUNCTION nombre_funcion(parametro TIPO)
RETURNS tipo_retorno AS $$
DECLARE
    -- declaración de variables
BEGIN
    -- cuerpo de la función
    RETURN valor;
END;
$$ LANGUAGE plpgsql;
```


El bloque DECLARE es opcional y solo se incluye si necesitas variables locales. El bloque BEGIN ... END contiene la lógica. Veamos un ejemplo sencillo:

```sql
-- Función que calcula el precio con IVA de un libro
CREATE OR REPLACE FUNCTION precio_con_iva(libro_id INTEGER)
RETURNS DECIMAL AS $$
DECLARE
    precio_base DECIMAL;
    iva CONSTANT DECIMAL := 0.04; -- IVA reducido para libros en España
BEGIN
    SELECT precio INTO precio_base
    FROM libros
    WHERE id = libro_id;
 
    RETURN ROUND(precio_base * (1 + iva), 2);
END;
$$ LANGUAGE plpgsql STABLE;


-- Uso
SELECT titulo, precio, precio_con_iva(id) AS precio_con_iva
FROM libros
LIMIT 5;
```


La palabra clave STABLE indica a PostgreSQL que la función no modifica datos y devuelve el mismo resultado para los mismos parámetros dentro de una misma consulta, lo que permite optimizaciones internas.

📖 Referencia: Function Declaration — PostgreSQL Docs



## Variables y tipos
Declaración básica
Las variables se declaran en el bloque DECLARE con su tipo. Pueden tener un valor por defecto y pueden ser constantes:

```sql
DECLARE
    total DECIMAL := 0;
    nombre_cliente VARCHAR(100);
    fecha_hoy DATE := CURRENT_DATE;
    iva CONSTANT DECIMAL := 0.04;
    encontrado BOOLEAN := FALSE;
```


### %TYPE y %ROWTYPE
En lugar de escribir el tipo a mano, puedes referenciar el tipo de una columna existente con %TYPE o el de una fila completa con %ROWTYPE. Esto hace que la función se adapte automáticamente si la tabla cambia:

```sql
CREATE OR REPLACE FUNCTION info_libro(p_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_titulo libros.titulo%TYPE;      -- mismo tipo que la columna titulo
    v_pedido pedidos%ROWTYPE;          -- una fila completa de pedidos
BEGIN
    SELECT titulo INTO v_titulo
    FROM libros WHERE id = p_id;
 
    RETURN COALESCE(v_titulo, 'Libro no encontrado');
END;
$$ LANGUAGE plpgsql STABLE;


INTO: asignar resultados de consultas a variables
La cláusula INTO dentro de un SELECT es la forma estándar de capturar resultados en variables:

-- Capturar múltiples columnas a la vez
SELECT titulo, precio, stock
INTO v_titulo, v_precio, v_stock
FROM libros
WHERE id = p_id;
```


📖 Referencia: Variables — PostgreSQL Docs


## Condicionales: IF, ELSIF, CASE
IF / ELSIF / ELSE
```sql
-- Función que clasifica un pedido según su importe total
CREATE OR REPLACE FUNCTION clasificar_pedido(p_pedido_id INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    v_total DECIMAL;
BEGIN
    SELECT total INTO v_total
    FROM pedidos
    WHERE id = p_pedido_id;
 
    IF v_total IS NULL THEN
        RETURN 'Pedido no encontrado';
    ELSIF v_total >= 100 THEN
        RETURN 'Premium';
    ELSIF v_total >= 30 THEN
        RETURN 'Estándar';
    ELSE
        RETURN 'Básico';
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;
```


### CASE
Cuando evalúas una misma expresión contra múltiples valores, CASE es más limpio:

```sql
-- Función que traduce el estado de un pedido a texto descriptivo
CREATE OR REPLACE FUNCTION estado_legible(p_pedido_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_estado VARCHAR;
BEGIN
    SELECT estado INTO v_estado
    FROM pedidos
    WHERE id = p_pedido_id;
 
    RETURN CASE v_estado
        WHEN 'pendiente'  THEN 'Pendiente de confirmación'
        WHEN 'confirmado' THEN 'Confirmado, preparando envío'
        WHEN 'procesando' THEN 'En preparación en almacén'
        WHEN 'enviado'    THEN 'En camino'
        WHEN 'entregado'  THEN 'Entregado correctamente'
        WHEN 'cancelado'  THEN 'Cancelado'
        ELSE 'Estado desconocido'
    END;
END;
$$ LANGUAGE plpgsql STABLE;
```


📖 Referencia: Conditionals — PostgreSQL Docs



## Bucles
LOOP básico con EXIT
El bucle más simple se repite indefinidamente hasta que ejecutas EXIT:

```sql
-- Generar números de pedido secuenciales hasta encontrar uno libre
CREATE OR REPLACE FUNCTION generar_numero_pedido()
RETURNS VARCHAR AS $$
DECLARE
    v_numero VARCHAR;
    v_contador INTEGER := 1;
BEGIN
    LOOP
        v_numero := 'P-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || LPAD(v_contador::TEXT, 5, '0');
 
        -- Salir si el número no existe
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM pedidos WHERE numero_pedido = v_numero
        );
 
        v_contador := v_contador + 1;
    END LOOP;
 
    RETURN v_numero;
END;
$$ LANGUAGE plpgsql;
```


### WHILE
Repite mientras se cumpla una condición:

```sql
-- Aplicar descuento progresivo: 5% adicional por cada 50€ de compra (máx 25%)
CREATE OR REPLACE FUNCTION calcular_descuento(p_total DECIMAL)
RETURNS DECIMAL AS $$
DECLARE
    v_descuento DECIMAL := 0;
    v_umbral DECIMAL := 50;
BEGIN
    WHILE v_umbral <= p_total AND v_descuento < 25 LOOP
        v_descuento := v_descuento + 5;
        v_umbral := v_umbral + 50;
    END LOOP;
 
    RETURN v_descuento;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```


### FOR numérico
Itera sobre un rango de enteros:

```sql
-- Ejemplo didáctico: calcular el factorial
CREATE OR REPLACE FUNCTION factorial(n INTEGER)
RETURNS BIGINT AS $$
DECLARE
    resultado BIGINT := 1;
BEGIN
    FOR i IN 1..n LOOP
        resultado := resultado * i;
    END LOOP;
 
    RETURN resultado;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```


### FOR sobre consulta
Esta es la forma más habitual en PL/pgSQL — iterar sobre los resultados de un SELECT:

```sql
-- Función que genera un resumen de texto con los libros de una categoría
CREATE OR REPLACE FUNCTION resumen_categoria(p_categoria_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_libro RECORD;
    v_resumen TEXT := '';
BEGIN
    FOR v_libro IN
        SELECT titulo, precio, stock
        FROM libros
        WHERE categoria_id = p_categoria_id
        ORDER BY titulo
    LOOP
        v_resumen := v_resumen || v_libro.titulo
                  || ' (' || v_libro.precio || '€, '
                  || v_libro.stock || ' uds.)' || E'\n';
    END LOOP;
 
    RETURN COALESCE(NULLIF(v_resumen, ''), 'No hay libros en esta categoría');
END;
$$ LANGUAGE plpgsql STABLE;
```


### FOREACH sobre arrays
Si trabajas con arrays, FOREACH los recorre elemento a elemento:

```sql
-- Comprobar si varios ISBN existen en el catálogo
CREATE OR REPLACE FUNCTION verificar_isbns(p_isbns TEXT[])
RETURNS TABLE(isbn TEXT, existe BOOLEAN) AS $$
DECLARE
    v_isbn TEXT;
BEGIN
    FOREACH v_isbn IN ARRAY p_isbns LOOP
        isbn := v_isbn;
        existe := EXISTS (SELECT 1 FROM libros l WHERE l.isbn = v_isbn);
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;


-- Uso
SELECT * FROM verificar_isbns(ARRAY['9788408258759', '0000000000000']);
```


📖 Referencia: Loops — PostgreSQL Docs



## RETURN NEXT y RETURNS TABLE
Cuando una función debe devolver múltiples filas, usamos RETURNS TABLE para definir las columnas de salida y RETURN NEXT para emitir cada fila:

```sql
-- Función que devuelve los libros con stock bajo
CREATE OR REPLACE FUNCTION libros_stock_bajo(p_umbral INTEGER DEFAULT 5)
RETURNS TABLE(id INTEGER, titulo VARCHAR, stock INTEGER, precio DECIMAL) AS $$
BEGIN
    RETURN QUERY
        SELECT l.id, l.titulo, l.stock, l.precio
        FROM libros l
        WHERE l.stock <= p_umbral
        ORDER BY l.stock ASC;
END;
$$ LANGUAGE plpgsql STABLE;


-- Uso: se comporta como una tabla
SELECT * FROM libros_stock_bajo(3);
```


`RETURN QUERY` es la forma más eficiente cuando el resultado proviene directamente de un SELECT. Usa RETURN NEXT cuando necesites construir cada fila manualmente dentro de un bucle (como vimos en el ejemplo de verificar_isbns).

📖 Referencia: Returning from a Function — PostgreSQL Docs



## Manejo de errores: EXCEPTION
El bloque EXCEPTION captura errores dentro de BEGIN ... END y permite manejarlos sin que la función falle:

```sql
-- Función segura para registrar un nuevo cliente
CREATE OR REPLACE FUNCTION registrar_cliente(
    p_nombre VARCHAR,
    p_apellidos VARCHAR,
    p_email VARCHAR
)
RETURNS TEXT AS $$
BEGIN
    INSERT INTO clientes (nombre, apellidos, email, direccion, ciudad)
    VALUES (p_nombre, p_apellidos, p_email, 'Pendiente', 'Pendiente');
 
    RETURN 'Cliente registrado correctamente';
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Error: el email ' || p_email || ' ya está registrado';
    WHEN check_violation THEN
        RETURN 'Error: el formato del email no es válido';
    WHEN OTHERS THEN
        RETURN 'Error inesperado: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;
```


`SQLERRM` contiene el mensaje de error y SQLSTATE el código de error estándar de 5 caracteres. Los nombres de condición más habituales son unique_violation, check_violation, foreign_key_violation, not_null_violation y no_data_found.

RAISE: lanzar mensajes y errores propios
RAISE permite emitir mensajes informativos o lanzar errores personalizados:

```sql
CREATE OR REPLACE FUNCTION actualizar_stock(
    p_libro_id INTEGER,
    p_cantidad INTEGER
)
RETURNS VOID AS $$
DECLARE
    v_stock_actual INTEGER;
BEGIN
    SELECT stock INTO v_stock_actual
    FROM libros
    WHERE id = p_libro_id;
 
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El libro con ID % no existe', p_libro_id;
    END IF;
 
    IF v_stock_actual + p_cantidad < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente: hay % unidades, se intentan retirar %',
            v_stock_actual, ABS(p_cantidad);
    END IF;
 
    UPDATE libros
    SET stock = stock + p_cantidad
    WHERE id = p_libro_id;
 
    RAISE NOTICE 'Stock actualizado: % → %', v_stock_actual, v_stock_actual + p_cantidad;
END;
$$ LANGUAGE plpgsql;
```


Los niveles de RAISE son: DEBUG, LOG, INFO, NOTICE (informativo, se muestra al cliente), WARNING y EXCEPTION (aborta la transacción).

📖 Referencia: Errors and Messages — PostgreSQL Docs



## FOUND: ¿la última consulta devolvió algo?
La variable especial FOUND se establece automáticamente después de cada SELECT INTO, INSERT, UPDATE, DELETE y FOR. Es TRUE si la sentencia afectó o devolvió al menos una fila:

```sql
CREATE OR REPLACE FUNCTION obtener_precio(p_isbn VARCHAR)
RETURNS DECIMAL AS $$
DECLARE
    v_precio DECIMAL;
BEGIN
    SELECT precio INTO v_precio
    FROM libros
    WHERE isbn = p_isbn;
 
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe ningún libro con ISBN %', p_isbn;
    END IF;
 
    RETURN v_precio;
END;
$$ LANGUAGE plpgsql STABLE;
```


📖 Referencia: Obtaining the Result Status — PostgreSQL Docs



## SQL dinámico: EXECUTE
EXECUTE permite construir y ejecutar sentencias SQL en tiempo de ejecución. Es útil cuando el nombre de la tabla, la columna o la cláusula ORDER BY no se conocen de antemano:

```sql
-- Función genérica para contar registros de cualquier tabla del schema bookify
CREATE OR REPLACE FUNCTION contar_registros(p_tabla TEXT)
RETURNS BIGINT AS $$
DECLARE
    v_total BIGINT;
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM %I', p_tabla)
    INTO v_total;
 
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;


-- Uso
SELECT contar_registros('libros');    -- ej: 150
SELECT contar_registros('pedidos');   -- ej: 3420
```


La función format con %I escapa el nombre de la tabla para evitar inyección SQL. Usa siempre %I para identificadores (nombres de tabla/columna) y %L para literales (valores):

```sql
-- Buscar libros por una columna dinámica
EXECUTE format('SELECT titulo FROM libros WHERE %I = %L', p_columna, p_valor)
INTO v_titulo;
```


⚠️ Cuidado: el SQL dinámico no se valida en tiempo de compilación. Usa format con %I y %L siempre — nunca concatenes directamente valores del usuario.

📖 Referencia: Dynamic Commands — PostgreSQL Docs



## Procedimientos (PROCEDURE) vs. Funciones
Desde PostgreSQL 11 existen los procedimientos, que se diferencian de las funciones en dos aspectos: no devuelven un valor y pueden manejar transacciones (COMMIT / ROLLBACK) dentro de su cuerpo.

```sql
-- Procedimiento para cancelar un pedido y restaurar el stock
CREATE OR REPLACE PROCEDURE cancelar_pedido(p_pedido_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_detalle RECORD;
BEGIN
    -- Restaurar stock de cada libro del pedido
    FOR v_detalle IN
        SELECT libro_id, cantidad
        FROM detalles_pedido
        WHERE pedido_id = p_pedido_id
    LOOP
        UPDATE libros
        SET stock = stock + v_detalle.cantidad
        WHERE id = v_detalle.libro_id;
    END LOOP;
 
    -- Marcar pedido como cancelado
    UPDATE pedidos
    SET estado = 'cancelado'
    WHERE id = p_pedido_id;
 
    RAISE NOTICE 'Pedido % cancelado y stock restaurado', p_pedido_id;
END;
$$;

-- Los procedimientos se invocan con CALL, no con SELECT
CALL cancelar_pedido(42);
```
📖 Referencia: CREATE PROCEDURE — PostgreSQL Docs



Resumen de sentencias
**Variables**: DECLARE, %TYPE, %ROWTYPE, INTO, FOUND.

**Condicionales**: IF / ELSIF / ELSE / END IF, CASE / WHEN / END CASE.

**Bucles**: LOOP / EXIT WHEN / END LOOP, WHILE ... LOOP, FOR i IN 1..n LOOP, FOR record IN SELECT ... LOOP, FOREACH element IN ARRAY ... LOOP.

**Retorno**: RETURN, RETURN NEXT, RETURN QUERY, RETURNS TABLE.

**Errores**: EXCEPTION WHEN ... THEN, RAISE NOTICE/EXCEPTION, SQLERRM, SQLSTATE.

**SQL dinámico**: EXECUTE, format('%I', '%L').

**Procedimientos**: CREATE PROCEDURE, CALL.