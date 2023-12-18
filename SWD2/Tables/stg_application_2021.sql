CREATE TABLE STG_APPLICATION_2021
(
  APPL_STUDENT_ID    NUMBER(10),
  FUNDING_YEAR       NUMBER(4),
  DISABLING_COND_ID  NUMBER(9),
  MIGRATED_IND       VARCHAR2(1 BYTE),
  ERR_DATE           DATE,
  ERR_DESC           VARCHAR2(4000 BYTE)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;