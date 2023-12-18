CREATE TABLE SWD_APPL_ADJ_LVL_TRANSLATION
(
  TRANSLATION_ID     NUMBER(7),
  TRANSLATION_TYPE   VARCHAR2(10 BYTE),
  APPL_ADJ_LVL_CODE  VARCHAR2(20 BYTE),
  TRANSLATION_LVL    NUMBER(6,2),
  EFF_FROM_DATE      DATE,
  EFF_TO_DATE        DATE,
  TRANSLATION_DESC   VARCHAR2(250 BYTE),
  SORT_ORDER         NUMBER(4),
  CREATED_BY         VARCHAR2(100 BYTE),
  CREATED_DATE       DATE,
  LAST_UPD_BY        VARCHAR2(100 BYTE),
  LAST_UPD_DATE      DATE
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
