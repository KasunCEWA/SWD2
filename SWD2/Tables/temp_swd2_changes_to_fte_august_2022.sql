CREATE TABLE TEMP_SWD2_CHANGES_TO_FTE_AUGUST_2022
(
  SCHOOL        VARCHAR2(100 BYTE),
  CONSULTANT    VARCHAR2(50 BYTE),
  STUDENT       VARCHAR2(50 BYTE),
  APP_ID        VARCHAR2(50 BYTE),
  ACTION        VARCHAR2(50 BYTE),
  CONFIMED_FTE  VARCHAR2(50 BYTE),
  NEW_FTE       VARCHAR2(10 BYTE)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
