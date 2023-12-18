CREATE OR REPLACE PACKAGE BODY swd_migration IS
/******************************************************************************

 Modification History
 --------------------
 MOD:02     Date: 08-Jun-2021     Author: A Woo
 Created. Package name repurposed from INTERIM to SWD2 migration.
 
 MOD:03     Date: 10-Aug-2021     Author: A Woo
 Rewrite procedure pr_upd_proc_status.
 Add function get_scio_student_nbr.
 Add procedures
 - pr_upd_legacy_student_id
 - pr_maint_ceodb_students
 - pr_maint_ceodb_student_schools
 - pr_maint_ceodb_stu_disablties
 - pr_maint_ceodb_disabilities
 - pr_upd_scio_swd
 - pr_ins_scio_swd

 MOD:04     Date: 19-Oct-2021     Author: A Woo
 Add global variable g_err_msg.
 In pr_upd_proc_status, modify update part of MERGE statement to update 
 STG_DATA_CORRECTION.SWD2_APPL_ID.
 Add procedure pr_ins_swd2.
******************************************************************************/
   GC_APP_ALIAS     CONSTANT VARCHAR2(10) := 'STG';
   GC_PACKAGE       CONSTANT VARCHAR2(30) := 'SWD.SWD_MIGRATION';
   GC_START         CONSTANT VARCHAR2(01) := 'S';
   GC_END           CONSTANT VARCHAR2(01) := 'E';

   g_indent_count            INTEGER := 0;
   g_err_count               INTEGER := 0;
   g_err_msg                 VARCHAR2(1000); --MOD:04


/*****************************************************************************************
 PURPOSE: Logs the start and end of a procedure or function.
          This also controls the indentation of the messages logged.
 ****************************************************************************************/
PROCEDURE pr_debug_start_end (p_flag IN VARCHAR2, p_subprog_unit IN VARCHAR2) IS

BEGIN

   IF (p_flag = GC_START) THEN
      DBMS_APPLICATION_INFO.SET_MODULE (GC_PACKAGE, p_subprog_unit);
      g_indent_count := g_indent_count + 1;
      com_utils.pr_log(p_module      => GC_PACKAGE
                      ,p_location    => p_subprog_unit
                      ,p_app_alias   => GC_APP_ALIAS
                      ,p_text        => '=====  START '||p_subprog_unit||'  ====='
                      ,p_user        => v('APP_USER')
                      ,p_debug_level => com_utils.gc_debug_lvl1);

   ELSIF (p_flag = GC_END) THEN
      g_indent_count := g_indent_count - 1;
      IF (g_indent_count < 0) THEN
         g_indent_count := 0;
      END IF;
      com_utils.pr_log (p_module      => GC_PACKAGE
                       ,p_location    => p_subprog_unit
                       ,p_app_alias   => GC_APP_ALIAS
                       ,p_text        => '=====  END '||p_subprog_unit||'  ====='
                       ,p_user        => v('APP_USER')
                       ,p_debug_level => com_utils.gc_debug_lvl1);
      DBMS_APPLICATION_INFO.SET_MODULE(GC_PACKAGE, NULL);
   END IF;

END pr_debug_start_end;


/*****************************************************************************************
 PURPOSE: Logs a debug message.
 ****************************************************************************************/
PROCEDURE pr_debug (p_debug_level IN VARCHAR2
                   ,p_location    IN VARCHAR2
                   ,p_text        IN VARCHAR2) IS

BEGIN
   com_utils.pr_log (p_module      => GC_PACKAGE
                    ,p_location    => p_location
                    ,p_app_alias   => GC_APP_ALIAS
                    ,p_text        => RPAD('*', g_indent_count, '*')||' '||p_text
                    ,p_debug_level => p_debug_level);

END pr_debug;


/*****************************************************************************************
 MOD:03
 PURPOSE: Update STG_DATA_CORRECTION with processing status.

    p_proc_ind
    ----------
    B = Brand New
    M = Migrated
    F = Failed migration
    E = Error
 ****************************************************************************************/
PROCEDURE pr_upd_proc_status (p_fund_year         IN stg_data_correction.funding_year%TYPE
                             ,p_legacy_student_id IN stg_data_correction.scio_student_nbr%TYPE
                             ,p_surname           IN stg_data_correction.surname%TYPE
                             ,p_first_name        IN stg_data_correction.first_name%TYPE
                             ,p_dob               IN stg_data_correction.dob%TYPE
                             ,p_gender            IN stg_data_correction.gender%TYPE
                             ,p_fund_school_lvl   IN stg_data_correction.school_grade%TYPE
                             ,p_swd2_appl_id      IN stg_data_correction.swd2_appl_id%TYPE
                             ,p_proc_ind          IN stg_data_correction.proc_ind%TYPE
                             ,p_err_msg           IN stg_data_correction.err_message%TYPE) IS
   PRAGMA AUTONOMOUS_TRANSACTION;

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_upd_proc_status';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   MERGE INTO stg_data_correction dest
   USING (SELECT p_fund_year         fund_year
                ,p_legacy_student_id legacy_student_id
                ,p_surname           surname
                ,p_first_name        first_name
                ,p_dob               dob
                ,p_gender            gender
                ,p_fund_school_lvl   fund_school_lvl
                ,p_swd2_appl_id      swd2_appl_id
                ,p_proc_ind          proc_ind
                ,SYSDATE             proc_date
                ,p_err_msg           proc_msg
          FROM   DUAL) src
   ON (    dest.funding_year = src.fund_year
       AND dest.surname      = src.surname
       AND dest.first_name   = src.first_name
       AND dest.dob          = src.dob
       AND dest.gender       = src.gender)
   WHEN MATCHED THEN
      UPDATE
      SET    dest.scio_student_nbr = src.legacy_student_id
            ,dest.swd2_appl_id     = src.swd2_appl_id --MOD:04
            ,dest.proc_ind         = src.proc_ind
            ,dest.err_date         = src.proc_date
            ,dest.err_message      = src.proc_msg
   WHEN NOT MATCHED THEN
      INSERT (funding_year
             ,scio_student_nbr
             ,surname
             ,first_name
             ,dob
             ,gender
             ,school_grade
             ,swd2_appl_id
             ,proc_ind
             ,err_date
             ,err_message)
      VALUES (src.fund_year
             ,src.legacy_student_id
             ,src.surname
             ,src.first_name
             ,src.dob
             ,src.gender
             ,src.fund_school_lvl
             ,src.swd2_appl_id
             ,src.proc_ind
             ,src.proc_date
             ,src.proc_msg);

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_upd_proc_status;


/*****************************************************************************************
 PURPOSE: Assert given condition. If assertion fails, append message to g_err_msg.
    Ensure g_err_msg is cleared prior to call to assert so that it contains only
    relevant message(s).
 ****************************************************************************************/
PROCEDURE assert (p_cond       IN     BOOLEAN
                 ,p_err_msg    IN     VARCHAR2
                 ,p_raise_excp IN     VARCHAR2 DEFAULT 'N') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'assert';

   e_condition_not_met       EXCEPTION;

BEGIN
   IF NOT p_cond THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Assertion failed: '||p_err_msg);
      g_err_msg   := SUBSTR(g_err_msg||' '||p_err_msg, 1, 1000);
      g_err_count := g_err_count + 1;

      IF (p_raise_excp = 'Y') THEN
         RAISE e_condition_not_met;
      END IF;
   END IF;

END assert;


/*****************************************************************************************
 PURPOSE: Validate disability information input
    N.B.: Based on SWD_FUNDING_APPLICATION.PR_VALIDATE_DISABL_INPUT.
 ****************************************************************************************/
PROCEDURE pr_validate_disabl_input (
   p_appl_status        IN swd_appl_status.status_code%TYPE
  ,p_disabl_cond_id     IN swd_appl_disability.disability_cond_id%TYPE
  ,p_diagnostician_type IN swd_appl_disability.diagnostician_type_code%TYPE
  ,p_diagnostician      IN swd_appl_disability.diagnostician%TYPE
  ,p_diagnosis_date     IN swd_appl_disability.diagnosis_date%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_validate_disabl_input';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (p_appl_status <> 'DRAFT') THEN
      assert((p_disabl_cond_id IS NOT NULL),     'Disability Type and Disabling Condition are required.', 'N');
      assert((p_diagnostician_type IS NOT NULL), 'Diagnostician Type is required.', 'N');

      IF (p_diagnostician_type <> 'NA') THEN
         assert((p_diagnostician IS NOT NULL),   'Diagnostician is required.', 'N');
         assert((p_diagnosis_date IS NOT NULL),  'Diagnosis Date is required.', 'N');
      END IF;
   END IF;

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'err_count='||g_err_count);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_validate_disabl_input;


/*****************************************************************************************
 PURPOSE: Validate relevant input at relevant statuses.
    N.B.: Based on SWD_FUNDING_APPLICATION.PR_VALIDATE_INPUT.
 ****************************************************************************************/
PROCEDURE pr_validate_input (
   p_appl_status        IN swd_appl_status.status_code%TYPE
  ,p_funding_year       IN swd_application.funding_year%TYPE
  ,p_school_id          IN swd_application.school_id%TYPE
  ,p_ssn                IN swd_application.state_student_nbr%TYPE
  ,p_username           IN swd_application.student_username%TYPE
  ,p_given_name         IN swd_application.student_first_name%TYPE
  ,p_surname            IN swd_application.student_surname%TYPE
  ,p_dob                IN swd_application.dob%TYPE
  ,p_gender             IN swd_application.gender%TYPE
  ,p_enrolld_sch_lvl    IN swd_application.enrolled_school_lvl%TYPE
  ,p_funding_sch_lvl    IN swd_application.funding_school_lvl%TYPE
  ,p_parent_consent_flg IN swd_application.parent_consent_flg%TYPE
  ,p_nccd_catgy         IN swd_application.nccd_catgy_code%TYPE
  ,p_nccd_loa           IN swd_application.nccd_adj_lvl_code%TYPE
  ,p_appl_loa           IN swd_application.appl_adj_lvl_code%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_validate_input';

   e_invalid_input           EXCEPTION;
   
   v_valid_flg               VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   --Only raise an ASSERT exception if you want to stop further validation.
   assert((p_appl_status IS  NOT NULL),    'Application Status is required.', 'N');
   assert((p_funding_year IS NOT NULL),    'Funding Year is required.', 'N');
   assert((p_school_id IS NOT NULL),       'School is required.', 'N');
   assert((p_given_name IS NOT NULL),      'Given Name is required.', 'N');
   assert((p_surname IS NOT NULL),         'Surname is required.', 'N');
   assert((p_funding_sch_lvl IS NOT NULL), 'Funding Year Level is required.', 'N');
   IF (p_funding_sch_lvl IS NOT NULL) THEN
      v_valid_flg := CASE education.edu_utils.get_academic_lvl_desc (p_funding_sch_lvl, TRUNC(SYSDATE))
                     WHEN 'Unknown' THEN
                        'N'
                     ELSE
                        'Y'
                     END;
      IF (v_valid_flg = 'N') THEN
         assert((v_valid_flg = 'Y'), 'Funding Year Level '||p_funding_sch_lvl||' is not valid', 'N');
      END IF;
   END IF;

   IF (p_appl_status <> 'DRAFT') THEN
      assert((p_dob IS NOT NULL),          'DOB is required.', 'N');
      assert(((MONTHS_BETWEEN(TO_DATE('01-JAN-'||p_funding_year, 'DD-MON-YYYY'), p_dob) / 12) < 20)
                                          ,'Student must be younger than 20', 'N');
      assert((p_gender IS NOT NULL),       'Gender is required.', 'N');
      assert((p_parent_consent_flg = 'Y'), 'Parental Permission is required.', 'N');
      assert((p_nccd_catgy IS NOT NULL),   'NCCD Category is required.', 'N');
      assert((p_nccd_loa IS NOT NULL),     'NCCD Adjustment Level is required.', 'N');
   END IF;

   IF (p_appl_status = 'FUNDAPPR') THEN
      assert((p_appl_loa IS NOT NULL),  'SWD Adjustment Level is required.', 'Y');
   END IF;

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'err_count='||g_err_count);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_validate_input;


/*****************************************************************************************
 PURPOSE: Log any application that exists in SCIO but not found in SWD2 for the given year.
    If year = 0, reconcile all.

    Data between the 2 systems will be matched on the following
    - First name
    - Surname
    - DOB
    - Gender
    - School
    - Academic year level
    - Funding year
 ****************************************************************************************/
PROCEDURE pr_log_missing_swd2_appl (p_recon_year IN NUMBER DEFAULT 0) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_log_missing_swd2_appl';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params recon_year='||p_recon_year);

   INSERT INTO stg_application_2021 (
      appl_student_id
     ,funding_year
     ,disabling_cond_id
     ,migrated_ind
     ,err_date
     ,err_desc)
   WITH scio_data AS (
      SELECT s.student#
            ,s.first_name
            ,s.surname
            ,s.dob
            ,s.gender
            ,s.stu_notes
            ,s.school_id
            ,s.school_year
            ,s.grade
            ,sd.dpts
            ,sd.dpts_star
      FROM   ceodb_student_temp_v s
             INNER JOIN ceodb.student_disabilities sd
                ON  s.student#     = sd.student#
                AND s.school_year  = sd.year
                AND (s.school_year = p_recon_year OR p_recon_year = 0)
   )
   SELECT d.student#
         ,d.school_year
         ,NULL    --disabling_cond_id
         ,'N'     --migrated_ind
         ,SYSDATE
         ,'surname='||d.surname||', first_name='||d.first_name||', msg=No match found in SWD_APPLICATION. '||
             'Unable to migrate student note, asterisk and disability level'
   FROM   scio_data d
          LEFT JOIN swd_application a
             ON  d.first_name  = a.student_first_name
             AND d.surname     = a.student_surname
             AND d.dob         = a.dob
             AND d.gender      = a.gender
             AND d.school_id   = a.school_id
             AND d.grade       = a.funding_school_lvl
             AND d.school_year = a.funding_year
             AND a.delete_date IS NULL
             AND (a.funding_year = p_recon_year OR p_recon_year = 0)
   WHERE a.appl_id IS NULL;

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      RAISE;
END pr_log_missing_swd2_appl;


/*****************************************************************************************
 PURPOSE: Log any disability that exists in SCIO but not found in SWD2 for matching 
    applications in the given year.
    If year = 0, reconcile all.

    Data between the 2 systems will be matched on the following
    - First name
    - Surname
    - DOB
    - Gender
    - School
    - Academic year level
    - Funding year
    - Disabling condition id
    - Primary condition ind
 ****************************************************************************************/
PROCEDURE pr_log_missing_swd2_disabl (p_recon_year IN NUMBER DEFAULT 0) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_log_missing_swd2_disabl';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params recon_year='||p_recon_year);

   MERGE INTO stg_application_2021 dest
   USING (SELECT s.student#
                ,s.first_name
                ,s.surname
                ,s.school_year
                ,s.grade
                ,sdc.id                disabling_cond_id
                ,d.dis_cat_id          dis_cat_id
                ,d.sub_cat_id          sub_cat_id
                ,NVL(d.primary_condition, 'N') primary_cond_ind
                ,UPPER(d.dis_level)    disability_lvl
                ,TRIM(d.comments)      disability_comm
          FROM   ceodb_student_temp_v s
                 INNER JOIN ceodb.disabilities d
                    ON  s.student#     = d.student#
                    AND (s.school_year = p_recon_year OR p_recon_year = 0)
                 INNER JOIN ceodb.sub_disability_categories sdc
                    ON  d.dis_cat_id = sdc.dis_cat_id
                    AND d.sub_cat_id = sdc.sub_cat_id
                 INNER JOIN swd_application a
                    ON  s.first_name    = a.student_first_name
                    AND s.surname       = a.student_surname
                    AND s.dob           = a.dob
                    AND s.gender        = a.gender
                    AND s.school_id     = a.school_id
                    AND s.grade         = a.funding_school_lvl
                    AND s.school_year   = a.funding_year
                    AND (a.funding_year = p_recon_year OR p_recon_year = 0)
                    AND a.delete_date IS NULL
                 LEFT JOIN swd_appl_disability ad
                    ON  a.appl_id = ad.appl_id
                    AND sdc.id    = ad.disability_cond_id
                    AND NVL(d.primary_condition, 'N') = ad.primary_cond_flg
                    AND ad.delete_date IS NULL
          WHERE ad.appl_disabl_id IS NULL) src
   ON (    dest.appl_student_id   = src.student#
       AND dest.funding_year      = src.school_year
       AND dest.disabling_cond_id = src.disabling_cond_id)
   WHEN MATCHED THEN
      UPDATE 
      SET    dest.migrated_ind = 'N'
            ,dest.err_date     = SYSDATE
            ,dest.err_desc     = dest.err_desc||', dis_cat='||src.dis_cat_id||', sub_cat='||src.sub_cat_id||
                                    ', primary_flg='||src.primary_cond_ind||', msg=No match found in SWD_APPL_DISABILITY'
   WHEN NOT MATCHED THEN
      INSERT (dest.appl_student_id
             ,dest.funding_year
             ,dest.disabling_cond_id
             ,dest.migrated_ind
             ,dest.err_date
             ,dest.err_desc)
      VALUES (src.student#
             ,src.school_year
             ,src.disabling_cond_id
             ,'N'
             ,SYSDATE
             ,'surname='||src.surname||', first_name='||src.first_name||', dis_cat='||src.dis_cat_id||
                 ', sub_cat='||src.sub_cat_id||', primary_flg='||src.primary_cond_ind||
                 ', msg=No match found in SWD_APPL_DISABILITY'
             )
   LOG ERRORS INTO stg_application_2021_err REJECT LIMIT 100;

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      RAISE;
END pr_log_missing_swd2_disabl;


/*****************************************************************************************
 PURPOSE: Copy values for new columns from SCIO to SWD2 for the given year. Report any
    application or disability that exists in SCIO but not found in SWD2. New columns are
    - SWD_APPLICATION.APPL_ADJ_LVL_COMMENT
    - SWD_APPLICATION.FED_GOVT_FUNDING_EXCL_FLG
    - SWD_APPL_DISABILITY.DISABILITY_LVL_CODE
    - SWD_APPL_DISABILITY.DISABILITY_COMMENT

    Data between the 2 systems will be matched on the following
    - First name
    - Surname
    - DOB
    - Gender
    - School
    - Academic year

    Populate SWD.SWD_APPLICATION.LEGACY_STUDENT_ID for any matches.

    mode R = report only
         U = update
 ****************************************************************************************/
PROCEDURE pr_migrate_new_cols_to_swd2 (p_migrate_year IN NUMBER DEFAULT 0
                                      ,p_mode         IN VARCHAR2) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_migrate_new_cols_to_swd2';
   VC_MODE_RPT_ONLY CONSTANT VARCHAR2(01) := 'R';
   VC_MODE_UPD      CONSTANT VARCHAR2(01) := 'U';

   e_invalid_input           EXCEPTION;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params migrate_year='||p_migrate_year||' mode='||p_mode);

   IF (p_mode = VC_MODE_RPT_ONLY) THEN
      pr_log_missing_swd2_appl (p_migrate_year);
      pr_log_missing_swd2_disabl(p_migrate_year);

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Report on new columns of SWD_APPLICATION to update');
      MERGE INTO stg_application_2021 dest
      USING (SELECT s.student#
                   ,s.first_name
                   ,s.surname
                   ,s.dob
                   ,s.gender
                   ,NVL2(s.stu_notes, '-MIG_SWD '||TO_CHAR(SYSDATE, 'DD/MM/YYYY')||'- '||s.stu_notes||' -end-', NULL) stu_notes
                   ,s.school_id
                   ,s.school_year
                   ,s.grade
                   ,NVL(sd.dpts_star, 'N') dpts_star
                   ,a.appl_id
                   ,a.appl_adj_lvl_comment
                   ,NULL     disabling_cond_id
             FROM   ceodb_student_temp_v s
                    INNER JOIN ceodb.student_disabilities sd
                       ON  s.student#     = sd.student#
                       AND s.school_year  = sd.year
                       AND (s.school_year = p_migrate_year OR p_migrate_year = 0)
                    INNER JOIN swd_application a
                       ON  s.first_name  = a.student_first_name
                       AND s.surname     = a.student_surname
                       AND s.dob         = a.dob
                       AND s.gender      = a.gender
                       AND s.school_id   = a.school_id
                       AND s.grade       = a.funding_school_lvl
                       AND s.school_year = a.funding_year
                       AND a.delete_date IS NULL
                       AND (a.funding_year = p_migrate_year OR p_migrate_year = 0)) src
      ON (    dest.appl_student_id   = src.student#
          AND dest.funding_year      = src.school_year
          AND dest.disabling_cond_id = src.disabling_cond_id)
      WHEN MATCHED THEN
         UPDATE
         SET    dest.migrated_ind = 'N'
               ,dest.err_date     = SYSDATE
               ,dest.err_desc     = dest.err_desc||', Match found in SWD_APPLICATION. '||
                                    'appl_id='||src.appl_id||', surname='||src.surname||', first_name='||src.first_name||
                                    ', Set fed_govt_funding_excl_flg='||src.dpts_star||
                                    ', appl_adj_lvl_comment='||NVL2(src.appl_adj_lvl_comment, src.appl_adj_lvl_comment||'; ', NULL)||src.stu_notes
      WHEN NOT MATCHED THEN
         INSERT (dest.appl_student_id
                ,dest.funding_year
                ,dest.disabling_cond_id
                ,dest.migrated_ind
                ,dest.err_date
                ,dest.err_desc)
         VALUES (src.student#
                ,src.school_year
                ,src.disabling_cond_id
                ,'N'
                ,SYSDATE
                ,'Match found in SWD_APPLICATION. appl_id='||src.appl_id||' surname='||src.surname||' first_name='||src.first_name||
                 ', Set fed_govt_funding_excl_flg='||src.dpts_star||
                 ', appl_adj_lvl_comment='||NVL2(src.appl_adj_lvl_comment, src.appl_adj_lvl_comment||'; ', NULL)||src.stu_notes)
      LOG ERRORS INTO stg_application_2021_err REJECT LIMIT 100;

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Report on new columns of SWD_APPL_DISABILITY to update.');
      MERGE INTO stg_application_2021 dest
      USING (SELECT s.student#
                   ,s.first_name
                   ,s.surname
                   ,s.dob
                   ,s.gender
                   ,s.school_id
                   ,s.school_year
                   ,s.grade
                   ,sdc.id               disabling_cond_id
                   ,sdc.dis_cat_id
                   ,sdc.sub_cat_id
                   ,NVL(d.primary_condition, 'N') primary_cond_ind
                   ,UPPER(d.dis_level)   disability_lvl
                   ,TRIM(d.comments)     disability_comm
                   ,a.appl_id
             FROM   ceodb_student_temp_v s
                    INNER JOIN ceodb.disabilities d
                       ON  s.student#     = d.student#
                       AND (s.school_year = p_migrate_year OR p_migrate_year = 0)
                    INNER JOIN ceodb.sub_disability_categories sdc
                       ON  d.dis_cat_id = sdc.dis_cat_id
                       AND d.sub_cat_id = sdc.sub_cat_id
                    INNER JOIN swd_application a
                       ON  s.first_name    = a.student_first_name
                       AND s.surname       = a.student_surname
                       AND s.dob           = a.dob
                       AND s.gender        = a.gender
                       AND s.school_id     = a.school_id
                       AND s.grade         = a.funding_school_lvl
                       AND s.school_year   = a.funding_year
                       AND (a.funding_year = p_migrate_year OR p_migrate_year = 0)
                       AND a.delete_date IS NULL
                    INNER JOIN swd_appl_disability ad
                       ON  a.appl_id = ad.appl_id
                       AND sdc.id    = ad.disability_cond_id
                       AND NVL(d.primary_condition, 'N') = ad.primary_cond_flg
                       AND ad.delete_date IS NULL) src
      ON (    dest.appl_student_id   = src.student#
          AND dest.funding_year      = src.school_year
          AND dest.disabling_cond_id = src.disabling_cond_id)
      WHEN MATCHED THEN
         UPDATE
         SET    dest.migrated_ind = 'N'
               ,dest.err_date     = SYSDATE
               ,dest.err_desc     = dest.err_desc||', Match found in SWD_APPL_DISABILITY. appl_id='||src.appl_id||
                                       ', surname='||src.surname||', first_name='||src.first_name||
                                       ', dis_cat='||src.dis_cat_id||', sub_cat='||src.sub_cat_id||
                                       ', primary_flg='||src.primary_cond_ind||
                                       ', Set disability_lvl_code='||src.disability_lvl||
                                       ', disability_comment='||src.disability_comm
      WHEN NOT MATCHED THEN
         INSERT (dest.appl_student_id
                ,dest.funding_year
                ,dest.disabling_cond_id
                ,dest.migrated_ind
                ,dest.err_date
                ,dest.err_desc)
         VALUES (src.student#
                ,src.school_year
                ,src.disabling_cond_id
                ,'N'
                ,SYSDATE
                ,'Match found in SWD_APPL_DISABILITY. appl_id='||src.appl_id||', surname='||src.surname||
                    ', first_name='||src.first_name||', dis_cat='||src.dis_cat_id||', sub_cat='||src.sub_cat_id||
                    ', primary_flg='||src.primary_cond_ind||', Set disability_lvl_code='||src.disability_lvl||
                    ', disability_comment='||src.disability_comm)
      LOG ERRORS INTO stg_application_2021_err REJECT LIMIT 100;

   ELSIF (p_mode = VC_MODE_UPD) THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Update new columns of SWD_APPLICATION');
      MERGE INTO swd_application dest
      USING (SELECT s.student#
                   ,s.first_name
                   ,s.surname
                   ,s.dob
                   ,s.gender
                   ,NVL2(s.stu_notes, '-MIG_SWD '||TO_CHAR(SYSDATE, 'DD/MM/YYYY')||'- '||s.stu_notes||' -end-', NULL) stu_notes
                   ,s.school_id
                   ,s.school_year
                   ,s.grade
                   ,sd.dpts
                   ,NVL(sd.dpts_star, 'N') dpts_star
             FROM   ceodb_student_temp_v s
                    INNER JOIN ceodb.student_disabilities sd
                       ON  s.student#     = sd.student#
                       AND s.school_year  = sd.year
                       AND (s.school_year = p_migrate_year OR p_migrate_year = 0)) src
      ON (    src.first_name  = dest.student_first_name
          AND src.surname     = dest.student_surname
          AND src.dob         = dest.dob
          AND src.gender      = dest.gender
          AND src.school_id   = dest.school_id
          AND src.grade       = dest.funding_school_lvl
          AND src.school_year = dest.funding_year
          AND dest.delete_date IS NULL
          AND (dest.funding_year = p_migrate_year OR p_migrate_year = 0))
      WHEN MATCHED THEN
         UPDATE
         SET    dest.appl_adj_lvl_comment      = NVL2(dest.appl_adj_lvl_comment, dest.appl_adj_lvl_comment||'; ', NULL)||src.stu_notes
               ,dest.fed_govt_funding_excl_flg = src.dpts_star
               ,dest.legacy_student_id         = src.student#;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Merged '||SQL%ROWCOUNT||' into SWD_APPLICATION');

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Update new columns of SWD_APPL_DISABILITY');
      MERGE INTO swd_appl_disability dest
      USING (SELECT a.appl_id
                    ,s.student#
                    ,s.first_name
                    ,s.surname
                    ,s.dob
                    ,s.gender
                    ,s.school_id
                    ,s.school_year
                    ,s.grade
                    ,sdc.id                disabling_cond_id
                    ,NVL(d.primary_condition, 'N') primary_cond_ind
                    ,UPPER(d.dis_level)    disability_lvl
                    ,TRIM(d.comments)      disability_comm
             FROM   ceodb_student_temp_v s
                    INNER JOIN ceodb.disabilities d
                       ON  s.student#     = d.student#
                       AND (s.school_year = p_migrate_year OR p_migrate_year = 0)
                    INNER JOIN ceodb.sub_disability_categories sdc
                       ON  d.dis_cat_id = sdc.dis_cat_id
                       AND d.sub_cat_id = sdc.sub_cat_id
                    INNER JOIN swd_application a
                       ON  s.first_name    = a.student_first_name
                       AND s.surname       = a.student_surname
                       AND s.dob           = a.dob
                       AND s.gender        = a.gender
                       AND s.school_id     = a.school_id
                       AND s.grade         = a.funding_school_lvl
                       AND s.school_year   = a.funding_year
                       AND (a.funding_year = p_migrate_year OR p_migrate_year = 0)
                       AND a.delete_date IS NULL) src
      ON (    src.appl_id           = dest.appl_id
          AND src.disabling_cond_id = dest.disability_cond_id
          AND src.primary_cond_ind  = dest.primary_cond_flg
          AND dest.delete_date IS NULL)
      WHEN MATCHED THEN
         UPDATE
         SET    dest.disability_lvl_code = src.disability_lvl
               ,dest.disability_comment  = src.disability_comm;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Merged '||SQL%ROWCOUNT||' into SWD_APPL_DISABILITY');
   END IF;

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      RAISE;
END pr_migrate_new_cols_to_swd2;


/*****************************************************************************************
 MOD:03
 PURPOSE: Update LEGACY_STUDENT_ID and STATE_STUDENT_NBR in SWD_APPLICATION using mappings
     provided in STG_DATA_CORRECTION.
 ****************************************************************************************/
PROCEDURE pr_upd_legacy_student_id (p_disable_trigger IN VARCHAR2 DEFAULT 'N') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_upd_legacy_student_id';

   v_scio_student_nbr        stg_data_correction.scio_student_nbr%TYPE;
   v_coll_appl               DBMS_SQL.VARCHAR2_TABLE;
   v_appl_id_cnt             NUMBER(03) := 0;
   v_upd_cnt                 NUMBER(03) := 0;
   v_distinct_cnt            NUMBER(03) := 0;

   CURSOR c_stg IS
      SELECT ROWID
            ,dc.funding_year
            ,dc.scio_student_nbr
            ,dc.swd2_appl_id     stg_appl_id
            ,dc.wasn
            ,dc.surname
            ,dc.first_name
            ,dc.dob
            ,dc.gender
      FROM   stg_data_correction dc
      WHERE  dc.swd2_appl_id IS NOT NULL
      AND    dc.proc_ind = 'N'
      ORDER BY dc.scio_student_nbr
      FOR UPDATE NOWAIT;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (UPPER(p_disable_trigger) = 'Y') THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Disabling trigger SWD_APPLICATION_BIU');
      EXECUTE IMMEDIATE 'ALTER TRIGGER swd_application_biu DISABLE';
   END IF;

   FOR r IN c_stg LOOP
      v_coll_appl.DELETE;
      v_scio_student_nbr := r.scio_student_nbr;

      SAVEPOINT student_upd;

      --Set the legacy_student_id
      UPDATE swd_application a
      SET    a.legacy_student_id = r.scio_student_nbr
            ,a.state_student_nbr = NVL(a.state_student_nbr, r.wasn)
      WHERE  a.appl_id IN (SELECT COLUMN_VALUE
                           FROM   TABLE(APEX_STRING.SPLIT_NUMBERS(r.stg_appl_id, ',')))
      RETURNING a.state_student_nbr ||':'||
                a.student_first_name||':'||
                a.student_surname||':'||
                TO_CHAR(a.dob, 'DD-MON-YYYY')||':'||
                a.gender
      BULK COLLECT INTO v_coll_appl;

      --Get total number of appl_ids mapped to the student number.
      v_appl_id_cnt := APEX_STRING.SPLIT_NUMBERS(r.stg_appl_id, ',').COUNT;
      
      --Get total number of rows updated.
      v_upd_cnt := v_coll_appl.COUNT;

      --Basic check that the applications updated belong to the same student.
      SELECT COUNT(DISTINCT COLUMN_VALUE)
      INTO   v_distinct_cnt
      FROM   TABLE(v_coll_appl);

      pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT
              ,'scio_student_nbr='||r.scio_student_nbr||'  stg_appl_id='||r.stg_appl_id||
               '  total appl_id count='||v_appl_id_cnt||'  upd_cnt='||v_upd_cnt||
               '  distinct_cnt='||v_distinct_cnt);

      IF (v_upd_cnt = 0)
      OR (v_upd_cnt <> v_appl_id_cnt) THEN
         UPDATE stg_data_correction
         SET    proc_ind    = 'E'
               ,err_date    = SYSDATE
               ,err_message = 'At least one appl_id not found in SWD_APPLICATION.'
         WHERE CURRENT OF c_stg;

      ELSIF (v_distinct_cnt > 1) THEN
         ROLLBACK TO SAVEPOINT student_upd;

         UPDATE stg_data_correction
         SET    proc_ind    = 'E'
               ,err_date    = SYSDATE
               ,err_message = 'Student first name, surname, DOB or gender not identical across all appl_id of this student.'
         WHERE CURRENT OF c_stg;

      ELSE
         UPDATE stg_data_correction
         SET    proc_ind = 'Y'
         WHERE CURRENT OF c_stg;
      END IF;

   END LOOP;

   COMMIT;

   IF (UPPER(p_disable_trigger) = 'Y') THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Enabling trigger SWD_APPLICATION_BIU');
      EXECUTE IMMEDIATE 'ALTER TRIGGER swd_application_biu ENABLE';
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      IF (UPPER(p_disable_trigger) = 'Y') THEN
         pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Enabling trigger SWD_APPLICATION_BIU');
         EXECUTE IMMEDIATE 'ALTER TRIGGER swd_application_biu ENABLE';
      END IF;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT
              ,'Error processing student_nbr '||v_scio_student_nbr||' '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
END pr_upd_legacy_student_id;


/*****************************************************************************************
 MOD:03
 PURPOSE: Attempt to find a student match in CEODB.STUDENTS based on 
    - Surname
    - First name
    - DOB
    - Gender
    - School
    - School grade
   or confirm provided legacy student id.
   
   If gender is Unknown (X) or not exactly one record returned from student match,
   return 0 else return the matched student number.
 ****************************************************************************************/
FUNCTION get_scio_student_nbr (p_fund_year         IN NUMBER
                              ,p_surname           IN VARCHAR2
                              ,p_first_name        IN VARCHAR2
                              ,p_dob               IN DATE
                              ,p_gender            IN VARCHAR2
                              ,p_ceowa_nbr         IN NUMBER
                              ,p_school_grade      IN VARCHAR2
                              ,p_legacy_student_id IN NUMBER)
RETURN NUMBER IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_scio_student_nbr';
   VC_GENDER_UNK    CONSTANT VARCHAR2(01) := 'X';

   e_student_id_mismatch     EXCEPTION;

   v_params                  VARCHAR2(500);
   v_scio_student_nbr        NUMBER(10) := 0;
   v_msg                     VARCHAR2(500);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   
   v_params := 'params fund_year='||p_fund_year||' surname='||p_surname||' first_name='||p_first_name||
      ' dob='||TO_CHAR(p_dob, 'DD-MON-YYYY')||' gender='||p_gender||
      ' ceowa_nbr='||p_ceowa_nbr||' school_grade='||p_school_grade||
      ' IN legacy_student_id='||p_legacy_student_id;
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, v_params);

   IF (p_gender = VC_GENDER_UNK) THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Reject record for integration due to Unknown gender.');
      v_scio_student_nbr := 0;

   ELSE
      SELECT student#
      INTO   v_scio_student_nbr
      FROM  (SELECT s.student#
             FROM   ceodb_students_v s
                    INNER JOIN ceodb_student_schools_v ss
                       ON s.student# = ss.student#
             WHERE TRIM(UPPER(s.surname))      = p_surname
             AND   TRIM(INITCAP(s.first_name)) = p_first_name
             AND   s.dob                       = p_dob
             AND   s.gender                    = p_gender
             AND   ss.school#                  = p_ceowa_nbr
             AND   ss.grade                    = p_school_grade
             AND   EXTRACT(YEAR FROM ss.start_date) = p_fund_year
             UNION
             SELECT s2.student#
             FROM   ceodb_students_v s2
             WHERE  s2.student# = NVL(p_legacy_student_id, 0));

      IF (v_scio_student_nbr <> NVL(p_legacy_student_id, v_scio_student_nbr)) THEN
         v_msg := 'SCIO student# ('||v_scio_student_nbr||') does not match SWD legacy_student_id ('||p_legacy_student_id||')';
         RAISE TOO_MANY_ROWS;
      END IF;
   END IF;

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return scio_student_nbr='||v_scio_student_nbr);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_scio_student_nbr;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, NVL(v_msg, 'No match found, return 0. '||v_params));
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;
   WHEN TOO_MANY_ROWS THEN
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, NVL(v_msg, 'More than one match found, return 0. '||v_params));
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;
   WHEN OTHERS THEN
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM||'  '||v_params);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;
END get_scio_student_nbr;


/*****************************************************************************************
 MOD:03
 PURPOSE: Maintain CEODB.STUDENTS
 ****************************************************************************************/
PROCEDURE pr_maint_ceodb_students (p_legacy_student_id IN OUT ceodb_students_v.student#%TYPE
                                  ,p_surname           IN     ceodb_students_v.surname%TYPE
                                  ,p_first_name        IN     ceodb_students_v.first_name%TYPE
                                  ,p_dob               IN     ceodb_students_v.dob%TYPE
                                  ,p_gender            IN     ceodb_students_v.gender%TYPE
                                  ,p_student_note      IN     ceodb_students_v.notes%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maint_ceodb_students';

   v_scio_student_nbr        ceodb_students_v.student#%TYPE;
   v_student_note            ceodb_students_v.notes%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   v_scio_student_nbr := NVL(p_legacy_student_id, ceodb_student_id.NEXTVAL);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '   scio_student_nbr='||v_scio_student_nbr);

   --Do not integrate back notes that originated from SCIO SWD
   --or comment about Service Now requests.
   IF  (p_student_note NOT LIKE '-MIG_SWD%')
   AND (INSTR(p_student_note, 'Service Now') = 0) THEN
      v_student_note := p_student_note;
   ELSE
      v_student_note := NULL;
   END IF;

   MERGE INTO ceodb_students_v dest
   USING (SELECT v_scio_student_nbr  legacy_student_id
                ,p_surname           surname
                ,p_first_name        first_name
                ,p_dob               dob
                ,p_gender            gender
                ,v_student_note      student_note
          FROM DUAL) src
   ON (dest.student# = src.legacy_student_id)
   WHEN MATCHED THEN
      UPDATE
      SET dest.surname    = src.surname
         ,dest.first_name = src.first_name
         ,dest.dob        = src.dob
         ,dest.gender     = src.gender
         ,dest.notes      = NVL2(dest.notes, dest.notes||'. ', NULL)||src.student_note
   WHEN NOT MATCHED THEN
      INSERT (student#
             ,surname
             ,first_name
             ,dob
             ,gender
             ,catholic
             ,stu_type
             ,notes)
      VALUES (src.legacy_student_id
             ,src.surname
             ,src.first_name
             ,src.dob
             ,src.gender
             ,'Y'
             ,'SLN'
             ,src.student_note);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '   Merged rowcount='||SQL%ROWCOUNT);

   p_legacy_student_id := v_scio_student_nbr;
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_maint_ceodb_students;


/*****************************************************************************************
 MOD:03
 PURPOSE: Maintain CEODB.STUDENT_SCHOOLS
 ****************************************************************************************/
PROCEDURE pr_maint_ceodb_student_schools (
   p_fund_year          IN NUMBER
  ,p_ceowa_nbr          IN ceodb_student_schools_v.school#%TYPE
  ,p_legacy_student_id  IN ceodb_student_schools_v.student#%TYPE
  ,p_school_grade       IN ceodb_student_schools_v.grade%TYPE
  ,p_state_eligible_flg IN ceodb_student_schools_v.eligible%TYPE
  ,p_federal_funded_flg IN ceodb_student_schools_v.funded%TYPE
  ,p_student_fte        IN ceodb_student_schools_v.stu_fte%TYPE
  ,p_inactive_flg       IN VARCHAR2) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maint_ceodb_student_schools';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'params fund_year='||p_fund_year||
      ' ceowa_nbr='||p_ceowa_nbr||' legacy_student_id='||p_legacy_student_id||
      ' school_grade='||p_school_grade||' state_elig_flg='||p_state_eligible_flg||
      ' fed_funded_flg='||p_federal_funded_flg||' student_fte='||p_student_fte||
      ' inactive_flg='||p_inactive_flg);

   MERGE INTO ceodb_student_schools_v dest
   USING (SELECT p_fund_year          fund_year
                ,p_ceowa_nbr          ceowa_nbr
                ,p_legacy_student_id  legacy_student_id
                ,p_school_grade       school_grade
                ,p_state_eligible_flg state_elig_flg
                ,p_federal_funded_flg fed_funded_flg
                ,p_student_fte        student_fte
                ,DECODE(p_school_grade, 'K', 'Y', 'N') student_support
                ,p_inactive_flg       inactive_flg
                ,TO_DATE('01-JAN-'||p_fund_year, 'DD-MON-YYYY') start_date
                ,TO_DATE('31-DEC-'||p_fund_year, 'DD-MON-YYYY') end_date
          FROM   DUAL) src
   ON (    dest.student#   = src.legacy_student_id
       AND dest.start_date = src.start_date)
   WHEN MATCHED THEN
      UPDATE
      SET    school#     = src.ceowa_nbr
            ,grade       = src.school_grade
            ,eligible    = src.state_elig_flg
            ,funded      = src.fed_funded_flg
            ,wbl         = 'N'
            ,stu_fte     = src.student_fte
            ,stu_support = src.student_support
      DELETE WHERE src.inactive_flg = 'Y'
   WHEN NOT MATCHED THEN
      INSERT (school#
             ,student#
             ,grade
             ,start_date
             ,end_date
             ,eligible
             ,funded
             ,wbl
             ,stu_fte
             ,stu_support)
      VALUES (src.ceowa_nbr
             ,src.legacy_student_id
             ,src.school_grade
             ,src.start_date
             ,src.end_date
             ,src.state_elig_flg
             ,src.fed_funded_flg
             ,'N'
             ,src.student_fte
             ,src.student_support);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '   Merged rowcount='||SQL%ROWCOUNT);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_maint_ceodb_student_schools;


/*****************************************************************************************
 MOD:03
 PURPOSE: Maintain CEODB.STUDENT_DISABILITIES
 ****************************************************************************************/
PROCEDURE pr_maint_ceodb_stu_disablties (
   p_fund_year              IN ceodb_student_disabilities_v.year%TYPE
  ,p_legacy_student_id      IN ceodb_student_disabilities_v.student#%TYPE
  ,p_appl_adj_lvl           IN ceodb_student_disabilities_v.dpts%TYPE
  ,p_fed_govt_fund_excl_flg IN ceodb_student_disabilities_v.dpts_star%TYPE
  ,p_inactive_flg           IN VARCHAR2 DEFAULT 'N') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maint_ceodb_stu_disablties';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'params fund_year='||p_fund_year||
      ' legacy_student_id='||p_legacy_student_id||' appl_adj_lvl='||p_appl_adj_lvl||
      ' fed_govt_fund_excl_flg='||p_fed_govt_fund_excl_flg);

   MERGE INTO ceodb_student_disabilities_v dest
   USING (SELECT p_fund_year              fund_year
                ,p_legacy_student_id      legacy_student_id
                ,p_appl_adj_lvl           appl_adj_lvl
                ,p_fed_govt_fund_excl_flg fed_govt_fund_excl_flg
                ,DECODE(p_appl_adj_lvl, '4.2', 'Y', 'N') hsn
                ,p_inactive_flg           inactive_flg
          FROM   DUAL) src
   ON (    dest.student# = src.legacy_student_id
       AND dest.year     = src.fund_year)
   WHEN MATCHED THEN
      UPDATE
      SET    dpts      = src.appl_adj_lvl
            ,dpts_star = src.fed_govt_fund_excl_flg
            ,hsn       = src.hsn
      DELETE WHERE src.inactive_flg = 'Y'
   WHEN NOT MATCHED THEN
      INSERT (student#
             ,year
             ,dpts
             ,dpts_star
             ,hsn
             ,ta_fte)
      VALUES (src.legacy_student_id
             ,src.fund_year
             ,src.appl_adj_lvl
             ,src.fed_govt_fund_excl_flg
             ,src.hsn
             ,NULL);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '   Merged rowcount='||SQL%ROWCOUNT);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_maint_ceodb_stu_disablties;


/*****************************************************************************************
 MOD:03
 PURPOSE: Maintain CEODB.DISABILITIES
 ****************************************************************************************/
PROCEDURE pr_maint_ceodb_disabilities (
   p_legacy_student_id IN ceodb_disabilities_v.student#%TYPE
  ,p_appl_id           IN swd_appl_disability.appl_id%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maint_ceodb_disabilities';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'params legacy_student_id='||
      p_legacy_student_id||' appl_id='||p_appl_id);

   DELETE FROM ceodb_disabilities_v dest
   WHERE  dest.student# = p_legacy_student_id;
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Deleted rowcount='||SQL%ROWCOUNT);

   INSERT INTO ceodb_disabilities_v (
      student#
     ,dis_cat_id
     ,sub_cat_id
     ,comments
     ,dis_level
     ,primary_condition)
   SELECT p_legacy_student_id
         ,sdc.dis_cat_id
         ,sdc.sub_cat_id
         ,d.disability_comment
         ,NVL(DECODE(d.disability_lvl_code, 'B/L', 'B/L', INITCAP(d.disability_lvl_code)), 'Unsp') 
         ,d.primary_cond_flg
   FROM   swd_appl_disability d
          INNER JOIN ceodb_sub_disability_catg_v sdc
             ON d.disability_cond_id = sdc.id
   WHERE  d.delete_date IS NULL
   AND    d.appl_id = p_appl_id;
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '   Inserted rowcount='||SQL%ROWCOUNT);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_maint_ceodb_disabilities;


/*****************************************************************************************
 MOD:03
 PURPOSE: Integrate to SCIO SWD funding year 2022 applications at Funding Approval or
    Not Eligible status that are either for new applicants or have been modified since
    being rolled over from 2021 applications.
    
    NB: Disable these triggers first:
        - CEODB.TRG_STUDENT_SCHOOLS_BIU
        - CEODB.TRG_STUDENT_DISABILITIES_BIU
 ****************************************************************************************/
PROCEDURE pr_upd_scio_swd IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_upd_scio_swd';

   v_appl_id                 swd_application.appl_id%TYPE;
   v_scio_student_nbr        swd_application.legacy_student_id%TYPE;
   v_state_elig_flg          VARCHAR2(01);

   CURSOR c_appl_to_integrate IS
      SELECT a2.funding_year                  fund_year
            ,a2.appl_id                       appl_id
            ,a2.state_student_nbr             wasn
            ,a2.legacy_student_id             legacy_student_id
            ,a2.student_first_name            first_name
            ,a2.student_surname               surname
            ,a2.dob                           dob
            ,a2.gender                        gender
            ,a2.school_id                     school_id
            ,(SELECT es.ceowa_nbr
              FROM   education.school es
              WHERE  es.school_id = a2.school_id)   ceowa_nbr
            ,a2.funding_school_lvl            fund_school_lvl
            ,DECODE(a2.funding_school_lvl
                   ,'PP', 'PP'
                   , 'K',  'K'
                   ,TO_NUMBER(LTRIM(a2.funding_school_lvl, 'Y'))) school_grade
            ,TO_NUMBER(a2.appl_adj_lvl_code, '9D0') appl_adj_lvl
            ,a2.appl_adj_lvl_comment          appl_adj_lvl_comm
            ,a2.student_fte                   student_fte
            ,a2.fed_govt_funding_excl_flg     fed_govt_fund_excl_flg
            ,CASE
             WHEN (a2.appl_sts = 'NE')
             OR   (a2.fed_govt_funding_excl_flg = 'Y') THEN
                'N'
             ELSE
                'Y'
             END                              federal_funded_flg
            ,NVL2(a2.inactive_date, 'Y', 'N') inactive_flg
            ,a2.appl_sts                      appl_sts
      FROM   (SELECT a.appl_id
                    ,COUNT(*) sts_cnt
              FROM   swd_application a
                     INNER JOIN swd_appl_status s
                        ON s.appl_id = a.appl_id
              WHERE  a.funding_year = 2022
              AND    a.delete_date IS NULL
              AND    swd_funding_application.appl_been_revised(a.appl_id) = 'N'
              AND    swd_funding_application.get_appl_sts(a.appl_id) IN ('FUNDAPPR', 'NE')
              GROUP BY a.appl_id) b
              INNER JOIN (SELECT funding_year
                                ,appl_id
                                ,state_student_nbr
                                ,legacy_student_id
                                ,student_first_name
                                ,student_surname
                                ,dob
                                ,gender
                                ,school_id
                                ,funding_school_lvl
                                ,appl_adj_lvl_code
                                ,appl_adj_lvl_comment
                                ,student_fte
                                ,fed_govt_funding_excl_flg
                                ,inactive_date
                                ,swd_funding_application.get_appl_sts(appl_id) appl_sts
                                ,ROWNUM
                          FROM   swd_application
                          WHERE  funding_year = 2022
                          AND    delete_date IS NULL
                          AND    swd_funding_application.appl_been_revised(appl_id) = 'N'
                         ) a2
                 ON b.appl_id = a2.appl_id
      WHERE   b.sts_cnt > 1
      AND     NOT EXISTS (SELECT NULL
                          FROM   stg_data_correction dc
                          WHERE  dc.swd2_appl_id = b.appl_id
                          AND    dc.proc_ind IN ('B','M'));

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   <<integration_loop>>
   FOR r IN c_appl_to_integrate LOOP
      v_appl_id := r.appl_id;

      <<process_appl>>
      BEGIN
         SAVEPOINT curr_appl;

         v_scio_student_nbr := get_scio_student_nbr(r.fund_year, r.surname, r.first_name, r.dob, r.gender
                                                   ,r.ceowa_nbr ,r.school_grade, r.legacy_student_id);

         IF (v_scio_student_nbr = 0) THEN
            pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'scio_student_nbr=0. Flag possible Brand New applicant');
            pr_upd_proc_status (r.fund_year, v_scio_student_nbr, r.surname, r.first_name, r.dob
                               ,r.gender, r.fund_school_lvl, r.appl_id, 'B'
                               ,'Possibly Brand New applicant. Review.');
            CONTINUE integration_loop;
         END IF;

         pr_maint_ceodb_students (v_scio_student_nbr, r.surname, r.first_name, r.dob, r.gender, r.appl_adj_lvl_comm);

         CASE r.appl_sts
         WHEN 'FUNDAPPR' THEN
            v_state_elig_flg := 'Y';
         ELSE  --appl_sts = NE
            v_state_elig_flg := 'N';
         END CASE;
         pr_maint_ceodb_student_schools (r.fund_year, r.ceowa_nbr, v_scio_student_nbr, r.school_grade
                                        ,v_state_elig_flg, r.federal_funded_flg, r.student_fte, r.inactive_flg);
         pr_maint_ceodb_stu_disablties (r.fund_year, v_scio_student_nbr, r.appl_adj_lvl, r.fed_govt_fund_excl_flg
                                       ,r.inactive_flg);
         pr_maint_ceodb_disabilities (v_scio_student_nbr, r.appl_id);

         --Flag application as [M]igrated
         pr_upd_proc_status (r.fund_year, v_scio_student_nbr, r.surname, r.first_name, r.dob, r.gender
                            ,r.fund_school_lvl, r.appl_id, 'M', NULL);

      EXCEPTION
         WHEN OTHERS THEN
            ROLLBACK TO SAVEPOINT curr_appl;
            pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Rollback to savepoint. Flag [F]ailed migration');
            pr_upd_proc_status (r.fund_year, v_scio_student_nbr, r.surname, r.first_name, r.dob, r.gender
                               ,r.fund_school_lvl, r.appl_id, 'F', SQLERRM);
      END proc_appl;
   END LOOP integration_loop;

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Commiting');
   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error migrating appl_id='||v_appl_id||'. '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_upd_scio_swd;


/*****************************************************************************************
 MOD:03
 PURPOSE: Integrate to SCIO SWD funding year 2022 applications at Funding Approval or
    Not Eligible status for new applicants.
    
    NB: Disable these triggers first:
        - CEODB.TRG_STUDENT_SCHOOLS_BIU
        - CEODB.TRG_STUDENT_DISABILITIES_BIU
 ****************************************************************************************/
PROCEDURE pr_ins_scio_swd IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_ins_scio_swd';

   v_appl_id                 swd_application.appl_id%TYPE;
   v_scio_student_nbr        swd_application.legacy_student_id%TYPE;
   v_state_elig_flg          VARCHAR2(01);

   CURSOR c_new_student_to_integrate IS
      SELECT a2.funding_year                  fund_year
            ,a2.appl_id                       appl_id
            ,a2.state_student_nbr             wasn
            ,a2.legacy_student_id             legacy_student_id
            ,a2.student_first_name            first_name
            ,a2.student_surname               surname
            ,a2.dob                           dob
            ,a2.gender                        gender
            ,a2.school_id                     school_id
            ,(SELECT es.ceowa_nbr
              FROM   education.school es
              WHERE  es.school_id = a2.school_id)   ceowa_nbr
            ,a2.funding_school_lvl            fund_school_lvl
            ,DECODE(a2.funding_school_lvl
                   ,'PP', 'PP'
                   , 'K',  'K'
                   ,TO_NUMBER(LTRIM(a2.funding_school_lvl, 'Y'))) school_grade
            ,TO_NUMBER(a2.appl_adj_lvl_code, '9D0') appl_adj_lvl
            ,a2.appl_adj_lvl_comment          appl_adj_lvl_comm
            ,a2.student_fte                   student_fte
            ,a2.fed_govt_funding_excl_flg     fed_govt_fund_excl_flg
            ,CASE
             WHEN (a2.appl_sts = 'NE')
             OR   (a2.fed_govt_funding_excl_flg = 'Y') THEN
                'N'
             ELSE
                'Y'
             END                              federal_funded_flg
            ,NVL2(a2.inactive_date, 'Y', 'N') inactive_flg
            ,a2.appl_sts                      appl_sts
      FROM   (SELECT funding_year
                    ,appl_id
                    ,state_student_nbr
                    ,legacy_student_id
                    ,student_first_name
                    ,student_surname
                    ,dob
                    ,gender
                    ,school_id
                    ,funding_school_lvl
                    ,appl_adj_lvl_code
                    ,appl_adj_lvl_comment
                    ,student_fte
                    ,fed_govt_funding_excl_flg
                    ,inactive_date
                    ,swd_funding_application.get_appl_sts(appl_id) appl_sts
                    ,ROWNUM
              FROM   swd_application
              WHERE  funding_year = 2022
              AND    delete_date IS NULL
              AND    swd_funding_application.appl_been_revised(appl_id) = 'N'
             ) a2
             INNER JOIN stg_data_correction dc
                ON  TO_CHAR(a2.appl_id) = dc.swd2_appl_id
                AND a2.appl_sts IN ('FUNDAPPR', 'NE')
                AND dc.proc_ind    = 'B'
                AND dc.err_date    IS NULL
                AND dc.err_message IS NULL;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   <<integration_loop>>
   FOR r IN c_new_student_to_integrate LOOP
      v_appl_id := r.appl_id;
      v_scio_student_nbr := NULL;

      <<process_appl>>
      BEGIN
         SAVEPOINT curr_appl;

         pr_maint_ceodb_students (v_scio_student_nbr, r.surname, r.first_name, r.dob, r.gender, r.appl_adj_lvl_comm);

         CASE r.appl_sts
         WHEN 'FUNDAPPR' THEN
            v_state_elig_flg := 'Y';
         ELSE  --appl_sts = NE
            v_state_elig_flg := 'N';
         END CASE;
         pr_maint_ceodb_student_schools (r.fund_year, r.ceowa_nbr, v_scio_student_nbr, r.school_grade
                                        ,v_state_elig_flg, r.federal_funded_flg, r.student_fte, r.inactive_flg);
         pr_maint_ceodb_stu_disablties (r.fund_year, v_scio_student_nbr, r.appl_adj_lvl, r.fed_govt_fund_excl_flg
                                       ,r.inactive_flg);
         pr_maint_ceodb_disabilities (v_scio_student_nbr, r.appl_id);

         --Flag application as [M]igrated
         pr_upd_proc_status (r.fund_year, v_scio_student_nbr, r.surname, r.first_name, r.dob, r.gender
                            ,r.fund_school_lvl, r.appl_id, 'M', NULL);

      EXCEPTION
         WHEN OTHERS THEN
            ROLLBACK TO SAVEPOINT curr_appl;
            pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Rollback to savepoint. Flag [F]ailed migration');
            pr_upd_proc_status (r.fund_year, v_scio_student_nbr, r.surname, r.first_name, r.dob, r.gender
                               ,r.fund_school_lvl, r.appl_id, 'F', SQLERRM);
      END proc_appl;
   END LOOP integration_loop;

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Commiting');
   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error migrating appl_id='||v_appl_id||'. '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_ins_scio_swd;

/*****************************************************************************************
 MOD:04
 PURPOSE: Migrate legacy data from SCIO SWD to SWD2.
 
    p_excl_stu_list is a colon delimited list of legacy student ids NOT to migrate
 ****************************************************************************************/
PROCEDURE pr_ins_swd2 (p_max_fund_year IN NUMBER
                      ,p_excl_stu_list IN VARCHAR2 DEFAULT '1') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_ins_swd2';

   TYPE MinMaxTab IS TABLE OF INTEGER INDEX BY PLS_INTEGER;
   TYPE CtrlTab   IS TABLE OF MinMaxTab INDEX BY PLS_INTEGER;
   v_coll_ctrl               CtrlTab;

   e_migration_error         EXCEPTION;

   v_new_appl_id             swd_application.appl_id%TYPE;
   v_new_appl_disabl_id      swd_appl_disability.appl_disabl_id%TYPE;

   CURSOR c_loop_ctrl (cp_max_fund_year IN NUMBER) IS
      SELECT LEVEL idx
            ,DECODE(LEVEL, 1, b.min_stu_nbr, b.min_stu_nbr + ((LEVEL-1) * 4000) + 1) low_bound
            ,b.min_stu_nbr + (LEVEL * 4000)     high_bound
      FROM   (SELECT MIN(s.student#)   min_stu_nbr
                    ,MAX(s.student#)   max_stu_nbr
              FROM   ceodb.students s
                     INNER JOIN ceodb.student_schools ss
                        ON  s.student# = ss.student#
                        AND EXTRACT(YEAR FROM ss.start_date) <= cp_max_fund_year
              ) b
      CONNECT BY LEVEL < ((b.max_stu_nbr - b.min_stu_nbr) / 4000);

   CURSOR c_appl_det (cp_max_fund_year IN NUMBER
                     ,cp_min_stu_nbr   IN NUMBER
                     ,cp_max_stu_nbr   IN NUMBER) IS
      SELECT  s.student#           legacy_student_id
             ,DECODE(ss.eligible, 'N', 'NE', 'FUNDAPPR') appl_sts
             ,'Migrated from SCIO SWD' appl_sts_comm
             ,EXTRACT(YEAR FROM ss.start_date) fund_year
             ,education.edu_utils.get_school_id_frm_ceowa_nbr(ss.school#) school_id
             ,NULL                  wasn
             ,NULL                  username
             ,INITCAP(s.first_name) first_name
             ,UPPER(s.surname)      surname
             ,s.dob                 dob
             ,s.gender              gender
             ,DECODE(ss.grade
                    , 'K', 'K4'
                    ,'PP', 'PS'
                    ,'Y'||LPAD(ss.grade, 2, '0')) fund_school_lvl
             ,'Y'                   parent_consent_flg
             ,'NA'                  nccd_catgy
             ,'NA'                  nccd_loa
             ,'NA'                  iap_curric_partcp_loa
             ,'NA'                  iap_commun_partcp_loa
             ,'NA'                  iap_mobility_loa
             ,'NA'                  iap_personal_care_loa
             ,'NA'                  iap_soc_skills_loa
             ,'NA'                  iap_safety_loa
             ,TRIM(s.notes)         appl_adj_lvl_comm
             ,TO_CHAR(sd.dpts, '0D0') appl_adj_lvl
             ,ss.stu_fte            stu_fte
             ,DECODE(ss.funded, 'Y', 'N', 'Y') fed_govt_fund_excl_flg
             ,sd.dpts_star          dpts_star
      FROM   ceodb.students s
             INNER JOIN ceodb.student_schools ss
                ON s.student# = ss.student#
             INNER JOIN ceodb.student_disabilities sd
                ON  s.student#  = sd.student#
                AND ss.student# = sd.student#
                AND EXTRACT(YEAR FROM ss.start_date) = sd.year
      WHERE  ss.grade <> 'EXIT'
      AND    EXTRACT(YEAR FROM ss.start_date) <= cp_max_fund_year
      AND    s.student# BETWEEN cp_min_stu_nbr AND cp_max_stu_nbr
      AND    NOT EXISTS (SELECT NULL
                         FROM   swd_application a
                         WHERE  a.legacy_student_id = sd.student#
                         AND    a.funding_year      = sd.year)
      AND    NOT EXISTS (SELECT NULL
                         FROM   TABLE(apex_string.split(p_excl_stu_list, ':')) e
                         WHERE   s.student# = TO_NUMBER(e.column_value))
      --awdebug AND s.student# IN (10003, 10004, 10005)
      ORDER BY sd.student#, sd.year;

   CURSOR c_disability (cp_stu_nbr IN NUMBER) IS
      SELECT (SELECT sdc.id
              FROM   ceodb.sub_disability_categories sdc
              WHERE  sdc.dis_cat_id = d.dis_cat_id
              AND    sdc.sub_cat_id = d.sub_cat_id) disabl_cond_id
            ,d.primary_condition primary_flg
            ,'NA'                diag_type
            ,NULL                diagnostician
            ,NULL                diag_date
            ,NULL                diag_text
            ,NVL(UPPER(d.dis_level), 'UNSP') disabl_lvl
            ,TRIM(d.comments)    disabl_comm
      FROM   ceodb.disabilities d
      WHERE  d.student# = cp_stu_nbr;

   v_disability_rec          c_disability%ROWTYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Get student number loop controls');
   FOR r IN c_loop_ctrl (p_max_fund_year) LOOP
      v_coll_ctrl(r.idx)(1) := r.low_bound;
      v_coll_ctrl(r.idx)(2) := r.high_bound;
   END LOOP;

   FOR i IN v_coll_ctrl.FIRST..v_coll_ctrl.LAST LOOP
      pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'loop='||i||
         '  student nbr start='||v_coll_ctrl(i)(1)||'  student nbr end='||v_coll_ctrl(i)(2));
      
      <<student_loop>>
      FOR r IN c_appl_det (p_max_fund_year, v_coll_ctrl(i)(1), v_coll_ctrl(i)(2)) LOOP
         pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'process stu_nbr='||r.legacy_student_id||
            ' fund_year='||r.fund_year);
         <<student_block>>
         BEGIN
            SAVEPOINT appl_start;

            g_err_msg   := NULL;
            g_err_count := 0;

            pr_validate_input (r.appl_sts, r.fund_year, r.school_id, r.wasn, r.username
                              ,r.first_name, r.surname, r.dob, r.gender, NULL, r.fund_school_lvl
                              ,r.parent_consent_flg, r.nccd_catgy, r.nccd_loa, r.appl_adj_lvl);

            FOR rd IN c_disability (r.legacy_student_id) LOOP
               pr_validate_disabl_input (r.appl_sts, rd.disabl_cond_id, rd.diag_type
                                        ,rd.diagnostician, rd.diag_date);
            END LOOP;

            IF (g_err_count > 0) THEN
               RAISE e_migration_error;
            END IF;

            v_new_appl_id := NULL;
            g_err_msg     := NULL;

            swd_funding_application.pr_maintain_appl (
               p_appl_id                => v_new_appl_id
              ,p_appl_status            => r.appl_sts
              ,p_appl_status_reason     => r.appl_sts_comm
              ,p_funding_year           => r.fund_year
              ,p_school_id              => r.school_id
              ,p_ssn                    => r.wasn
              ,p_username               => r.username
              ,p_given_name             => r.first_name
              ,p_surname                => r.surname
              ,p_dob                    => r.dob
              ,p_gender                 => r.gender
              ,p_enrolld_sch_lvl        => NULL
              ,p_funding_sch_lvl        => r.fund_school_lvl
              ,p_parent_consent_flg     => r.parent_consent_flg
              ,p_nccd_catgy             => r.nccd_catgy
              ,p_nccd_loa               => r.nccd_loa
              ,p_iap_curric_partcp_comm => NULL
              ,p_iap_curric_partcp_loa  => r.iap_curric_partcp_loa
              ,p_iap_commun_partcp_comm => NULL
              ,p_iap_commun_partcp_loa  => r.iap_commun_partcp_loa
              ,p_iap_mobility_comm      => NULL
              ,p_iap_mobility_loa       => r.iap_mobility_loa
              ,p_iap_personal_care_comm => NULL
              ,p_iap_personal_care_loa  => r.iap_personal_care_loa
              ,p_iap_soc_skills_comm    => NULL
              ,p_iap_soc_skills_loa     => r.iap_soc_skills_loa
              ,p_iap_safety_comm        => NULL
              ,p_iap_safety_loa         => r.iap_safety_loa
              ,p_delete_date            => NULL
              ,p_appl_adj_lvl_comm      => r.appl_adj_lvl_comm
              ,p_appl_loa               => r.appl_adj_lvl
              ,p_read_version_nbr       => NULL
              ,p_related_appl_id        => NULL
              ,p_review_date            => NULL
              ,p_review_comment         => NULL
              ,p_stu_fte                => r.stu_fte
              ,p_fed_govt_fund_excl_flg => r.fed_govt_fund_excl_flg);

            IF (v_new_appl_id IS NULL) THEN
               pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Null appl_id returned');
               g_err_msg   := 'No application created.';
               g_err_count := g_err_count + 1; 
               RAISE e_migration_error;
            END IF;
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'New appl_id = '||v_new_appl_id);

            --Set the legacy_student_id
            UPDATE swd_application a
            SET    a.legacy_student_id = r.legacy_student_id
            WHERE  a.appl_id = v_new_appl_id;

            OPEN c_disability (r.legacy_student_id);
            <<disability_loop>>
            LOOP
               FETCH c_disability
               INTO  v_disability_rec;
               EXIT WHEN c_disability%NOTFOUND;

               v_new_appl_disabl_id := NULL;
               g_err_msg            := NULL;

               swd_funding_application.pr_maintain_disabilities (
                  p_appl_disabl_id     => v_new_appl_disabl_id
                 ,p_appl_id            => v_new_appl_id
                 ,p_appl_status        => r.appl_sts
                 ,p_disabl_cond_id     => v_disability_rec.disabl_cond_id
                 ,p_primary_flg        => v_disability_rec.primary_flg
                 ,p_diagnostician_type => v_disability_rec.diag_type
                 ,p_diagnostician      => v_disability_rec.diagnostician
                 ,p_diagnosis_date     => v_disability_rec.diag_date
                 ,p_diagnostician_text => v_disability_rec.diag_text
                 ,p_disabl_lvl_code    => v_disability_rec.disabl_lvl
                 ,p_disabl_comment     => v_disability_rec.disabl_comm);
            END LOOP disability_loop;

            IF (c_disability%ROWCOUNT = 0) THEN
               g_err_msg   := 'No disability found, rolling back application.';
               g_err_count := g_err_count + 1;
               RAISE e_migration_error;
            END IF;
            
            CLOSE c_disability;

            pr_upd_proc_status (r.fund_year, r.legacy_student_id, r.surname, r.first_name
                               ,r.dob, r.gender, r.fund_school_lvl, v_new_appl_id, 'M', NULL);
         EXCEPTION
            WHEN e_migration_error THEN
               pr_upd_proc_status (r.fund_year, r.legacy_student_id, r.surname, r.first_name
                                  ,r.dob, r.gender, r.fund_school_lvl, v_new_appl_id, 'F', g_err_msg);
               IF c_disability%ISOPEN THEN
                  CLOSE c_disability;
               END IF;
               ROLLBACK TO SAVEPOINT appl_start;
            WHEN OTHERS THEN
               pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'ERROR! student#='||r.legacy_student_id||'  '||SQLERRM);
               pr_upd_proc_status (r.fund_year, r.legacy_student_id, r.surname, r.first_name
                                  ,r.dob, r.gender, r.fund_school_lvl, v_new_appl_id, 'E', SQLERRM||'  '||g_err_msg);
               IF c_disability%ISOPEN THEN
                  CLOSE c_disability;
               END IF;
               ROLLBACK TO SAVEPOINT appl_start;
         END student_block;
      END LOOP student_loop;

      COMMIT;
   END LOOP;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'ERROR! '||SQLERRM);
      ROLLBACK;
END pr_ins_swd2;


END swd_migration;
/
