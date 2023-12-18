CREATE OR REPLACE TRIGGER DISABILITY_CATEGORIES_BIU
BEFORE INSERT OR UPDATE
ON DISABILITY_CATEGORIES
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 31-May-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;
   END IF;
   IF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   :NEW.eff_from_date := TRUNC(:NEW.eff_from_date);
   :NEW.eff_to_date   := TRUNC(:NEW.eff_to_date);
   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END;
/

CREATE OR REPLACE TRIGGER SUB_DISABILITY_CATEGORIES_BIU
BEFORE INSERT OR UPDATE
ON SUB_DISABILITY_CATEGORIES
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 31-May-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.id           := NVL(:NEW.id, swd_seq.NEXTVAL);
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   :NEW.eff_from_date := TRUNC(:NEW.eff_from_date);
   :NEW.eff_to_date   := TRUNC(:NEW.eff_to_date);
   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END;
/

CREATE OR REPLACE TRIGGER SWD_APPLICATION_BIU
BEFORE INSERT OR UPDATE
ON SWD_APPLICATION
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 10-May-2019     Author: A Woo
 Created

 MOD:02     Date: 05-Feb-2021     Author: A Woo
 Log error

 MOD:03     Date: 03-May-2021     Author: A Woo
 Set specific case for STUDENT_FIRST_NAME if STATE_STUDENT_NBR is 37818779.

 MOD:04     Date: 09-Jul-2021     Author: A Woo
 Stop CREATED_BY and CREATED_DATE from changing on UPDATE.
 ******************************************************************************/
DECLARE

   e_data_changed            EXCEPTION;

BEGIN
   IF INSERTING THEN
      :NEW.appl_id      := COALESCE(:NEW.appl_id, swd_application_seq.NEXTVAL);
      :NEW.version_nbr  := 1;
      :NEW.created_by   := COALESCE(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      --Prevent lost updates
      IF (:NEW.version_nbr <> :OLD.version_nbr) THEN
         RAISE e_data_changed;
      ELSE
         :NEW.version_nbr := :OLD.version_nbr + 1;
      END IF;

      :NEW.created_by   := :OLD.created_by;   --MOD:04
      :NEW.created_date := :OLD.created_date; --MOD:04
   END IF;

   CASE
   WHEN (:NEW.state_student_nbr = 37818779) THEN --MOD:03
      :NEW.student_first_name := 'Hawa''ij';
   ELSE
      :NEW.student_first_name := INITCAP(:NEW.student_first_name);
   END CASE;

   :NEW.student_surname    := UPPER(:NEW.student_surname);
   :NEW.last_upd_by        := COALESCE(v('APP_USER'), USER);
   :NEW.last_upd_date      := SYSDATE;

EXCEPTION
   WHEN e_data_changed THEN
      com_utils.pr_log (p_module      => 'SWD_APPLICATION_BIU'
                       ,p_location    => 'Main'
                       ,p_app_alias   => 'SWD2'
                       ,p_text        => 'EXCEPTION e_data_changed. OLD version_nbr='||:OLD.version_nbr||'   NEW='||:NEW.version_nbr
                       ,p_debug_level => COM_UTILS.GC_ERROR_LVL); --MOD:02
      APEX_ERROR.ADD_ERROR (p_message => 'The funding application has been changed by another user since you viewed it. '
         ||'<span style="font-weight: bold; color: #ff0000;">To avoid losing your data, copy your changes into Word.</span>'
         ||'<br>Then refresh the page (Ctrl + R) to view the latest version.'
                           ,p_display_location => APEX_ERROR.C_INLINE_IN_NOTIFICATION);
      RAISE;
   WHEN OTHERS THEN
      com_utils.pr_log (p_module      => 'SWD_APPLICATION_BIU'
                       ,p_location    => 'Main'
                       ,p_app_alias   => 'SWD2'
                       ,p_text        => 'EXCEPTION OTHERS. '||SQLERRM
                       ,p_debug_level => COM_UTILS.GC_ERROR_LVL); --MOD:02

END swd_application_biu;
/

CREATE OR REPLACE TRIGGER SWD_APPL_ADJ_LVL_TRANSL_BIU
BEFORE INSERT OR UPDATE
ON SWD_APPL_ADJ_LVL_TRANSLATION
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 03-Jun-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.translation_id := NVL(:NEW.translation_id, swd_seq.NEXTVAL);
      :NEW.created_by     := NVL(v('APP_USER'), USER);
      :NEW.created_date   := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by     := :OLD.created_by;
      :NEW.created_date   := :OLD.created_date;
   END IF;

   :NEW.translation_type := UPPER(:NEW.translation_type);
   :NEW.eff_from_date    := TRUNC(:NEW.eff_from_date);
   :NEW.eff_to_date      := TRUNC(:NEW.eff_to_date);
   :NEW.last_upd_by      := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date    := SYSDATE;

END;
/

CREATE OR REPLACE TRIGGER SWD_APPL_DISABILITY_BIU
BEFORE INSERT OR UPDATE
ON SWD_APPL_DISABILITY
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 10-May-2019     Author: A Woo
 Created

 MOD:02     Date: 31-May-2021     Author: A Woo
 Remove referential integrity check to CEODB.SUB_DISABILITY_CATEGORIES.
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.appl_disabl_id := NVL(:NEW.appl_disabl_id, swd_appl_disability_seq.NEXTVAL);
      :NEW.created_by     := NVL(v('APP_USER'), USER);
      :NEW.created_date   := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by     := :OLD.created_by;
      :NEW.created_date   := :OLD.created_date;
   END IF;

   :NEW.last_upd_by    := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date  := SYSDATE;

END swd_appl_disability_biu;
/

CREATE OR REPLACE TRIGGER SWD_APPL_DOCUMENT_BIU
BEFORE INSERT OR UPDATE ON SWD_APPL_DOCUMENT
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 06-JUN-2020     Author: A Woo
 Created

 MOD:02     Date: 09-JUL-2020     Author: A Woo
 Stop CREATED_BY and CREATED_DATE from changing on UPDATE.
******************************************************************************/
BEGIN
   IF INSERTING THEN
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;

   END IF;

END swd_appl_document_biu;
/

CREATE OR REPLACE TRIGGER SWD_APPL_STATUS_BIU
BEFORE INSERT OR UPDATE
ON SWD_APPL_STATUS
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 15-May-2019     Author: A Woo
 Created

 MOD:02     Date: 09-Jul-2021     Author: A Woo
 Stop CREATED_BY and CREATED_DATE from changing on UPDATE.
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.appl_status_id := NVL(:NEW.appl_status_id, swd_appl_status_seq.NEXTVAL);
      :NEW.created_by     := NVL(v('APP_USER'), USER);
      :NEW.created_date   := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by     := :OLD.created_by;
      :NEW.created_date   := :OLD.created_date;
   END IF;

   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END swd_appl_status_biu;
/

CREATE OR REPLACE TRIGGER SWD_CODES_BIU
BEFORE INSERT OR UPDATE
ON SWD_CODES
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 15-May-2019     Author: A Woo
 Created

 MOD:02     Date: 29-Jan-2021     Author: A Woo
 Ensure data in columns SWD_CODE_TYPE and SWD_CODE is in uppercase.

 MOD:03     Date: 06-Jul-2021     Author: A Woo
 Ensure CREATED_BY and CREATED_DATE values cannot be changed on update.
 ******************************************************************************/

BEGIN
   IF INSERTING THEN
      :NEW.swd_code_id  := COALESCE(:NEW.swd_code_id, swd_codes_seq.NEXTVAL);
      :NEW.created_by   := COALESCE(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN --MOD:03
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   :NEW.swd_code_type := UPPER(:NEW.swd_code_type); --MOD:02
   :NEW.swd_code      := UPPER(:NEW.swd_code); --MOD:02
   :NEW.eff_from_date := TRUNC(:NEW.eff_from_date);
   :NEW.eff_to_date   := TRUNC(:NEW.eff_to_date);
   :NEW.last_upd_by   := COALESCE(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END swd_codes_biu;
/

CREATE OR REPLACE TRIGGER SWD_CONSULTANT_SCHOOL_BIU
BEFORE INSERT OR UPDATE
ON SWD_CONSULTANT_SCHOOL
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 31-May-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE
   e_parent_key_not_found    EXCEPTION;

   v_cnt                     NUMBER(01) := 0;
   v_msg                     VARCHAR2(150);

BEGIN
   IF INSERTING THEN
      :NEW.consult_school_id := NVL(:NEW.consult_school_id, swd_seq.NEXTVAL);
      :NEW.created_by        := NVL(v('APP_USER'), USER);
      :NEW.created_date      := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   --Check reference data
   SELECT COUNT(*)
   INTO   v_cnt
   FROM   education.employee_v e
   WHERE  e.employee# = :NEW.employee#;

   IF (v_cnt = 0) THEN
      v_msg := 'Employee number not found in parent table.';
      RAISE e_parent_key_not_found;
   END IF;

   :NEW.eff_from_date := TRUNC(:NEW.eff_from_date);
   :NEW.eff_to_date   := TRUNC(:NEW.eff_to_date);
   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

EXCEPTION
   WHEN e_parent_key_not_found THEN
      RAISE_APPLICATION_ERROR(-20000, v_msg);

END;
/

CREATE OR REPLACE TRIGGER SWD_DISABL_COND_DIAG_BIU
BEFORE INSERT OR UPDATE
ON SWD_DISABL_COND_DIAGNOSTICIAN
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 09-Sep-2020     Author: A Woo
 Created

 MOD:02     Date: 31-May-2021     Author: A Woo
 Remove referential check to CEODB.SUB_DISABILITY_CATEGORIES.
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.disabl_cond_diag_id := NVL(:NEW.disabl_cond_diag_id, swd_disabl_cond_diag_seq.NEXTVAL);
      :NEW.created_by          := NVL(v('APP_USER'), USER);
      :NEW.created_date        := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by          := :OLD.created_by;
      :NEW.created_date        := :OLD.created_date;
   END IF;

   :NEW.last_upd_by    := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date  := SYSDATE;

END swd_disabl_cond_diag_biu;
/

CREATE OR REPLACE TRIGGER SWD_DISABL_DIAGNOSTICIAN_BIU
BEFORE INSERT OR UPDATE
ON SWD_DISABL_DIAGNOSTICIAN
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 21-May-2019     Author: A Woo
 Created

 MOD:02     Date: 29-Jan-2021     Author: A Woo
 Added new id column.

 MOD:03     Date: 31-May-2021     Author: A Woo
 Remove referential integrity check to CEODB.DISABILITY_CATEGORIES.
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.disabl_diag_id := NVL(:NEW.disabl_diag_id, swd_disabl_diagnostician_seq.NEXTVAL); --MOD:02
      :NEW.created_by     := NVL(v('APP_USER'), USER);
      :NEW.created_date   := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by     := :OLD.created_by;
      :NEW.created_date   := :OLD.created_date;
   END IF;

   :NEW.eff_from_date := TRUNC(:NEW.eff_from_date);
   :NEW.eff_to_date   := TRUNC(:NEW.eff_to_date);
   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END swd_disabl_diagnostician_biu;
/

CREATE OR REPLACE TRIGGER SWD_DOCUMENT_BIU
BEFORE INSERT OR UPDATE ON SWD_DOCUMENT
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 18-MAY-2020     Author: A Woo
 Created

 MOD:02     Date: 09-Jul-2021     Author: A Woo
 Stop CREATED_BY and CREATED_DATE from changing on UPDATE.
******************************************************************************/
BEGIN
   IF INSERTING THEN
      :NEW.doc_id        := NVL(:new.doc_id, swd_document_seq.NEXTVAL);
      :NEW.created_by    := NVL(v('APP_USER'), USER);
      :NEW.created_date  := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by    := :OLD.created_by;
      :NEW.created_date  := :OLD.created_date;

   END IF;

   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END swd_document_biu;
/

CREATE OR REPLACE TRIGGER SWD_FUNDING_DEFAULT_BIU
BEFORE INSERT OR UPDATE
ON SWD_FUNDING_DEFAULT
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 01-Jun-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END;
/

CREATE OR REPLACE TRIGGER SWD_GRANT_BIU
BEFORE INSERT OR UPDATE
ON SWD_GRANT
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 31-May-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.swd_grant_id := NVL(:NEW.swd_grant_id, swd_grant_seq.NEXTVAL);
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   :NEW.paid_date     := TRUNC(:NEW.paid_date);
   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END;
/

CREATE OR REPLACE TRIGGER SWD_NOTIFICATION_LOG_BIU
BEFORE INSERT OR UPDATE ON SWD_NOTIFICATION_LOG
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 22-APR-2020     Author: A Woo
 Created

 MOD:02     Date: 09-Jul-2021     Author: A Woo
 Stop CREATED_BY and CREATED_DATE from changing on UPDATE.
******************************************************************************/
BEGIN
   IF INSERTING THEN
      :NEW.notif_id     := NVL(:NEW.notif_id, swd_notification_log_seq.NEXTVAL);
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;

   END IF;

   SELECT UPPER(:NEW.notif_type)
   INTO   :NEW.notif_type
   FROM   swd_codes
   WHERE  swd_code_type = 'NOTIFTYPE'
   AND    swd_code      = UPPER(:NEW.notif_type);

   :NEW.notif_date := CASE
                      WHEN :NEW.err_date IS NULL THEN
                         SYSDATE
                      ELSE
                         NULL
                      END;

   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Notification type is invalid');

END swd_notification_log_biu;
/

CREATE OR REPLACE TRIGGER SWD_STATE_PER_CAPITA_RATE_BIU
BEFORE INSERT OR UPDATE
ON SWD_STATE_PER_CAPITA_RATE
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
/******************************************************************************
 Modification History
 --------------------
 MOD:01     Date: 04-Jun-2021     Author: A Woo
 Created
 ******************************************************************************/
DECLARE

BEGIN
   IF INSERTING THEN
      :NEW.spc_rate_id  := NVL(:NEW.spc_rate_id, swd_seq.NEXTVAL);
      :NEW.created_by   := NVL(v('APP_USER'), USER);
      :NEW.created_date := SYSDATE;

   ELSIF UPDATING THEN
      :NEW.created_by   := :OLD.created_by;
      :NEW.created_date := :OLD.created_date;
   END IF;

   :NEW.last_upd_by   := NVL(v('APP_USER'), USER);
   :NEW.last_upd_date := SYSDATE;

END;
/
