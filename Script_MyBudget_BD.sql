-- *** CREATE TABLES AND SECUENCES *** ---

-- PERSON
CREATE TABLE PERSON (
	PERSON NUMBER,
	EMAIL VARCHAR2(100) NOT NULL,
	PASSWORD VARCHAR2(1000) NOT NULL,
	PERSON_TOKEN VARCHAR2(1000) NOT NULL,
	FIRST_NAME VARCHAR2(100) NOT NULL,
	LAST_NAME VARCHAR2(100) NOT NULL,
	ADD_DATE DATE DEFAULT SYSDATE,
	PRIMARY KEY(PERSON)
);


CREATE SEQUENCE SQ_PERSON NOCACHE;

-- CATEGORY 

-- BANK
CREATE TABLE BANK (
	BANK NUMBER,
	BANK_NAME VARCHAR2(100),
	PRIMARY KEY(BANK)
);

CREATE SEQUENCE SQ_BANK NOCACHE;

-- CURRENCIE
CREATE TABLE CURRENCIE (
	CURRENCIE NUMBER,
	CURRENCIE_NAME VARCHAR2(50),
	CURRENCIE_SYMBOL VARCHAR2(5),
	PRIMARY KEY(CURRENCIE)
);

CREATE SEQUENCE SQ_CURRENCIE NOCACHE;

-- BANK ACCOUNT
CREATE TABLE BANK_ACCOUNT (
	BANK_ACCOUNT VARCHAR2(50),
	BANK_NAME NUMBER,
	PERSON_ACCOUNT NUMBER,
	AMOUNT NUMBER,
	CURRENCIE NUMBER,
	ADD_DATE DATE DEFAULT SYSDATE,
	MOD_DATE DATE,
	
	PRIMARY KEY(BANK_ACCOUNT),
	FOREIGN KEY(BANK_NAME) REFERENCES BANK(BANK),
	FOREIGN KEY(PERSON_ACCOUNT) REFERENCES PERSON(PERSON),
	FOREIGN KEY(CURRENCIE) REFERENCES CURRENCIE(CURRENCIE)
);

-- RECORD TYPE
CREATE TABLE RECORD_TYPE (
	RECORD_TYPE NUMBER,
	RECORD_TYPE_NAME VARCHAR2(25),
	PRIMARY KEY (RECORD_TYPE)
);


-- CATEGORY 
CREATE TABLE CATEGORY (
	CATEGORY NUMBER,
	CATEGORY_TYPE NUMBER,
	CATEGORY_NAME VARCHAR2(25),
	PRIMARY KEY (CATEGORY),
	FOREIGN KEY (CATEGORY_TYPE) REFERENCES RECORD_TYPE(RECORD_TYPE)
);

-- RECORD HISTORY
CREATE TABLE RECORD_HISTORY (
	RECORD_HISTORY NUMBER,
	RECORD_TYPE NUMBER,
	BANK_ACCOUNT VARCHAR2(50),
	CATEGORY NUMBER,
	AMOUNT NUMBER,
	DESCRIPTION VARCHAR2(50),
	RECORD_DATE DATE DEFAULT SYSDATE,
	PRIMARY KEY (RECORD_HISTORY),
	FOREIGN KEY (RECORD_TYPE) REFERENCES RECORD_TYPE(RECORD_TYPE),
	FOREIGN KEY (BANK_ACCOUNT) REFERENCES BANK_ACCOUNT(BANK_ACCOUNT),
	FOREIGN KEY (CATEGORY) REFERENCES CATEGORY(CATEGORY)
);

CREATE SEQUENCE SQ_RECORD;

--  *** FUNCTIONS *** ---
-- API TOKEN
CREATE OR REPLACE FUNCTION API_TOKEN(PSECRET VARCHAR2) RETURN VARCHAR2
IS 
	VRESULT VARCHAR2(4000);
BEGIN
		SELECT UTL_RAW.CAST_TO_VARCHAR2(UTL_I18N.STRING_TO_RAW(STANDARD_HASH(PSECRET, 'MD5' ), 'AL32UTF8')) INTO VRESULT FROM DUAL;
		RETURN VRESULT;
END API_TOKEN;

-- RECORD INCOME
CREATE OR REPLACE FUNCTION RECORD_INCOME(BANK_ACCOUNT_API VARCHAR2, CATEGORY NUMBER, AMOUNT_API NUMBER,  DESCRIPTION VARCHAR2) RETURN VARCHAR2
IS 
	STATUS_TRANSACTION VARCHAR2(500);
BEGIN
	INSERT INTO RECORD_HISTORY VALUES(SQ_RECORD.NEXTVAL, 1, BANK_ACCOUNT_API, CATEGORY, AMOUNT_API, DESCRIPTION, SYSDATE);
	UPDATE BANK_ACCOUNT 
		SET AMOUNT = AMOUNT + AMOUNT_API, MOD_DATE = SYSDATE
	WHERE BANK_ACCOUNT = BANK_ACCOUNT_API;
	COMMIT;
	STATUS_TRANSACTION :='commit';
	RETURN(STATUS_TRANSACTION);
EXCEPTION
	WHEN OTHERS THEN
	ROLLBACK;
	STATUS_TRANSACTION :='rollback';
	RETURN(STATUS_TRANSACTION);
END RECORD_INCOME;

-- RECORD EXPENSE 

CREATE OR REPLACE FUNCTION RECORD_EXPENSE(BANK_ACCOUNT_API VARCHAR2, CATEGORY NUMBER, AMOUNT_API NUMBER, DESCRIPTION VARCHAR2) RETURN VARCHAR2
IS 
	STATUS_TRANSACTION VARCHAR2(500);
	AMOUNT_BANK NUMBER;
BEGIN
	--Traemos el dinero que tiene la cuenta 
	SELECT AMOUNT INTO AMOUNT_BANK FROM BANK_ACCOUNT WHERE BANK_ACCOUNT=BANK_ACCOUNT_API;
	-- Verificamos si podemos retarle a la cuenta
	IF AMOUNT_BANK >= AMOUNT_API THEN
		-- Ingresamos un nuevo registro en record
		INSERT INTO RECORD_HISTORY VALUES(SQ_RECORD.NEXTVAL, 2, BANK_ACCOUNT_API, CATEGORY, AMOUNT_API, DESCRIPTION, SYSDATE);
		-- Restamos dinero a la cuenta
		UPDATE BANK_ACCOUNT 
			SET AMOUNT = AMOUNT - AMOUNT_API, MOD_DATE = SYSDATE
		WHERE BANK_ACCOUNT = BANK_ACCOUNT_API;
		--Guardamos los cambios
		COMMIT;
		--Retornamos el estado de la transaccion
		STATUS_TRANSACTION :='commit';
		RETURN(STATUS_TRANSACTION);
	ELSIF AMOUNT_BANK < AMOUNT_API THEN
		COMMIT;
		STATUS_TRANSACTION :='undo';
		RETURN(STATUS_TRANSACTION);
	END IF;
-- Si ocurre un error, hacemos rollback
EXCEPTION
	WHEN OTHERS THEN
	ROLLBACK;
	--Regresamos el estado de la transaccion
	STATUS_TRANSACTION :='rollback';
	RETURN(STATUS_TRANSACTION);
END RECORD_EXPENSE;

-- TRANSFER MONEY 

CREATE OR REPLACE FUNCTION TRANSFER_MONEY(BANK_ACCOUNT_OUT VARCHAR2, BANK_ACCOUNT_IN VARCHAR2, AMOUNT_OUT NUMBER, AMOUNT_IN NUMBER, DESCRIPTION VARCHAR2) RETURN VARCHAR2
IS 
	STATUS_TRANSACTION VARCHAR2(500);
	AMOUNT_BANK NUMBER;
BEGIN
	--Traemos el dinero que tiene la cuenta 
	SELECT AMOUNT INTO AMOUNT_BANK FROM BANK_ACCOUNT WHERE BANK_ACCOUNT=BANK_ACCOUNT_OUT;
	-- Verificamos si podemos retarle a la cuenta
	IF AMOUNT_BANK >= AMOUNT_OUT THEN
		-- Ingresamos un nuevo registro en record 2 para expense y 4 para transfer out
		INSERT INTO RECORD_HISTORY VALUES(SQ_RECORD.NEXTVAL, 2, BANK_ACCOUNT_OUT, 4, AMOUNT_OUT, DESCRIPTION, SYSDATE);
		-- Restamos dinero a la cuenta
		UPDATE BANK_ACCOUNT 
			SET AMOUNT = AMOUNT - AMOUNT_OUT, MOD_DATE = SYSDATE
		WHERE BANK_ACCOUNT = BANK_ACCOUNT_OUT;
	
		--Transferimos el dinero a la siguiente cuenta
		-- Ingresamos un nuevo registro en record 2 para expense y 3 para transfer
		INSERT INTO RECORD_HISTORY VALUES(SQ_RECORD.NEXTVAL, 1, BANK_ACCOUNT_IN, 3, AMOUNT_IN, DESCRIPTION, SYSDATE);
		-- Restamos dinero a la cuenta
		UPDATE BANK_ACCOUNT 
			SET AMOUNT = AMOUNT + AMOUNT_IN, MOD_DATE = SYSDATE
		WHERE BANK_ACCOUNT = BANK_ACCOUNT_IN;
		--Guardamos los cambios
		COMMIT;
		--Retornamos el estado de la transaccion
		STATUS_TRANSACTION :='commit';
		RETURN(STATUS_TRANSACTION);
	ELSIF AMOUNT_BANK < AMOUNT_OUT THEN
		COMMIT;
		STATUS_TRANSACTION :='undo';
		RETURN(STATUS_TRANSACTION);
	END IF;
-- Si ocurre un error, hacemos rollback
EXCEPTION
	WHEN OTHERS THEN
	ROLLBACK;
	--Regresamos el estado de la transaccion
	STATUS_TRANSACTION :='rollback';
	RETURN(STATUS_TRANSACTION);
END TRANSFER_MONEY;


