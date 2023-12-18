CREATE TABLE SWD_APPL_DISABILITY_20220401
(
  APPL_DISABL_ID           NUMBER(9),
  APPL_ID                  NUMBER(9),
  DISABILITY_COND_ID       NUMBER(9),
  PRIMARY_COND_FLG         VARCHAR2(1 BYTE),
  DIAGNOSTICIAN_TYPE_CODE  VARCHAR2(20 BYTE),
  DIAGNOSTICIAN            VARCHAR2(400 BYTE),
  DIAGNOSIS_DATE           DATE,
  DIAGNOSTICIAN_TEXT       VARCHAR2(4000 BYTE),
  DELETE_DATE              DATE,
  CREATED_BY               VARCHAR2(100 BYTE),
  CREATED_DATE             DATE,
  LAST_UPD_BY              VARCHAR2(100 BYTE),
  LAST_UPD_DATE            DATE,
  DISABILITY_LVL_CODE      VARCHAR2(20 BYTE),
  DISABILITY_COMMENT       VARCHAR2(100 BYTE)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
