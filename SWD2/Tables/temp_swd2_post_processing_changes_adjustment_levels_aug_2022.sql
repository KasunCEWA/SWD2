CREATE TABLE TEMP_SWD2_POST_PROCESSING_CHANGES_ADJUSTMENT_LEVELS_AUG_2022
(
  SCHOOL      VARCHAR2(100 BYTE),
  CONSULTANT  VARCHAR2(50 BYTE),
  STUDENT     VARCHAR2(50 BYTE),
  APP_ID      NUMBER,
  ACTION      VARCHAR2(146 BYTE),
  LVL         VARCHAR2(10 BYTE),
  STATUS      VARCHAR2(30 BYTE)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
