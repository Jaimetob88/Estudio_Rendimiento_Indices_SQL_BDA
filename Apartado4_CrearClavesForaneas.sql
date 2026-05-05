### APARTADO 4. Creación de las claves foraneas
### Practica 2 - BDA - curso 25-26

USE bda_p2;

ALTER TABLE dept_emp 		ADD FOREIGN KEY (emp_no) REFERENCES employee(emp_no) ON DELETE CASCADE;
ALTER TABLE dept_emp 		ADD FOREIGN KEY (dept_no) REFERENCES department(dept_no) ON DELETE CASCADE;
ALTER TABLE dept_manager 	ADD FOREIGN KEY (emp_no) REFERENCES employee(emp_no) ON DELETE CASCADE;
ALTER TABLE dept_manager 	ADD FOREIGN KEY (dept_no) REFERENCES department(dept_no) ON DELETE CASCADE;
ALTER TABLE city 			ADD FOREIGN KEY (country_id) REFERENCES country (country_id) ON DELETE CASCADE;
ALTER TABLE city_emp 		ADD FOREIGN KEY (emp_no) REFERENCES employee (emp_no) ON DELETE CASCADE;
ALTER TABLE city_emp 		ADD FOREIGN KEY (city_id)  REFERENCES city (id) ON DELETE CASCADE;
ALTER TABLE salary 			ADD FOREIGN KEY (emp_no) REFERENCES employee (emp_no) ON DELETE CASCADE;
ALTER TABLE sg_emp 			ADD FOREIGN KEY (emp_no) REFERENCES employee (emp_no) ON DELETE CASCADE;
ALTER TABLE sg_emp 			ADD FOREIGN KEY (sg_no)  REFERENCES salary_group (sg_no) ON DELETE CASCADE;
ALTER TABLE titles			ADD FOREIGN KEY (emp_no) REFERENCES employee (emp_no) ON DELETE CASCADE;



