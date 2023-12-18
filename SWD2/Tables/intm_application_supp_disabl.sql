CREATE TABLE INTM_APPLICATION_SUPP_DISABL
(
  SUPP_DISABL_ID      NUMBER(10),
  APPL_ID             NUMBER(10),
  DISABILITY_TYPE     VARCHAR2(4000 BYTE),
  DIAGNOSTICIAN_TYPE  VARCHAR2(4000 BYTE),
  DIAGNOSTICIAN       VARCHAR2(4000 BYTE),
  DISABLING_COND      VARCHAR2(4000 BYTE),
  DIAGNOSIS_DATE      VARCHAR2(4000 BYTE),
  DIAGNOSTICIAN_TEXT  VARCHAR2(4000 BYTE),
  MIGRATED_IND        VARCHAR2(1 BYTE)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
