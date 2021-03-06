CREATE DATABASE IF NOT EXISTS Jenssalon;
USE Jenssalon;
START TRANSACTION;
/*************************************************************/
	/*BASE TABLES*/

CREATE TABLE IF NOT EXISTS Branch (
    branchId INT AUTO_INCREMENT NOT NULL,
    street VARCHAR(25),
    town VARCHAR(25),
    county VARCHAR(25),
    eirCode VARCHAR(7) NOT NULL,
    contactNumber INT,
    emailAddress VARCHAR(25),
    PRIMARY KEY (branchId)
);

CREATE TABLE IF NOT EXISTS Employee (
    employeeId INT AUTO_INCREMENT,
    fName VARCHAR(25),
    lName VARCHAR(25),
    street VARCHAR(25),
    town VARCHAR(25),
    county VARCHAR(25),
    eirCode VARCHAR(7) NOT NULL,
    contactNumber INT,
    emailAddress VARCHAR(50),
    position ENUM('Stylist', 'Manager', 'PT_Stylist') NOT NULL,
    startDate DATE DEFAULT '2020-01-01',
    managerEmpId INT,
    branchId INT,
    PRIMARY KEY (employeeId),
    CONSTRAINT fk_branchId FOREIGN KEY (branchId)
        REFERENCES Branch (branchId)
        ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_mgrId FOREIGN KEY (managerEmpId)
        REFERENCES Employee (employeeId)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS Customer (
    customerId INT AUTO_INCREMENT NOT NULL,
    fName VARCHAR(25) NOT NULL,
    lName VARCHAR(25) NOT NULL,
    contactNumber INT NOT NULL,
    PRIMARY KEY (customerId)
);

CREATE TABLE IF NOT EXISTS familyMember (
    employeeId INT NOT NULL,
    customerId INT NOT NULL,
    relationship VARCHAR(25),
    discountRate DECIMAL(2 , 2 ),
    UNIQUE (employeeId , customerId),
    PRIMARY KEY (employeeId , customerId),
    CONSTRAINT fk_employeeId FOREIGN KEY (employeeId)
        REFERENCES Employee (employeeId)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT fk_familyCustId FOREIGN KEY (customerId)
        REFERENCES Customer (customerId)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS fullTimeEmployee (
    employeeId INT,
    salary DECIMAL(7 , 2 ),
    pensionContribution DECIMAL(2 , 2 ),
    PRIMARY KEY (employeeId),
    CONSTRAINT fk_ftEmployeeId FOREIGN KEY (employeeId)
        REFERENCES Employee (employeeId)
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS partTimeEmployee (
    employeeId INT,
    hourlyRate DECIMAL(4 , 2 ),
    PRIMARY KEY (employeeId),
    CONSTRAINT fk_ptEmployeeId FOREIGN KEY (employeeId)
        REFERENCES Employee (employeeId)
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Appointment (
    appointmentId INT AUTO_INCREMENT NOT NULL,
    appointmentTime TIME NOT NULL,
    appointmentDate DATE NOT NULL,
    service ENUM('Wash,blowdry', 'Wash,Cut,Blowdry', 'Colour') NOT NULL,
    customerId INT,
    PRIMARY KEY (appointmentId),
    CONSTRAINT fk_customerId FOREIGN KEY (customerId)
        REFERENCES Customer (customerId)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS worksOn (
    employeeId INT,
    appointmentId INT,
    duration INT,
    PRIMARY KEY (employeeId , appointmentId),
    CONSTRAINT fk_wrkEmployeeId FOREIGN KEY (employeeId)
        REFERENCES Employee (employeeId)
        ON UPDATE CASCADE,
    CONSTRAINT fk_wrkAppointmentId FOREIGN KEY (appointmentId)
        REFERENCES Appointment (appointmentId)
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Supplier (
    supplierId INT AUTO_INCREMENT NOT NULL,
    companyName VARCHAR(25),
    street VARCHAR(25),
    town VARCHAR(25),
    county VARCHAR(25),
    eirCode VARCHAR(7) NOT NULL,
    contactNumber INT NOT NULL,
    emailAddress VARCHAR(50) NOT NULL,
    PRIMARY KEY (supplierId)
);

CREATE TABLE IF NOT EXISTS Product (
    productid INT AUTO_INCREMENT NOT NULL,
    description VARCHAR(255) NOT NULL,
    stockQuantity INT,
    unitcost DECIMAL(5 , 2 ),
    supplierId INT NOT NULL,
    PRIMARY KEY (productId),
    CONSTRAINT fk_supplierId FOREIGN KEY (supplierId)
        REFERENCES Supplier (supplierId)
        ON UPDATE CASCADE
);


CREATE TABLE IF NOT EXISTS appointmentUses (
    appointmentId INT NOT NULL,
    productid INT NOT NULL,
    productQuantity  DECIMAL(3 , 2 ),
    PRIMARY KEY (appointmentId , productId),
    CONSTRAINT fk_productid FOREIGN KEY (productid)
        REFERENCES Product (productid)
        ON UPDATE CASCADE,
    CONSTRAINT fk_appointmentId FOREIGN KEY (appointmentId)
        REFERENCES Appointment (appointmentId)
        ON UPDATE CASCADE
);

/*************************************************************/


/********************TRIGGER CONFIG*******************************/
-- Log tables for triggers
CREATE TABLE IF NOT EXISTS FTEmpSalaryChangeLOG (
	id INT auto_increment,
    employeeId INT NOT NULL,
    previousSalary DECIMAL(7 , 2 ),
    changeDate DATETIME DEFAULT NULL,
    action VARCHAR(50) DEFAULT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS PTEmpRateChangeLOG (
	id INT auto_increment,
    employeeId INT NOT NULL,
    previousHourlyRate DECIMAL(7 , 2 ),
    changeDate DATETIME DEFAULT NULL,
    action VARCHAR(50) DEFAULT NULL,
	PRIMARY KEY (id)
);


-- Product price change
CREATE TABLE IF NOT EXISTS productPriceChangeLOG (
	id INT auto_increment,
    productid INT NOT NULL,
    unitCostOld DECIMAL(7 , 2 ),
    lastPriceChange DECIMAL(7 , 2 ),
    changeDate DATETIME DEFAULT NULL,
    action VARCHAR(50) DEFAULT NULL,
    PRIMARY KEY (id)
);

-- Triggers enforcing maintenance of salary and payscale log
-- Drop trigger if exists. Prevents error on DDL RUN
DROP TRIGGER IF EXISTS beforeSalaryChange;
DELIMITER $$
CREATE TRIGGER  beforeSalaryChange
	AFTER UPDATE ON fullTimeEmployee
    FOR EACH ROW
BEGIN
	INSERT INTO FTEmpSalaryChangeLOG
    SET action ='update',
		employeeId = OLD.employeeId,
		previousSalary = OLD.salary,
		changeDate = NOW();
END $$
DELIMITER ;

-- Drop trigger if exists. Prevents error on DDL RUN
DROP TRIGGER IF EXISTS beforeRateChange;
DELIMITER $$
CREATE TRIGGER beforeRateChange
	BEFORE UPDATE ON partTimeEmployee
    FOR EACH ROW
BEGIN
	INSERT INTO PTEmpRateChangeLOG
    SET action ='update',
		employeeId = OLD.employeeId,
		previousHourlyRate = OLD.hourlyRate,
		changeDate = NOW();
END $$
DELIMITER ;

-- Trigger monitoring product unit cost change
-- Drop trigger if exists. Prevents error on DDL RUN
DROP TRIGGER IF EXISTS beforePriceChange;
DELIMITER $$
CREATE TRIGGER beforePriceChange
	before UPDATE ON Product
    FOR EACH ROW
BEGIN
	INSERT INTO productPriceChangeLOG
    SET action ='update',
		productid = OLD.productid,
		unitCostOld = OLD.unitcost,
        lastPriceChange = ((OLD.unitcost-NEW.unitcost)*-1),
		changeDate = NOW();
END $$
DELIMITER ;
/*************************************************************/


/**********STORED PROCEDURES************/
-- Updates the price of all products
DROP PROCEDURE IF EXISTS productPriceChangeSp;
DELIMITER $$
CREATE PROCEDURE productPriceChangeSp(
	priceChange DECIMAL(5 , 2 )
    )
BEGIN
	update product SET unitCost = cast(unitCost * priceChange as DECIMAL(5 , 2 ));
END $$
DELIMITER ;

-- Stored procedure to update full time employee salary using employee Id
DROP PROCEDURE IF EXISTS ftEmpSalChangeSp;
DELIMITER $$
CREATE PROCEDURE ftEmpSalChangeSp(
    empId int,
	newSalary DECIMAL(7 , 2 )
    )
BEGIN
	update fulltimeemployee SET salary = newSalary
    where employeeId = empId; 
END $$
DELIMITER ;

-- Stored procedure to update part time employee pay rate using employee Id
DROP PROCEDURE IF EXISTS ptEmpRateChangeSp;
DELIMITER $$
CREATE PROCEDURE ptEmpRateChangeSp(
    empId int,
	newHourlyRate DECIMAL(4 , 2 )
    )
BEGIN
	update parttimeemployee SET hourlyRate = newHourlyRate
    where employeeId = empId; 
END $$
DELIMITER ;
/************************************/



/**********VIEWS************/
-- View all appointments and related data
CREATE OR REPLACE VIEW customerAppointmentVw AS
SELECT 
appointmentDate, appointmentTime, service, cus.fName as'customerFName', cus.lName as'customerLName', cus.contactNumber, 
duration, emp.fname as 'employeeFName', emp. lname as 'employeeLName', bch.town
from appointment apt
join customer cus on cus.customerId=apt.customerId
join workson wrk on wrk.appointmentId = apt.appointmentId
join employee emp on emp.employeeId = wrk.employeeId
join branch bch on bch.branchId = emp.branchId
join appointmentuses aptuse on aptuse.appointmentId = apt.appointmentId
order by appointmentDate, appointmentTime, 'customerFName';

-- View all employees and pay data and benefits
CREATE OR REPLACE VIEW employeeVw AS
SELECT 
emp.employeeId, emp.fname, emp.lName, emp.contactNumber, position, hourlyRate, 
salary, pensionContribution
from employee emp
left join fulltimeemployee fte on emp.employeeId = fte.employeeId
left join parttimeemployee pte on emp.employeeId = pte.employeeId
order by position asc, salary desc, emp.lName asc;

-- Part time employees, hours worked  from beginning of month to current date
CREATE OR REPLACE VIEW ptEmpHoursVw AS
SELECT 
employeeId, fname, lName, contactNumber, position, hourlyRate, duration
from employee emp
natural join parttimeemployee pte
natural join workson
natural join appointment
where (appointmentDate between  DATE_FORMAT(NOW() ,'%Y-%m-01') AND NOW() )
group by employeeId
order by position asc, lName asc;

-- Employee family member discount data view
CREATE OR REPLACE VIEW empFamilyVw AS
SELECT 
emp.employeeId, emp.fname, emp.lName, emp.contactNumber, position , cus.fName as cusfName, cus.lName as cuslName,
cus.contactNumber as cuslContact, relationship, discountRate
from employee emp
left join familymember fam on fam.employeeId = emp.employeeId
left join customer cus on cus.customerId = fam.customerId;
/************************************/



/**********INDEX************/
 CREATE INDEX customerLastNameIdx
  ON customer (lName ASC);
  
CREATE INDEX appointmentDateIdx
  ON appointment (appointmentDate ASC);
/************************************/



/*****************************************************/
/*****************INSERT STATEMENTS*******************/
/*****************************************************/
insert into branch (street, town, county, eirCode, contactNumber, emailAddress) values 
('Woodland Road','Mooncoin','Kilkenny','H23FE45','0834567891','Mooncoin@Jsalon.com'),
('Oakwood Road','Thurles','Tipperary','P24HW12','0831239921','Thurles@Jsalon.com'),
('Beech Close','Ferrybank','Waterford','P14FF42','0831261337','Ferrybank@Jsalon.com');


insert into employee (fName, lName, street, town, county, eirCode, contactNumber, emailAddress, position, startDate,branchId) values 
('Jo' , 'Betts' , 'Woodstock Road' , 'Lowfield Bottom' , 'Kilkenny' , 'P32OK73' , '539135916' , 'JoBetts@jensalon.com','Manager','2006-02-1','1'),
('Maizie' , 'Lyon' , 'Wren Close' , 'Jesmond Fairway' , 'Tipperary' , 'T23OK68' , '419823605' , 'MaizieLyon@jensalon.com','Manager','2011-01-16','2'),
('Teigan' , 'Davenport' , 'Hall Lane' , 'Harper Crescent' , 'Waterford' , 'T12067' , '1890948982' , 'TeiganDavenport@jensalon.com','Manager','2004-08-17','3');
insert into employee (fName, lName, street, town, county, eirCode, contactNumber, emailAddress, position, startDate,branchId,managerEmpId) values 
('Syeda' , 'Hope' , 'Whitehall Road' , 'Kenmore Las' , 'Tipperary' , 'H23TY84' , '0719855856' , 'SyedaHope@jensalon.com','Stylist','2008-11-9','1','1'),
('Amirah' , 'Bray' , 'Beech Grove' , 'Shetland Terrace' , 'Waterford' , 'T56FE73' , '0288774818' , 'AmirahBray@jensalon.com','Stylist','2004-02-22','1','1'),
('Amirah' , 'Taylor' , 'Poplar Close' , 'Admirals Hey' , 'Tipperary' , 'H16073' , '429376140' , 'AmirahTaylor@jensalon.com','PT_Stylist','2006-12-7','1','1'),
('Amy-Louise' , 'Richardson' , 'Heather Close' , 'Rothesay Villas' , 'Tipperary' , 'P14075' , '539135916' , 'Amy-LouiseRichardson@jensalon.com','Stylist','2014-12-17','2','2'),
('Siena' , 'Aldred' , 'Nightingale Close' , 'Kennet Crescent' , 'Waterford' , 'P24TR59' , '0667121530' , 'SienaAldred@jensalon.com','Stylist','2007-10-15','2','2'),
('Jamie-Leigh' , 'Faulkner' , 'Meadow Lane' , 'Kings Royd' , 'Waterford' , 'T12GF0' , '0484066211' , 'Jamie-LeighFaulkner@jensalon.com','Stylist','2005-08-12','2','2'),
('Gurleen' , 'Salas' , 'Whitehall Road' , 'Northampton Square' , 'Kilkenny' , 'P24TR88' , '051561800' , 'GurleenSalas@jensalon.com','PT_Stylist','2010-11-10','2','2'),
('Sydney' , 'Hastings' , 'Eastfield Road' , 'Rutherford Moor' , 'Waterford' , '0FE85' , '0214364002' , 'SydneyHastings@jensalon.com','Stylist','2009-10-22','3','3'),
('Tiana' , 'Hale' , 'Kent Road' , 'Holyrood Brook' , 'Kilkenny' , '0OK0' , '0288774818' , 'TianaHale@jensalon.com','Stylist','2015-11-11','3','3'),
('Ailsa' , 'Sparrow' , 'Gladstone Street' , 'Harper Crescent' , 'Waterford' , 'P14FE71' , '0214279933' , 'AilsaSparrow@jensalon.com','Stylist','2010-08-15','3','3'),
('Wendy' , 'Liu' , 'Hazel Avenue' , 'Jesmond Fairway' , 'Tipperary' , '0OK88' , '719644081' , 'WendyLiu@jensalon.com','PT_Stylist','2000-09-22','3','3');


insert into customer(fName, lName, contactNumber) values
('Jerry' , 'Russo','599173407'),
('Siena' , 'Rubio','214289200'),
('Maizie' , 'Blundell','014910346'),
('Teigan' , 'Felix','04781300'),
('Nancy' , 'Mays','0851102405'),
('Francesca' , 'Adam','539135916'),
('Maizie' , 'Zimmerman','214289200'),
('Kiah' , 'Felix','0288774818'),
('Raya' , 'Shaw','0214279933'),
('Ruby-Leigh' , 'Russo','0214279933'),
('Evie-Grace' , 'Thomas','0449343849'),
('Jerry' , 'Blundell','06732770'),
('Wendy' , 'Hastings','0469023167'),
('Ruby-Leigh' , 'Thomas','429376140'),
('Amirah' , 'Felix','419823605'),
('Inaaya' , 'Richardson','419823605'),
('Hebe' , 'Mays','04781300'),
('Jamie-Leigh' , 'Davenport','91647029'),
('Jordanne' , 'Hansen','0851102405'),
('Amy-Louise' , 'Glenn','0949870939'),
('Jasleen' , 'Blair','91524675'),
('Pearl' , 'Blundell','719197672'),
('Tiffany' , 'Liu','09522272'),
('Zane' , 'Hale','51386440'),
('Ruby-Leigh' , 'Rice','419823605'),
('Teigan' , 'Blundell','51386440'),
('Sydney' , 'Villegas','0214375628'),
('Lottie' , 'Richardson','719161537'),
('Ariya' , 'Felix','719197672'),
('Jasleen' , 'Prince','0288774818'),
('Maizie' , 'Sanderson','214289200'),
('Amanpreet' , 'Cain','0416861777'),
('Wendy' , 'Hansen','0214375628'),
('Keziah' , 'Brown','0949022017'),
('Harper' , 'Mays','04781300'),
('Lisa' , 'Faulkner','599173407'),
('Kiah' , 'Richardson','0949870939'),
('Maizie' , 'Villegas','0288774818'),
('Gaia' , 'Thomas','06732770'),
('Leja' , 'Hilton','16102866'),
('Samanta' , 'Wainwright','09522272'),
('Jerry' , 'Felix','429376140'),
('Zarah' , 'Sanderson','719197672'),
('Amirah' , 'Valencia','599173407'),
('Elysia' , 'Devlin','09522272'),
('Wendy' , 'Hope','0214364002'),
('Francesca' , 'Lyon','0489064212'),
('Keziah' , 'Richardson','0288774818'),
('Hebe' , 'Davenport','06732770'),
('Lisa' , 'Clark','539135916');

insert into familyMember (employeeId, customerId, relationship, discountRate) values
('1','2','Daughter','0.85'),
('2','4','Sister','0.85'),
('3','6','Mother','0.85'),
('4','8','Grandmother','0.85'),
('5','10','Aunt','0.85'),
('6','12','Daughter','0.85'),
('7','2','Sister','0.85'),
('8','4','Mother','0.85'),
('9','6','Grandmother','0.85'),
('10','2','Aunt','0.85'),
('11','15','Daughter','0.85'),
('12','16','Sister','0.85'),
('13','17','Mother','0.85'),
('14','1','Grandmother','0.85'),
('1','3','Aunt','0.85'),
('1','5','Daughter','0.85'),
('5','7','Sister','0.85'),
('8','20','Mother','0.85');



insert into supplier (companyName,street,town, county,eirCode, contactNumber,emailAddress) values
('SalonproductsIreland' , 'St Peters Close' , 'Borrowdale Parc' , 'Waterford' , 'H23VG71' , '0214364002' , 'SalonproductsIreland@jensalon.com'),
('HairCare' , 'Heather Close' , 'Lowfield Bottom' , 'Waterford' , 'P47TY51' , '419823605' , 'HairCare@jensalon.com'),
('Deisehairproducts' , 'Poplar Close' , 'Russet Banks' , 'Wexford' , 'P24TR69' , '719197672' , 'Deisehairproducts@jensalon.com'),
('Loreal' , 'Silver Street' , 'Rutherford Moor' , 'Wexford' , 'T56RT93' , '014910346' , 'Loreal@jensalon.com'),
('LovelyHair' , 'Lime Street' , 'Canterbury Ridings' , 'Waterford' , 'P32VG84' , '09522272' , 'LovelyHair@jensalon.com');

insert into product (description, stockQuantity, unitcost, supplierId) values
('Schwartzkopf Hair Spray','10','15.99','1'),
('Fructis Full Shampoo','15','16.99','2'),
('Coconut Milk Shampoo and Conditioner','20','17.99','3'),
('Moisture Co-Wash Whipped Cleansing Conditioner','25','15.5','4'),
('Oribe Dry Texturizing Spray','10','27.5','5'),
('Moroccanoil Curl Defining Cream','15','18.49','1'),
('Briogeo Scalp Revival Treatment','20','19.49','2'),
('Living Proof Dry Shampoo','25','20.49','3'),
('OUAI Repair Shampoo','10','18','4'),
('Kevin Murphy Blonde Angel Wash','15','30','5'),
('Bumble and Bumble Overnight Hair Mask','20','20.99','1'),
('Christophe Robin Volumizing Conditioner.','25','21.99','2'),
('Kérastase Elixir Ultime Oil Serum','5','22.99','3'),
('ghd Curve 1.25" Soft Curl Iron','15','20.5','4'),
('Bumble and Bumble Brilliantine','20','32.5','5'),
('Shu Uemura Cleansing Oil Shampoo','25','23.49','1'),
('Olaplex Hair Perfector No','10','24.49','1'),
('Virtue Create Lifting Powder','15','25.49','1'),
('Shu Uemura Muroto Volume Lightweight Care Conditioner.','20','23','5');



insert into Appointment values
('1','12:00:00','2020-11-06','Wash,Cut,Blowdry','1'),
('2','12:30:00','2020-11-03','Wash,Cut,Blowdry ','2'),
('3','13:00:00','2020-11-02','Colour','3'),
('4','13:30:00','2020-11-01','Wash,Blowdry','4'),
('5','14:00:00','2020-11-30','Wash,Cut,Blowdry','5'),
('6','14:30:00','2020-11-29','Wash,Cut,Blowdry ','6'),
('7','15:00:00','2020-11-28','Colour','7'),
('8','15:30:00','2020-11-27','Wash,Cut,Blowdry','8'),
('9','16:00:00','2020-11-26','Wash,Cut,Blowdry ','9'),
('10','16:30:00','2020-11-04','Colour','10'),
('11','17:00:00','2020-11-03','Wash,Blowdry','11'),
('12','17:30:00','2020-11-02','Colour','12'),
('13','18:00:00','2020-11-01','Wash,Cut,Blowdry','13'),
('14','12:00:00','2020-11-30','Wash,Cut,Blowdry ','14'),
('15','12:30:00','2020-11-29','Colour','15'),
('16','13:00:00','2020-11-28','Wash,Cut,Blowdry','16'),
('17','13:30:00','2020-11-27','Wash,Blowdry','17'),
('18','14:00:00','2020-11-26','Wash,Cut,Blowdry','18'),
('19','14:30:00','2020-11-04','Colour','19'),
('20','15:00:00','2020-11-03','Wash,Cut,Blowdry','20'),
('21','15:30:00','2020-11-02','Wash,Cut,Blowdry ','21'),
('22','16:00:00','2020-11-01','Colour','22'),
('23','16:30:00','2020-11-30','Wash,Cut,Blowdry','23'),
('24','17:00:00','2020-11-29','Colour','24'),
('25','17:30:00','2020-11-28','Wash,Cut,Blowdry','25'),
('26','18:00:00','2020-11-27','Wash,Cut,Blowdry ','26'),
('27','12:00:00','2020-11-27','Colour','27'),
('28','12:30:00','2020-11-07','Wash,Cut,Blowdry','28'),
('29','13:00:00','2020-11-06','Wash,Blowdry','29'),
('30','13:30:00','2020-11-05','Wash,Cut,Blowdry','30'),
('31','14:00:00','2020-11-04','Colour','31'),
('32','14:30:00','2020-11-03','Wash,Cut,Blowdry','32'),
('33','15:00:00','2020-11-02','Colour','33'),
('34','15:30:00','2020-11-04','Wash,Cut,Blowdry','34'),
('35','16:00:00','2020-11-03','Wash,Cut,Blowdry ','35'),
('36','16:30:00','2020-11-02','Colour','36'),
('37','17:00:00','2020-11-01','Wash,Cut,Blowdry','37'),
('38','17:30:00','2020-11-30','Wash,Blowdry','38'),
('39','18:00:00','2020-11-29','Wash,Cut,Blowdry','39'),
('40','12:00:00','2020-11-27','Colour','40'),
('41','12:30:00','2020-11-27','Wash,Cut,Blowdry','41'),
('42','13:00:00','2020-11-26','Wash,Cut,Blowdry ','42'),
('43','13:30:00','2020-11-23','Colour','43'),
('44','14:00:00','2020-11-22','Wash,Cut,Blowdry','44'),
('45','14:30:00','2020-11-21','Wash,Cut,Blowdry ','45'),
('46','15:00:00','2020-11-20','Colour','46'),
('47','15:30:00','2020-11-19','Wash,Cut,Blowdry','47'),
('48','16:00:00','2020-11-18','Wash,Cut,Blowdry ','48'),
('49','16:30:00','2020-11-17','Colour','49'),
('50','17:00:00','2020-11-04','Wash,Cut,Blowdry','50'),
('51','12:00:00','2020-11-03','Wash,Cut,Blowdry ','37'),
('52','12:30:00','2020-11-02','Wash,Blowdry','38'),
('53','13:00:00','2020-11-01','Wash,Cut,Blowdry ','39'),
('54','13:30:00','2020-11-30','Colour','40'),
('55','14:00:00','2020-11-29','Wash,Cut,Blowdry','37'),
('56','14:30:00','2020-11-28','Wash,Cut,Blowdry ','38'),
('57','15:00:00','2020-11-27','Wash,Cut,Blowdry','47'),
('58','15:30:00','2020-11-26','Wash,Cut,Blowdry ','48'),
('59','16:30:00','2020-11-04','Colour','10'),
('60','17:00:00','2020-11-03','Wash,Blowdry','11'),
('61','17:30:00','2020-11-02','Colour','12'),
('62','18:00:00','2020-11-01','Wash,Cut,Blowdry','13'),
('63','12:00:00','2020-11-21','Wash,Cut,Blowdry ','14'),
('64','12:00:00','2020-11-13','Colour','15'),
('65','12:00:00','2020-11-28','Wash,Cut,Blowdry','16'),
('66','13:30:00','2020-11-27','Wash,Blowdry','17'),
('67','14:00:00','2020-11-26','Wash,Cut,Blowdry','18'),
('68','14:30:00','2020-11-04','Colour','19'),
('69','15:00:00','2020-11-03','Wash,Cut,Blowdry','20'),
('70','15:30:00','2020-11-02','Wash,Cut,Blowdry ','21'),
('71','16:00:00','2020-11-01','Colour','22'),
('72','16:30:00','2020-11-30','Wash,Cut,Blowdry','23'),
('73','17:00:00','2020-11-29','Colour','24'),
('74','17:30:00','2020-11-28','Wash,Cut,Blowdry','25'),
('75','18:00:00','2020-11-27','Wash,Cut,Blowdry ','26'),
('76','12:00:00','2020-11-26','Colour','27'),
('77','12:30:00','2020-11-07','Wash,Cut,Blowdry','28'),
('78','13:00:00','2020-11-06','Wash,Blowdry','29'),
('79','13:30:00','2020-11-05','Wash,Cut,Blowdry','30'),
('80','14:00:00','2020-11-04','Colour','31'),
('81','14:30:00','2020-11-03','Wash,Cut,Blowdry','32'),
('82','15:00:00','2020-11-02','Colour','33'),
('83','15:30:00','2020-11-04','Wash,Cut,Blowdry','34'),
('84','16:00:00','2020-11-03','Wash,Cut,Blowdry ','35'),
('85','16:30:00','2020-11-02','Colour','36'),
('86','17:00:00','2020-11-01','Wash,Cut,Blowdry','37'),
('87','17:30:00','2020-11-30','Wash,Blowdry','38'),
('88','18:00:00','2020-11-29','Wash,Cut,Blowdry','39'),
('89','12:00:00','2020-11-28','Colour','40'),
('90','12:30:00','2020-11-27','Wash,Cut,Blowdry','41'),
('91','13:00:00','2020-11-26','Wash,Cut,Blowdry ','42'),
('92','13:30:00','2020-11-23','Colour','43'),
('93','14:00:00','2020-11-22','Wash,Cut,Blowdry','44'),
('94','14:30:00','2020-11-21','Wash,Cut,Blowdry ','45'),
('95','15:00:00','2020-11-20','Colour','46'),
('96','15:30:00','2020-11-19','Wash,Cut,Blowdry','47'),
('97','16:00:00','2020-11-18','Wash,Cut,Blowdry ','48'),
('98','16:30:00','2020-11-17','Colour','49'),
('99','17:00:00','2020-11-04','Wash,Cut,Blowdry','50'),
('100','12:00:00','2020-11-03','Wash,Cut,Blowdry ','37'),
('101','12:30:00','2020-11-02','Wash,Blowdry','38'),
('102','13:00:00','2020-11-01','Wash,Cut,Blowdry ','39'),
('103','13:30:00','2020-11-30','Colour','40'),
('104','14:00:00','2020-11-29','Wash,Cut,Blowdry','37'),
('105','14:30:00','2020-11-28','Wash,Cut,Blowdry ','38'),
('106','15:00:00','2020-11-27','Wash,Cut,Blowdry','47'),
('107','15:30:00','2020-11-26','Wash,Cut,Blowdry ','48'),
('108','12:00:00','2020-12-04','Wash,Cut,Blowdry','1'),
('109','12:30:00','2020-12-03','Wash,Cut,Blowdry ','2'),
('110','13:00:00','2020-12-02','Colour','3'),
('111','13:30:00','2020-12-01','Wash,Blowdry','4'),
('112','14:00:00','2020-12-30','Wash,Cut,Blowdry','5'),
('113','14:30:00','2020-12-29','Wash,Cut,Blowdry ','6'),
('114','15:00:00','2020-12-28','Colour','7'),
('115','15:30:00','2020-12-27','Wash,Cut,Blowdry','8'),
('116','16:00:00','2020-12-26','Wash,Cut,Blowdry ','9'),
('117','16:30:00','2020-12-04','Colour','10'),
('118','17:00:00','2020-12-03','Wash,Blowdry','11'),
('119','17:30:00','2020-12-02','Colour','12'),
('120','18:00:00','2020-12-01','Wash,Cut,Blowdry','13'),
('121','12:00:00','2020-12-30','Wash,Cut,Blowdry ','14'),
('122','12:30:00','2020-12-29','Colour','15'),
('123','13:00:00','2020-12-28','Wash,Cut,Blowdry','16'),
('124','13:30:00','2020-12-27','Wash,Blowdry','17'),
('125','14:00:00','2020-12-26','Wash,Cut,Blowdry','18'),
('126','14:30:00','2020-12-04','Colour','19'),
('127','15:00:00','2020-12-03','Wash,Cut,Blowdry','20'),
('128','15:30:00','2020-12-02','Wash,Cut,Blowdry ','21'),
('129','16:00:00','2020-12-01','Colour','22'),
('130','16:30:00','2020-12-30','Wash,Cut,Blowdry','23'),
('131','17:00:00','2020-12-29','Colour','24'),
('132','17:30:00','2020-12-28','Wash,Cut,Blowdry','25'),
('133','18:00:00','2020-12-27','Wash,Cut,Blowdry ','26'),
('134','12:00:00','2020-12-26','Colour','27'),
('135','12:30:00','2020-12-07','Wash,Cut,Blowdry','28'),
('136','13:00:00','2020-12-06','Wash,Blowdry','29'),
('137','13:30:00','2020-12-05','Wash,Cut,Blowdry','30'),
('138','14:00:00','2020-12-04','Colour','31'),
('139','14:30:00','2020-12-03','Wash,Cut,Blowdry','32'),
('140','15:00:00','2020-12-02','Colour','33'),
('141','15:30:00','2020-12-04','Wash,Cut,Blowdry','34'),
('142','16:00:00','2020-12-03','Wash,Cut,Blowdry ','35'),
('143','16:30:00','2020-12-02','Colour','36'),
('144','17:00:00','2020-12-01','Wash,Cut,Blowdry','37'),
('145','17:30:00','2020-12-30','Wash,Blowdry','38'),
('146','18:00:00','2020-12-29','Wash,Cut,Blowdry','39'),
('147','12:00:00','2020-12-28','Colour','40'),
('148','12:30:00','2020-12-27','Wash,Cut,Blowdry','41'),
('149','13:00:00','2020-12-26','Wash,Cut,Blowdry ','42'),
('150','13:30:00','2020-12-23','Colour','43'),
('151','14:00:00','2020-12-22','Wash,Cut,Blowdry','44'),
('152','14:30:00','2020-12-21','Wash,Cut,Blowdry ','45'),
('153','15:00:00','2020-12-20','Colour','46'),
('154','15:30:00','2020-12-19','Wash,Cut,Blowdry','47'),
('155','16:00:00','2020-12-18','Wash,Cut,Blowdry ','48'),
('156','16:30:00','2020-12-17','Colour','49'),
('157','17:00:00','2020-12-04','Wash,Cut,Blowdry','50'),
('158','12:00:00','2020-12-03','Wash,Cut,Blowdry ','37'),
('159','12:30:00','2020-12-02','Wash,Blowdry','38'),
('160','13:00:00','2020-12-01','Wash,Cut,Blowdry ','39'),
('161','13:30:00','2020-12-30','Colour','40'),
('162','14:00:00','2020-12-29','Wash,Cut,Blowdry','37'),
('163','14:30:00','2020-12-28','Wash,Cut,Blowdry ','38'),
('164','15:00:00','2020-12-27','Wash,Cut,Blowdry','47'),
('165','15:30:00','2020-12-26','Wash,Cut,Blowdry ','48'),
('166','16:30:00','2020-12-04','Colour','10'),
('167','17:00:00','2020-12-03','Wash,Blowdry','11'),
('168','17:30:00','2020-12-02','Colour','12'),
('169','18:00:00','2020-12-01','Wash,Cut,Blowdry','13'),
('170','12:00:00','2020-12-21','Wash,Cut,Blowdry ','14'),
('171','12:00:00','2020-12-13','Colour','15'),
('172','12:00:00','2020-12-28','Wash,Cut,Blowdry','16'),
('173','13:30:00','2020-12-27','Wash,Blowdry','17'),
('174','14:00:00','2020-12-26','Wash,Cut,Blowdry','18'),
('175','14:30:00','2020-12-04','Colour','19'),
('176','15:00:00','2020-12-03','Wash,Cut,Blowdry','20'),
('177','15:30:00','2020-12-02','Wash,Cut,Blowdry ','21'),
('178','16:00:00','2020-12-01','Colour','22'),
('179','16:30:00','2020-12-30','Wash,Cut,Blowdry','23'),
('180','17:00:00','2020-12-29','Colour','24'),
('181','17:30:00','2020-12-28','Wash,Cut,Blowdry','25'),
('182','18:00:00','2020-12-27','Wash,Cut,Blowdry ','26'),
('183','12:00:00','2020-12-26','Colour','27'),
('184','12:30:00','2020-12-07','Wash,Cut,Blowdry','28'),
('185','13:00:00','2020-12-06','Wash,Blowdry','29'),
('186','13:30:00','2020-12-05','Wash,Cut,Blowdry','30'),
('187','14:00:00','2020-12-04','Colour','31'),
('188','14:30:00','2020-12-03','Wash,Cut,Blowdry','32'),
('189','15:00:00','2020-12-02','Colour','33'),
('190','15:30:00','2020-12-04','Wash,Cut,Blowdry','34'),
('191','16:00:00','2020-12-03','Wash,Cut,Blowdry ','35'),
('192','16:30:00','2020-12-02','Colour','36'),
('193','17:00:00','2020-12-01','Wash,Cut,Blowdry','37'),
('194','17:30:00','2020-12-30','Wash,Blowdry','38'),
('195','18:00:00','2020-12-29','Wash,Cut,Blowdry','39'),
('196','12:00:00','2020-12-28','Colour','40'),
('197','12:30:00','2020-12-27','Wash,Cut,Blowdry','41'),
('198','13:00:00','2020-12-26','Wash,Cut,Blowdry ','42'),
('199','13:30:00','2020-12-23','Colour','43'),
('200','14:00:00','2020-12-22','Wash,Cut,Blowdry','44'),
('201','14:30:00','2020-12-21','Wash,Cut,Blowdry ','45'),
('202','15:00:00','2020-12-20','Colour','46'),
('203','15:30:00','2020-12-19','Wash,Cut,Blowdry','47'),
('204','16:00:00','2020-12-18','Wash,Cut,Blowdry ','48'),
('205','16:30:00','2020-12-17','Colour','49'),
('206','17:00:00','2020-12-04','Wash,Cut,Blowdry','50'),
('207','12:00:00','2020-12-03','Wash,Cut,Blowdry ','37'),
('208','12:30:00','2020-12-02','Wash,Blowdry','38'),
('209','13:00:00','2020-12-01','Wash,Cut,Blowdry ','39'),
('210','13:30:00','2020-12-30','Colour','40'),
('211','14:00:00','2020-12-29','Wash,Cut,Blowdry','37'),
('212','14:30:00','2020-12-28','Wash,Cut,Blowdry ','38'),
('213','15:00:00','2020-12-27','Wash,Cut,Blowdry','47'),
('214','15:30:00','2020-12-26','Wash,Cut,Blowdry ','48');


insert into partTimeEmployee values
('6', '13.50'),
('10', '13.50'),
('14', '13.50');

insert into fullTimeEmployee values
('1','35000','0.04'),
('2','32000','0.04'),
('3','33000','0.04'),
('4','22000','0.03'),
('5','31000','0.03'),
('7','22000','0.03'),
('8','22000','0.03'),
('9','27000','0.03'),
('11','22000','0.03'),
('12','19000','0.03'),
('13','19500','0.03');



insert into workson values
('1','1','64'),
('2','2','34'),
('3','3','89'),
('4','4','83'),
('5','5','87'),
('6','6','60'),
('7','7','35'),
('8','8','47'),
('9','9','44'),
('10','10','79'),
('11','11','38'),
('12','12','81'),
('13','13','82'),
('14','14','84'),
('1','15','76'),
('2','16','70'),
('3','17','63'),
('4','18','67'),
('5','19','84'),
('6','20','87'),
('7','21','68'),
('8','22','45'),
('9','23','38'),
('10','24','57'),
('11','25','83'),
('12','26','81'),
('13','27','71'),
('14','28','85'),
('1','29','83'),
('2','30','85'),
('3','31','69'),
('4','32','60'),
('5','33','31'),
('6','34','64'),
('7','35','38'),
('8','36','32'),
('9','37','68'),
('10','38','44'),
('11','39','76'),
('12','40','67'),
('13','41','42'),
('14','42','82'),
('1','43','85'),
('2','44','86'),
('3','45','45'),
('4','46','82'),
('5','47','40'),
('6','48','90'),
('7','49','83'),
('8','50','60'),
('9','51','54'),
('10','52','68'),
('11','53','62'),
('12','54','74'),
('13','55','44'),
('14','56','67'),
('1','57','52'),
('2','58','90'),
('3','59','40'),
('4','60','48'),
('5','61','42'),
('6','62','84'),
('7','63','45'),
('8','64','72'),
('9','65','73'),
('10','66','68'),
('11','67','85'),
('12','68','87'),
('13','69','88'),
('14','70','76'),
('1','71','83'),
('2','72','35'),
('3','73','63'),
('4','74','76'),
('5','75','66'),
('6','76','70'),
('7','77','89'),
('8','78','81'),
('9','79','40'),
('10','80','82'),
('11','81','76'),
('12','82','58'),
('13','83','60'),
('14','84','60'),
('1','85','30'),
('2','86','59'),
('3','87','64'),
('4','88','62'),
('5','89','63'),
('6','90','32'),
('7','91','54'),
('8','92','53'),
('9','93','89'),
('10','94','36'),
('11','95','82'),
('12','96','60'),
('13','97','66'),
('14','98','52'),
('1','99','56'),
('2','100','35'),
('3','101','84'),
('4','102','72'),
('5','103','71'),
('6','104','89'),
('7','105','43'),
('8','106','31'),
('9','107','32'),
('10','108','30'),
('11','109','74'),
('12','110','40'),
('13','111','69'),
('14','112','73'),
('1','113','33'),
('2','114','35'),
('3','115','90'),
('4','116','60'),
('5','117','65'),
('6','118','67'),
('7','119','75'),
('8','120','62'),
('9','121','74'),
('10','122','48'),
('11','123','59'),
('12','124','72'),
('13','125','38'),
('14','126','83'),
('1','127','82'),
('2','128','86'),
('3','129','74'),
('4','130','52'),
('5','131','39'),
('6','132','51'),
('7','133','40'),
('8','134','52'),
('9','135','35'),
('10','136','81'),
('11','137','78'),
('12','138','75'),
('13','139','47'),
('14','140','83'),
('1','141','43'),
('2','142','58'),
('3','143','50'),
('4','144','41'),
('5','145','36'),
('6','146','53'),
('7','147','76'),
('8','148','83'),
('9','149','68'),
('10','150','88'),
('11','151','56'),
('12','152','48'),
('13','153','70'),
('14','154','37'),
('1','155','51'),
('2','156','43'),
('3','157','38'),
('4','158','82'),
('5','159','34'),
('6','160','85'),
('7','161','62'),
('8','162','90'),
('9','163','31'),
('10','164','74'),
('11','165','67'),
('12','166','30'),
('13','167','88'),
('14','168','38'),
('1','169','86'),
('2','170','70'),
('3','171','57'),
('4','172','33'),
('5','173','32'),
('6','174','85'),
('7','175','65'),
('8','176','58'),
('9','177','82'),
('10','178','68'),
('11','179','45'),
('12','180','87'),
('13','181','49'),
('14','182','47'),
('1','183','46'),
('2','184','40'),
('3','185','37'),
('4','186','57'),
('5','187','68'),
('6','188','55'),
('7','189','63'),
('8','190','90'),
('9','191','36'),
('10','192','57'),
('11','193','47'),
('12','194','83'),
('13','195','65'),
('14','196','39'),
('1','197','40'),
('2','198','36'),
('3','199','86'),
('4','200','32'),
('5','201','76'),
('6','202','77'),
('7','203','65'),
('8','204','37'),
('9','205','49'),
('10','206','34'),
('11','207','46'),
('12','208','36'),
('13','209','66'),
('14','210','35'),
('1','211','35'),
('2','212','48'),
('3','213','47'),
('4','214','50');

insert into appointmentuses values
('4','1','1.5'),
('13','6','0.75'),
('22','11','1'),
('37','1','1'),
('53','17','1.5'),
('62','18','2'),
('71','2','2'),
('86','7','1.5'),
('102','1','2'),
('3','3','0.5'),
('12','8','1.5'),
('21','13','2'),
('33','4','1.5'),
('36','9','0.75'),
('52','1','0.75'),
('61','5','1.5'),
('70','10','0.5'),
('82','15','2'),
('85','19','2'),
('101','1','1'),
('2','6','1.5'),
('11','11','1'),
('20','1','0.5'),
('32','17','0.75'),
('35','18','1'),
('51','2','0.5'),
('60','7','0.75'),
('69','12','1'),
('81','3','0.5'),
('84','8','0.5'),
('100','13','1'),
('1','4','2'),
('10','9','0.75'),
('19','2','1.5'),
('31','5','1.5'),
('34','10','1.5'),
('50','15','1.5'),
('59','19','2'),
('68','1','2'),
('80','6','0.5'),
('83','11','1.5'),
('99','16','2'),
('30','17','0.75'),
('79','18','1.5'),
('29','2','0.5'),
('78','7','0.75'),
('28','2','0.5'),
('77','3','0.5'),
('64','8','1'),
('49','13','1'),
('98','4','2'),
('48','9','0.75'),
('97','14','0.5'),
('47','5','1'),
('96','3','0.75'),
('46','15','1.5'),
('95','19','1'),
('45','1','0.75'),
('63','6','2'),
('94','11','1.5'),
('44','16','0.75'),
('93','17','2'),
('43','18','1.5'),
('92','2','0.5'),
('9','7','2'),
('18','12','1'),
('27','3','1'),
('42','8','0.5'),
('58','13','0.5'),
('67','4','1.5'),
('76','9','1.5'),
('91','14','2'),
('107','5','1'),
('8','10','1'),
('17','15','2'),
('26','19','2'),
('46','1','1'),
('95','6','1.5'),
('45','11','1'),
('63','16','0.75'),
('94','17','1'),
('44','18','0.5'),
('93','2','0.75'),
('43','7','0.5'),
('92','12','1.5'),
('9','3','0.75'),
('18','8','0.5'),
('27','13','0.5'),
('42','4','1.5'),
('58','9','2'),
('67','14','0.5'),
('76','5','0.5'),
('91','10','2'),
('107','15','1.5'),
('8','19','2'),
('17','1','0.5'),
('26','6','0.75'),
('88','11','0.5'),
('104','16','2'),
('5','17','1'),
('14','18','2'),
('23','2','1.5'),
('38','7','0.75'),
('54','12','2'),
('72','3','1'),
('87','8','2'),
('103','13','2'),
('111','4','2'),
('120','9','0.5'),
('129','14','1.5'),
('144','5','1'),
('160','10','2'),
('169','15','0.75'),
('178','19','0.75'),
('193','1','2'),
('209','6','1'),
('110','11','0.5'),
('119','16','2'),
('128','17','1.5'),
('140','18','0.5'),
('143','2','2'),
('159','7','2'),
('168','12','2'),
('177','3','1'),
('189','8','1.5'),
('192','13','1'),
('208','4','1'),
('109','9','0.5'),
('118','14','0.5'),
('127','5','2'),
('139','10','1'),
('142','15','0.5'),
('158','19','0.5'),
('167','1','2'),
('176','6','1.5'),
('188','11','0.5'),
('191','16','1'),
('207','17','1.5'),
('108','18','0.75'),
('117','2','1.5'),
('126','7','1.5'),
('138','12','1'),
('141','3','1.5'),
('157','8','1'),
('166','13','1.5'),
('175','4','0.75'),
('187','9','1.5'),
('190','14','1'),
('206','5','0.75'),
('137','10','1.5'),
('186','15','0.75'),
('136','19','1.5'),
('185','1','2'),
('135','6','1'),
('184','11','1'),
('171','16','2'),
('156','17','1.5'),
('205','18','0.5'),
('155','2','0.75'),
('204','7','0.5'),
('154','12','1.5'),
('203','3','0.75'),
('153','8','2'),
('202','13','0.5'),
('152','4','1.5'),
('170','9','2'),
('201','14','1.5'),
('151','5','1'),
('200','10','0.5'),
('150','15','1'),
('199','19','0.75'),
('116','1','0.75'),
('125','6','2'),
('134','11','0.75'),
('149','16','0.5'),
('165','17','0.75'),
('174','18','0.75'),
('183','2','2'),
('198','7','1'),
('214','12','0.75'),
('115','3','1'),
('124','8','0.75'),
('133','13','0.75'),
('148','4','1'),
('164','9','0.75'),
('173','14','1'),
('182','5','2'),
('197','10','0.75'),
('213','15','0.5'),
('114','19','1.5'),
('123','1','0.5'),
('132','6','1'),
('147','11','1'),
('163','16','2'),
('172','17','1'),
('181','18','1.5'),
('196','2','0.5'),
('212','7','0.5'),
('113','12','2'),
('122','3','0.5'),
('131','8','1.5'),
('146','13','1'),
('162','4','2'),
('180','9','2'),
('195','14','1'),
('211','5','1.5'),
('112','10','1.5'),
('121','15','0.5'),
('130','19','1.5'),
('145','1','1.5'),
('161','6','1'),
('179','11','0.5'),
('194','16','2'),
('210','17','2');
/*****************************************************/
COMMIT;