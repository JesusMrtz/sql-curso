# Tipos de datos básicos en SQL
## Cadenas de texto
* `text`. Recibe desde un caracter hasta n cantidades de caracteres ya que no tiene una longitud establecida, podemos guardar información de hasta 1gb de tamaño.
* `character`. Recibe caracteres hasta una longítud máxima y si la cadena de texto es menor a la longítud establecida, entonces lo rellenará con espacios.
* `varchar`. Es exactamente lo mismo que character pero es variable, ya que si la longítud es minima a la establecida, no se va a rellenar con espacios.

## Números enteros

* `smallint`. No guardan ningún punto decimal y además las propiedades con este tipo, solo van a ocupar de nuestra memoria un total de 2 bytes y se puede almacenar números desde **-32,768 hasta 32,767**
* `integer`. Son números que no vienen integrado sin nigún punto decimal y estamos reservando 4 bytes para almacenar este valor númerico desde: **-2,147,483,648 hasta 2,147,483,647**
* `bigint`. No guarda nungún punto decimal y ademas las propiedades de este tipo, van a reservar 8 bytes para almacenar este valor númerico desde: **-9,233,372,036,854,775,808 hasta 9,233,372,036,854,775,807**


## Números autoincrementables
* `smallserial`. Es parecido al `smallint`.
* `serial`. Es parecido al `integer`.
* `bigserial` es parecido al `bigint`.

## Número decimales

Existen dos tipos de valores para números decimales, los de coma flotante y los de coma fija o presición arbitaria:

* `numeric(n,n)`. Es de coma fija o presición arbitraria
* `real`. Es un tipo de dato para almacenar un valor de hasta 4 bytes
* `double precision`. Es un tipo de dato para almacenar un valor de hasta 8 bytes.


## Fechas y horas
* `timestamp`. Representa una fecha como la hora en la que ocurrió un evento determinado, por defecto reserva 8 bytes de nuestra memoria.
* `date`. Representa unicamente la fecha sin la hora y solo reservará 4 bytes de nuestro disco.
* `time`. Solo representa la hora y reservará 8 bytes de nuestro disco duro.
* `interval`. Representará un intervalo de tiempo y es muy útil para realizar cálculos, este tipo de datos van a reservar 16 bytes de nuestro disco.


## Tipos avanzados de datos
``