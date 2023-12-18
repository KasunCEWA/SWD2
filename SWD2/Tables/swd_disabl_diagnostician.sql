CREATE TABLE SWD_DISABL_DIAGNOSTICIAN
(
  DISABL_DIAG_ID           NUMBER(9),
  DISABILITY_TYPE_CODE     VARCHAR2(10 BYTE),
  DIAGNOSTICIAN_TYPE_CODE  VARCHAR2(20 BYTE),
  EFF_FROM_DATE            DATE,
  EFF_TO_DATE              DATE,
  CREATED_BY               VARCHAR2(100 BYTE),
  CREATED_DATE             DATE,
  LAST_UPD_BY              VARCHAR2(100 BYTE),
  LAST_UPD_DATE            DATE
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
