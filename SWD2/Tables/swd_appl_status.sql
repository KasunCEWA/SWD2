CREATE TABLE SWD_APPL_STATUS
(
  APPL_STATUS_ID  NUMBER(9),
  APPL_ID         NUMBER(9),
  STATUS_CODE     VARCHAR2(20 BYTE),
  STATUS_DATE     DATE,
  STATUS_REASON   VARCHAR2(1000 BYTE),
  CREATED_BY      VARCHAR2(100 BYTE),
  CREATED_DATE    DATE,
  LAST_UPD_BY     VARCHAR2(100 BYTE),
  LAST_UPD_DATE   DATE
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
