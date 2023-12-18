CREATE TABLE SWD_APPLICATION_26082022
(
  APPL_ID                         NUMBER(9),
  FUNDING_YEAR                    NUMBER(4),
  STATE_STUDENT_NBR               NUMBER(8),
  STUDENT_USERNAME                VARCHAR2(70 BYTE),
  STUDENT_FIRST_NAME              VARCHAR2(50 BYTE),
  STUDENT_SURNAME                 VARCHAR2(50 BYTE),
  DOB                             DATE,
  GENDER                          VARCHAR2(2 BYTE),
  RELIGION_CODE                   VARCHAR2(20 BYTE),
  SCHOOL_ID                       INTEGER,
  ENROLLED_SCHOOL_LVL             VARCHAR2(20 BYTE),
  FUNDING_SCHOOL_LVL              VARCHAR2(20 BYTE),
  PARENT_CONSENT_FLG              VARCHAR2(1 BYTE),
  APPL_ADJ_LVL_CODE               VARCHAR2(20 BYTE),
  APPL_ADJ_LVL_COMMENT            VARCHAR2(4000 BYTE),
  NCCD_CATGY_CODE                 VARCHAR2(20 BYTE),
  NCCD_ADJ_LVL_CODE               VARCHAR2(20 BYTE),
  IAP_CURRIC_PARTCP_COMMENT       VARCHAR2(4000 BYTE),
  IAP_CURRIC_PARTCP_ADJ_LVL_CODE  VARCHAR2(20 BYTE),
  IAP_COMMUN_PARTCP_COMMENT       VARCHAR2(4000 BYTE),
  IAP_COMMUN_PARTCP_ADJ_LVL_CODE  VARCHAR2(20 BYTE),
  IAP_MOBILITY_COMMENT            VARCHAR2(4000 BYTE),
  IAP_MOBILITY_ADJ_LVL_CODE       VARCHAR2(20 BYTE),
  IAP_PERSONAL_CARE_COMMENT       VARCHAR2(4000 BYTE),
  IAP_PERSONAL_CARE_ADJ_LVL_CODE  VARCHAR2(20 BYTE),
  IAP_SOC_SKILLS_COMMENT          VARCHAR2(4000 BYTE),
  IAP_SOC_SKILLS_ADJ_LVL_CODE     VARCHAR2(20 BYTE),
  IAP_SAFETY_COMMENT              VARCHAR2(4000 BYTE),
  IAP_SAFETY_ADJ_LVL_CODE         VARCHAR2(20 BYTE),
  DELETE_DATE                     DATE,
  VERSION_NBR                     NUMBER(4),
  RELATED_APPL_ID                 NUMBER(9),
  CREATED_BY                      VARCHAR2(100 BYTE),
  CREATED_DATE                    DATE,
  LAST_UPD_BY                     VARCHAR2(100 BYTE),
  LAST_UPD_DATE                   DATE,
  INACTIVE_DATE                   DATE,
  REVIEW_DATE                     DATE,
  REVIEW_COMMENT                  VARCHAR2(4000 BYTE),
  STUDENT_FTE                     NUMBER(2,1),
  FED_GOVT_FUNDING_EXCL_FLG       VARCHAR2(1 BYTE),
  LEGACY_STUDENT_ID               NUMBER(10)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
