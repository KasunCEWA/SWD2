CREATE TABLE STG_APPLICATION
(
  APPL_ID                  NUMBER(10),
  STU_UPN                  VARCHAR2(4000 BYTE),
  STU_FIRST_NAME           VARCHAR2(40 BYTE),
  STU_SURNAME              VARCHAR2(40 BYTE),
  CURR_SCHOOL_CODE         NUMBER(10),
  CURR_SCHOOL_LOCN         VARCHAR2(40 BYTE),
  DOB                      VARCHAR2(40 BYTE),
  GENDER                   VARCHAR2(40 BYTE),
  RELIGIOUS                VARCHAR2(400 BYTE),
  STATE_ID                 VARCHAR2(400 BYTE),
  STU_CURR_YR              VARCHAR2(40 BYTE),
  PARENT_CONSENT_IND       VARCHAR2(40 BYTE),
  PARENT_CONSENT_DATE      VARCHAR2(40 BYTE),
  NCCD_CATGY               VARCHAR2(4000 BYTE),
  NCCD_DISABILITY_TYPE     VARCHAR2(4000 BYTE),
  NCCD_LOA                 VARCHAR2(4000 BYTE),
  SWD_DISABILITY_TYPE      VARCHAR2(4000 BYTE),
  DIAGNOSTICIAN_TYPE       VARCHAR2(4000 BYTE),
  DIAGNOSTICIAN            VARCHAR2(4000 BYTE),
  DISABLING_COND           VARCHAR2(4000 BYTE),
  DIAGNOSIS_DATE           VARCHAR2(4000 BYTE),
  DIAGNOSTICIAN_TXT        VARCHAR2(4000 BYTE),
  IAP_CURRIC_PARTCP_COMM   VARCHAR2(4000 BYTE),
  IAP_CURRIC_PARTCP_LOA    VARCHAR2(4000 BYTE),
  IAP_COMMUNC_PARTCP_COMM  VARCHAR2(4000 BYTE),
  IAP_COMMUNC_PARTCP_LOA   VARCHAR2(4000 BYTE),
  IAP_MOBILITY_COMM        VARCHAR2(4000 BYTE),
  IAP_MOBILITY_LOA         VARCHAR2(4000 BYTE),
  IAP_PERSONAL_CARE_COMM   VARCHAR2(4000 BYTE),
  IAP_PERSONAL_CARE_LOA    VARCHAR2(4000 BYTE),
  IAP_SOC_SKILLS_COMM      VARCHAR2(4000 BYTE),
  IAP_SOC_SKILLS_LOA       VARCHAR2(4000 BYTE),
  IAP_SAFETY_COMM          VARCHAR2(4000 BYTE),
  IAP_SAFETY_LOA           VARCHAR2(4000 BYTE),
  APPLICATION_DATE         VARCHAR2(4000 BYTE),
  APPLICATION_STATE        VARCHAR2(4 BYTE),
  PRIM_SEC_DISABILITY_IND  VARCHAR2(4000 BYTE),
  UPDATED_BY               VARCHAR2(4000 BYTE),
  APPLICATION_LOA          VARCHAR2(4000 BYTE),
  FUNDING_YR               VARCHAR2(100 BYTE),
  MIGRATED_IND             VARCHAR2(1 BYTE),
  ERR_DATE                 DATE,
  ERR_DESC                 VARCHAR2(4000 BYTE)
)
LOGGING 
NOCOMPRESS 
NO INMEMORY
NOCACHE
RESULT_CACHE (MODE DEFAULT)
NOPARALLEL;
