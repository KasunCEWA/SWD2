CREATE UNIQUE INDEX DISABL_CATGY_PK ON DISABILITY_CATEGORIES
(DIS_CAT_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX NOTIFICATIONS_PK ON SWD_NOTIFICATION_LOG
(NOTIF_ID)
LOGGING
NOPARALLEL;

CREATE INDEX NOTIF_SRC_REC_ID_CHR_IDX ON SWD_NOTIFICATION_LOG
(NOTIF_TYPE, NOTIF_SOURCE, SOURCE_REC_ID_CHR)
LOGGING
NOPARALLEL;

CREATE INDEX NOTIF_SRC_REC_ID_NUM_IDX ON SWD_NOTIFICATION_LOG
(NOTIF_TYPE, NOTIF_SOURCE, SOURCE_REC_ID_NUM)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX STG_APPL_2019_PK ON STG_APPLICATION_2019
(APPL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX STG_APPL_2021_IDX ON STG_APPLICATION_2021
(APPL_STUDENT_ID, FUNDING_YEAR, DISABLING_COND_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX STG_APPL_PK ON STG_APPLICATION
(APPL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX STG_APPL_SUPP_2019_DISABL_PK ON STG_APPL_SUPP_DISAB_2019
(SUPP_DISABL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX STG_APPL_SUPP_DISABL_PK ON STG_APPLICATION_SUPP_DISABL
(SUPP_DISABL_ID)
LOGGING
NOPARALLEL;

CREATE INDEX STG_DATA_CORR_IDX1 ON STG_DATA_CORRECTION
(SCIO_STUDENT_NBR)
LOGGING
NOPARALLEL;

CREATE INDEX STG_DATA_CORR_IDX2 ON STG_DATA_CORRECTION
(SWD2_APPL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SUB_DISABL_CATGY_PK ON SUB_DISABILITY_CATEGORIES
(ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SUB_DISABL_CATGY_UK1 ON SUB_DISABILITY_CATEGORIES
(DIS_CAT_ID, SUB_CAT_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPLICATION_PK ON SWD_APPLICATION
(APPL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_ADJ_LVL_PK ON SWD_APPL_ADJ_LVL_TRANSLATION
(TRANSLATION_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_ADJ_LVL_UK1 ON SWD_APPL_ADJ_LVL_TRANSLATION
(TRANSLATION_TYPE, APPL_ADJ_LVL_CODE, EFF_FROM_DATE)
LOGGING
NOPARALLEL;

CREATE INDEX SWD_APPL_APPL_FK ON SWD_APPLICATION
(RELATED_APPL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_DISABILITY_UK1 ON SWD_APPL_DISABILITY
(APPL_ID, DISABILITY_COND_ID, DIAGNOSTICIAN_TYPE_CODE, DELETE_DATE)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_DISABL_PK ON SWD_APPL_DISABILITY
(APPL_DISABL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_DOCUMENT_UK ON SWD_APPL_DOCUMENT
(APPL_ID, DOC_ID, DOC_HIDE_DATE)
LOGGING
NOPARALLEL;

CREATE INDEX SWD_APPL_IDX ON SWD_APPLICATION
(SCHOOL_ID, STATE_STUDENT_NBR, DELETE_DATE)
LOGGING
NOPARALLEL;

CREATE INDEX SWD_APPL_STATUS_I1 ON SWD_APPL_STATUS
(APPL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_STATUS_PK ON SWD_APPL_STATUS
(APPL_STATUS_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_APPL_UK ON SWD_APPLICATION
(FUNDING_YEAR, FUNDING_SCHOOL_LVL, STUDENT_SURNAME, STUDENT_FIRST_NAME, STUDENT_USERNAME, 
DOB, RELATED_APPL_ID, DELETE_DATE, INACTIVE_DATE)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_CODES_PK ON SWD_CODES
(SWD_CODE_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_CODES_UK1 ON SWD_CODES
(SWD_CODE_TYPE, SWD_CODE)
LOGGING
NOPARALLEL;

CREATE INDEX SWD_CONSULT_SCHOOL_EMP_IDX ON SWD_CONSULTANT_SCHOOL
(EMPLOYEE#, SCHOOL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_CONSULT_SCHOOL_PK ON SWD_CONSULTANT_SCHOOL
(CONSULT_SCHOOL_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_DISABL_COND_DIAG_PK ON SWD_DISABL_COND_DIAGNOSTICIAN
(DISABL_COND_DIAG_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_DISABL_COND_DIAG_UK ON SWD_DISABL_COND_DIAGNOSTICIAN
(DISABILITY_TYPE_CODE, DISABILITY_COND_CODE, DIAGNOSTICIAN_TYPE_CODE)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_DISABL_DIAG_PK ON SWD_DISABL_DIAGNOSTICIAN
(DISABL_DIAG_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_DISABL_DIAG_UK1 ON SWD_DISABL_DIAGNOSTICIAN
(DISABILITY_TYPE_CODE, DIAGNOSTICIAN_TYPE_CODE)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_DOCUMENT_PK ON SWD_DOCUMENT
(DOC_ID)
LOGGING
NOPARALLEL;



CREATE UNIQUE INDEX SWD_FUNDING_DEFLT_PK ON SWD_FUNDING_DEFAULT
(FUNDING_YEAR)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_GRANT_PK ON SWD_GRANT
(SWD_GRANT_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_SPC_RATE_PK ON SWD_STATE_PER_CAPITA_RATE
(SPC_RATE_ID)
LOGGING
NOPARALLEL;

CREATE UNIQUE INDEX SWD_SPC_RATE_UK1 ON SWD_STATE_PER_CAPITA_RATE
(FUNDING_YEAR, FUNDING_TYPE, STATE_FUNDING_CATGY)
LOGGING
NOPARALLEL;

