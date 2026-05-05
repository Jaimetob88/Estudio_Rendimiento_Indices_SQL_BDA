### APARTADO 3. Creación de las claves primarias
### Practica 2 - BDA - curso 25-26

USE bda_p2;
 
ALTER TABLE country   		MODIFY country_id int not null auto_increment PRIMARY  KEY;
ALTER TABLE department 		ADD PRIMARY  KEY (dept_no);
ALTER TABLE dept_emp 		ADD PRIMARY  KEY (emp_no, dept_no, from_date);
ALTER TABLE dept_manager 	ADD PRIMARY  KEY (emp_no, dept_no, from_date);
ALTER TABLE employee 		ADD PRIMARY  KEY (emp_no);
ALTER TABLE city 			ADD PRIMARY  KEY (id);
ALTER TABLE city_emp 		ADD PRIMARY  KEY (emp_no, city_iD, from_date);
ALTER TABLE salary  		ADD PRIMARY  KEY (emp_no, from_date);
ALTER TABLE salary_group 	ADD PRIMARY  KEY (sg_no, from_date);
ALTER TABLE sg_emp   		ADD PRIMARY  KEY (emp_no, sg_no, from_date);
ALTER TABLE titles     		ADD PRIMARY  KEY (emp_no, title, from_date);

-- Consulta al catalogo para comprobar que se han creado las PK
SELECT 
    TABLE_NAME,
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'bda_p2_19k' 
  AND CONSTRAINT_TYPE ='PRIMARY KEY';
  
