CREATE TABLE SWD_FUNDING_DEFAULT
(
  FUNDING_YEAR        NUMBER(4),
  DPTS_CUTOFF         NUMBER(1),
  DPTS_VALUE          NUMBER(12,2)              DEFAULT ON NULL 0.00,
  INCENTIVE_VALUE     NUMBER(12,2)              DEFAULT ON NULL 0.00,
  WBL_VALUE           NUMBER(12,2)              DEFAULT ON NULL 0.00,
  TA_MAIN_VALUE       NUMBER(12,2)              DEFAULT ON NULL 0.00,
  TA_UNIT_VALUE       NUMBER(12,2)              DEFAULT ON NULL 0.00,
  GRG_DPTS_CUTOFF     NUMBER(2)                 DEFAULT ON NULL 0,
  GRG_VALUE           NUMBER(12,2)              DEFAULT ON NULL 0.00,
  APPROVAL_DATE       DATE,
  DPTS_VALUE_1        NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_1_1      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_2        NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_2_1      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_3        NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_3_1      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_3_2      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_3_3      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_4        NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_4_1      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  DPTS_VALUE_4_2_ISN  NUMBER(12,2)              DEFAULT ON NULL 0.00,
  PROVIS_PER_DED      NUMBER(12,2)              DEFAULT ON NULL 0.00,
  CREATED_BY          VARCHAR2(100 BYTE),
  CREATED_DATE        DATE,
  LAST_UPD_BY         VARCHAR2(100 BYTE),
  LAST_UPD_DATE       DATE
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;