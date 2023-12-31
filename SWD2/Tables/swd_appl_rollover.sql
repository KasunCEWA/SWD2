CREATE GLOBAL TEMPORARY TABLE SWD_APPL_ROLLOVER
(
  APPL_ID               NUMBER(9),
  FUNDING_YEAR          NUMBER(4),
  STATE_STUDENT_NUMBER  NUMBER(8),
  STUDENT_FIRST_NAME    VARCHAR2(50 BYTE),
  STUDENT_SURNAME       VARCHAR2(50 BYTE),
  SCHOOL_ID             INTEGER,
  ENROLLED_SCHOOL_LVL   VARCHAR2(20 BYTE),
  FUNDING_SCHOOL_LVL    VARCHAR2(20 BYTE)
)
ON COMMIT PRESERVE ROWS
NOCACHE;
