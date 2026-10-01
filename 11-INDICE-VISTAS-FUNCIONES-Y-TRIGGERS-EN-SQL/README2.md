# Lectura: Búsqueda avanzada de texto en PostgreSQL

## Introducción: el problema de buscar texto
Imagina que un usuario de nuestra tienda Bookify escribe "aventuras en la sombra" en el buscador. Lo que espera es encontrar libros cuyo título o descripción contenga esas palabras, sin importar si aparecen en ese orden exacto, si el título dice "Aventura" en singular o si usa mayúsculas. Lo que no espera es que le digamos "no se encontraron resultados" porque ningún título contiene esa cadena literal.

PostgreSQL resuelve todos estos problemas con su motor de Full-Text Search (FTS), construido sobre dos tipos de datos fundamentales: tsvector y tsquery. Este artículo explica en detalle cómo funcionan, cómo configurarlos y cómo aplicarlos a nuestra base de datos Bookify para construir un buscador profesional.

## Los fundamentos: tsvector y tsquery
### ¿Qué es un tsvector?
Un `tsvector` es la representación procesada y optimizada de un documento de texto, preparada para ser buscada. Cuando PostgreSQL convierte un texto a tsvector, realiza tres transformaciones fundamentales.

En primer lugar, tokeniza el texto: lo divide en palabras individuales (tokens). En segundo lugar, normaliza cada token aplicando un proceso de stemming (reducción a la raíz lingüística): "aventuras" se convierte en "aventur", "corriendo" en "corr", "libros" en "libr". Esto permite que una búsqueda por "aventura" encuentre también "aventuras", "aventurero" o "aventurarse". En tercer lugar, elimina las stop words (palabras vacías): artículos, preposiciones y conjunciones que no aportan valor semántico a la búsqueda, como "el", "de", "en", "la", "y", "que".

El resultado es un conjunto ordenado de lexemas únicos, cada uno con su posición original en el texto:

```sql
-- Convertir un texto a tsvector usando la configuración en español
SELECT to_tsvector('spanish', 'Las aventuras del caballero en la sombra oscura');
 
-- Resultado:
'aventur':2 'caball':4 'oscur':8 'sombr':7
```


Observa lo que ha ocurrido: "Las", "del", "en" y "la" han desaparecido (son stop words en español). "aventuras" se ha reducido a "aventur", "caballero" a "caball", "sombra" a "sombr" y "oscura" a "oscur". Los números junto a cada lexema indican la posición original de la palabra en el texto.

### ¿Qué es un tsquery?
Un `tsquery` es la representación procesada de una consulta de búsqueda. Aplica el mismo proceso de normalización que el tsvector (stemming y eliminación de stop words), pero además permite combinar términos con operadores lógicos.



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


### El operador de coincidencia @@
El operador `@@` es el corazón del Full-Text Search. Comprueba si un tsvector satisface un tsquery:

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


## Configuraciones de idioma (Text Search Configurations)
### ¿Por qué importa el idioma?
El primer parámetro que reciben to_tsvector y to_tsquery es la configuración de búsqueda de texto, que determina qué diccionario de stemming y qué lista de stop words se aplican. Elegir la configuración incorrecta produce resultados absurdos.

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


### Configuraciones disponibles
PostgreSQL incluye configuraciones para múltiples idiomas. Puedes ver todas las disponibles en tu instalación con:

```sql
SELECT cfgname FROM pg_ts_config ORDER BY cfgname;
```


Las más habituales son spanish, english, french, german, italian, portuguese y simple. La configuración simple no aplica stemming ni elimina stop words — simplemente convierte a minúsculas y tokeniza. Es útil para datos técnicos como códigos ISBN o identificadores donde no quieres que se modifique el texto.

### Configuración por defecto
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


## Funciones de conversión: to_tsvector, to_tsquery y variantes
### to_tsvector
Esta es la función principal para convertir texto en un vector de búsqueda. Acepta una configuración de idioma y uno o más textos:

```sql
-- Uso básico
SELECT to_tsvector('spanish', 'El nombre del viento');
 
-- Concatenar varios campos en un solo tsvector
-- Útil para buscar simultáneamente en título y descripción
SELECT to_tsvector('spanish', titulo || ' ' || COALESCE(descripcion, ''))
FROM libros;
```


### to_tsquery
Convierte una cadena de búsqueda en un tsquery aplicando stemming. Requiere que los operadores estén explícitos (&, |, !, <->):

```sql
-- Correcto: operadores explícitos
SELECT to_tsquery('spanish', 'sombra & viento');
 
-- ERROR: no acepta texto libre sin operadores
-- SELECT to_tsquery('spanish', 'sombra viento');  -- ¡Falla!
```


### plainto_tsquery
Convierte texto libre (como lo escribiría un usuario normal) en un tsquery donde todas las palabras se combinan con AND. Es la función más práctica para buscadores:

```sql
-- Texto libre: el usuario escribe naturalmente
SELECT plainto_tsquery('spanish', 'sombra del viento');
-- Resultado: 'sombr' & 'vient'
-- ("del" se elimina como stop word, las demás se unen con &)
```


### phraseto_tsquery
Similar a plainto_tsquery, pero combina las palabras con el operador de proximidad <-> en lugar de &. Busca las palabras en el orden exacto y adyacentes:

```sql
SELECT phraseto_tsquery('spanish', 'sombra del viento');
-- Resultado: 'sombr' <-> 'vient'
-- Busca "sombra" seguido inmediatamente de "viento" (ignorando stop words)
```


### websearch_to_tsquery
Introducida en PostgreSQL 11, esta función interpreta una sintaxis similar a la de los buscadores web. Es la opción más intuitiva para usuarios finales:

```sql
-- Buscar documentos que contengan ambas palabras
SELECT websearch_to_tsquery('spanish', 'sombra viento');
-- Resultado: 'sombr' & 'vient'
 
-- Buscar frase exacta con comillas
SELECT websearch_to_tsquery('spanish', '"sombra del viento"');
-- Resultado: 'sombr' <-> 'vient'
 
-- Excluir un término con el signo menos
SELECT websearch_to_tsquery('spanish', 'sombra -terror');
-- Resultado: 'sombr' & !'terror'
 
-- Operador OR
SELECT websearch_to_tsquery('spanish', 'sombra OR misterio');
-- Resultado: 'sombr' | 'misteri'
```

Esta es probablemente la función que usarás en la mayoría de casos reales, ya que acepta la sintaxis que los usuarios ya conocen de Google y otros buscadores.



## Aplicación práctica en Bookify
### Búsqueda básica sin índice
Empecemos por la forma más sencilla de implementar Full-Text Search sobre la tabla libros:

```sql
-- Buscar libros cuyo título contenga "sombra"
SELECT id, titulo, precio
FROM libros
WHERE to_tsvector('spanish', titulo) @@ to_tsquery('spanish', 'sombra');
 
-- Buscar libros que contengan "aventura" Y "noche"
SELECT id, titulo, precio
FROM libros
WHERE to_tsvector('spanish', titulo)
      @@ plainto_tsquery('spanish', 'aventura noche');
```

Esto funciona correctamente, pero tiene un problema de rendimiento: PostgreSQL debe calcular to_tsvector('spanish', titulo) para cada fila de la tabla en cada consulta. Con miles de libros, esto se vuelve lento.



### Columna tsvector generada automáticamente
La solución es precalcular el tsvector y almacenarlo en una columna de la tabla. PostgreSQL 12+ permite usar columnas generadas (generated columns) que se actualizan automáticamente:

```sql
-- Añadir columna tsvector generada a partir del título
ALTER TABLE libros
  ADD COLUMN titulo_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('spanish', titulo)) STORED;
  ```

Si además quisiéramos buscar en campos de otras tablas relacionadas (como el nombre del autor), podríamos crear una columna generada que combine múltiples campos, o bien mantener una columna tsvector actualizada mediante triggers.


### Crear el índice GIN
Una vez tenemos la columna tsvector, creamos un índice GIN sobre ella para que las búsquedas sean instantáneas:

```sql
-- Índice GIN sobre la columna tsvector precalculada
CREATE INDEX idx_libros_titulo_fts
  ON libros USING gin (titulo_tsv);
 
-- Ahora esta consulta usa el índice
SELECT id, titulo, precio
FROM libros
WHERE titulo_tsv @@ websearch_to_tsquery('spanish', 'sombra viento');
```


### Índice GIN sobre expresión (sin columna adicional)
Si prefieres no añadir una columna extra a la tabla, puedes crear un índice GIN directamente sobre la expresión to_tsvector:

```sql
-- Índice GIN sobre expresión (no requiere columna adicional)
CREATE INDEX idx_libros_titulo_fts_expr
  ON libros USING gin (to_tsvector('spanish', titulo));
 
-- IMPORTANTE: la consulta debe usar exactamente la misma expresión
SELECT id, titulo, precio
FROM libros
WHERE to_tsvector('spanish', titulo)
      @@ websearch_to_tsquery('spanish', 'sombra viento');
```


La desventaja de este enfoque es que el tsvector se recalcula en cada inserción o actualización del título, y la expresión en la consulta debe coincidir literalmente con la del índice.



### Búsqueda combinada en título y categoría
Uno de los puntos fuertes de FTS es la capacidad de combinar múltiples campos en una sola búsqueda. Supongamos que queremos buscar simultáneamente en el título del libro y en el nombre de su categoría:

```sql
-- Búsqueda combinada con JOIN
SELECT l.id, l.titulo, c.nombre AS categoria, l.precio
FROM libros l
LEFT JOIN categorias c ON c.id = l.categoria_id
WHERE to_tsvector('spanish', l.titulo || ' ' || COALESCE(c.nombre, ''))
      @@ websearch_to_tsquery('spanish', 'terror oscuro');
```


Para optimizar este caso con un índice, necesitaríamos un trigger que mantuviera un campo tsvector combinado actualizado, ya que las columnas generadas no pueden referenciar otras tablas.

## Pesos y relevancia: ts_rank y ts_rank_cd
### El concepto de pesos
Un buscador profesional no solo encuentra resultados, sino que los ordena por relevancia. PostgreSQL permite asignar pesos (A, B, C, D) a diferentes partes de un documento para indicar su importancia relativa. El peso A es el más importante y el D es el menos importante.

Esto es extremadamente útil cuando indexamos múltiples campos: queremos que una coincidencia en el título tenga más peso que una coincidencia en la descripción o en el nombre de la categoría.

```sql
-- Asignar peso A al título y peso C a la categoría
SELECT
  setweight(to_tsvector('spanish', l.titulo), 'A') ||
  setweight(to_tsvector('spanish', COALESCE(c.nombre, '')), 'C')
  AS documento_ponderado
FROM libros l
LEFT JOIN categorias c ON c.id = l.categoria_id;
```


El resultado es un tsvector donde cada lexema lleva asociado su peso:

`'aventur':2A 'caball':4A 'ficción':6C 'sombr':7A`


### ts_rank: puntuación de relevancia
La función ts_rank calcula una puntuación numérica que indica cuán relevante es un documento para una consulta dada. Tiene en cuenta la frecuencia de los términos buscados y sus pesos:

```sql
-- Buscar y ordenar por relevancia
SELECT
  l.titulo,
  ts_rank(
    setweight(to_tsvector('spanish', l.titulo), 'A') ||
    setweight(to_tsvector('spanish', COALESCE(c.nombre, '')), 'C'),
    websearch_to_tsquery('spanish', 'aventura oscura')
  ) AS relevancia
FROM libros l
LEFT JOIN categorias c ON c.id = l.categoria_id
WHERE (
  setweight(to_tsvector('spanish', l.titulo), 'A') ||
  setweight(to_tsvector('spanish', COALESCE(c.nombre, '')), 'C')
) @@ websearch_to_tsquery('spanish', 'aventura oscura')
ORDER BY relevancia DESC;
```


### ts_rank_cd: relevancia por densidad de cobertura
ts_rank_cd es una variante que tiene en cuenta la proximidad entre los términos buscados dentro del documento. Si los términos aparecen cerca unos de otros, la puntuación es mayor. Esto suele producir resultados más intuitivos para el usuario:

```sql
SELECT
  l.titulo,
  ts_rank_cd(
    setweight(to_tsvector('spanish', l.titulo), 'A'),
    websearch_to_tsquery('spanish', 'sombra viento')
  ) AS relevancia
FROM libros l
WHERE to_tsvector('spanish', l.titulo)
      @@ websearch_to_tsquery('spanish', 'sombra viento')
ORDER BY relevancia DESC
LIMIT 20;
```


### Opciones de normalización
Ambas funciones de ranking aceptan un parámetro de normalización que compensa las diferencias de longitud entre documentos. Sin normalización, los documentos más largos tienden a obtener puntuaciones más altas simplemente porque contienen más palabras:

```sql
-- Normalizar por longitud del documento (flag 2)
SELECT titulo,
       ts_rank(titulo_tsv, query, 2) AS relevancia
FROM libros,
     websearch_to_tsquery('spanish', 'aventura') AS query
WHERE titulo_tsv @@ query
ORDER BY relevancia DESC;
 
-- Normalizar por log de longitud (flag 1) + por número único de palabras (flag 8)
-- Los flags se suman: 1 + 8 = 9
SELECT titulo,
       ts_rank(titulo_tsv, query, 1 | 8) AS relevancia
FROM libros,
     websearch_to_tsquery('spanish', 'aventura') AS query
WHERE titulo_tsv @@ query
ORDER BY relevancia DESC;
```


Los flags disponibles son: 0 (sin normalización, por defecto), 1 (dividir por 1 + log de la longitud), 2 (dividir por la longitud), 4 (dividir por la distancia armónica media entre extensiones), 8 (dividir por el número de palabras únicas), 16 (dividir por 1 + log del número de palabras únicas) y 32 (dividir por el rango mismo + 1). Se pueden combinar sumándolos o usando el operador |.



## Resaltado de resultados: ts_headline
Cuando mostramos resultados de búsqueda, es muy útil mostrar un fragmento del texto con los términos buscados resaltados en negrita, tal como hacen Google y otros buscadores. La función ts_headline se encarga de esto:

```sql
-- Resaltar los términos encontrados con etiquetas HTML
SELECT
  titulo,
  ts_headline(
    'spanish',
    titulo,
    websearch_to_tsquery('spanish', 'sombra'),
    'StartSel=<b>, StopSel=</b>, MaxWords=35, MinWords=15'
  ) AS titulo_resaltado
FROM libros
WHERE to_tsvector('spanish', titulo)
      @@ websearch_to_tsquery('spanish', 'sombra');
```


Si el título fuera "La sombra del viento", el resultado de ts_headline sería: La <b>sombra</b> del viento.

## Opciones de ts_headline
La función acepta varias opciones para controlar el formato del fragmento:

```sql
SELECT ts_headline(
  'spanish',
  'Este es un texto largo sobre las aventuras de un caballero en tierras oscuras y misteriosas',
  to_tsquery('spanish', 'aventura & oscuro'),
  'StartSel=<mark>, StopSel=</mark>, MaxWords=20, MinWords=10, ShortWord=3, MaxFragments=2, FragmentDelimiter= ... '
);
```


StartSel y StopSel definen las etiquetas que envuelven los términos encontrados (por defecto son <b> y </b>). MaxWords y MinWords controlan la longitud del fragmento. ShortWord establece la longitud mínima de palabra para que se incluya en el fragmento. MaxFragments permite devolver múltiples fragmentos del documento separados por FragmentDelimiter.

⚠️ Nota de rendimiento: ts_headline es computacionalmente costosa porque necesita volver al texto original (no al tsvector) para generar el fragmento. Aplícala solo a los resultados que vayas a mostrar (después del LIMIT), nunca sobre toda la tabla.



## El operador de proximidad <->
El operador de proximidad (también llamado operador FOLLOWED BY) permite buscar palabras que aparecen en un orden específico y a una distancia determinada:

```sql
-- Palabras adyacentes: "sombra" seguido inmediatamente de "viento"
SELECT * FROM libros
WHERE titulo_tsv @@ to_tsquery('spanish', 'sombra <-> viento');
 
-- Palabras a distancia 2: una palabra entre medias
SELECT * FROM libros
WHERE titulo_tsv @@ to_tsquery('spanish', 'sombra <2> viento');
 
-- Cadena de proximidad: tres palabras consecutivas
SELECT * FROM libros
WHERE titulo_tsv @@ to_tsquery('spanish', 'nombre <-> del <-> viento');
```


Este operador es esencial cuando la diferencia entre "gato negro" y "negro gato" importa, o cuando quieres encontrar frases concretas y no simplemente documentos que contengan ambas palabras en cualquier posición.

💡 Tip: Recuerda que phraseto_tsquery y websearch_to_tsquery (con comillas) generan automáticamente operadores de proximidad, así que en la práctica no necesitas construirlos a mano en la mayoría de casos.



## Búsqueda por prefijo
PostgreSQL FTS permite buscar por el inicio de una palabra usando el sufijo :* en la consulta. Esto es ideal para implementar autocompletado mientras el usuario escribe:

```sql
-- Buscar todas las palabras que empiecen por "aven"
-- (encontrará aventura, aventurero, avenida, etc.)
SELECT titulo FROM libros
WHERE titulo_tsv @@ to_tsquery('spanish', 'aven:*');
 
-- Combinar prefijo con otros términos
SELECT titulo FROM libros
WHERE titulo_tsv @@ to_tsquery('spanish', 'aven:* & sombr:*');
```


Hay que tener en cuenta que la búsqueda por prefijo opera sobre los lexemas normalizados, no sobre las palabras originales. Esto significa que buscar aventur:* puede no encontrar "aventura" si el stemmer ya ha reducido "aventura" a "aventur" (coincidencia exacta, no prefijo). En la práctica, conviene usar prefijos cortos (3-4 caracteres) para maximizar los resultados.



**[AVANZADO: Revisar antes la clase de Triggers]**
## Ejemplo completo: buscador profesional para Bookify
Combinando todo lo aprendido, vamos a construir paso a paso un buscador completo para la tienda Bookify.

### Preparar la estructura
```sql
-- Paso 1: Añadir columna tsvector ponderada a libros
-- Usamos un trigger porque necesitamos datos de otras tablas (categoría)
ALTER TABLE libros ADD COLUMN busqueda_tsv tsvector;
 
-- Paso 2: Crear la función que calcula el tsvector ponderado
CREATE OR REPLACE FUNCTION actualizar_busqueda_tsv()
RETURNS trigger AS $$
DECLARE
  nombre_categoria TEXT;
BEGIN
  -- Obtener el nombre de la categoría
  SELECT nombre INTO nombre_categoria
  FROM categorias
  WHERE id = NEW.categoria_id;
 
  -- Construir el tsvector ponderado:
  -- Peso A: título (lo más importante)
  -- Peso B: categoría
  -- Peso D: idioma
  NEW.busqueda_tsv :=
    setweight(to_tsvector('spanish', COALESCE(NEW.titulo, '')), 'A') ||
    setweight(to_tsvector('spanish', COALESCE(nombre_categoria, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(NEW.idioma, '')), 'D');
 
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
 
-- Paso 3: Crear el trigger
CREATE TRIGGER trg_libros_busqueda_tsv
  BEFORE INSERT OR UPDATE OF titulo, categoria_id, idioma
  ON libros
  FOR EACH ROW
  EXECUTE FUNCTION actualizar_busqueda_tsv();
 
-- Paso 4: Poblar la columna para los datos existentes
UPDATE libros SET titulo = titulo;
```


### Crear el índice
```sql
-- Índice GIN sobre la columna de búsqueda
CREATE INDEX idx_libros_busqueda_fts
  ON libros USING gin (busqueda_tsv);
```


### La consulta del buscador
```sql
-- Función de búsqueda completa
CREATE OR REPLACE FUNCTION buscar_libros(
  terminos TEXT,
  limite INTEGER DEFAULT 20,
  offset_val INTEGER DEFAULT 0
)
RETURNS TABLE (
  id INTEGER,
  titulo VARCHAR,
  precio DECIMAL,
  categoria VARCHAR,
  relevancia REAL,
  titulo_resaltado TEXT
) AS $$
DECLARE
  consulta tsquery;
BEGIN
  -- Construir la consulta usando websearch (sintaxis tipo Google)
  consulta := websearch_to_tsquery('spanish', terminos);
 
  RETURN QUERY
  SELECT
    l.id,
    l.titulo,
    l.precio,
    c.nombre AS categoria,
    ts_rank_cd(l.busqueda_tsv, consulta, 2)::REAL AS relevancia,
    ts_headline(
      'spanish', l.titulo, consulta,
      'StartSel=<b>, StopSel=</b>, MaxWords=50, MinWords=10'
    ) AS titulo_resaltado
  FROM libros l
  LEFT JOIN categorias c ON c.id = l.categoria_id
  WHERE l.busqueda_tsv @@ consulta
  ORDER BY relevancia DESC
  LIMIT limite
  OFFSET offset_val;
END;
$$ LANGUAGE plpgsql STABLE;
```


### Usar el buscador
```sql
-- Búsqueda simple
SELECT * FROM buscar_libros('aventura oscura');
 
-- Búsqueda con frase exacta
SELECT * FROM buscar_libros('"sombra del viento"');
 
-- Búsqueda excluyendo un término
SELECT * FROM buscar_libros('misterio -terror');
 
-- Búsqueda con OR
SELECT * FROM buscar_libros('ciencia ficción OR fantasía');
 
-- Con paginación
SELECT * FROM buscar_libros('aventura', 10, 20);
```


## Búsqueda Full-Text en autores
La misma técnica se puede aplicar a la tabla de autores para buscar por nombre, apellidos o contenido de la biografía:

```sql
-- Columna tsvector generada para autores
ALTER TABLE autores
  ADD COLUMN autor_tsv tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('spanish', COALESCE(nombre, '')), 'A') ||
    setweight(to_tsvector('spanish', COALESCE(apellidos, '')), 'A') ||
    setweight(to_tsvector('spanish', COALESCE(biografia, '')), 'C')
  ) STORED;
 
-- Índice GIN
CREATE INDEX idx_autores_fts
  ON autores USING gin (autor_tsv);
 
-- Buscar autores
SELECT nombre, apellidos,
       ts_rank(autor_tsv, query) AS relevancia
FROM autores,
     websearch_to_tsquery('spanish', 'García colombiano') AS query
WHERE autor_tsv @@ query
ORDER BY relevancia DESC;
```


## Búsqueda federada: libros + autores
Para ofrecer una experiencia de búsqueda unificada donde el usuario pueda escribir "García sombra" y encontrar tanto libros con "sombra" en el título como libros escritos por alguien con apellido "García", necesitamos combinar la información:

```sql
-- Búsqueda federada: un solo término busca en libros y en sus autores
SELECT DISTINCT
  l.id,
  l.titulo,
  STRING_AGG(a.nombre || ' ' || COALESCE(a.apellidos, ''), ', ') AS autores,
  l.precio,
  GREATEST(
    ts_rank(l.busqueda_tsv, query),
    COALESCE(MAX(ts_rank(a.autor_tsv, query)), 0)
  ) AS relevancia
FROM libros l
LEFT JOIN libros_autores la ON la.libro_id = l.id
LEFT JOIN autores a ON a.id = la.autor_id,
     websearch_to_tsquery('spanish', 'García sombra') AS query
WHERE l.busqueda_tsv @@ query
   OR a.autor_tsv @@ query
GROUP BY l.id, l.titulo, l.precio, l.busqueda_tsv, query
ORDER BY relevancia DESC
LIMIT 20;
```


## Diagnóstico y depuración
### Inspeccionar tokens y lexemas
Cuando una búsqueda no devuelve los resultados esperados, estas funciones te ayudan a entender qué está ocurriendo internamente:

```sql
-- Ver cómo se tokeniza un texto (antes del stemming)
SELECT * FROM ts_parse('default', 'La sombra del viento, 3ª edición');
 
-- Ver los tokens con su tipo
SELECT alias, description, token
FROM ts_debug('spanish', 'La sombra del viento, 3ª edición');
```


ts_debug es especialmente útil porque muestra para cada token qué diccionario lo ha procesado, si ha sido eliminado como stop word, y cuál es el lexema resultante.

### Verificar que el índice se está usando
Usa EXPLAIN ANALYZE para confirmar que PostgreSQL utiliza el índice GIN en lugar de un Sequential Scan:

```sql
EXPLAIN ANALYZE
SELECT id, titulo
FROM libros
WHERE busqueda_tsv @@ websearch_to_tsquery('spanish', 'aventura');
```


Deberías ver algo como Bitmap Index Scan on idx_libros_busqueda_fts en el plan de ejecución. Si ves un Seq Scan, verifica que el índice existe y que la expresión de la consulta coincide exactamente con la expresión indexada.



### Estadísticas del tsvector
Para entender la distribución de lexemas en tus datos:

```sql
-- Palabras más frecuentes en los títulos de libros
SELECT word, ndoc
FROM ts_stat('SELECT busqueda_tsv FROM libros')
ORDER BY ndoc DESC
LIMIT 20;
 
-- Esto te ayuda a identificar:
-- 1. Palabras demasiado comunes que podrían añadirse como stop words
-- 2. Patrones inesperados en tus datos
```


## Resumen de funciones y operadores
Estas son las funciones y operadores fundamentales del Full-Text Search en PostgreSQL que hemos cubierto en este artículo:

**Conversión a tsvector**: to_tsvector(config, text) convierte texto en un vector de búsqueda aplicando tokenización, stemming y eliminación de stop words.

**Conversión a tsquery**: to_tsquery(config, text) requiere operadores explícitos entre términos. plainto_tsquery(config, text) convierte texto libre uniendo todos los términos con AND. phraseto_tsquery(config, text) convierte texto libre uniendo los términos con el operador de proximidad. websearch_to_tsquery(config, text) acepta sintaxis tipo Google con comillas, OR y el signo menos.

**Coincidencia**: el operador @@ comprueba si un tsvector satisface un tsquery.

**Relevancia**: ts_rank(vector, query) calcula relevancia por frecuencia de términos. ts_rank_cd(vector, query) calcula relevancia por densidad de cobertura (tiene en cuenta la proximidad).

**Resaltado**: ts_headline(config, text, query, options) genera un fragmento del texto con los términos buscados resaltados.

**Pesos**: setweight(vector, weight) asigna un peso (A, B, C o D) a todos los lexemas de un tsvector.

**Diagnóstico**: ts_debug(config, text) muestra el procesamiento detallado de cada token. ts_stat(query) devuelve estadísticas sobre la distribución de lexemas.



## Conclusión
El sistema de Full-Text Search de PostgreSQL es una de las funcionalidades más potentes y a menudo subestimadas de este motor. Con tsvector, tsquery, los índices GIN y las funciones de ranking, puedes construir buscadores sofisticados sin necesidad de herramientas externas como Elasticsearch o Solr.

Para nuestra base de datos Bookify, hemos visto cómo implementar desde una búsqueda simple por título hasta un buscador federado con pesos, relevancia, resaltado de resultados y tolerancia a errores ortográficos. La clave está en elegir la función de conversión adecuada (websearch_to_tsquery para interfaces de usuario), asignar pesos correctos según la importancia de cada campo, y crear los índices GIN apropiados para mantener el rendimiento.

En el próximo tema del curso seguiremos profundizando en las capacidades avanzadas de PostgreSQL.