drop table if EXISTS `sequence`;

CREATE TABLE `sequence` (
`name` VARCHAR ( 50 )  NOT NULL COMMENT '序列的名字',
`current_value` INT ( 8 ) NOT NULL COMMENT '序列的当前值',
`current_text` VARCHAR ( 19 ) NOT NULL COMMENT '序列的当前字符串2018-07-30-12345678',
`increment` INT ( 8 ) NOT NULL DEFAULT '1' COMMENT '序列的自增值',
`fmt` VARCHAR(19)  DEFAULT '%Y-%m-%d-' COMMENT '序列格式',
`initial_text` VARCHAR(19)  DEFAULT '0000-00-00-12345678' COMMENT '初始值',
PRIMARY KEY ( `name` ) 
);

show variables like 'log_bin_trust_function_creators';
set global log_bin_trust_function_creators=1;

-- 创建返回当前(包含日期格式的唯一自增ID)的函数
DROP FUNCTION IF EXISTS currval; 
DELIMITER $ 
CREATE FUNCTION currval (seq_name VARCHAR(50)) 
     RETURNS VARCHAR(19)
BEGIN 
     DECLARE val VARCHAR(19);
     DECLARE fmt_text VARCHAR(19);
		 SELECT fmt into fmt_text from sequence where `name` = seq_name;
     -- SET val = '0000-00-00-12345678';
		 SELECT initial_text into val from sequence where `name` = seq_name;
		 select date_format(now(), CONCAT(fmt_text, '00000000')) into val;
     SELECT current_text INTO val 
          FROM sequence 
          WHERE `name` = seq_name; 
     RETURN val; 
END
$
DELIMITER ; 

-- 创建返回下一个(包含日期格式的唯一自增ID)的函数
DROP FUNCTION IF EXISTS nextval; 
DELIMITER $ 
CREATE FUNCTION nextval (seq_name VARCHAR(50)) 
     RETURNS VARCHAR(19)
BEGIN 
     DECLARE fmt_text VARCHAR(19);
		 SELECT fmt into fmt_text from sequence where `name` = seq_name;
     UPDATE sequence 
          SET current_value = current_value + increment, current_text =  CONCAT(date_format(now(), fmt_text), LPAD(current_value, 8 , 0))
          WHERE name = seq_name;
     RETURN currval(seq_name); 
END 
$
DELIMITER ; 


-- 创建返回更新(包含日期格式的唯一自增ID)的函数
DROP FUNCTION IF EXISTS setval;

DELIMITER $
CREATE FUNCTION setval (seq_name VARCHAR(50), val INTEGER, inc INTEGER, fmt_text VARCHAR(19), init_text VARCHAR(19)) 
     RETURNS VARCHAR(19) 
BEGIN
		 -- 处理表原来的数据		 
		 DELETE from sequence where `name`=seq_name;
     INSERT INTO sequence(`name`, `current_value`, `current_text`, `increment`, `fmt`, `initial_text`)
          value(seq_name, val, CONCAT(date_format(now(), fmt_text), LPAD(val, 8 , 0)), inc, fmt_text, init_text);
     
		 RETURN currval(seq_name); 
END 
$ 
DELIMITER ;


-- 设置超限触发器
DROP TRIGGER IF EXISTS trig_sequence;
DELIMITER $
create trigger trig_sequence BEFORE UPDATE on sequence for each row
begin
     DECLARE fmt_text VARCHAR(19);
		 SELECT fmt into fmt_text from sequence where `name` = NEW.`name`;
		 if new.current_value+new.increment > 99999999 then
			 set NEW.current_value = 0;
			 set NEW.current_text = CONCAT(date_format(now(), fmt_text), LPAD(0, 8 , 0));
		 end if;
END 
$ 
DELIMITER ;

-- 设置指定sequence的初始值
drop PROCEDURE IF EXISTS init_sequence;
CREATE PROCEDURE init_sequence()
BEGIN
	DECLARE seq_name VARCHAR(40);
	
	-- 初始化flight表序列
	set seq_name =  'flight_seq';
	SELECT SETVAL(seq_name, 0, 1, '%Y-%m-%d-', '0000-00-00-12345678');
	SELECT CURRVAL(seq_name);
	SELECT NEXTVAL(seq_name);
	
	-- 初始化QAR表序列
	set seq_name =  'qar_seq';
	SELECT SETVAL(seq_name, 0, 1, '%Y%m%d-', '00000000-12345678');
	SELECT CURRVAL(seq_name);
	SELECT NEXTVAL(seq_name);
END

-- 执行初始化存储过程
CALL init_sequence();

--测试最大值
SELECT SETVAL('flight_seq', 99999998, 1, '%Y-%m-%d-', '0000-00-00-12345678');
SELECT NEXTVAL('flight_seq');

SELECT SETVAL('qar_seq', 99999999, 1, '%Y%m%d-', '00000000-12345678');
SELECT NEXTVAL('qar_seq');
