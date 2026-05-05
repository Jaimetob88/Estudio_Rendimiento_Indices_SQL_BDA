#Apartado 1
 -- en seccion b) el diagrama no aparece conectado ya que el dump que han pasado crea las tablas sin definir Pk's y Fk's
 
 -- c)
SELECT
	TABLE_NAME,
	TABLE_ROWS AS registros_aproximados,
	ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS tamano_MB
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'bda_p2'
ORDER BY TABLE_NAME ASC;

-- d)
SELECT *
FROM INFORMATION_SCHEMA.TABLE_constraints
WHERE TABLE_SCHEMA = 'bda_p2';

ALTER TABLE country DROP PRIMARY KEY; -- No se puede eliminar porque el Id del los paises esta hechocon un AUTO_INCREMENT
-- Para eliminar la PK hay que eliminar la propiedad autoincremental, y volver eliminar la Pk
ALTER TABLE country MODIFY `country_id` INT NOT NULL; 




#Apartado 2

-- a) 

-- COSTE SIN EXISTS: 1847083, tiempo 0,297
SELECT COUNT(emp_no) AS NEmpleados, city_id 
	FROM city_emp
		WHERE to_date = '9999-01-01' AND 
			city_id IN (SELECT ID 
						FROM city 
								WHERE country_id IN(SELECT country_id 
													FROM country 
                                                    WHERE code_iso3='DEU'))
					GROUP BY city_id
                    ORDER BY NEmpleados DESC;
                 
-- CON EXISTS: 1859304, 12221 más y tiempo 0,313
SELECT ce.city_id, COUNT(ce.emp_no) AS NEmpleados
FROM city_emp ce
WHERE ce.to_date = '9999-01-01' 
  AND EXISTS (
      SELECT 1
      FROM city c
      INNER JOIN country co ON c.country_id = co.country_id
      WHERE c.id = ce.city_id 
        AND co.code_iso3 = 'DEU'
  )
GROUP BY ce.city_id
ORDER BY NEmpleados DESC;

-- b)

/* El problema estructural: Al carecer de índices (PK y FK), MySQL no tiene "atajos" para encontrar la información. 
Está obligado a hacer Full Table Scans (escaneos completos), leyendo cada registro de city_emp, city y country una y otra vez.

El motor frente a IN vs EXISTS: Generalmente, sin índices, un EXISTS puede llegar a ser muy costoso 
porque se evalúa por cada fila de la consulta principal. */

-- c/d)

/* 
ANALYZE TABLE:Fuerza al optimizador a recalcular sus estadísticas y actualizar los metadatos.

OPTIMIZE TABLE: Reorganiza físicamente la tabla y desfragmenta el espacio en el disco para eliminar los espacios vacios de datos borrados.

Definitivamente, te conviene ejecutar ANALYZE TABLE en las tablas implicadas en tu consulta (city, country, city_emp).
Como solo has importado datos y no has borrado nada masivamente, no hay "huecos" que desfragmentar, por lo que OPTIMIZE TABLE no deberia aportar gran cosa ahora mismo. */

ANALYZE TABLE city,city_emp, country;-- SIN EXISTS: 1847083. CON:1859304 / IGUALES :(

-- SIN EXISTS: 1847083. CON:1859304 / IGUALES :( 
/*Como tus tablas todavía no tienen índices ni claves primarias, el Optimizador solo tiene una ruta posible: leer la tabla entera de arriba a abajo (Full Table Scan)*/

OPTIMIZE TABLE city,city_emp, country;-- SIN EXISTS: 1849... CON:186... / EMPEORA :(

/* . Como tus tablas no tienen una Clave Primaria (PK) definida, InnoDB las está manejando con un índice interno oculto. 
Al reconstruir la tabla, los datos se empaquetan en nuevas páginas de disco y se borran las cachés temporales. Esta nueva distribución física hace que la fórmula del optimizador 
(que suma el coste de leer bloques de disco y el uso de CPU) recalcule al alza, dándote un "Query Cost" mayor, ¡aunque la tabla esté más ordenada!# */



# APARTADO 3
-- COSTE Y SIN EXISTS: 144987; Se ha reducido en ambos casos y se han quedado las 2 consultas igual
/* 
Que ambas consultas (la de IN y la de EXISTS) tengan ahora exactamente el mismo coste no es casualidad.
El optimizador de MySQL moderno es muy inteligente: cuando analiza tu código, se da cuenta de que ambas consultas piden lógicamente lo mismo. 
Internamente, reescribe ambas sentencias utilizando una estrategia, generando exactamente el mismo plan de ejecución para las dos consultas.
El coste baja ya que INNODB hace INDICES PRIMARY con las PK's. 

Porque sigue habiendo FULL TABLE SCAN?
Si miramos las consultas, estás filtrando por condiciones como to_date = '9999-01-01' o code_iso3 = 'DEU', y estás uniendo tablas a través de columnas como country_id.
Como esas columnas no son la Clave Primaria, MySQL no tiene un "atajo" construido para ellas todavía, por lo que no le queda más remedio que seguir escaneando toda la tabla para encontrar esos valores.
*/

# APARTADO 4
-- COSTE Y SIN EXISTS: 16747; Se ha reducido en ambos casos y se han quedado las 2 consultas igual

SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'bda_p2' AND INDEX_NAME != 'PRIMARY';
/* ambas sentencias utilizando una estrategia la creacionde FK's a ayudado a que se use indices que crea en la tabla etc...

Cuando añades una Clave Foránea (FK) en MySQL (específicamente trabajando con el motor InnoDB, que es el estándar),
 el motor crea automáticamente un índice regular sobre la columna de esa clave foránea en la tabla "hija" si es que no existía uno previamente como puede ser el indice PRIMARY.
 
 Si la tabla es de clave compuesta el indice primary seran sus Apellidos/nombre por el orden de la PK si Apellidos es FK usara este indice cuando solo busque por apellidos sin nombre.
 
 ¿Que pasa si hay que buscar primero por el atributo nombre que es FK y PRIMARY no empiza por él?
 Que el indice PRIMARY no vale para nada, por lo que INNODB crea una INDICE por 'nombre' por si acaso se va acceder a esa tabla por su PK
*/

-- Ver restriccones (Pk's y Fk's)
SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE, TABLE_NAME 
FROM information_schema.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'bda_p2';

-- Para ver qué columnas forman esas restricciones
SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME 
FROM information_schema.KEY_COLUMN_USAGE 
WHERE TABLE_SCHEMA = 'bda_p2';

-- STADISTICS: Esta tabla guarda la información vital sobre los índices.
SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, SEQ_IN_INDEX, CARDINALITY 
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = 'bda_p2' AND TABLE_NAME = 'employee';

#APARTADO 5
-- SELECTIVIDAD, cuanto mas cerca de 1 mejor par un indice:
SELECT COUNT(DISTINCT date_of_termination)/(SELECT CARDINALITY
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'bda_p2'
AND table_name = 'employee') Selectividad
FROM employee;

-- SELECTIVIDAD y CARDINALIDAD del FROM city_emp  WHERE to_date = '9999-01-01' /// SELECTIVIDAD CASI 0 -> MUY MALO :(
SELECT 
    COUNT(DISTINCT to_date) AS Cardinalidad,
    ROUND(COUNT(DISTINCT to_date) / COUNT(*), 6) AS Selectividad
FROM city_emp;

-- SELECTIVIDAD y CARDINALIDAD del FROM  country  WHERE code_iso3 = 'DEU' /// SELECTIVIDAD 1 -> MUY BUENO
SELECT 
    COUNT(DISTINCT code_iso3) AS Cardinalidad,
    ROUND(COUNT(DISTINCT code_iso3) / COUNT(*), 6) AS Selectividad
FROM country;

-- SELECTIVIDAD y CARDINALIDAD del FROM  city_emp  WHERE city_id IN... ///Indice ya creado gracias a INNODB
SELECT 
    COUNT(DISTINCT city_id) AS Cardinalidad,
    ROUND(COUNT(DISTINCT city_id) / COUNT(*), 6) AS Selectividad
FROM city_emp;

-- SELECTIVIDAD y CARDINALIDAD del FROM city WHERE country_id IN...  ///Indice ya creado gracias a INNODB
SELECT 
    COUNT(DISTINCT country_id) AS Cardinalidad,
    ROUND(COUNT(DISTINCT country_id) / COUNT(*), 6) AS Selectividad
FROM city;

-- INDICES:
CREATE INDEX idx_to_date ON city_emp(to_date);
CREATE INDEX idx_code_iso3 ON country(code_iso3);

-- COSTE Y SIN EXISTS: 658.18; Se ha reducido en ambos casos y se han quedado las 2 consultas igual. El optimizador usa idx_code_iso3 pero ignora idx_to_date debida a su baja selectividad

-- Si forzamos el indice de la fecha de salida: FORCE INDEX (idx_to_date). El coste se va a lima proque es mucho mejor usar el indice city_id de FK

-- forzamos los unimos las tablas por su orden actual: STRAIGHT_JOIN. El coste se va a lima por razones como que los joins son peores que juntamos todas las tablas antes de hacer usar los indices con el where
SELECT ce.city_id, COUNT(ce.emp_no) AS NEmpleados
FROM city_emp ce
STRAIGHT_JOIN city c ON c.id = ce.city_id 
STRAIGHT_JOIN country co ON c.country_id = co.country_id
WHERE co.code_iso3 ='DEU' AND ce.to_date= '9999-01-01'
GROUP BY c.id ORDER BY NEmpleados DESC;

#APARTADO 6 
SELECT e.emp_no, concat(first_name, ' ', middle_names, ' ', last_name), AVG(salary) AS avg_salary
	FROM employee e inner join salary s on e.emp_no = s.emp_no
		where year(date_of_birth) = 1990
		and e.emp_no in (select emp_no
							from city_emp ce inner join city t on ce.city_id = t.id
								inner join country c on t.country_id = c.country_id
										where continent <> 'Europe' 
                                        OR continent <> 'Africa'
										and (c.population*1.1) > 1000000 
                                        and district like '%a')
			GROUP BY e.emp_no
				HAVING AVG(salary) > 50000;

-- Se obtiene el nº empledo, su nombre completo, su salario promedio de los empleados con mas de 50mil $ de salario promedio, 
-- que sean nacidos en 1990,  que no sean de europa, Y si lo son de europa, que no sean de africa (nunca lo van a ser), que el 110% de su poblacion sea mayor a 1 millon y que su distrito termine en a.


DROP INDEX idx_to_date ON city_emp;
DROP INDEX idx_code_iso3 ON country;

-- COSTE INICIAL: 1094760

-- Consulta optimizada:
SELECT e.emp_no, e.first_name, e.middle_names, e.last_name, AVG(s.salary) AS avg_salary
FROM employee e 
INNER JOIN salary s ON e.emp_no = s.emp_no
WHERE e.date_of_birth BETWEEN '1990-01-01' AND '1990-12-31'
  AND e.emp_no IN (
      SELECT ce.emp_no
      FROM city_emp ce 
      INNER JOIN city ci ON ce.city_id = ci.id
      INNER JOIN country c ON ci.country_id = c.country_id
      WHERE c.continent <> 'Europe' 
         OR (c.population > (1000000 / 1.1) AND ci.district LIKE '%a')
  )
GROUP BY e.emp_no
HAVING AVG(s.salary) > 50000;
-- COSTE DESPUES DE OPT DE CONSULTA: 104782 , muy reducido

-- INDICES ESTUDIO

SELECT 
    COUNT(DISTINCT date_of_birth) AS Cardinalidad,
    ROUND(COUNT(DISTINCT date_of_birth) / COUNT(*), 6) AS Selectividad
FROM employee;

SELECT 
    COUNT(DISTINCT population) AS Cardinalidad,
    ROUND(COUNT(DISTINCT population) / COUNT(*), 6) AS Selectividad
FROM country; -- > SELECTIVIDAD 0,9414 :) agregar indice

CREATE INDEX inx_population ON country(population);  -- no lo usa
CREATE INDEX idx_emp_birth ON employee(date_of_birth); -- Debido a que queremos que el optimzador la busqueda por rangos del indice en vez de FULL TABLE SCAN
-- COSTE DESPUES DE INDICES E OPT: 76242 se reducio aun más

# APARTADO 7

/* Como MySQL decidió empezar por los empleados (el bloque naranja de la izquierda), va avanzando de tabla en tabla a través de las Claves Foráneas (los rombos de nested loop).
Cuando el motor llega desde la ciudad (ci) hacia el país (c), ya sabe exactamente qué country_id está buscando para ese empleado en concreto.

Al tener el ID exacto, MySQL usa la Clave Primaria (PRIMARY) del país para ir directamente a esa única fila (por eso encima de la flecha pone "1 row"). Es la búsqueda más rápida que existe (instantánea).

Una vez que MySQL tiene esa fila del país en la mano usando la Clave Primaria, simplemente lee la columna de población y dice: "¿Es mayor que X? Sí/No". 
No necesita, ni puede, usar tu índice de población porque ya ha accedido a la fila a través de su Clave Primaria gracias al JOIN. */

-- 1. El índice no es selectivo (baja selectividad).
 /* Si el atributo tiene una selectividad terrible, como un indice sobre el fecha de fin de los EMPLEADOS, al solo tener 1 valores posibles su selectividad es muy mala:*/
SELECT 
    COUNT(DISTINCT date_of_termination) AS Cardinalidad,
    ROUND(COUNT(DISTINCT date_of_termination) / COUNT(*), 6) AS Selectividad
FROM employee; -- > CARDINALIDAD=1 , SELECTIVIDAD = 0  literalmente lo peor porque no hay manera de distinguir las filas ya que todas tienen el mismo valor en esta columna.

 /* Si creamos un indice para este atributo para que ayuda a filtrar los empleados por su fecha de fin, lo más seguro es que el optimizador pase del 
 culo del indice ya que le sale más a cuenta leer la tabla de forma normal o leer por la clave primaria para encontrar lo que quiere, que tener leer un incice que es casi la tabla entera */
 CREATE INDEX idx_date_of_termination ON employee(date_of_termination);
 
 SELECT e.emp_no, ci.district FROM employee e INNER JOIN city_emp ce ON e.emp_no=ce.emp_no  INNER JOIN city ci ON ce.city_id=ci.ID WHERE ci.District LIKE 'A%' AND e.date_of_termination='9999-01-01';
 
 DROP INDEX idx_date_of_termination ON employee;
 
 -- 2. La consulta devuelve un porcentaje demasiado alto de filas.
 
 /* Aunque el atributo sea genial y tenga una selectividad altísima (como la fecha de nacimiento), 
   si hacemos una consulta con un rango GIGANTE que incluya a casi todo el mundo, el 
   Optimizador pasará del índice. Leer el índice para acabar leyendo el 90% de la tabla a 
   "saltitos" es mucho más lento que escanear la tabla entera de golpe (Full Table Scan). */

-- Supongamos que tenemos creado el índice en date_of_birth (que tiene excelente selectividad)
-- CREATE INDEX idx_emp_birth ON employee(date_of_birth);

-- Si pedimos los nacidos después de 1900 (¡Básicamente toda la plantilla viva!): 
SELECT * FROM employee 
WHERE date_of_birth > '1900-01-01'; 

-- El 'type' saldrá como 'FULL TYPE SCAN' ignorando el índice, porque le estamos pidiendo casi toda la tabla.

-- Ahora si la consulta  se acota como por ejemplo los nacidos en 1990, ya si lo usara porque no va leer toda la tabala solo para 10% de la people
SELECT * FROM employee 
WHERE date_of_birth BETWEEN '1990-01-01'AND '1990-12-31'; 

-- 3. Uso de operaciones sobre columnas indexadas.
-- Para el indice: CREATE INDEX idx_population ON country(population)
/* Queremos saber las personas, donde la mitad de la poblacion de su pais sea superior a 10M de habitantes
 si la consulta la desarrolamos asi:*/

SELECT ce.emp_no, c.Name FROM city_emp ce INNER JOIN city ci ON ce.city_id=ci.ID INNER JOIN country c ON ci.country_id=c.country_id WHERE (c.population * 0.5) > 10000000;

/* Al multiplicar la poblacion por 0,5 nos cargamos que pueda usar su indice de buena selectividad. 
Pero tiene soluccion es despejar la operacion par tener el calculo sin operaciones sobre la poblacion:*/

SELECT ce.emp_no, c.Name FROM city_emp ce INNER JOIN city ci ON ce.city_id=ci.ID INNER JOIN country c ON ci.country_id=c.country_id WHERE c.population > (10000000*2);
-- ya usa el indice

-- 4. Funciones en columnas indexadas.

SELECT * FROM employee 
WHERE YEAR(date_of_birth)='1900'; -- al usar la funcion year impedimos que pueda usar el indice.

SELECT * FROM employee 
WHERE date_of_birth BETWEEN '1990-01-01'AND '1990-12-31';  -- al usar between le decimos al optimizador que use range index

-- 5. Uso del comodín (%) al principio de un LIKE.
-- Supongamos un índice: CREATE INDEX idx_district ON city(District);

/* Los índices B-Tree ordenan los textos alfabéticamente de izquierda a derecha.
   Si pones el comodín '%' al principio, le pides a MySQL: "busca lo que termine en 'a'". 
   El motor se queda ciego porque no sabe por qué letra empezar a buscar en el índice, 
   así que lo ignora y lee la tabla entera (Full Table Scan). */

-- MAL (Ignora el índice):
SELECT * FROM city WHERE District LIKE '%a';

-- BIEN (Sí usa el índice haciendo un 'Range Scan'):
SELECT * FROM city WHERE District LIKE 'A%'; 
-- DROP INDEX idx_district ON city;

-- 6. Uso de la cláusula OR en las condiciones.

/* El operador OR es el gran enemigo del Optimizador. Cuando usas un OR, 
   le estás diciendo a MySQL que la fila es válida si cumple una condición, 
   la otra, o ambas. 
   El problema ocurre si una de esas dos columnas NO tiene un índice creado. 
   MySQL razona así: "Tengo que leer la tabla entera de todas formas para buscar 
   esta columna sin índice, así que ignoraré también el índice de la otra columna 
   porque no me ahorra trabajo". El resultado es un Full Table Scan. */

-- MAL (Hace Full Table Scan si 'first_name' no tiene un índice, ignorando la PK emp_no):
SELECT * FROM employee 
WHERE emp_no = 10001  OR first_name = 'Georgi';

/* Una técnica clásica de optimización para "salvar" los índices cuando necesitas un OR 
   es reescribir la consulta dividiéndola en dos búsquedas independientes unidas por UNION. 
   De esta forma, MySQL evalúa cada bloque por separado y SÍ utiliza el índice 
   en la consulta de arriba. */

-- BIEN (Usa el índice de la PK para el primer bloque):
SELECT * FROM employee WHERE emp_no = 10001
UNION
SELECT * FROM employee WHERE first_name = 'Georgi';

-- 7. Consultas con ORDER BY y LIMIT.

/* Este es el famoso dilema de "Filtrar vs. Ordenar". Si le pides a MySQL que filtre 
   por una columna, pero que devuelva los datos ordenados por otra columna distinta 
   y limitando el resultado, el Optimizador puede ignorar el índice de filtrado. 
   ¿Por qué? Porque a veces calcula que es más rápido escanear toda la tabla usando 
   el índice de ordenación (para evitar hacer un "Filesort" en RAM) y simplemente 
   parar de leer cuando encuentre las primeras X filas que cumplan la condición. */

-- Supongamos que tenemos: CREATE INDEX idx_emp_birth ON employee(date_of_birth);
-- y que 'emp_no' es la Clave Primaria (y por tanto, ya está ordenada por defecto).

-- MAL (Ignora 'idx_emp_birth' y escanea usando la Primary Key buscando las 5 primeras): 
SELECT * FROM employee 
WHERE date_of_birth > '1950-01-01' 
AND date_of_hiring > '1990-01-01'
ORDER BY emp_no LIMIT 5;

/* SOLUCIÓN: Si vemos que se equivoca y hace un escaneo muy lento (ALL o Index Scan 
   completo), podemos obligarle a usar el índice de filtrado con FORCE INDEX (aunque seguramente empeore la consulta ya que tendra hacer un fileshort gigante,
   depues de haber cogido las personas que nacieron despues de 1950, ya es casi toda la tabla), o 
   lo mas OPTIMO ES, crear un índice compuesto que sirva para ambas cosas: (date_of_birth, date_of_hiring , emp_no). */
 
-- CREATE INDEX idx_date_of_birth_date_of_hiring_emp_no ON employee(date_of_birth, date_of_hiring, emp_no);
-- (Nota interna: Al ser InnoDB, la PK 'emp_no' ya se añade automáticamente al final del índice)
SELECT * FROM employee FORCE INDEX (idx_date_of_birth_date_of_hiring_emp_no) 
WHERE date_of_birth > '1950-01-01' 
AND date_of_hiring > '1990-01-01'
ORDER BY emp_no LIMIT 5; -- El coste empeora ¿PORQUE?


/* Al forzar a MySQL a  usar el índice y busca a los nacidos después de 1950 y contratados después de 1990. Como son fechas muy antiguas, resulta que 200.000 empleados cumplen esa condición.
Como le has pedido ORDER BY emp_no, ejecuta una operación Filesort pesadísima para ordenar esos 200.000 registros numéricamente, lo cual cuesta que no veas para luego una vez ordenados solo 
coge los 5 primeros de esos 200.000 empleados.

El optimizador por defecto ve que tenemos un ORDER BY emp_no LIMIT 5. Y sabe que la tabla física ya está ordenada perfectamente por emp_no (porque es la Clave Primaria).
Además, MySQL ve tus filtros (> 1950 y > 1990) y dice: "Oye, estadísticamente casi toda la plantilla cumple estas condiciones".
Así que MySQL empieza a leer la tabla por el principio (empleado #1, #2, #3...). Están ordenados gratis.
Lee el empleado #1: ¿Cumple las fechas? Sí. ¡Me lo guardo!
Lee el empleado #2: ¿Cumple las fechas? No, este es más viejo. Lo descarto.
Lee el empleado #3: ¿Cumple? Sí...

Sigue así, y como las condiciones de fecha son muy fáciles de cumplir, solo necesita leer unas 10 o 15 filas hasta encontrar a 5 primeras las personas que cumplan los filtros.*/

-- 8. Uso de LIKE con comodín al principio.

-- Supongamos un índice: CREATE INDEX idx_district ON city(District);

/* Los índices B-Tree son como diccionarios: ordenan los textos alfabéticamente 
   de izquierda a derecha. Si pones el comodín '%' al principio, le estás diciendo 
   a MySQL: "busca lo que termine en 'a'". El motor se queda totalmente ciego porque 
   no sabe por qué letra empezar a buscar en el índice, así que lo descarta y hace 
   un Full Table Scan leyendo todas las ciudades una a una. */

-- MAL (Ignora el índice porque no sabe por dónde empezar):
 
SELECT * FROM city WHERE District LIKE '%a';

/* SOLUCIÓN: Si los requisitos del negocio lo permiten, hay que buscar siempre 
   por prefijos colocando el comodín al final. Así MySQL va directo a la letra 
   correspondiente en el árbol del índice (haciendo un rápido Range Scan). */
 
SELECT * FROM city WHERE District LIKE 'A%';


# APARTADO 8

-- Copia la tabla de salary
CREATE TABLE salary_test LIKE salary;
-- Inserta 10.000 registros
INSERT INTO salary_test SELECT * FROM salary WHERE emp_no < 40000 LIMIT
10000;
-- Quedarse solamente con la clave primaria
SHOW INDEX FROM salary_test; -- Solo PRIMARY
-- INSERT masivo
INSERT INTO salary_test (emp_no, salary, from_date, to_date)
SELECT emp_no, salary+1000, from_date, to_date
FROM salary WHERE emp_no BETWEEN 12000 AND 22000;
-- UPDATE masivo
UPDATE salary_test SET salary = salary * 1.1 WHERE emp_no > 10000;
-- DELETE masivo
delete from salary_test where emp_no > 20000;

-- TIEMPOS /COSTE ANTES DE INDICES: 
-- Insert into: 0.156/111246
-- Insert 0.859/39902
-- update 0.859
-- delete 0.125

TRUNCATE TABLE salary_test;

CREATE INDEX idx_from_date ON salary_test(from_date);
CREATE INDEX idx_to_date ON salary_test(to_date);
CREATE INDEX idx_salary ON salary_test(salary);
CREATE INDEX idx_to_date_emp_no_salary ON salary_test(to_date, emp_no, salary);

-- TIEMPOS DESPUES DE INDICES: 
-- Insert into: 0.407
-- Insert 1.953
-- update 2.344
-- delete 0.469

# APARTADO 9
SELECT 
    e.emp_no, 
    e.date_of_birth, 
    e.first_name, 
    e.last_name, 
    e.gender, 
    e.date_of_hiring, 
    e.date_of_termination,
    c_actual.Name AS Pais_Actual, 
    COUNT(DISTINCT c_hist.country_id) AS Total_Paises
FROM employee e
-- CAMINO 1: Buscar solo el país ACTUAL
INNER JOIN city_emp ce_actual ON e.emp_no = ce_actual.emp_no AND ce_actual.to_date = '9999-01-01'
INNER JOIN city ci_actual ON ce_actual.city_id = ci_actual.ID
INNER JOIN country c_actual ON ci_actual.country_id = c_actual.country_id

-- CAMINO 2: Buscar TODO el historial para poder contarlo
INNER JOIN city_emp ce_hist ON e.emp_no = ce_hist.emp_no
INNER JOIN city ci_hist ON ce_hist.city_id = ci_hist.ID
INNER JOIN country c_hist ON ci_hist.country_id = c_hist.country_id

-- Ahora agrupamos por el empleado y su país actual. El COUNT se encarga de resumir el Camino 2.
GROUP BY 
    e.emp_no, 
    e.date_of_birth, 
    e.first_name, 
    e.last_name, 
    e.gender, 
    e.date_of_hiring, 
    e.date_of_termination,
    c_actual.Name;
-- Tiempo tardado: 2.735


-- DESNORMALIZACION:
CREATE TABLE employee_desnor LIKE employee;
INSERT INTO employee_desnor SELECT * FROM employee;

-- Añadir los atributos de la desnormalización a la tabla employee_desnor
ALTER TABLE employee_desnor ADD country_name_act VARCHAR (50);
ALTER TABLE employee_desnor ADD Tot_countries INT;

-- AÑADIR LOS DATOS:
UPDATE employee_desnor ed
INNER JOIN (
    -- Aquí metemos literalmente la consulta del apartado 9.a como si fuera una tabla virtual
    SELECT 
        e.emp_no, 
        c_actual.Name AS Pais_Actual, 
        COUNT(DISTINCT c_hist.country_id) AS Total_Paises
    FROM employee e
    INNER JOIN city_emp ce_actual ON e.emp_no = ce_actual.emp_no AND ce_actual.to_date = '9999-01-01'
    INNER JOIN city ci_actual ON ce_actual.city_id = ci_actual.ID
    INNER JOIN country c_actual ON ci_actual.country_id = c_actual.country_id
    INNER JOIN city_emp ce_hist ON e.emp_no = ce_hist.emp_no
    INNER JOIN city ci_hist ON ce_hist.city_id = ci_hist.ID
    INNER JOIN country c_hist ON ci_hist.country_id = c_hist.country_id
    GROUP BY e.emp_no, c_actual.Name
) AS datos_calculados ON ed.emp_no = datos_calculados.emp_no
SET 
    ed.country_name_act = datos_calculados.Pais_Actual,
    ed.tot_countries = datos_calculados.Total_Paises; -- 7.688s
  
-- Volver a hacer la consulta ahora desnormalizada:
SELECT * FROM bda_p2.employee_desnor;
-- Tiempo tardado: 0.000

-- GESTION DE COHERENCIA: TRIGGERS

-- 1. TRIGGER PARA CUANDO SE AÑADE UN NUEVO DESTINO (INSERT)
DELIMITER //
CREATE TRIGGER trg_city_emp_after_insert
AFTER INSERT ON city_emp
FOR EACH ROW
BEGIN
    -- Recalculamos los datos mágicos pero SOLO para el empleado afectado (NEW.emp_no)
    UPDATE employee_desnor 
    SET 
        country_name_act = (
            SELECT c.Name 
            FROM city_emp ce 
            INNER JOIN city ci ON ce.city_id = ci.ID 
            INNER JOIN country c ON ci.country_id = c.country_id 
            WHERE ce.emp_no = NEW.emp_no AND ce.to_date = '9999-01-01' 
            LIMIT 1
        ),
        tot_countries = (
            SELECT COUNT(DISTINCT ci.country_id) 
            FROM city_emp ce 
            INNER JOIN city ci ON ce.city_id = ci.ID 
            WHERE ce.emp_no = NEW.emp_no
        )
    WHERE emp_no = NEW.emp_no;
END //
DELIMITER ;


-- 2. TRIGGER PARA CUANDO SE MODIFICA UN DESTINO (UPDATE)
-- (Por ejemplo, cuando to_date pasa de '9999-01-01' a una fecha pasada)
DELIMITER //
CREATE TRIGGER trg_city_emp_after_update
AFTER UPDATE ON city_emp
FOR EACH ROW
BEGIN
    UPDATE employee_desnor 
    SET 
        country_name_act = (
            SELECT c.Name 
            FROM city_emp ce 
            INNER JOIN city ci ON ce.city_id = ci.ID 
            INNER JOIN country c ON ci.country_id = c.country_id 
            WHERE ce.emp_no = NEW.emp_no AND ce.to_date = '9999-01-01' 
            LIMIT 1
        ),
        tot_countries = (
            SELECT COUNT(DISTINCT ci.country_id) 
            FROM city_emp ce 
            INNER JOIN city ci ON ce.city_id = ci.ID 
            WHERE ce.emp_no = NEW.emp_no
        )
    WHERE emp_no = NEW.emp_no;
END //
DELIMITER ;


-- 3. TRIGGER PARA CUANDO SE BORRA UN DESTINO (DELETE)
-- (Nota: Aquí usamos OLD.emp_no porque la fila nueva ya no existe)
DELIMITER //
CREATE TRIGGER trg_city_emp_after_delete
AFTER DELETE ON city_emp
FOR EACH ROW
BEGIN
    UPDATE employee_desnor 
    SET 
        country_name_act = (
            SELECT c.Name 
            FROM city_emp ce 
            INNER JOIN city ci ON ce.city_id = ci.ID 
            INNER JOIN country c ON ci.country_id = c.country_id 
            WHERE ce.emp_no = OLD.emp_no AND ce.to_date = '9999-01-01' 
            LIMIT 1
        ),
        tot_countries = (
            SELECT COUNT(DISTINCT ci.country_id) 
            FROM city_emp ce 
            INNER JOIN city ci ON ce.city_id = ci.ID 
            WHERE ce.emp_no = OLD.emp_no
        )
    WHERE emp_no = OLD.emp_no;
END //
DELIMITER ;


SELECT emp_no, country_name_act, tot_countries 
FROM employee_desnor 
WHERE emp_no = 10001;-- AHORA VIVE EN RUSSIA

-- Cerramos su etapa anterior
UPDATE city_emp 
SET to_date = '2026-04-23' 
WHERE emp_no = 10001 AND to_date = '9999-01-01';
-- Le asignamos una nueva ciudad (MADRID) como su trabajo actual (9999-01-01)
INSERT INTO city_emp (emp_no, city_id, from_date, to_date)
VALUES (10001, 653, '2026-04-23', '9999-01-01');





# APARTADO 10

-- 1. Creamos la tabla clonada pero con particiones de 5 en 5 años [cite: 136]
CREATE TABLE salary_part (
    emp_no INT NOT NULL,
    salary INT NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    PRIMARY KEY (emp_no, from_date) 
)
PARTITION BY RANGE (YEAR(from_date)) (
    PARTITION p0 VALUES LESS THAN (1990),
    PARTITION p1 VALUES LESS THAN (1995),
    PARTITION p2 VALUES LESS THAN (2000),
    PARTITION p3 VALUES LESS THAN (2005),
    PARTITION p4 VALUES LESS THAN (2010),
    PARTITION p5 VALUES LESS THAN (2015),
    PARTITION p6 VALUES LESS THAN (2020),
    PARTITION p7 VALUES LESS THAN (2025),
    PARTITION p8 VALUES LESS THAN (2030),
    PARTITION p_max VALUES LESS THAN MAXVALUE
);

-- 2. Insertamos todos los datos de la tabla original a la particionada [cite: 137]
-- (Esto puede tardar un poco dependiendo del volumen de datos)
INSERT INTO salary_part SELECT * FROM salary; 

-- CONSULTAS:
-- Consulta 1: Salarios entre '2010-01-01' y '2025-08-01' [cite: 141]
-- Magia: MySQL leerá solo las particiones p5, p6, p7 y p8.
 SELECT * FROM salary_part WHERE from_date BETWEEN '2010-01-01' AND '2025-08-01'; 

-- Consulta 2: Salarios de los años 2025 y 2026 [cite: 142]
-- Magia: MySQL leerá ÚNICAMENTE la partición p8.
 SELECT * FROM salary_part 
WHERE YEAR(from_date) IN (2025, 2026); 
-- (Mejor aún sin funciones): WHERE from_date BETWEEN '2025-01-01' AND '2026-12-31'

-- Consulta 3: Salarios superiores a 70000 [cite: 143]
-- EL TRAMPÓN: Como no filtras por fecha (from_date), MySQL no sabe en qué cajón buscar. 
-- Tendrá que leer TODAS las particiones. ¡Aquí el particionamiento no ayuda nada!
 SELECT * FROM salary_part 
WHERE salary > 70000; 

-- Consulta 4: Salarios superiores a 70000 en años 3035 y 2026 [cite: 144]
-- (Por cierto, ese '3035' de tu PDF tiene toda la pinta de ser una errata del profe 😂, 
-- pero se lo ponemos literal) [cite: 144]
-- Magia: Hará la poda y solo mirará en p8 (año 2026) y en p_max (año 3035).
 SELECT * FROM salary_part 
WHERE salary > 70000 
  AND YEAR(from_date) IN (3035, 2026); 
  
  
  
  
  

# APARTADO 11: CONSULTAS

-- 1. Obtener, sin duplicados, el nombre de los países que tienen trabajadores en activo. Plantea una solución con distinct y otra con EXISTS. 

SELECT DISTINCT co.Name 
		FROM country co 
                INNER JOIN city ci ON co.country_id=ci.country_id
                INNER JOIN city_emp ce ON ci.ID=ce.city_id 
					WHERE ce.to_date='9999-01-01';

SELECT co.Name 
	FROM country co 
		WHERE EXISTS (
			SELECT 1 
				FROM city ci 
				INNER JOIN city_emp ce ON ci.ID = ce.city_id 
					WHERE ci.country_id = co.country_id   -- ¡Esta es la conexión mágica!
						AND ce.to_date = '9999-01-01');


-- 2. Obtener empleados (sus tres campos de nombre separados por un espacio en blanco) que hayan trabajado en Sevilla y en Cádiz (en las dos).

SELECT e.emp_no, CONCAT(e.first_name, ' ', e.last_name) AS nombre_completo
	FROM employee e
		WHERE EXISTS (
				SELECT 1 FROM city_emp ce 
				INNER JOIN city ci ON ce.city_id = ci.ID
				WHERE ce.emp_no = e.emp_no AND ci.Name = 'Sevilla')
		AND EXISTS (
				SELECT 1 FROM city_emp ce 
				INNER JOIN city ci ON ce.city_id = ci.ID
				WHERE ce.emp_no = e.emp_no AND ci.Name = 'Cadiz');





-- 3. Para aquellos empleados que nunca hayan trabajado en Europa (Europe) obtener aquel que haya
-- trabajado en más ciudades no europeas con población inferior a 1000 habitantes. Para obtener el
-- máximo plantea una solución con Having con >=ALL y otra sin Having pero con LIMIT

SELECT 
    e.emp_no, 
    CONCAT_WS(' ', e.first_name, e.middle_names, e.last_name) AS empleado,
    COUNT(DISTINCT ce.city_id) AS total_ciudades
FROM employee e
INNER JOIN city_emp ce ON e.emp_no = ce.emp_no
INNER JOIN city ci ON ce.city_id = ci.ID
INNER JOIN country c ON ci.country_id = c.country_id
WHERE c.Continent != 'Europe' -- No necesario ya que con el not exists nunca se va a dar esta condicion
  AND ci.Population < 1000
  AND NOT EXISTS (
      SELECT 1 FROM city_emp ce_euro
      INNER JOIN city ci_euro ON ce_euro.city_id = ci_euro.ID
      INNER JOIN country c_euro ON ci_euro.country_id = c_euro.country_id
      WHERE ce_euro.emp_no = e.emp_no AND c_euro.Continent = 'Europe'
  )
GROUP BY e.emp_no, empleado
HAVING COUNT(DISTINCT ce.city_id) >= ALL (
    -- Subconsulta para sacar la lista con los totales del resto de empleados 
    -- (Ojo, hay que repetir todo el bloque WHERE)
    SELECT COUNT(DISTINCT ce2.city_id)
    FROM employee e2
    INNER JOIN city_emp ce2 ON e2.emp_no = ce2.emp_no
    INNER JOIN city ci2 ON ce2.city_id = ci2.ID
    INNER JOIN country c2 ON ci2.country_id = c2.country_id
    WHERE c2.Continent != 'Europe' 
      AND ci2.Population < 1000
      AND NOT EXISTS (
          SELECT 1 FROM city_emp ce3
          INNER JOIN city ci3 ON ce3.city_id = ci3.ID
          INNER JOIN country c3 ON ci3.country_id = c3.country_id
          WHERE ce3.emp_no = e2.emp_no AND c3.Continent = 'Europe'
      )
    GROUP BY e2.emp_no
);




SELECT 
    e.emp_no, 
    CONCAT_WS(' ', e.first_name, e.middle_names, e.last_name) AS empleado,
    COUNT(DISTINCT ce.city_id) AS total_ciudades
FROM employee e
INNER JOIN city_emp ce ON e.emp_no = ce.emp_no
INNER JOIN city ci ON ce.city_id = ci.ID
INNER JOIN country c ON ci.country_id = c.country_id
WHERE NOT EXISTS (
	SELECT 1 FROM city_emp ce_euro
      INNER JOIN city ci_euro ON ce_euro.city_id = ci_euro.ID
      INNER JOIN country c_euro ON ci_euro.country_id = c_euro.country_id
      WHERE ce_euro.emp_no = e.emp_no AND c_euro.Continent = 'Europe')
AND ci.Population < 1000 
GROUP BY e.emp_no, empleado ORDER BY total_ciudades DESC LIMIT 1;








