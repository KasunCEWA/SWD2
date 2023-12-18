CREATE OR REPLACE PACKAGE BODY SWD.swd_funding_application IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01     Date: 29-May-2019     Author: A Woo
 Created

 MOD:02     Date: 10-Sep-2019     Author: A Woo
 In function is_school_yr_lvl_valid,  allow year level 'Ungraded'.
 In function get_next_sch_lvl,  cater for new school level 'New Enrolment'.
 In procedure pr_student_search,  expand school year level variable from
    VARCHAR2(03) to VARCHAR2(10).

 MOD:03     Date: 06-Nov-2019     Author: A Woo
 In is_swd_app_open
 - add date range to application period SELECT.
 - do not show 'error' message when application period is closed as it stopped
   process "Fetch row from SWD_APPL_DISABILITY" on page 10 of from running.
 In pr_decide_upd_access_p10,  set flags correctly for a new application.

 MOD:04     Date: 02-Dec-2019     Author: A Woo
 In pr_validate_input, change parental permission validation from 'not null' to
 'Y'.  Applications may not be submitted until consent is given.

 MOD:05     Date: 16-Dec-2019     Author: A Woo
 Allow SWD2 to be read-only outside of date range:
 - add function is_consultant_read_only
 - add consultant read-only status check to function may_change_appl_sts
 - add consultant read-only status check to procedure pr_decide_upd_access_p10

 MOD:06     Date: 14-Feb-2020     Author: A Woo
 In procedure pr_copy_appl, add GC_APPLSTS_NE to the assertion when a Revision
 is requested.

 MOD:07     Date: 23-Apr-2020     Author: A Woo
 Replace these deprecated functions:
 - APEX_UTIL.STRING_TO_TABLE
 Add procedures
 - pr_maintain_notif_log
 - pr_notify_deactivated_appl
 - pr_deactivate_appl
 - pr_maintain_appl_doc
 - pr_log_document_access
 - pr_notify_principal
 - pr_build_group_user_list
 - pr_delete_appl
 - pr_init_p1_items
 Add functions
 - get_inactive_date
 - is_principal_read_only
 - get_funded_sch_lvl
 In procedure pr_copy_appl,
 - add parameter p_school_id and assertion for it
 - modify assertion to allow revision of an inactive application.
 In procedure print_create_appl_hdr
 - remove application date
 - add student name and
 - add 'INACTIVE' to the header
 In procedure pr_decide_upd_access_p10
 - move revised application check higher to stop further checks.
 - add code to check for inactive date.
 - rewrite code when F_AUTH_PRINCIPAL = Y to include new principal access period
 In procedure pr_bulk_rollover_preview
 - rewrite it to use an Apex collection
 - remove enrolled school level as it is now obsolete
 - calculate the next funding school level and exclude Year 12s based
   on the funding school level,  not the enrolled school level
 - exclude inactive applications
 - pick up only Funding Approved applications
 - applications with LDC* are not eligible for rollover
 - add current school_id, current application status, new application status and review year
 In procedure pr_bulk_rollover, change cursor to reference an Apex collection.
 In procedure pr_build_user_list, replace SQL with call to get_school_code.
 In function get_default_funding_year, change the rule so that default funding
 year = current year if current month is less than June instead of July.
 In procedure pr_maintain_appl,
 - add parameters p_review_date, p_review_comment and p_stu_fte
 - add review_date, review_comment and student_fte to merge statement
 In function is_consultant_read_only,
 - ignore Consultant Access dates for an Administrator and
 - take Funding Application Period dates into consideration.
 In function may_change_appl_sts, cater for new control is_principal_read_only.
 In procedure pr_build_swd2_group_list, change the Active Directory group search
    base.
 In procedure pr_maintain_disabilities, change parameter p_appl_disabl_id to
    IN OUT to cater for Interactive Grid processing and modify MERGE statement
    to use given appl_disabl_id.
 In procedure pr_copy_appl, add v_appl_disabl_id.
 In proecdure pr_increment_version_nbr,  add parameter p_new_version_nbr.
 In procedure pr_init_app_items, change item name from F_APP_ISOPEN to F_APPL_ISOPEN.
 In function appl_been_revised, take into account a logically deleted application.

 MOD:08     Date: 03-May-2021     Author: A Woo
 In pr_maintain_appl, remove INITCAP from v_given_name and UPPER from v_surname
 as the trigger on SWD_APPLICATION already does it.

 MOD:09     Date: 01-Jun-2021     Author: A Woo
 With the merging of SCIO SWD, which is used to calculate funding amount, with SWD2,
 which is used by schools to apply for funding, the following references need to be
 changed:
 - from SCIO.GEN_SCHOOLS to EDUCATION.SCHOOL
 - from SCIO.GEN_SCHOOL_ADDRESSES to EDUCATION.SCHOOL_ADDRESS
 - from SCIO.GEN_CODES to EDUCATION.EDU_CODES
 - from SERVICE_PROVISION.SP_USERS to EDUCATION.EMPLOYEE_V
 - from CEODB.SCHOOL_CONSULTANTS to SWD.SWD_SCHOOL_CONSULTANT.
 In procedure pr_maintain_appl,
 - add parameters p_fed_govt_fund_excl_flg, p_legacy_stu_id
 In procedure pr_copy_appl,
 - add v_fed_govt_fund_excl_flg
 - add columns disability_lvl_code and disability_comment to cursor c_supp_disabl
 In procedure pr_bulk_rollover,
 - add column fed_govt_funding_excl_flg to cursor c_appl_rollover
 - add columns disability_lvl_code and disability_comment to SWD_APPL_DISABILITY
   INSERT statement.
 - do not send Year 10 applications to DRAFT
 In procedure pr_maintain_disabilities,
 - add parameters p_disabl_lvl_code, p_disabl_comment
 In function is_school_yr_lvl_valid, replace reference to SCIO.GEN_CODES with
 call to education.edu_utils.get_academic_lvl_desc.
 In procedure pr_notify_principal, change reference from EDUCATION.SCHOOL_DIRECTORY
 to EDUCATION.SCHOOL.
 In procedure pr_build_swd2_group_list, change group filter list from 'cn=SG-8445-SWD*'
 to specific list of the groups to avoid picking up groups unrelated to SWD2.
 Add procedures
 - pr_transfer_consult_school
 - pr_delete_funding_defaults
 - pr_copy_funding_defaults
 - pr_maintain_grant

 MOD:10     Date: 18-Jul-2021     Author: A Woo
 Add function is_federal_funded.

 MOD:11     Date: 14-Oct-2021     Author: A Woo
 In procedure pr_bulk_rollover_preview,
 - change Pre-Primary code from 'PP' to 'PS' due to change of MIM feed.
 - fix bug where multiple applications are bulk rolled over when applications
   belong to different schools for a student.
 - set new application status to DRAFT when new funding year = (review date year + 1)
 In procedure pr_bulk_rollover
 - clear review_date and review_comment when new funding year = (review date year + 1).

 MOD:12     Date: 17-APR-2023     Author: K Samarasinghe
 Fixing the issue listed by #INC-15514.

 Modified functions
 - pr_build_group_user_list
 - pr_build_user_list

 MOD:13     Date: 31-MAY-2023     Author: K Samarasinghe
 Enhancement listed by #INC-18021.
 Modified procedure pr_bulk_rollover_preview and included Y10 for bulk rollover.

 MOD:14     Date: 02-AUG-2023     Author: K Samarasinghe
 Fixed the defects listed by #INC-23450 and #INC-24279.
 This is to exclude Non dioscesan school applications from the application deactivation process.
 Modified pr_deactivate_appl and pr_notify_deactivated_appl procedures.

 MOD:15     Date: 04-AUG-2023     Author: K Samarasinghe
 Fixing the issue listed by #INC-15513.
 Modified functions
 - get_user_group_list
 - is_consultant_school
 - pr_notify_deactivated_appl
 - pr_build_swd2_group_list (Incorporated with environment based LDAP security groups).
 ******************************************************************************/

   GC_APP_ALIAS     CONSTANT VARCHAR2(10) := 'SWD2';
   GC_PACKAGE       CONSTANT VARCHAR2(30) := 'SWD.SWD_FUNDING_APPLICATION';
   GC_START         CONSTANT VARCHAR2(01) := 'S';
   GC_END           CONSTANT VARCHAR2(01) := 'E';

   g_indent_count            INTEGER := 0;
   g_err_count               INTEGER := 0;


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
 PURPOSE: Display error message on the screen.
 ****************************************************************************************/
PROCEDURE pr_show_error (p_msg IN VARCHAR2) IS

BEGIN
   IF (p_msg <> 'User-Defined Exception') THEN
      APEX_ERROR.ADD_ERROR (p_message => p_msg
                           ,p_display_location => APEX_ERROR.C_INLINE_IN_NOTIFICATION);
   END IF;

END pr_show_error;


/*****************************************************************************************
 PURPOSE: Assert given condition.  If assertion fails,  display message on the screen.
          An exception is raised if requested.
 ****************************************************************************************/
PROCEDURE assert (p_cond       IN     BOOLEAN
                 ,p_err_msg    IN     VARCHAR2
                 ,p_raise_excp IN     VARCHAR2 DEFAULT 'N') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'assert';

   e_condition_not_met       EXCEPTION;

BEGIN
   IF NOT p_cond THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Assertion failed: '||p_err_msg);
      g_err_count := g_err_count + 1;
      APEX_ERROR.ADD_ERROR (p_message => p_err_msg
                           ,p_display_location => APEX_ERROR.C_INLINE_IN_NOTIFICATION);

      IF (p_raise_excp = 'Y') THEN
         RAISE e_condition_not_met;
      END IF;
   END IF;

END assert;


/*****************************************************************************************
 PURPOSE: Return 'Y' if funding application period is open.
          Return 'N' otherwise.
 ****************************************************************************************/
FUNCTION is_swd_app_open
RETURN VARCHAR2 IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_swd_app_open';

   v_open_flg                VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   SELECT 'Y'
   INTO   v_open_flg
   FROM   swd.swd_codes c
   WHERE  c.swd_code_type = 'APPCTRL'
   AND    c.swd_code      = 'OPNCLS'
   AND    TRUNC(SYSDATE) BETWEEN c.eff_from_date AND NVL(c.eff_to_date, TRUNC(SYSDATE)); --MOD:03

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_open_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_open_flg;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Funding application period is closed or not found. Return N.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      --MOD:03 pr_show_error ('INFO: Funding application period is closed.');
      RETURN 'N';

   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM||'.  Return '||v_open_flg);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error (SQLERRM);
      RETURN 'N';

END is_swd_app_open;


/*****************************************************************************************
 MOD:05
 PURPOSE: Return 'N' if
          - user is an SWD2 Administrator or
          - funding application period is open or
          - consultant access period is open.

          Return 'Y' otherwise i.e. read-only for Consultants
 ****************************************************************************************/
FUNCTION is_consultant_read_only
RETURN VARCHAR2 IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_consultant_read_only';

   v_read_only_flg           VARCHAR2(01) := 'Y';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (v('F_AUTH_ADMIN') = 'Y')
   OR (is_swd_app_open   = 'Y') THEN --MOD:07
      v_read_only_flg := 'N';
   ELSE
      SELECT 'N'
      INTO   v_read_only_flg
      FROM   swd.swd_codes c
      WHERE  c.swd_code_type = 'APPCTRL'
      AND    c.swd_code      = 'CONSULTOPNCLS'
      AND    TRUNC(SYSDATE) BETWEEN c.eff_from_date AND NVL(c.eff_to_date, TRUNC(SYSDATE));
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_read_only_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_read_only_flg;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Application is read-only for SWD Consultants. Return Y.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      --MOD:03 pr_show_error ('INFO: Funding application period is closed.');
      RETURN 'Y';

   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM||'.  Return '||v_read_only_flg);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error (SQLERRM);
      RETURN 'Y';

END is_consultant_read_only;


/*****************************************************************************************
 MOD:07
 PURPOSE: Return 'N' if
          - funding application period is open or
          - principal access period is open.

          Return 'Y' otherwise i.e. read-only for Principals
 ****************************************************************************************/
FUNCTION is_principal_read_only
RETURN VARCHAR2 IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_principal_read_only';

   v_read_only_flg           VARCHAR2(01) := 'Y';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (is_swd_app_open = 'Y') THEN
      v_read_only_flg := 'N';
   ELSE
      SELECT 'N'
      INTO   v_read_only_flg
      FROM   swd.swd_codes c
      WHERE  c.swd_code_type = 'APPCTRL'
      AND    c.swd_code      = 'PRINCOPNCLS'
      AND    TRUNC(SYSDATE) BETWEEN c.eff_from_date AND NVL(c.eff_to_date, TRUNC(SYSDATE));
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_read_only_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_read_only_flg;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Application is read-only for Principals. Return Y.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 'Y';

   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM||'.  Return '||v_read_only_flg);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error (SQLERRM);
      RETURN 'Y';

END is_principal_read_only;


/*****************************************************************************************
 PURPOSE: Return 'Y' if school year level is valid
          Return 'N' otherwise.
 ****************************************************************************************/
FUNCTION is_school_yr_lvl_valid (p_sch_yr_lvl IN swd_application.enrolled_school_lvl%TYPE)
RETURN VARCHAR2 IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_school_yr_lvl_valid';

   v_valid_flg               VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   /* MOD:09
   SELECT 'Y'
   INTO   v_valid_flg
   FROM   scio.gen_codes c
   WHERE  module = 'GEN'
   AND    c.code_type = 'AD_YEAR_LEVEL'
   --MOD:02 AND    c.code <> 'UG'
   AND    TRUNC(SYSDATE) BETWEEN c.start_date AND NVL(c.end_date, TRUNC(SYSDATE))
   AND    c.code = UPPER(p_sch_yr_lvl); */

   v_valid_flg := CASE education.edu_utils.get_academic_lvl_desc (p_sch_yr_lvl, TRUNC(SYSDATE))
                  WHEN 'Unknown' THEN
                     'N'
                  ELSE
                     'Y'
                  END;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'School year level '||p_sch_yr_lvl||' is valid. Return Y.');
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_valid_flg;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'School year level '||p_sch_yr_lvl||' was not found. Return N.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 'N';

END is_school_yr_lvl_valid;


/*****************************************************************************************
 PURPOSE: Return Y if the application has been superseded by a revision.
          Return N otherwise.
 ****************************************************************************************/
FUNCTION appl_been_revised (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'appl_been_revised';

   v_revision_cnt            NUMBER(02)   := 0;
   v_revised_flg             VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params appl_id='||p_appl_id);

   SELECT COUNT(*)
   INTO   v_revision_cnt
   FROM   swd_application
   WHERE  delete_date IS NULL  --MOD:07
   AND    related_appl_id = p_appl_id;

   IF (v_revision_cnt > 0) THEN
      v_revised_flg := 'Y';
   ELSE
      v_revised_flg := 'N';
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_revised_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_revised_flg;

END appl_been_revised;


/*****************************************************************************************
 PURPOSE: Return Y if the school belongs to the SWD consultant.
          Return N otherwise.
 ****************************************************************************************/
FUNCTION is_consultant_school (p_username  IN VARCHAR2
                              ,p_school_id IN NUMBER)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_consultant_school';

   v_emp_nbr                 VARCHAR2(20);
   v_cnt                     NUMBER(03)   := 0;
   v_my_school_flg           VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param username='||p_username||
      ' school_id='||p_school_id);

   v_emp_nbr := com_utils.get_empno_foruserprincipalname(p_username); --MOD:15

   SELECT COUNT(sc.consult_school_id)  --MOD:09
   INTO   v_cnt
   FROM   swd.swd_consultant_school sc   --MOD:09
          INNER JOIN education.school gs --MOD:09
             ON sc.school_id = gs.school_id --MOD:09
   WHERE  TRUNC(SYSDATE) BETWEEN sc.eff_from_date AND NVL(sc.eff_to_date, TRUNC(SYSDATE)) --MOD:09
   AND    sc.employee# = v_emp_nbr       --MOD:09
   AND    gs.school_id = p_school_id;    --MOD:09

   IF (v_cnt > 0) THEN
      v_my_school_flg := 'Y';
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return consultant_school_flg '||v_my_school_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_my_school_flg;

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error! '||SQLERRM);
      RETURN NULL;

END is_consultant_school;


/*****************************************************************************************
 PURPOSE: Return Y if the school belongs to the session user including an SWD consultant.
          Return N otherwise.
 ****************************************************************************************/
FUNCTION is_user_school (p_username       IN VARCHAR2
                        ,p_appl_school_id IN NUMBER)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_user_school';

   v_my_school_flg           VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param username='||p_username||
      ' appl_school_id='||p_appl_school_id);

   IF (v('F_AUTH_TEACHER')   = 'Y')
   OR (v('F_AUTH_PRINCIPAL') = 'Y') THEN
      BEGIN
         SELECT 'Y'
         INTO   v_my_school_flg
         FROM  (--Convert comma-delimited school id list to rows.
                SELECT REGEXP_SUBSTR(v('F_USER_SCHOOL_IDS_ALL'), '[^,]+', 1, LEVEL) school_id
                FROM   DUAL
                CONNECT BY REGEXP_SUBSTR(v('F_USER_SCHOOL_IDS_ALL'), '[^,]+', 1, LEVEL) IS NOT NULL) b
         WHERE  b.school_id = p_appl_school_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_my_school_flg := 'N';
      END;

   ELSIF (v('F_AUTH_CONSULT') = 'Y') THEN
      v_my_school_flg := is_consultant_school (p_username, p_appl_school_id);

   ELSIF (v('F_AUTH_ADMIN') = 'Y') THEN
      v_my_school_flg := 'Y';

   ELSE
      v_my_school_flg := 'N';
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_my_school_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_my_school_flg;

END is_user_school;


/*****************************************************************************************
 PURPOSE: Return the default funding year.
 ****************************************************************************************/
FUNCTION get_default_funding_year
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_default_funding_year';

   v_funding_yr               NUMBER(04);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (TO_NUMBER(TO_CHAR(SYSDATE, 'MM')) < 6) THEN --MOD:07
      v_funding_yr := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'));
   ELSE
      v_funding_yr := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY')) + 1;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_funding_yr);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_funding_yr;

END get_default_funding_year;


/*****************************************************************************************
 PURPOSE: Return a 4-digit school code given the EDUCATION.SCHOOL.SCHOOL_ID.
 ****************************************************************************************/
FUNCTION get_school_code (p_school_id IN education.school.school_id%TYPE) --MOD:09
RETURN education.school.ceowa_nbr%TYPE IS --MOD:09

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_school_code';

   v_school_code             education.school.ceowa_nbr%TYPE; --MOD:09

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Parameter is school_id='||p_school_id);

   SELECT s.ceowa_nbr     --MOD:09
   INTO   v_school_code
   FROM   education.school s --MOD:09
   WHERE  s.school_id = p_school_id; --MOD:09

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'school_code='||v_school_code);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_school_code;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;

END get_school_code;


/*****************************************************************************************
 PURPOSE: Return the id given the EDUCATION.SCHOOL.CEOWA_NBR.
 ****************************************************************************************/
FUNCTION get_school_id (p_school_code IN education.school.ceowa_nbr%TYPE) --MOD:09
RETURN education.school.school_id%TYPE IS --MOD:09

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_school_id';

   v_school_id               education.school.school_id%TYPE; --MOD:09

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Parameter is school_code='||p_school_code);

   SELECT s.school_id --MOD:09
   INTO   v_school_id
   FROM   education.school s --MOD:09
   WHERE  s.ceowa_nbr = p_school_code; --MOD:09

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'school_id='||v_school_id);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_school_id;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;

END get_school_id;


/*****************************************************************************************
 PURPOSE: Return the disablity category id given the sub-disability id.
 ****************************************************************************************/
FUNCTION get_disabl_catgy_id (p_sub_disabl_catgy_id IN sub_disability_categories.id%TYPE) --MOD:09
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_disabl_catgy_id';

   v_disabl_catgy_id         sub_disability_categories.dis_cat_id%TYPE; --MOD:09

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param disabl_cond_id='||p_sub_disabl_catgy_id);

   SELECT sdc.dis_cat_id
   INTO   v_disabl_catgy_id
   FROM   sub_disability_categories sdc --MOD:09
   WHERE  sdc.id = p_sub_disabl_catgy_id;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return disabl_catgy_id='||v_disabl_catgy_id);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_disabl_catgy_id;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No data found. Return NULL');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN NULL;
END get_disabl_catgy_id;


/*****************************************************************************************
 PURPOSE: Return the next school level given a school level.
          Return Ungraded if current level is Ungraded.
          Return NULL if one could not be found e.g. when current level is Year 12.
 ****************************************************************************************/
FUNCTION get_next_sch_lvl (p_sch_lvl IN swd_application.enrolled_school_lvl%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_next_sch_lvl';

   v_next_sch_lvl            swd_application.enrolled_school_lvl%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param curr_sch_lvl='||p_sch_lvl);

   IF (p_sch_lvl = 'UG') THEN
      v_next_sch_lvl := 'UG';
   ELSIF (p_sch_lvl = 'NE') THEN  --MOD:02
      v_next_sch_lvl := 'NE';
   ELSE
      SELECT c2.edu_code
      INTO   v_next_sch_lvl
      FROM   education.edu_codes c2 --MOD:09
      WHERE  c2.edu_code_type = 'AD_YR_LVL' --MOD:09
      AND    c2.sort_order = (SELECT c.sort_order
                              FROM   education.edu_codes c --MOD:09
                              WHERE  c.edu_code_type = 'AD_YR_LVL' --MOD:09
                              AND    c.edu_code = p_sch_lvl) + 1;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Next school level is '||v_next_sch_lvl);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_next_sch_lvl;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;

END get_next_sch_lvl;


/*****************************************************************************************
 PURPOSE: Return the name portion of the user's DN.
          DN format expected: CN=First_Name.Surname,OU=<container>,OU=<container>...
 ****************************************************************************************/
FUNCTION get_username_from_dn (p_user_dn IN VARCHAR2)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_username_from_dn';

   v_username                VARCHAR2(50);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param user_dn='||p_user_dn);

   v_username := SUBSTR(p_user_dn, INSTR(p_user_dn, '=')+1, (INSTR(p_user_dn, ',')-INSTR(p_user_dn, '=')-1));
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return username '||v_username);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_username;

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error! '||SQLERRM);
      RETURN NULL;

END get_username_from_dn;


/*****************************************************************************************
 PURPOSE: Return the enrolled school level of an application.
 ****************************************************************************************/
FUNCTION get_enrolled_sch_lvl (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_enrolled_sch_lvl';

   v_enrolled_sch_lvl        swd_application.enrolled_school_lvl%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param appl_id='||p_appl_id);

   SELECT a.enrolled_school_lvl
   INTO   v_enrolled_sch_lvl
   FROM   swd_application a
   WHERE  a.appl_id = p_appl_id;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Enrolled school level is '||v_enrolled_sch_lvl);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_enrolled_sch_lvl;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;

END get_enrolled_sch_lvl;


/*****************************************************************************************
 MOD:07
 PURPOSE: Return the funded school level of an application.
 ****************************************************************************************/
FUNCTION get_funded_sch_lvl (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_funded_sch_lvl';

   v_fund_sch_lvl            swd_application.funding_school_lvl%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param appl_id='||p_appl_id);

   SELECT a.funding_school_lvl
   INTO   v_fund_sch_lvl
   FROM   swd_application a
   WHERE  a.appl_id = p_appl_id;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Funded school level is '||v_fund_sch_lvl);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_fund_sch_lvl;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;

END get_funded_sch_lvl;


/*****************************************************************************************
 PURPOSE: Return the funding year of the application.
 ****************************************************************************************/
FUNCTION get_funding_year (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_funding_year';

   v_funding_year            swd_application.funding_year%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param appl_id='||p_appl_id);

   SELECT funding_year
   INTO   v_funding_year
   FROM   swd_application a
   WHERE  a.appl_id = p_appl_id;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Funding year is '||v_funding_year);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_funding_year;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;

END get_funding_year;


/*****************************************************************************************
 PURPOSE: Return the current application status code.
 ****************************************************************************************/
FUNCTION get_appl_sts (p_appl_id IN swd_appl_status.appl_id%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_appl_sts';

   v_last_sts                swd_appl_status.status_code%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param appl_id='||p_appl_id);

   SELECT DISTINCT FIRST_VALUE(status_code) OVER (ORDER BY appl_status_id DESC) last_sts
   INTO   v_last_sts
   FROM   swd_appl_status
   WHERE  appl_id = p_appl_id;
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Current status is '||v_last_sts);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_last_sts;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No existing status');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN NULL;

END get_appl_sts;


/*****************************************************************************************
 PURPOSE: Return the current application status description.
 ****************************************************************************************/
FUNCTION get_appl_sts_desc (p_appl_id IN swd_appl_status.appl_id%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_appl_sts_desc';

   v_last_sts                VARCHAR2(4000);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param appl_id='||p_appl_id);

   SELECT c.short_description
   INTO   v_last_sts
   FROM   (SELECT DISTINCT FIRST_VALUE(status_code) OVER (ORDER BY appl_status_id DESC) last_sts
           FROM   swd_appl_status
           WHERE  appl_id = p_appl_id) b
           INNER JOIN swd_codes c
              ON b.last_sts = c.swd_code
              WHERE c.swd_code_type = 'APPLSTS';
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Current status is '||v_last_sts);

   RETURN v_last_sts;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No existing status');
      RETURN NULL;

END get_appl_sts_desc;


/*****************************************************************************************
 PURPOSE: Return the short description of the code.
 ****************************************************************************************/
FUNCTION get_code_desc (p_code_type IN swd_codes.swd_code_type%TYPE
                       ,p_code      IN swd_codes.swd_code%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_code_desc';

   v_short_desc              swd_codes.short_description%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param code_type='||p_code_type||' code='||p_code);

   SELECT c.short_description
   INTO   v_short_desc
   FROM   swd_codes c
   WHERE  c.swd_code_type = UPPER(p_code_type)
   AND    c.swd_code      = UPPER(p_code);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Short description (first 100 chars) is '||SUBSTR(v_short_desc, 1, 100));

   RETURN v_short_desc;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Code not found');
      RETURN NULL;

END get_code_desc;


/*****************************************************************************************
 MOD:07
 PURPOSE: Return the inactive date of the application.
          Return NULL if application is active.
 ****************************************************************************************/
FUNCTION get_inactive_date (p_appl_id IN swd_application.appl_id%TYPE)
RETURN DATE IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_inactive_date';

   v_inactive_date           swd_application.inactive_date%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params appl_id='||p_appl_id);

   SELECT inactive_date
   INTO   v_inactive_date
   FROM   swd_application
   WHERE  appl_id = p_appl_id;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Inactive date is '||TO_CHAR(v_inactive_date, 'DD-MON-YYYY'));
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_inactive_date;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'NO_DATA_FOUND. Return NULL');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN NULL;

END get_inactive_date;


/*****************************************************************************************
 PURPOSE: Return Y if an application for the given funding year already exists for
    the student.  Not 100% proof as students are identified as best as data allows.
 ****************************************************************************************/
FUNCTION is_fund_year_appl_exist (p_appl_id      IN swd_application.appl_id%TYPE
                                 ,p_funding_year IN swd_application.funding_year%TYPE)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_fund_year_appl_exist';

   v_exist_flg               VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params appl_id='||p_appl_id||
      ' funding_year='||p_funding_year);

   SELECT 'Y'
   INTO   v_exist_flg
   FROM   swd_application aori
          INNER JOIN swd_application anew
             ON (   (    aori.student_username  = anew.student_username
                     OR  aori.state_student_nbr = anew.state_student_nbr
                     OR (    aori.student_first_name = anew.student_first_name
                         AND aori.student_surname    = anew.student_surname
                         AND aori.dob                = anew.dob))
                 AND anew.delete_date IS NULL --MOD:07
                 AND anew.funding_year = p_funding_year
                )
   WHERE aori.appl_id = p_appl_id
   AND   ROWNUM < 2;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return Y');
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_exist_flg;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No data found. Return N');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 'N';

   WHEN TOO_MANY_ROWS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'More than one match found. Return N');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 'N';

END is_fund_year_appl_exist;


/*****************************************************************************************
 PURPOSE: Return Y if the application status may be changed by the user.
          Return N otherwise.
          Uses Apex application items.
 ****************************************************************************************/
FUNCTION may_change_appl_sts (p_appl_id  IN swd_application.appl_id%TYPE
                             ,p_username IN VARCHAR2)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'may_change_appl_sts';

   e_superseded_appl         EXCEPTION;
   e_inactive_appl           EXCEPTION; --MOD:07

   v_change_flg              VARCHAR2(01) := 'N';
   v_appl_period_open_flg    VARCHAR2(01) := 'N';
   v_appl_revised_flg        VARCHAR2(01) := 'N';
   v_own_school_flg          VARCHAR2(01) := 'N';
   v_appl_consult_ro_flg     VARCHAR2(01) := 'N'; --MOD:05
   v_appl_princ_ro_flg       VARCHAR2(01) := 'N'; --MOD:07
   v_text                    VARCHAR2(200); --MOD:07
   v_appl_sts                swd_appl_status.status_code%TYPE;
   v_appl_school_id          swd_application.school_id%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params appl_id='||p_appl_id||
      ' username='||p_username);

   --Initialise
   v_appl_period_open_flg := is_swd_app_open;
   v_appl_revised_flg     := appl_been_revised (p_appl_id);

   --MOD:07 moved from after is_user_school to avoid unnecessary checks.
   IF (v_appl_revised_flg = 'Y') THEN
      v_text := 'Application superseded by revision. Return N.';
      RAISE e_superseded_appl;
   END IF;

   --MOD:07
   IF (get_inactive_date(p_appl_id) IS NOT NULL) THEN
      v_text := 'Application is inactive. Return N.';
      RAISE e_inactive_appl;
   END IF;

   v_appl_sts            := get_appl_sts (p_appl_id);
   v_appl_consult_ro_flg := is_consultant_read_only; --MOD:05
   v_appl_princ_ro_flg   := is_principal_read_only; --MOD:07

   SELECT a.school_id
   INTO   v_appl_school_id
   FROM   swd_application a
   WHERE  a.appl_id = p_appl_id;

   v_own_school_flg := is_user_school (p_username, v_appl_school_id);

   --Now work out whether or not user may change the application status.
   IF (v('F_AUTH_TEACHER') = 'Y') THEN
      IF  (v_appl_period_open_flg = 'Y')
      AND (v_own_school_flg       = 'Y')
      AND (v_appl_sts = GC_APPLSTS_DRAFT) THEN
         v_change_flg := 'Y';
      END IF;

   ELSIF (v('F_AUTH_PRINCIPAL') = 'Y') THEN
      --MOD:07
      IF  (v_own_school_flg    = 'Y')
      AND (v_appl_princ_ro_flg = 'N')
      AND (v_appl_sts  IN (GC_APPLSTS_DRAFT, GC_APPLSTS_REVIEWED)) THEN
         v_change_flg := 'Y';
      END IF;

   ELSIF (v('F_AUTH_CONSULT') = 'Y') THEN
      CASE
         WHEN (v_appl_consult_ro_flg = 'Y') THEN --MOD:05
            v_change_flg := 'N';

         WHEN (v_own_school_flg = 'Y')
         AND  (v_appl_sts IN (GC_APPLSTS_DRAFT, GC_APPLSTS_SUBMIT)) THEN
            v_change_flg := 'Y';

         WHEN (v_own_school_flg = 'N')
         AND  (v_appl_sts = GC_APPLSTS_PRINCAPPR) THEN
            v_change_flg := 'Y';

         ELSE
            v_change_flg := 'N';
      END CASE;

   ELSIF (v('F_AUTH_ADMIN') = 'Y') THEN
      IF (v_appl_sts NOT IN (GC_APPLSTS_FUNDAPPR, GC_APPLSTS_NE)) THEN
         v_change_flg := 'Y';
      END IF;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_change_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_change_flg;

EXCEPTION
   WHEN e_superseded_appl
   OR   e_inactive_appl   THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, v_text);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 'N';

END may_change_appl_sts;


/*****************************************************************************************
 PURPOSE: Search for a student in Active Directory.
 ****************************************************************************************/
PROCEDURE pr_student_search (p_school_id          IN education.school.school_id%TYPE --MOD:09
                            ,p_given_name         IN VARCHAR2 DEFAULT NULL
                            ,p_surname            IN VARCHAR2 DEFAULT NULL
                            ,p_state_student_nbr  IN NUMBER   DEFAULT NULL
                            ,p_enrolld_sch_lvl    IN VARCHAR2 DEFAULT NULL) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_student_search';

   e_skip_ad_search          EXCEPTION;

   v_in_given_name           VARCHAR2(50);
   v_in_surname              VARCHAR2(50);
   v_in_ssn                  NUMBER(08) := 0;
   v_in_school_yr_lvl        VARCHAR2(03);
   v_own_school_flg          VARCHAR2(01) := 'N';
   v_school_code             education.school.ceowa_nbr%TYPE; --MOD:09
   v_coll_return_attrib      common.com_utils.LDAPStrColl;
   v_coll_student_dets       common.com_utils.ADEntTab;
   v_attr_name               VARCHAR2(20);
   v_attr_value              VARCHAR2(256);
   v_attrval_samaccname      VARCHAR2(256);
   v_attrval_given_name      VARCHAR2(256);
   v_attrval_surname         VARCHAR2(256);
   v_attrval_ssn             NUMBER(08);
   v_attrval_school_code     NUMBER(04);
   v_attrval_school_yr_lvl   VARCHAR2(10); --MOD:02

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params school_id='||
      p_school_id||' given_name='||p_given_name||' surname='||p_surname||
      ' state_student_nbr='||p_state_student_nbr||' enrolled_yr_lvl='||p_enrolld_sch_lvl);

   --MOD:07 pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Create the Apex collection to store LDAP query result');
   APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION (p_collection_name => GC_APX_COLL_STUDENTS);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Verify that at least one search parameter given');
   assert((   p_school_id IS NOT NULL OR p_given_name IS NOT NULL
           OR p_surname   IS NOT NULL OR p_state_student_nbr IS NOT NULL
           OR p_enrolld_sch_lvl IS NOT NULL)
          ,'At least one search value must be given', 'Y');

   IF (p_school_id IS NOT NULL) THEN
      v_own_school_flg := is_user_school (v('APP_USER'), p_school_id);

      --If the session user is NOT associated with the school,  skip searching in AD
      --because funding applications may not be created for those students.
      IF (v_own_school_flg = 'N') THEN
         pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Session User is associated with the school. Skip AD search.');
         RAISE e_skip_ad_search;
      ELSE
         pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Session User is NOT associated with the school. Continue AD search.');
      END IF;
   END IF;

   --Assign input parameters to local variables and modify.
   v_school_code      := get_school_code (p_school_id);
   v_in_given_name    := p_given_name||'*';
   v_in_surname       := p_surname||'*';
   v_in_ssn           := p_state_student_nbr;
   v_in_school_yr_lvl := UPPER(p_enrolld_sch_lvl);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Set up desired return attributes');
   v_coll_return_attrib(1) := COMMON.COM_AD_ATTR.GC_GEN_SAMACC;
   v_coll_return_attrib(2) := COMMON.COM_AD_ATTR.GC_GEN_GIVEN_NAME;
   v_coll_return_attrib(3) := COMMON.COM_AD_ATTR.GC_GEN_SURNAME;
   v_coll_return_attrib(4) := COMMON.COM_AD_ATTR.GC_STU_SSN;
   v_coll_return_attrib(5) := COMMON.COM_AD_ATTR.GC_STU_SCH_CODE;
   v_coll_return_attrib(6) := COMMON.COM_AD_ATTR.GC_STU_SCH_YR_LVL;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Call COM_UTILS.GET_STUDENT_DETAILS');
   v_coll_student_dets := com_utils.get_student_details (
                             p_school_code        => v_school_code
                            ,p_given_name         => v_in_given_name
                            ,p_surname            => v_in_surname
                            ,p_state_student_nbr  => v_in_ssn
                            ,p_school_year_level  => v_in_school_yr_lvl
                            ,p_return_attrib_coll => v_coll_return_attrib);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Query returned '||v_coll_student_dets.COUNT||' matches');
   IF (v_coll_student_dets.COUNT > 0) THEN
      <<matches_returned_loop>>
      FOR i IN v_coll_student_dets.FIRST..v_coll_student_dets.LAST LOOP
         pr_debug (COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Entry number='||i);

         <<attributes_loop>>
         FOR j IN v_coll_student_dets(i).FIRST..v_coll_student_dets(i).LAST LOOP
            v_attr_name  := v_coll_student_dets(i)(j).attr_name;
            --Only the first value of the attribute will be used therefore unsuitable for attributes like memberOf.
            v_attr_value := v_coll_student_dets(i)(j).attr_val(v_coll_student_dets(i)(j).attr_val.FIRST);
            pr_debug (COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, '--- Attribute name='||v_attr_name||
               '   first value='||v_attr_value);

            CASE v_attr_name
            WHEN COMMON.COM_AD_ATTR.GC_GEN_SAMACC THEN
               v_attrval_samaccname    := v_attr_value;
            WHEN COMMON.COM_AD_ATTR.GC_GEN_GIVEN_NAME THEN
               v_attrval_given_name    := INITCAP(v_attr_value);
            WHEN COMMON.COM_AD_ATTR.GC_GEN_SURNAME THEN
               v_attrval_surname       := UPPER(v_attr_value);
            WHEN COMMON.COM_AD_ATTR.GC_STU_SSN THEN
               BEGIN
                  v_attrval_ssn        := TO_NUMBER(v_attr_value);
               EXCEPTION
                  WHEN INVALID_NUMBER
                  OR   VALUE_ERROR    THEN
                     v_attrval_ssn     := NULL;
               END;
            WHEN COMMON.COM_AD_ATTR.GC_STU_SCH_CODE THEN
               v_attrval_school_code   := TO_NUMBER(v_attr_value);
            WHEN COMMON.COM_AD_ATTR.GC_STU_SCH_YR_LVL THEN
               v_attrval_school_yr_lvl := v_attr_value;
            END CASE;
         END LOOP attributes_loop;

         pr_debug (COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Add member to Apex collection');
         --!! Placement matters as Apex will expect specific values in specific columns.
         APEX_COLLECTION.ADD_MEMBER (p_collection_name => GC_APX_COLL_STUDENTS
                                    ,p_c001 => v_attrval_samaccname
                                    ,p_c002 => v_attrval_given_name
                                    ,p_c003 => v_attrval_surname
                                    ,p_c004 => v_attrval_school_yr_lvl
                                    ,p_n001 => get_school_id(v_attrval_school_code)
                                    ,p_n002 => v_attrval_ssn);

      END LOOP matches_returned_loop;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_skip_ad_search THEN
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error (SQLERRM);
END pr_student_search;


/*****************************************************************************************
 PURPOSE: Attempt to update SWD_APPLICATION.VERSION_NBR with the version acquired on
    reading the data.  Trigger will take care of the actual increment if the version
    has not changed.
 ****************************************************************************************/
PROCEDURE pr_increment_version_nbr (p_appl_id         IN     swd_application.appl_id%TYPE
                                   ,p_old_version_nbr IN     swd_application.version_nbr%TYPE
                                   ,p_new_version_nbr    OUT swd_application.version_nbr%TYPE) IS --MOD:07

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_increment_version_nbr';

   v_new_version_nbr         swd_application.version_nbr%TYPE; --MOD:07

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Param old_ver_nbr='||p_old_version_nbr);

   assert((p_old_version_nbr IS NOT NULL), 'Old version number is required.', 'Y');

   UPDATE swd_application a
   SET    a.version_nbr = p_old_version_nbr
   WHERE  a.appl_id = p_appl_id
   RETURNING a.version_nbr INTO v_new_version_nbr; --MOD:07
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'new_ver_nbr='||v_new_version_nbr); --MOD:07

   p_new_version_nbr := v_new_version_nbr; --MOD:07

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_increment_version_nbr;


/*****************************************************************************************
 PURPOSE: Validate disability information input
 ****************************************************************************************/
PROCEDURE pr_validate_disabl_input (
   p_appl_status        IN swd_appl_status.status_code%TYPE
  ,p_disabl_cond_id     IN swd_appl_disability.disability_cond_id%TYPE
  ,p_diagnostician_type IN swd_appl_disability.diagnostician_type_code%TYPE
  ,p_diagnostician      IN swd_appl_disability.diagnostician%TYPE
  ,p_diagnosis_date     IN swd_appl_disability.diagnosis_date%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_validate_disabl_input';

   e_invalid_input           EXCEPTION;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (p_appl_status <> GC_APPLSTS_DRAFT) THEN
      assert((p_disabl_cond_id IS NOT NULL),     'Disability Type and Disabling Condition are required.', 'N');
      assert((p_diagnostician_type IS NOT NULL), 'Diagnostician Type is required.', 'N');

      IF (p_diagnostician_type <> 'NA') THEN
         assert((p_diagnostician IS NOT NULL),   'Diagnostician is required.', 'N');
         assert((p_diagnosis_date IS NOT NULL),  'Diagnosis Date is required.', 'N');
      END IF;
   END IF;

   IF (g_err_count > 0) THEN
      RAISE e_invalid_input;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_invalid_input THEN
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;

END pr_validate_disabl_input;


/*****************************************************************************************
 PURPOSE: Maintain disabilities.
 ****************************************************************************************/
PROCEDURE pr_maintain_disabilities (
   p_appl_disabl_id     IN OUT swd_appl_disability.appl_disabl_id%TYPE --MOD:07
  ,p_appl_id            IN     swd_appl_disability.appl_id%TYPE
  ,p_appl_status        IN     swd_appl_status.status_code%TYPE
  ,p_disabl_cond_id     IN     swd_appl_disability.disability_cond_id%TYPE  DEFAULT NULL
  ,p_primary_flg        IN     swd_appl_disability.primary_cond_flg%TYPE    DEFAULT NULL
  ,p_diagnostician_type IN     swd_appl_disability.diagnostician_type_code%TYPE DEFAULT NULL
  ,p_diagnostician      IN     swd_appl_disability.diagnostician%TYPE       DEFAULT NULL
  ,p_diagnosis_date     IN     swd_appl_disability.diagnosis_date%TYPE      DEFAULT NULL
  ,p_diagnostician_text IN     swd_appl_disability.diagnostician_text%TYPE  DEFAULT NULL
  ,p_disabl_lvl_code    IN     swd_appl_disability.disability_lvl_code%TYPE DEFAULT NULL --MOD:09
  ,p_disabl_comment     IN     swd_appl_disability.disability_comment%TYPE  DEFAULT NULL --MOD:09
  ,p_delete_flg         IN     VARCHAR2 DEFAULT 'N') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maintain_disabilities';

   v_appl_disabl_id          swd_appl_disability.appl_disabl_id%TYPE; --MOD:07

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params are appl_disabl_id='||
      p_appl_disabl_id||' appl_id='||p_appl_id||' status='||p_appl_status||' disabl_cond_id='||
      p_disabl_cond_id||' prim_flg='||p_primary_flg||' diag_type='||p_diagnostician_type||
      ' diagnostician='||p_diagnostician||' diag_date='||TO_CHAR(p_diagnosis_date, 'DD-MON-YYYY')||
      ' disabl_lvl_code='||p_disabl_lvl_code||
      ' del_flg='||p_delete_flg);

   IF (p_delete_flg = 'Y') THEN
      UPDATE swd_appl_disability d
      SET    d.delete_date = TRUNC(SYSDATE)
      WHERE  d.appl_disabl_id = p_appl_disabl_id;

   ELSE
      pr_validate_disabl_input (p_appl_status
                               ,p_disabl_cond_id
                               ,p_diagnostician_type
                               ,p_diagnostician
                               ,p_diagnosis_date);

      v_appl_disabl_id := NVL(p_appl_disabl_id, swd_appl_disability_seq.NEXTVAL); --MOD:07

      MERGE INTO swd_appl_disability d
      USING (SELECT v_appl_disabl_id           appl_disabl_id  --MOD:07
                   ,p_appl_id                  appl_id
                   ,p_disabl_cond_id           disabl_cond_id
                   ,NVL(UPPER(p_primary_flg), 'N')   primary_flg
                   ,p_diagnostician_type       diagnostician_type
                   ,TRIM(p_diagnostician)      diagnostician
                   ,p_diagnosis_date           diagnosis_date
                   ,TRIM(p_diagnostician_text) diagnostician_text
                   ,NULL                       del_date
                   ,p_disabl_lvl_code          disabl_lvl_code --MOD:09
                   ,TRIM(p_disabl_comment)     disabl_comment  --MOD:09
             FROM DUAL) src
      ON (d.appl_disabl_id = src.appl_disabl_id)
      WHEN MATCHED THEN
         UPDATE SET
            d.disability_cond_id  = src.disabl_cond_id
           ,d.primary_cond_flg    = src.primary_flg
           ,d.diagnostician_type_code = src.diagnostician_type
           ,d.diagnostician       = src.diagnostician
           ,d.diagnosis_date      = src.diagnosis_date
           ,d.diagnostician_text  = src.diagnostician_text
           ,d.delete_date         = src.del_date
           ,d.disability_lvl_code = src.disabl_lvl_code --MOD:09
           ,d.disability_comment  = src.disabl_comment  --MOD:09
      WHEN NOT MATCHED THEN
         INSERT (appl_disabl_id --MOD:07
                ,appl_id
                ,disability_cond_id
                ,primary_cond_flg
                ,diagnostician_type_code
                ,diagnostician
                ,diagnosis_date
                ,diagnostician_text
                ,delete_date
                ,disability_lvl_code --MOD:09
                ,disability_comment) --MOD:09
         VALUES (src.appl_disabl_id  --MOD:07
                ,src.appl_id
                ,src.disabl_cond_id
                ,src.primary_flg
                ,src.diagnostician_type
                ,src.diagnostician
                ,src.diagnosis_date
                ,src.diagnostician_text
                ,src.del_date
                ,src.disabl_lvl_code --MOD:09
                ,src.disabl_comment  --MOD:09
                );
   END IF;

   p_appl_disabl_id := v_appl_disabl_id; --MOD:07

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error(SQLERRM);
      RAISE;

END pr_maintain_disabilities;


/*****************************************************************************************
 PURPOSE: Validate relevant input at relevant statuses.
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

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   --Only raise an ASSERT exception if you want to stop further validation.
   assert((p_appl_status IS  NOT NULL),    'Application Status is required.', 'N');
   assert((p_funding_year IS NOT NULL),    'Funding Year is required.', 'N');
   assert((p_school_id IS NOT NULL),       'School is required.', 'N');
   assert((p_given_name IS NOT NULL),      'Given Name is required.', 'N');
   assert((p_surname IS NOT NULL),         'Surname is required.', 'N');
   assert((p_funding_sch_lvl IS NOT NULL), 'Funding Year Level is required.', 'N');
   IF (p_enrolld_sch_lvl IS NOT NULL) THEN
      assert((is_school_yr_lvl_valid (p_enrolld_sch_lvl) = 'Y'), 'Enrolled Year Level '||p_enrolld_sch_lvl||' is not valid', 'N');
   END IF;

   IF (g_err_count > 0 ) THEN
      RAISE e_invalid_input;
   END IF;

   IF (p_appl_status <> GC_APPLSTS_DRAFT) THEN
      assert((p_dob IS NOT NULL),       'DOB is required.', 'N');
      assert((p_gender IS NOT NULL),    'Gender is required.', 'N');
      assert((p_parent_consent_flg = 'Y'), 'Parental Permission is required.', 'N'); --MOD:04
      assert((p_nccd_catgy IS NOT NULL),'NCCD Category is required.', 'N');
      assert((p_nccd_loa IS NOT NULL),  'NCCD Adjustment Level is required.', 'N');
   END IF;

   IF (g_err_count > 0 ) THEN
      RAISE e_invalid_input;
   END IF;

   IF (p_appl_status = GC_APPLSTS_FUNDAPPR) THEN
      assert((p_appl_loa IS NOT NULL),  'SWD Adjustment Level is required.', 'Y');
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_invalid_input THEN
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
END pr_validate_input;


/*****************************************************************************************
 PURPOSE: Maintain application status.
    Update occurs only when the application status matches the most recent status.
 ****************************************************************************************/
PROCEDURE pr_maintain_appl_sts (p_appl_id            IN swd_appl_status.appl_id%TYPE
                               ,p_appl_status        IN swd_appl_status.status_code%TYPE
                               ,p_appl_status_reason IN swd_appl_status.status_reason%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maintain_appl_sts';

   v_curr_sts                swd_appl_status.status_code%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params are appl_id='||p_appl_id||' status='||p_appl_status);

   v_curr_sts := get_appl_sts (p_appl_id);

   IF (NVL(p_appl_status, '?') <> NVL(v_curr_sts, '?')) THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Inserting new status into SWD_APPL_STATUS');
      INSERT INTO swd_appl_status (
         appl_id
        ,status_code
        ,status_date
        ,status_reason)
      VALUES (
         p_appl_id
        ,p_appl_status
        ,TRUNC(SYSDATE)
        ,p_appl_status_reason);
   ELSE
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Update SWD_APPL_STATUS');
      UPDATE swd_appl_status
      SET    status_reason = p_appl_status_reason
      WHERE  appl_status_id = (SELECT MAX(appl_status_id)
                               FROM   swd_appl_status
                               WHERE  appl_id = p_appl_id);
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_maintain_appl_sts;


/*****************************************************************************************
 PURPOSE: Maintain SWD_APPLICATION
 ****************************************************************************************/
PROCEDURE pr_maintain_appl (
   p_appl_id                IN OUT swd_appl_status.appl_id%TYPE
  ,p_appl_status            IN swd_appl_status.status_code%TYPE
  ,p_appl_status_reason     IN swd_appl_status.status_reason%TYPE
  ,p_funding_year           IN swd_application.funding_year%TYPE
  ,p_school_id              IN swd_application.school_id%TYPE
  ,p_ssn                    IN swd_application.state_student_nbr%TYPE
  ,p_username               IN swd_application.student_username%TYPE
  ,p_given_name             IN swd_application.student_first_name%TYPE
  ,p_surname                IN swd_application.student_surname%TYPE
  ,p_dob                    IN swd_application.dob%TYPE
  ,p_gender                 IN swd_application.gender%TYPE
  ,p_enrolld_sch_lvl        IN swd_application.enrolled_school_lvl%TYPE
  ,p_funding_sch_lvl        IN swd_application.funding_school_lvl%TYPE
  ,p_parent_consent_flg     IN swd_application.parent_consent_flg%TYPE
  ,p_nccd_catgy             IN swd_application.nccd_catgy_code%TYPE
  ,p_nccd_loa               IN swd_application.nccd_adj_lvl_code%TYPE
  ,p_iap_curric_partcp_comm IN swd_application.iap_curric_partcp_comment%TYPE
  ,p_iap_curric_partcp_loa  IN swd_application.iap_curric_partcp_adj_lvl_code%TYPE
  ,p_iap_commun_partcp_comm IN swd_application.iap_commun_partcp_comment%TYPE
  ,p_iap_commun_partcp_loa  IN swd_application.iap_commun_partcp_adj_lvl_code%TYPE
  ,p_iap_mobility_comm      IN swd_application.iap_mobility_comment%TYPE
  ,p_iap_mobility_loa       IN swd_application.iap_mobility_adj_lvl_code%TYPE
  ,p_iap_personal_care_comm IN swd_application.iap_personal_care_comment%TYPE
  ,p_iap_personal_care_loa  IN swd_application.iap_personal_care_adj_lvl_code%TYPE
  ,p_iap_soc_skills_comm    IN swd_application.iap_soc_skills_comment%TYPE
  ,p_iap_soc_skills_loa     IN swd_application.iap_soc_skills_adj_lvl_code%TYPE
  ,p_iap_safety_comm        IN swd_application.iap_safety_comment%TYPE
  ,p_iap_safety_loa         IN swd_application.iap_safety_adj_lvl_code%TYPE
  ,p_delete_date            IN swd_application.delete_date%TYPE
  ,p_appl_adj_lvl_comm      IN swd_application.appl_adj_lvl_comment%TYPE
  ,p_appl_loa               IN swd_application.appl_adj_lvl_code%TYPE
  ,p_read_version_nbr       IN swd_application.version_nbr%TYPE
  ,p_related_appl_id        IN swd_application.related_appl_id%TYPE
  ,p_review_date            IN swd_application.review_date%TYPE    --MOD:07
  ,p_review_comment         IN swd_application.review_comment%TYPE --MOD:07
  ,p_stu_fte                IN swd_application.student_fte%TYPE    --MOD:07
  ,p_fed_govt_fund_excl_flg IN swd_application.fed_govt_funding_excl_flg%TYPE   DEFAULT 'N'--MOD:09
) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maintain_appl';

   v_appl_id                 swd_application.appl_id%TYPE;
   v_appl_status             swd_appl_status.status_code%TYPE;
   v_appl_status_reason      swd_appl_status.status_reason%TYPE;
   v_funding_year            swd_application.funding_year%TYPE;
   v_school_id               swd_application.school_id%TYPE;
   v_ssn                     swd_application.state_student_nbr%TYPE;
   v_username                swd_application.student_username%TYPE;
   v_given_name              swd_application.student_first_name%TYPE;
   v_surname                 swd_application.student_surname%TYPE;
   v_dob                     swd_application.dob%TYPE;
   v_gender                  swd_application.gender%TYPE;
   v_enrolld_sch_lvl         swd_application.enrolled_school_lvl%TYPE;
   v_funding_sch_lvl         swd_application.funding_school_lvl%TYPE;
   v_parent_consent_flg      swd_application.parent_consent_flg%TYPE;
   v_nccd_catgy              swd_application.nccd_catgy_code%TYPE;
   v_nccd_loa                swd_application.nccd_adj_lvl_code%TYPE;
   v_appl_adj_comm           swd_application.appl_adj_lvl_comment%TYPE;
   v_appl_loa                swd_application.appl_adj_lvl_code%TYPE;
   v_iap_curric_comm         swd_application.iap_curric_partcp_comment%TYPE;
   v_iap_curric_loa          swd_application.iap_curric_partcp_adj_lvl_code%TYPE;
   v_iap_commun_comm         swd_application.iap_commun_partcp_comment%TYPE;
   v_iap_commun_loa          swd_application.iap_commun_partcp_adj_lvl_code%TYPE;
   v_iap_mobility_comm       swd_application.iap_mobility_comment%TYPE;
   v_iap_mobility_loa        swd_application.iap_mobility_adj_lvl_code%TYPE;
   v_iap_personal_care_comm  swd_application.iap_personal_care_comment%TYPE;
   v_iap_personal_care_loa   swd_application.iap_personal_care_adj_lvl_code%TYPE;
   v_iap_soc_skills_comm     swd_application.iap_soc_skills_comment%TYPE;
   v_iap_soc_skills_loa      swd_application.iap_soc_skills_adj_lvl_code%TYPE;
   v_iap_safety_comm         swd_application.iap_safety_comment%TYPE;
   v_iap_safety_loa          swd_application.iap_safety_adj_lvl_code%TYPE;
   v_delete_date             swd_application.delete_date%TYPE;
   v_read_version_nbr        swd_application.version_nbr%TYPE;
   v_related_appl_id         swd_application.related_appl_id%TYPE;
   v_review_date             swd_application.review_date%TYPE;    --MOD:07
   v_review_comment          swd_application.review_comment%TYPE; --MOD:07
   v_stu_fte                 swd_application.student_fte%TYPE;    --MOD:07
   v_fed_govt_fund_excl_flg  swd_application.fed_govt_funding_excl_flg%TYPE; --MOD:09

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Parameters are appl_id='||p_appl_id||
      ' appl_sts='||p_appl_status||' fund_yr='||p_funding_year||' school_id='||p_school_id||
      ' SSN='||p_ssn||' username='||p_username||' given_name='||p_given_name||
      ' surname='||p_surname||' DOB='||TO_CHAR(p_dob, 'DD-MON-YYYY')||' gender='||p_gender||
      ' enrolled_sch_lvl='||p_enrolld_sch_lvl||' funding_sch_lvl='||p_funding_sch_lvl||
      ' parent_consent_flg='||p_parent_consent_flg||' nccd_catgy='||p_nccd_catgy||
      ' nccd_loa='||p_nccd_loa||' appl_loa='||p_appl_loa||' curric_loa='||p_iap_curric_partcp_loa||
      ' communic_loa='||p_iap_commun_partcp_loa||' mobility_loa='||p_iap_mobility_loa||
      ' personal_care_loa='||p_iap_personal_care_loa||' soc_skills_loa='||p_iap_soc_skills_loa||
      ' safety_loa='||p_iap_safety_loa||' read_ver_nbr='||p_read_version_nbr||
      ' related_appl_id='||p_related_appl_id||
      ' review_date='||TO_CHAR(p_review_date, 'DD-MON-YYYY')||' fte='||p_stu_fte||
      ' fed_govt_fund_excl_flg='||p_fed_govt_fund_excl_flg); --MOD:07, MOD:09

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Assign to local variables');
   v_appl_id                := NVL(p_appl_id, swd_application_seq.NEXTVAL);
   v_appl_status            := UPPER(p_appl_status);
   v_appl_status_reason     := TRIM(p_appl_status_reason);
   v_funding_year           := p_funding_year;
   v_school_id              := p_school_id;
   v_ssn                    := TRIM(p_ssn);
   v_username               := TRIM(p_username);
   v_given_name             := TRIM(p_given_name); --MOD:08
   v_surname                := TRIM(p_surname); --MOD:08
   v_dob                    := p_dob;
   v_gender                 := UPPER(p_gender);
   v_enrolld_sch_lvl        := UPPER(TRIM(p_enrolld_sch_lvl));
   v_funding_sch_lvl        := UPPER(TRIM(p_funding_sch_lvl));
   v_parent_consent_flg     := UPPER(TRIM(p_parent_consent_flg));
   v_appl_adj_comm          := TRIM(p_appl_adj_lvl_comm);
   v_appl_loa               := CASE UPPER(p_appl_status)
                                  WHEN GC_APPLSTS_NE THEN
                                     '0.0'
                                  ELSE
                                     TRIM(p_appl_loa)
                               END;
   v_nccd_catgy             := UPPER(TRIM(p_nccd_catgy));
   v_nccd_loa               := UPPER(TRIM(p_nccd_loa));
   v_iap_curric_comm        := TRIM(p_iap_curric_partcp_comm);
   v_iap_curric_loa         := UPPER(TRIM(p_iap_curric_partcp_loa));
   v_iap_commun_comm        := TRIM(p_iap_commun_partcp_comm);
   v_iap_commun_loa         := UPPER(TRIM(p_iap_commun_partcp_loa));
   v_iap_mobility_comm      := TRIM(p_iap_mobility_comm);
   v_iap_mobility_loa       := UPPER(TRIM(p_iap_mobility_loa));
   v_iap_personal_care_comm := TRIM(p_iap_personal_care_comm);
   v_iap_personal_care_loa  := UPPER(TRIM(p_iap_personal_care_loa));
   v_iap_soc_skills_comm    := TRIM(p_iap_soc_skills_comm);
   v_iap_soc_skills_loa     := UPPER(TRIM(p_iap_soc_skills_loa));
   v_iap_safety_comm        := TRIM(p_iap_safety_comm);
   v_iap_safety_loa         := UPPER(TRIM(p_iap_safety_loa));
   v_delete_date            := p_delete_date;
   v_read_version_nbr       := p_read_version_nbr;
   v_related_appl_id        := p_related_appl_id;
   v_review_date            := p_review_date; --MOD:07
   v_review_comment         := TRIM(p_review_comment); --MOD:07
   v_stu_fte                := NVL(p_stu_fte, 1.0); --MOD:07
   v_fed_govt_fund_excl_flg := NVL(p_fed_govt_fund_excl_flg, 'N'); --MOD:09

   pr_validate_input (v_appl_status
                     ,v_funding_year
                     ,v_school_id
                     ,v_ssn
                     ,v_username
                     ,v_given_name
                     ,v_surname
                     ,v_dob
                     ,v_gender
                     ,v_enrolld_sch_lvl
                     ,v_funding_sch_lvl
                     ,v_parent_consent_flg
                     ,v_nccd_catgy
                     ,v_nccd_loa
                     ,v_appl_loa);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Merge record into SWD_APPLICATION');
   MERGE INTO swd_application a
   USING (SELECT v_appl_id                  appl_id
                ,v_funding_year             funding_year
                ,v_ssn                      ssn
                ,v_username                 username
                ,v_given_name               given_name
                ,v_surname                  surname
                ,v_dob                      dob
                ,v_gender                   gender
                ,NULL                       religion_code
                ,v_school_id                school_id
                ,v_enrolld_sch_lvl          enrolld_sch_lvl
                ,v_funding_sch_lvl          funding_sch_lvl
                ,v_parent_consent_flg       parent_consent_flg
                ,v_appl_adj_comm            appl_adj_comm
                ,v_appl_loa                 appl_loa
                ,v_nccd_catgy               nccd_catgy
                ,v_nccd_loa                 nccd_loa
                ,v_iap_curric_comm          iap_curric_comm
                ,v_iap_curric_loa           iap_curric_loa
                ,v_iap_commun_comm          iap_commun_comm
                ,v_iap_commun_loa           iap_commun_loa
                ,v_iap_mobility_comm        iap_mobility_comm
                ,v_iap_mobility_loa         iap_mobility_loa
                ,v_iap_personal_care_comm   iap_personal_care_comm
                ,v_iap_personal_care_loa    iap_personal_care_loa
                ,v_iap_soc_skills_comm      iap_soc_skills_comm
                ,v_iap_soc_skills_loa       iap_soc_skills_loa
                ,v_iap_safety_comm          iap_safety_comm
                ,v_iap_safety_loa           iap_safety_loa
                ,v_delete_date              delete_date
                ,v_read_version_nbr         version_nbr
                ,v_related_appl_id          related_appl_id
                ,v_review_date              review_date --MOD:07
                ,v_review_comment           review_comm --MOD:07
                ,v_stu_fte                  stu_fte --MOD:07
                ,v_fed_govt_fund_excl_flg   fed_govt_fund_excl_flg --MOD:09
          FROM   DUAL) src
   ON (a.appl_id = src.appl_id)
   WHEN MATCHED THEN
      UPDATE SET
         a.funding_year                   = src.funding_year
        ,a.state_student_nbr              = src.ssn
        ,a.student_username               = src.username
        ,a.student_first_name             = src.given_name
        ,a.student_surname                = src.surname
        ,a.dob                            = src.dob
        ,a.gender                         = src.gender
        ,a.religion_code                  = src.religion_code
        ,a.school_id                      = src.school_id
        ,a.enrolled_school_lvl            = src.enrolld_sch_lvl
        ,a.funding_school_lvl             = src.funding_sch_lvl
        ,a.parent_consent_flg             = src.parent_consent_flg
        ,a.appl_adj_lvl_comment           = src.appl_adj_comm
        ,a.appl_adj_lvl_code              = src.appl_loa
        ,a.nccd_catgy_code                = src.nccd_catgy
        ,a.nccd_adj_lvl_code              = src.nccd_loa
        ,a.iap_curric_partcp_comment      = src.iap_curric_comm
        ,a.iap_curric_partcp_adj_lvl_code = src.iap_curric_loa
        ,a.iap_commun_partcp_comment      = src.iap_commun_comm
        ,a.iap_commun_partcp_adj_lvl_code = src.iap_commun_loa
        ,a.iap_mobility_comment           = src.iap_mobility_comm
        ,a.iap_mobility_adj_lvl_code      = src.iap_mobility_loa
        ,a.iap_personal_care_comment      = src.iap_personal_care_comm
        ,a.iap_personal_care_adj_lvl_code = src.iap_personal_care_loa
        ,a.iap_soc_skills_comment         = src.iap_soc_skills_comm
        ,a.iap_soc_skills_adj_lvl_code    = src.iap_soc_skills_loa
        ,a.iap_safety_comment             = src.iap_safety_comm
        ,a.iap_safety_adj_lvl_code        = src.iap_safety_loa
        ,a.version_nbr                    = src.version_nbr  --trigger takes care of incrementing the version
        ,a.related_appl_id                = src.related_appl_id
        ,a.review_date                    = src.review_date --MOD:07
        ,a.review_comment                 = src.review_comm --MOD:07
        ,a.student_fte                    = src.stu_fte     --MOD:07
        ,a.fed_govt_funding_excl_flg      = src.fed_govt_fund_excl_flg --MOD:09
      WHERE a.appl_id = src.appl_id
      AND   get_appl_sts (src.appl_id) <> GC_APPLSTS_FUNDAPPR
   WHEN NOT MATCHED THEN
      INSERT (appl_id
             ,funding_year
             ,state_student_nbr
             ,student_username
             ,student_first_name
             ,student_surname
             ,dob
             ,gender
             ,religion_code
             ,school_id
             ,enrolled_school_lvl
             ,funding_school_lvl
             ,parent_consent_flg
             ,appl_adj_lvl_comment
             ,appl_adj_lvl_code
             ,nccd_catgy_code
             ,nccd_adj_lvl_code
             ,iap_curric_partcp_comment
             ,iap_curric_partcp_adj_lvl_code
             ,iap_commun_partcp_comment
             ,iap_commun_partcp_adj_lvl_code
             ,iap_mobility_comment
             ,iap_mobility_adj_lvl_code
             ,iap_personal_care_comment
             ,iap_personal_care_adj_lvl_code
             ,iap_soc_skills_comment
             ,iap_soc_skills_adj_lvl_code
             ,iap_safety_comment
             ,iap_safety_adj_lvl_code
             ,related_appl_id
             ,review_date    --MOD:07
             ,review_comment --MOD:07
             ,student_fte    --MOD:07
             ,fed_govt_funding_excl_flg) --MOD:09
      VALUES (src.appl_id
             ,src.funding_year
             ,src.ssn
             ,src.username
             ,src.given_name
             ,src.surname
             ,src.dob
             ,src.gender
             ,src.religion_code
             ,src.school_id
             ,src.enrolld_sch_lvl
             ,src.funding_sch_lvl
             ,src.parent_consent_flg
             ,src.appl_adj_comm
             ,src.appl_loa
             ,src.nccd_catgy
             ,src.nccd_loa
             ,src.iap_curric_comm
             ,src.iap_curric_loa
             ,src.iap_commun_comm
             ,src.iap_commun_loa
             ,src.iap_mobility_comm
             ,src.iap_mobility_loa
             ,src.iap_personal_care_comm
             ,src.iap_personal_care_loa
             ,src.iap_soc_skills_comm
             ,src.iap_soc_skills_loa
             ,src.iap_safety_comm
             ,src.iap_safety_loa
             ,src.related_appl_id
             ,src.review_date --MOD:07
             ,src.review_comm --MOD:07
             ,src.stu_fte     --MOD:07
             ,src.fed_govt_fund_excl_flg); --MOD:09

   pr_maintain_appl_sts (v_appl_id, v_appl_status, v_appl_status_reason);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Pass back appl_id='||v_appl_id);
   p_appl_id := v_appl_id;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error (SQLERRM);
      RAISE;

END pr_maintain_appl;


/*****************************************************************************************
 MOD:07
 PURPOSE: Logically delete an application.
    An application is eligible for deletion if
    - it is not already deleted and
    - it has not been revised and
    - its status is not Funding Approval or Not Eligible.
 ****************************************************************************************/
PROCEDURE pr_delete_appl (p_appl_id IN swd_application.appl_id%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_delete_appl';

   e_no_row_updated          EXCEPTION;

   v_appl_been_revised_flg   VARCHAR2(01) := 'N';
   v_appl_status             swd_appl_status.status_code%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params appl_id='||p_appl_id);

   v_appl_been_revised_flg := appl_been_revised(p_appl_id);
   v_appl_status           := get_appl_sts(p_appl_id);

   UPDATE swd_application
   SET    delete_date = TRUNC(SYSDATE)
   WHERE  appl_id = p_appl_id
   AND    delete_date IS NULL
   AND    v_appl_been_revised_flg = 'N'
   AND    v_appl_status NOT IN (GC_APPLSTS_FUNDAPPR, GC_APPLSTS_NE);
   IF (SQL%ROWCOUNT = 0) THEN
      RAISE e_no_row_updated;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_no_row_updated THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Application not found or ineligible for deletion.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;

   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;

END pr_delete_appl;


/*****************************************************************************************
 PURPOSE: Copy an existing application either for rolling over to the next funding year
    or as a revision in the current funding year.  Only Funding Approved applications
    may be revised.
 ****************************************************************************************/
PROCEDURE pr_copy_appl (p_appl_id          IN OUT swd_application.appl_id%TYPE
                       ,p_funding_year     IN swd_application.funding_year%TYPE
                       ,p_funding_sch_lvl  IN swd_application.funding_school_lvl%TYPE
                       ,p_school_id        IN swd_application.school_id%TYPE --MOD:07
                       ,p_request          IN VARCHAR2) IS

   VC_SUBPROG_UNIT    CONSTANT VARCHAR2(30) := 'pr_copy_appl';
   VC_REQ_ROLLOVERNOW CONSTANT VARCHAR2(15) := 'ROLLOVERNOW'; --Copy for another funding year
   VC_REQ_REVISE      CONSTANT VARCHAR2(10) := 'REVISE'; --Another version for same funding year
   VC_REQ_SCHTRNSFNOW CONSTANT VARCHAR2(15) := 'SCHTRANSFERNOW'; --MOD:07 Copy to another school

   e_copy_error              EXCEPTION;

   v_orig_funding_year       swd_application.funding_year%TYPE;
   v_orig_school_id          swd_application.school_id%TYPE; --MOD:07
   v_appl_exist_flg          VARCHAR2(01) := 'N';
   v_new_appl_id             swd_application.appl_id%TYPE;
   v_appl_status             swd_appl_status.status_code%TYPE;
   v_appl_status_reason      swd_appl_status.status_reason%TYPE;
   v_funding_year            swd_application.funding_year%TYPE;
   v_school_id               swd_application.school_id%TYPE;
   v_ssn                     swd_application.state_student_nbr%TYPE;
   v_username                swd_application.student_username%TYPE;
   v_given_name              swd_application.student_first_name%TYPE;
   v_surname                 swd_application.student_surname%TYPE;
   v_dob                     swd_application.dob%TYPE;
   v_gender                  swd_application.gender%TYPE;
   v_enrolld_sch_lvl         swd_application.enrolled_school_lvl%TYPE;
   v_funding_sch_lvl         swd_application.funding_school_lvl%TYPE;
   v_parent_consent_flg      swd_application.parent_consent_flg%TYPE;
   v_nccd_catgy              swd_application.nccd_catgy_code%TYPE;
   v_nccd_loa                swd_application.nccd_adj_lvl_code%TYPE;
   v_iap_curric_partcp_comm  swd_application.iap_curric_partcp_comment%TYPE;
   v_iap_curric_partcp_loa   swd_application.iap_curric_partcp_adj_lvl_code%TYPE;
   v_iap_commun_partcp_comm  swd_application.iap_commun_partcp_comment%TYPE;
   v_iap_commun_partcp_loa   swd_application.iap_commun_partcp_adj_lvl_code%TYPE;
   v_iap_mobility_comm       swd_application.iap_mobility_comment%TYPE;
   v_iap_mobility_loa        swd_application.iap_mobility_adj_lvl_code%TYPE;
   v_iap_personal_care_comm  swd_application.iap_personal_care_comment%TYPE;
   v_iap_personal_care_loa   swd_application.iap_personal_care_adj_lvl_code%TYPE;
   v_iap_soc_skills_comm     swd_application.iap_soc_skills_comment%TYPE;
   v_iap_soc_skills_loa      swd_application.iap_soc_skills_adj_lvl_code%TYPE;
   v_iap_safety_comm         swd_application.iap_safety_comment%TYPE;
   v_iap_safety_loa          swd_application.iap_safety_adj_lvl_code%TYPE;
   v_delete_date             swd_application.delete_date%TYPE;
   v_appl_adj_lvl_comm       swd_application.appl_adj_lvl_comment%TYPE;
   v_appl_loa                swd_application.appl_adj_lvl_code%TYPE;
   v_read_version_nbr        swd_application.version_nbr%TYPE;
   v_related_appl_id         swd_application.related_appl_id%TYPE;
   v_review_date             swd_application.review_date%TYPE;    --MOD:07
   v_review_comm             swd_application.review_comment%TYPE; --MOD:07
   v_fte                     swd_application.student_fte%TYPE;    --MOD:07
   v_fed_govt_fund_excl_flg  swd_application.fed_govt_funding_excl_flg%TYPE; --MOD:09
   v_appl_disabl_id          swd_appl_disability.appl_disabl_id%TYPE; --MOD:07

   CURSOR c_supp_disabl (cp_appl_id IN swd_application.appl_id%TYPE) IS
      SELECT d.disability_cond_id
            ,d.primary_cond_flg
            ,d.diagnostician_type_code
            ,d.diagnostician
            ,d.diagnosis_date
            ,d.diagnostician_text
            ,d.disability_lvl_code --MOD:09
            ,d.disability_comment  --MOD:09
      FROM   swd_appl_disability d
      WHERE  d.appl_id = cp_appl_id
      AND    d.delete_date IS NULL;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params copy_appl_id='||p_appl_id||
      ' fund_year='||p_funding_year||' fund_sch_lvl='||p_funding_sch_lvl||' request='||p_request);

   IF (p_request = VC_REQ_ROLLOVERNOW) THEN
      v_orig_funding_year := get_funding_year (p_appl_id);
      assert ((v_orig_funding_year IS NOT NULL), 'Original application not found', 'Y');
      assert ((v_orig_funding_year < p_funding_year), 'Funding year for the new application '||
         'must be after the original.', 'Y');

      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Does application exist for new funding year?');
      v_appl_exist_flg := is_fund_year_appl_exist (p_appl_id, p_funding_year);
      IF (v_appl_exist_flg = 'Y') THEN
         assert ((v_appl_exist_flg = 'N'), 'A '||p_funding_year||
            ' application has already been created for this student.', 'Y');
      END IF;

      assert ((get_funded_sch_lvl (p_appl_id) <> 'Y12'), 'Cannot rollover a Year 12 application.', 'Y');

   ELSIF (p_request = VC_REQ_REVISE) THEN
      assert ((appl_been_revised (p_appl_id) = 'N'), 'Application has been superseded by a revision.', 'Y'); --MOD:07
      assert ((   get_appl_sts (p_appl_id) IN (GC_APPLSTS_FUNDAPPR, GC_APPLSTS_NE)
               OR get_inactive_date (p_appl_id) IS NOT NULL) --MOD:07
              ,'Only applications (a) approved for funding or (b) ineligible or (c) inactive may be revised', 'Y'); --MOD:06, MOD:07

   ELSIF (p_request = VC_REQ_SCHTRNSFNOW) THEN
      SELECT school_id
      INTO   v_orig_school_id
      FROM   swd_application
      WHERE  appl_id = p_appl_id;

      assert ((v_orig_school_id <> p_school_id), 'New school must be different from the old school.', 'Y'); --MOD:07

   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Fetch original application');
   SELECT NULL  --appl_id
         ,DECODE(p_request, VC_REQ_SCHTRNSFNOW, get_appl_sts (p_appl_id), GC_APPLSTS_DRAFT) --MOD:07
         ,DECODE(p_request, VC_REQ_REVISE,      'Revision of Application Id '||p_appl_id
                          , VC_REQ_SCHTRNSFNOW, 'Created via School Transfer'
                          , NULL) --appl_status_reason  MOD:07
         ,p_funding_year
         ,p_school_id --MOD:07
         ,c.state_student_nbr
         ,c.student_username
         ,c.student_first_name
         ,c.student_surname
         ,c.dob
         ,c.gender
         ,NULL   --MOD:07  c.enrolled_school_lvl
         ,p_funding_sch_lvl
         ,c.parent_consent_flg
         ,c.nccd_catgy_code
         ,c.nccd_adj_lvl_code
         ,c.iap_curric_partcp_comment
         ,c.iap_curric_partcp_adj_lvl_code
         ,c.iap_commun_partcp_comment
         ,c.iap_commun_partcp_adj_lvl_code
         ,c.iap_mobility_comment
         ,c.iap_mobility_adj_lvl_code
         ,c.iap_personal_care_comment
         ,c.iap_personal_care_adj_lvl_code
         ,c.iap_soc_skills_comment
         ,c.iap_soc_skills_adj_lvl_code
         ,c.iap_safety_comment
         ,c.iap_safety_adj_lvl_code
         ,NULL  --delete_date
         ,c.appl_adj_lvl_comment
         ,c.appl_adj_lvl_code
         ,NULL  --read_version_nbr
         ,DECODE(p_request, VC_REQ_REVISE, p_appl_id, VC_REQ_SCHTRNSFNOW, p_appl_id, NULL) --MOD:07
         ,DECODE(p_request, VC_REQ_REVISE, c.review_date, NULL)    --review_date    --MOD:07
         ,DECODE(p_request, VC_REQ_REVISE, c.review_comment, NULL) --review_comment --MOD:07
         ,c.student_fte --MOD:07
         ,c.fed_govt_funding_excl_flg --MOD:09
   INTO  v_new_appl_id
        ,v_appl_status
        ,v_appl_status_reason
        ,v_funding_year
        ,v_school_id
        ,v_ssn
        ,v_username
        ,v_given_name
        ,v_surname
        ,v_dob
        ,v_gender
        ,v_enrolld_sch_lvl
        ,v_funding_sch_lvl
        ,v_parent_consent_flg
        ,v_nccd_catgy
        ,v_nccd_loa
        ,v_iap_curric_partcp_comm
        ,v_iap_curric_partcp_loa
        ,v_iap_commun_partcp_comm
        ,v_iap_commun_partcp_loa
        ,v_iap_mobility_comm
        ,v_iap_mobility_loa
        ,v_iap_personal_care_comm
        ,v_iap_personal_care_loa
        ,v_iap_soc_skills_comm
        ,v_iap_soc_skills_loa
        ,v_iap_safety_comm
        ,v_iap_safety_loa
        ,v_delete_date
        ,v_appl_adj_lvl_comm
        ,v_appl_loa
        ,v_read_version_nbr
        ,v_related_appl_id
        ,v_review_date --MOD:07
        ,v_review_comm --MOD:07
        ,v_fte         --MOD:07
        ,v_fed_govt_fund_excl_flg --MOD:09
   FROM  swd_application c
   WHERE c.appl_id = p_appl_id;

   pr_maintain_appl (v_new_appl_id
                    ,v_appl_status
                    ,v_appl_status_reason
                    ,v_funding_year
                    ,v_school_id
                    ,v_ssn
                    ,v_username
                    ,v_given_name
                    ,v_surname
                    ,v_dob
                    ,v_gender
                    ,v_enrolld_sch_lvl
                    ,v_funding_sch_lvl
                    ,v_parent_consent_flg
                    ,v_nccd_catgy
                    ,v_nccd_loa
                    ,v_iap_curric_partcp_comm
                    ,v_iap_curric_partcp_loa
                    ,v_iap_commun_partcp_comm
                    ,v_iap_commun_partcp_loa
                    ,v_iap_mobility_comm
                    ,v_iap_mobility_loa
                    ,v_iap_personal_care_comm
                    ,v_iap_personal_care_loa
                    ,v_iap_soc_skills_comm
                    ,v_iap_soc_skills_loa
                    ,v_iap_safety_comm
                    ,v_iap_safety_loa
                    ,v_delete_date
                    ,v_appl_adj_lvl_comm
                    ,v_appl_loa
                    ,v_read_version_nbr
                    ,v_related_appl_id
                    ,v_review_date --MOD:07
                    ,v_review_comm --MOD:07
                    ,v_fte         --MOD:07
                    ,v_fed_govt_fund_excl_flg --MOD:09
                    );

   IF (v_new_appl_id IS NULL) THEN
      RAISE e_copy_error;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Now copy each active disability.');
   FOR r IN c_supp_disabl (p_appl_id) LOOP
      v_appl_disabl_id := NULL; --MOD:07

      pr_maintain_disabilities (
         p_appl_disabl_id     => v_appl_disabl_id --MOD:07
        ,p_appl_id            => v_new_appl_id
        ,p_appl_status        => GC_APPLSTS_DRAFT
        ,p_disabl_cond_id     => r.disability_cond_id
        ,p_primary_flg        => r.primary_cond_flg
        ,p_diagnostician_type => r.diagnostician_type_code
        ,p_diagnostician      => r.diagnostician
        ,p_diagnosis_date     => r.diagnosis_date
        ,p_diagnostician_text => r.diagnostician_text
        ,p_disabl_lvl_code    => r.disability_lvl_code --MOD:09
        ,p_disabl_comment     => r.disability_comment  --MOD:09
        ,p_delete_flg         => 'N');
   END LOOP;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Pass back appl_id='||v_new_appl_id);
   p_appl_id := v_new_appl_id;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_copy_error THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error copying application.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
END pr_copy_appl;


/*****************************************************************************************
 MOD:07
 PURPOSE: Populate Apex collection with rollover data for preview.
          Where applications have been revised, only the latest will be picked up for
          rollover.
          Only applications meeting the following criteria are eligible for rollover:
          - current funding school level is not Year 12
          - where function is_fund_year_appl_exist return 'N'
          - is active
          - is Funding Approved
          - does not include LDC* disability

          Rollover status in SWD_APPL_STATUS
          ==================================
          If the new funding school level is IN ('PS', 'Y04', 'Y07')
          - roll application into Draft
          If the year of the old review date plus one matches the new funding year
          - roll application into Draft
          All others, roll over into the existing status.
 ****************************************************************************************/
PROCEDURE pr_bulk_rollover_preview (p_fund_year_from IN swd_application.funding_year%TYPE
                                   ,p_fund_year_to   IN swd_application.funding_year%TYPE
                                   ,p_school_id_from IN swd_application.school_id%TYPE
                                   ,p_school_id_to   IN swd_application.school_id%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_bulk_rollover_preview';

   v_curr_year               NUMBER(04) := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'));
   v_sql                     VARCHAR2(4000);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params fund_yr_frm='||p_fund_year_from||
      ' fund_yr_to='||p_fund_year_to||' school_id_frm='||p_school_id_from||' school_id_to='||p_school_id_to);

   assert((p_fund_year_to > p_fund_year_from), 'TO Funding Year must be greater than FROM Funding Year.', 'Y');

   IF APEX_COLLECTION.COLLECTION_EXISTS (GC_APX_COLL_ROLLPREV) THEN
      APEX_COLLECTION.DELETE_COLLECTION (GC_APX_COLL_ROLLPREV);
   END IF;

   -- !! Adhere to Apex collection requirement of APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERYB2 !!
   v_sql :=
   q'[SELECT b.appl_id          appl_id
            ,NVL(:p_fund_year_to, b.curr_fund_year) new_fund_year
            ,b.wasn             wasn
            ,b.curr_school_id   old_school_id --MOD:07
            ,NVL(:p_school_id_to, b.curr_school_id) new_school_id
            ,NULL --date_1
            ,NULL
            ,NULL
            ,NULL
            ,NULL --date_5
            ,b.surname          surname
            ,b.first_name       first_name
            ,b.new_fund_sch_lvl new_fund_sch_lvl
            ,b.curr_appl_sts    old_appl_sts --MOD:07
            ,(CASE
              WHEN (b.new_fund_sch_lvl IN ('PS', 'Y04', 'Y07', 'Y10')) THEN --MOD:09, MOD:11, MOD:13
                 'DRAFT'
              WHEN (NVL(:p_fund_year_to, b.curr_fund_year) = b.review_year + 1) THEN --MOD:11
                 'DRAFT'
              ELSE
                 b.curr_appl_sts
             END)               new_appl_sts --MOD:07
            ,b.review_year      review_year  --MOD:07
      FROM  (SELECT a.appl_id            appl_id
                   ,a.funding_year       curr_fund_year
                   ,a.state_student_nbr  wasn
                   ,a.school_id          curr_school_id
                   ,a.student_surname    surname
                   ,a.student_first_name first_name
                   --MOD:07 ,a.enrolled_school_lvl   enrolled_sch_lvl
                   ,swd_funding_application.get_next_sch_lvl (a.funding_school_lvl) new_fund_sch_lvl
                   ,swd.swd_funding_application.get_appl_sts(a.appl_id) curr_appl_sts --MOD:07
                   ,EXTRACT(YEAR FROM a.review_date) review_year --MOD:07
             FROM   swd_application a
                    INNER JOIN (--Want only the latest version
                                SELECT b.appl_id
                                FROM   swd_application b
                                WHERE  b.funding_school_lvl <> 'Y12'
                                AND    b.delete_date   IS NULL
                                AND    b.inactive_date IS NULL --MOD:07
                                AND    b.funding_year = :p_fund_year_from
                                AND    b.school_id    = NVL(:p_school_id_from, b.school_id)
                                AND    swd_funding_application.get_appl_sts(b.appl_id) = 'FUNDAPPR' --MOD:07
                                AND    NVL((SELECT 'Y'
                                            FROM   swd_appl_disability ad
                                                   INNER JOIN sub_disability_categories sdc --MOD:09
                                                      ON ad.disability_cond_id = sdc.id
                                            WHERE  ad.appl_id = b.appl_id
                                            AND    INSTR(sdc.sub_cat_id, 'LDC') > 0
                                            AND    ad.delete_date IS NULL), 'N') = 'N' --MOD:07
                                MINUS
                                SELECT b2.related_appl_id
                                FROM   swd_application b2
                                WHERE  b2.funding_school_lvl <> 'Y12'
                                AND    b2.delete_date IS NULL
                                AND    b2.funding_year = :p_fund_year_from
                                --MOD:11 AND    b2.school_id    = NVL(:p_school_id_from, b2.school_id)
                                ) c
                       ON a.appl_id = c.appl_id
             WHERE swd_funding_application.is_fund_year_appl_exist (a.appl_id, :p_fund_year_to) = 'N') b]';

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Create and populate collection '||GC_APX_COLL_ROLLPREV);
   APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERYB2 (
      p_collection_name => GC_APX_COLL_ROLLPREV
     ,p_query  => v_sql
     ,p_names  => APEX_STRING.STRING_TO_TABLE('p_fund_year_from:p_fund_year_to:p_school_id_from:p_school_id_to')
     ,p_values => APEX_STRING.STRING_TO_TABLE(p_fund_year_from||':'||p_fund_year_to||':'||p_school_id_from||':'||p_school_id_to));

   COMMIT; --MOD:07 Query across db link

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error copying rollover review data. '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_bulk_rollover_preview;


/*****************************************************************************************
 PURPOSE: Rollover applications by making a copy of the old application.
          Applications are not always copied exactly.

          SWD_APPLICATION
          ===============
          If the year of the old review date matches the new funding year
          - remove the application adjustment level and comment
          If the year of the old review date plus one matches the new funding year
          - remove the review date and comment
 ****************************************************************************************/
PROCEDURE pr_bulk_rollover IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_bulk_rollover';
   VC_LIMIT         CONSTANT NUMBER(03) := 100;

   CURSOR c_appl_rollover IS
      SELECT sr.old_appl_id                   old_appl_id
            ,swd_application_seq.NEXTVAL      new_appl_id
            ,sr.new_fund_year                 new_fund_yr
            ,a.state_student_nbr              ssn
            ,a.student_username               username
            ,a.student_first_name             first_name
            ,a.student_surname                surname
            ,a.dob                            dob
            ,a.gender                         gender
            ,a.religion_code                  relgn_code
            ,sr.new_school_id                 new_school_id
            --MOD:07 ,sr.new_enrolld_sch_lvl           new_enrolld_sch_lvl
            ,NULL                             new_enrolld_sch_lvl --MOD:07
            ,sr.new_fund_sch_lvl              new_fund_sch_lvl
            ,a.parent_consent_flg             parent_consent_flg
            ,a.appl_adj_lvl_comment           appl_adj_comm
            ,a.appl_adj_lvl_code              appl_loa
            ,a.nccd_catgy_code                nccd_catgy
            ,a.nccd_adj_lvl_code              nccd_loa
            ,a.iap_curric_partcp_comment      iap_curric_comm
            ,a.iap_curric_partcp_adj_lvl_code iap_curric_loa
            ,a.iap_commun_partcp_comment      iap_commun_comm
            ,a.iap_commun_partcp_adj_lvl_code iap_commun_loa
            ,a.iap_mobility_comment           iap_mobility_comm
            ,a.iap_mobility_adj_lvl_code      iap_mobility_loa
            ,a.iap_personal_care_comment      iap_personal_comm
            ,a.iap_personal_care_adj_lvl_code iap_personal_loa
            ,a.iap_soc_skills_comment         iap_soc_skills_comm
            ,a.iap_soc_skills_adj_lvl_code    iap_soc_skills_loa
            ,a.iap_safety_comment             iap_safety_comm
            ,a.iap_safety_adj_lvl_code        iap_safety_loa
            ,sr.review_year                   review_year  --MOD:07
            ,a.review_date                    review_date  --MOD:07
            ,a.review_comment                 review_comm  --MOD:07
            ,a.student_fte                    fte          --MOD:07
            ,a.fed_govt_funding_excl_flg      fed_govt_fund_excl_flg --MOD:09
            ,sr.new_appl_sts                  new_appl_sts --MOD:07
      FROM  (SELECT seq_id coll_row_id
                   ,n001   old_appl_id
                   ,n002   new_fund_year
                   ,n003   state_student_nbr
                   ,n004   old_school_id
                   ,n005   new_school_id
                   ,c001   stu_surname
                   ,c002   stu_first_name
                   ,c003   new_fund_sch_lvl
                   ,c004   old_appl_sts
                   ,c005   new_appl_sts
                   ,TO_NUMBER(c006)   review_year
             FROM   apex_collections
             WHERE  collection_name = GC_APX_COLL_ROLLPREV) sr --MOD:07
             INNER JOIN swd_application a
                ON sr.old_appl_id = a.appl_id;

   e_uk_violation            EXCEPTION;
   PRAGMA EXCEPTION_INIT (e_uk_violation, -00001);

   TYPE ApplRolloverTab IS TABLE OF c_appl_rollover%ROWTYPE
      INDEX BY PLS_INTEGER;
   v_coll_appl_rollover      ApplRolloverTab;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   OPEN c_appl_rollover;
   <<rollover_loop>>
   LOOP
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Fetch rollover data');
      FETCH c_appl_rollover
      BULK COLLECT INTO v_coll_appl_rollover
      LIMIT VC_LIMIT;

      EXIT WHEN v_coll_appl_rollover.COUNT = 0;

      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '----- Bulk insert into SWD_APPLICATION');
      FORALL i IN 1..v_coll_appl_rollover.COUNT
         INSERT INTO swd_application (
            appl_id
           ,funding_year
           ,state_student_nbr
           ,student_username
           ,student_first_name
           ,student_surname
           ,dob
           ,gender
           ,religion_code
           ,school_id
           ,enrolled_school_lvl
           ,funding_school_lvl
           ,parent_consent_flg
           ,appl_adj_lvl_comment
           ,appl_adj_lvl_code
           ,nccd_catgy_code
           ,nccd_adj_lvl_code
           ,iap_curric_partcp_comment
           ,iap_curric_partcp_adj_lvl_code
           ,iap_commun_partcp_comment
           ,iap_commun_partcp_adj_lvl_code
           ,iap_mobility_comment
           ,iap_mobility_adj_lvl_code
           ,iap_personal_care_comment
           ,iap_personal_care_adj_lvl_code
           ,iap_soc_skills_comment
           ,iap_soc_skills_adj_lvl_code
           ,iap_safety_comment
           ,iap_safety_adj_lvl_code
           ,review_date    --MOD:07
           ,review_comment --MOD:07
           ,student_fte    --MOD:07
           ,fed_govt_funding_excl_flg --MOD:09
           )
         VALUES (v_coll_appl_rollover(i).new_appl_id
                ,v_coll_appl_rollover(i).new_fund_yr
                ,v_coll_appl_rollover(i).ssn
                ,v_coll_appl_rollover(i).username
                ,v_coll_appl_rollover(i).first_name
                ,v_coll_appl_rollover(i).surname
                ,v_coll_appl_rollover(i).dob
                ,v_coll_appl_rollover(i).gender
                ,v_coll_appl_rollover(i).relgn_code
                ,v_coll_appl_rollover(i).new_school_id
                ,v_coll_appl_rollover(i).new_enrolld_sch_lvl
                ,v_coll_appl_rollover(i).new_fund_sch_lvl
                ,v_coll_appl_rollover(i).parent_consent_flg
                ,DECODE(v_coll_appl_rollover(i).new_appl_sts
                       ,GC_APPLSTS_DRAFT, NULL
                       ,v_coll_appl_rollover(i).appl_adj_comm) --MOD:07
                ,v_coll_appl_rollover(i).appl_loa
                ,v_coll_appl_rollover(i).nccd_catgy
                ,v_coll_appl_rollover(i).nccd_loa
                ,v_coll_appl_rollover(i).iap_curric_comm
                ,v_coll_appl_rollover(i).iap_curric_loa
                ,v_coll_appl_rollover(i).iap_commun_comm
                ,v_coll_appl_rollover(i).iap_commun_loa
                ,v_coll_appl_rollover(i).iap_mobility_comm
                ,v_coll_appl_rollover(i).iap_mobility_loa
                ,v_coll_appl_rollover(i).iap_personal_comm
                ,v_coll_appl_rollover(i).iap_personal_loa
                ,v_coll_appl_rollover(i).iap_soc_skills_comm
                ,v_coll_appl_rollover(i).iap_soc_skills_loa
                ,v_coll_appl_rollover(i).iap_safety_comm
                ,v_coll_appl_rollover(i).iap_safety_loa
                /** MOD:11 Start
                ,DECODE(v_coll_appl_rollover(i).review_year
                       ,v_coll_appl_rollover(i).new_fund_yr, NULL
                       ,v_coll_appl_rollover(i).review_date) */ --MOD:07
                ,CASE
                 WHEN (v_coll_appl_rollover(i).review_year + 1 = v_coll_appl_rollover(i).new_fund_yr) THEN
                    NULL
                 ELSE
                    v_coll_appl_rollover(i).review_date
                 END  --MOD:11 End
                 /** MOD:11 Start
                ,DECODE(v_coll_appl_rollover(i).review_year
                       ,v_coll_appl_rollover(i).new_fund_yr, NULL
                       ,v_coll_appl_rollover(i).review_comm) */ --MOD:07
                ,CASE
                 WHEN (v_coll_appl_rollover(i).review_year + 1 = v_coll_appl_rollover(i).new_fund_yr) THEN
                    NULL
                 ELSE
                    v_coll_appl_rollover(i).review_comm
                 END  --MOD:11 End
                ,v_coll_appl_rollover(i).fte --MOD:07
                ,v_coll_appl_rollover(i).fed_govt_fund_excl_flg --MOD:09
                );

      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '----- Insert into SWD_APPL_DISABILITY');
      FOR i IN 1..v_coll_appl_rollover.COUNT LOOP
         INSERT INTO swd_appl_disability (
            appl_disabl_id
           ,appl_id
           ,disability_cond_id
           ,primary_cond_flg
           ,diagnostician_type_code
           ,diagnostician
           ,diagnosis_date
           ,diagnostician_text
           ,disability_lvl_code --MOD:09
           ,disability_comment) --MOD:09
         SELECT swd_appl_disability_seq.NEXTVAL
               ,v_coll_appl_rollover(i).new_appl_id
               ,d.disability_cond_id
               ,d.primary_cond_flg
               ,d.diagnostician_type_code
               ,d.diagnostician
               ,d.diagnosis_date
               ,d.diagnostician_text
               ,d.disability_lvl_code --MOD:09
               ,d.disability_comment  --MOD:09
         FROM   swd_appl_disability d
         WHERE  d.appl_id = v_coll_appl_rollover(i).old_appl_id
         AND    d.delete_date IS NULL;
      END LOOP;

      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, '----- Bulk insert into SWD_APPL_STATUS');
      FORALL i IN 1..v_coll_appl_rollover.COUNT
         INSERT INTO swd_appl_status (
            appl_id
           ,status_code
           ,status_date
           ,status_reason)
         VALUES (
            v_coll_appl_rollover(i).new_appl_id
           ,v_coll_appl_rollover(i).new_appl_sts --MOD:07
           ,TRUNC(SYSDATE)
           ,'Bulk Rollover'); --MOD:07

      EXIT WHEN v_coll_appl_rollover.COUNT < VC_LIMIT;

   END LOOP rollover_loop;
   CLOSE c_appl_rollover;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Outside fetch loop. Clear rollover data.');
   APEX_COLLECTION.DELETE_COLLECTION (GC_APX_COLL_ROLLPREV);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_uk_violation THEN
      IF c_appl_rollover%ISOPEN THEN
         CLOSE c_appl_rollover;
      END IF;
      ROLLBACK;
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error! '||SQLERRM);
      APEX_ERROR.ADD_ERROR(p_message => 'Duplicate application(s) detected'
                          ,p_display_location => APEX_ERROR.C_INLINE_IN_NOTIFICATION);
      RAISE;
   WHEN OTHERS THEN
      IF c_appl_rollover%ISOPEN THEN
         CLOSE c_appl_rollover;
      END IF;
      ROLLBACK;
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error! '||SQLERRM);
      RAISE;

END pr_bulk_rollover;


/*****************************************************************************************
 PURPOSE: Build an Apex collection of SWD2 groups in Active Directory
 ****************************************************************************************/
PROCEDURE pr_build_swd2_group_list IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_build_swd2_group_list';

   v_coll_swd2_groups        common.com_utils.LDAPGroupColl;
   v_group                   VARCHAR2(100);
   v_environment             VARCHAR2(5) := common.com_network_utils.get_env; --MOD:15

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Get list of SWD2 AD groups');
   v_coll_swd2_groups := com_utils.get_multi_group_attrb (
                            p_attribute    => 'distinguishedName'
                           ,p_group_filter => CASE
                                                WHEN v_environment = 'P' THEN
                                                  '|(cn=SG-8445-SWD-Administrators)(cn=SG-8445-SWD-Consultants)(cn=SG-8445-SWD-Principals)(cn=SG-8445-SWD-Teachers)'
                                                ELSE
                                                  '|(cn=SG-8445-tst-SWD-Administrators)(cn=SG-8445-tst-SWD-Consultants)(cn=SG-8445-tst-SWD-Principals)(cn=SG-8445-tst-SWD-Teachers)'
                                                END
                                                );--MOD:15
                           --MOD:09 ,p_group_filter => 'cn=SG-8445-SWD*');
                           --MOD:07 ,p_search_base  => 'OU=Migrated OU,DC=cewa,DC=edu,DC=au');

   --MOD:07 pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Create the Apex collection to store LDAP query result');
   APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION (p_collection_name => GC_APX_COLL_SWD2_GRP);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Group count returned is '||v_coll_swd2_groups.COUNT);
   IF (v_coll_swd2_groups.COUNT > 0) THEN
      FOR i IN v_coll_swd2_groups.FIRST..v_coll_swd2_groups.LAST LOOP
         v_group := SUBSTR(v_coll_swd2_groups(i), INSTR(v_coll_swd2_groups(i), '=')+1, (INSTR(v_coll_swd2_groups(i), ',')-INSTR(v_coll_swd2_groups(i), '=')-1));
         pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'group_dn='||v_coll_swd2_groups(i)||' group='||v_group);
         APEX_COLLECTION.ADD_MEMBER(p_collection_name => GC_APX_COLL_SWD2_GRP
                                   ,p_c001 => v_group
                                   ,p_c002 => v_coll_swd2_groups(i));
      END LOOP;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_build_swd2_group_list;


/*****************************************************************************************
 PURPOSE: Return a colon delimited list of the display value of SWD2 groups that are
    assigned to the user. (Although there should be only one.)
 ****************************************************************************************/
FUNCTION get_user_group_list (p_user_dn IN VARCHAR2)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_user_group_list';

   v_coll_swd2_groups_disp   common.com_utils.LDAPGroupColl;
   v_coll_swd2_groups_dn     common.com_utils.LDAPGroupColl;
   v_coll_user_groups        common.com_utils.LDAPGroupColl;
   v_userprincipalname       VARCHAR2(200); --MOD:15
   v_user_group_list         VARCHAR2(4000);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params user_dn='||p_user_dn);

   SELECT c001  swd2_group_disp
         ,c002  swd2_group_dn
   BULK COLLECT INTO v_coll_swd2_groups_disp
                    ,v_coll_swd2_groups_dn
   FROM   apex_collections
   WHERE  collection_name = GC_APX_COLL_SWD2_GRP;

   v_userprincipalname := common.com_utils.get_userPrincipalName(p_user_dn);        --MOD:15
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params v_userprincipalname='||v_userprincipalname);--MOD:15

   --Selected user's group membership
   v_coll_user_groups := com_utils.get_member_of(v_userprincipalname); --MOD:15

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'User is member of '||v_coll_user_groups.COUNT||' groups.');
   IF (v_coll_user_groups.COUNT > 0) THEN
      <<user_groups_loop>>
      FOR i IN v_coll_user_groups.FIRST..v_coll_user_groups.LAST LOOP

         <<swd2_groups_loop>>
         FOR j IN v_coll_swd2_groups_dn.FIRST..v_coll_swd2_groups_dn.LAST LOOP
            --Is user member of any SWD2 group?
            IF (v_coll_user_groups(i) = v_coll_swd2_groups_dn(j)) THEN
               v_user_group_list := v_user_group_list||':'||v_coll_user_groups(i);
               EXIT swd2_groups_loop;
            END IF;
         END LOOP swd2_groups_loop;

      END LOOP user_groups_loop;
   END IF;

   v_user_group_list := LTRIM(v_user_group_list, ':');
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'User SWD groups are '||v_user_group_list);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_user_group_list;

END get_user_group_list;


/*****************************************************************************************
 PURPOSE: Build an Apex collection of the SWD2 group that is assigned to the user.
 ****************************************************************************************/
PROCEDURE pr_build_user_group_list(p_username IN VARCHAR2) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_build_user_group_list';

   v_coll_swd2_groups_disp   common.com_utils.LDAPGroupColl;
   v_coll_swd2_groups_dn     common.com_utils.LDAPGroupColl;
   v_coll_user_groups        common.com_utils.LDAPGroupColl;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params username='||p_username);

   SELECT c001  swd2_group_disp
         ,c002  swd2_group_dn
   BULK COLLECT INTO v_coll_swd2_groups_disp
                    ,v_coll_swd2_groups_dn
   FROM   apex_collections
   WHERE  collection_name = GC_APX_COLL_SWD2_GRP;

   --MOD:07 pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Create the Apex collection to store LDAP query result');
   APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION (p_collection_name => GC_APX_COLL_USER_GRP);

   --Selected user's group membership
   v_coll_user_groups := com_utils.get_member_of(p_username);

   IF (v_coll_user_groups.COUNT > 0) THEN
      <<user_groups_loop>>
      FOR i IN v_coll_user_groups.FIRST..v_coll_user_groups.LAST LOOP

         <<swd2_groups_loop>>
         FOR j IN v_coll_swd2_groups_dn.FIRST..v_coll_swd2_groups_dn.LAST LOOP
            --Is user member of any SWD2 group?
            IF (v_coll_user_groups(i) = v_coll_swd2_groups_dn(j)) THEN
               APEX_COLLECTION.ADD_MEMBER (p_collection_name => GC_APX_COLL_USER_GRP
                                          ,p_c001 => v_coll_swd2_groups_disp(j)
                                          ,p_c002 => v_coll_user_groups(i));
               EXIT swd2_groups_loop;
            END IF;
         END LOOP swd2_groups_loop;

      END LOOP user_groups_loop;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_build_user_group_list;


/*****************************************************************************************
 MOD:07
 PURPOSE: Build an Apex collection of members of a group.
 ****************************************************************************************/
PROCEDURE pr_build_group_user_list (p_group_dn IN VARCHAR2) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_build_group_user_list';
   VC_HO_CODE       CONSTANT NUMBER(04)   := 8445;

   v_coll_group_display      DBMS_LDAP.STRING_COLLECTION;
   v_coll_group_dn           DBMS_LDAP.STRING_COLLECTION;
   v_coll_search_filter      DBMS_LDAP.STRING_COLLECTION;
   v_coll_return_attrib      DBMS_LDAP.STRING_COLLECTION;
   v_coll_user_dn            com_utils.ADTab;
   v_group_display           VARCHAR2(255);
   v_group_dn                VARCHAR2(255);
   v_group_cnt               NUMBER(01) := 0;
   v_group_idx               NUMBER(01) := 1;
   v_ret_cnt                 NUMBER(04) := 0;
   v_user_dn                 VARCHAR2(255);
   v_username                VARCHAR2(100);
   v_main_school_code        NUMBER(04);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params group_dn='||p_group_dn);

   --MOD:07 pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Create the Apex collection to store LDAP query result');
   APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION (p_collection_name => GC_APX_COLL_GRP_USER);

   IF (p_group_dn IS NOT NULL) THEN
      v_group_display := get_username_from_dn (p_group_dn); --works on Group DN too
      v_group_dn      := p_group_dn;
   ELSE
      --Get all the SWD2 groups
      SELECT c001 group_disp
            ,c002 group_dn
      BULK COLLECT INTO v_coll_group_display
                       ,v_coll_group_dn
      FROM   apex_collections
      WHERE  collection_name = GC_APX_COLL_SWD2_GRP;
      v_group_cnt := v_coll_group_dn.COUNT;
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Group count is '||v_group_cnt);

      v_group_display := v_coll_group_display(v_group_idx);
      v_group_dn      := v_coll_group_dn(v_group_idx);
   END IF;

   <<group_loop>>
   WHILE v_group_dn IS NOT NULL LOOP
      --Prepare AD search criteria and execute search
      v_coll_search_filter(1) := 'distinguishedName='||v_group_dn;
      v_coll_return_attrib(1) := 'member';

      v_coll_user_dn := com_utils.get_attrib_values (
                           p_search_filter_coll => v_coll_search_filter
                          ,p_return_attrib_coll => v_coll_return_attrib
                          ,p_object_class       => 'group');

      v_ret_cnt := v_coll_user_dn(1).attr_val.COUNT;
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Member count is '||v_ret_cnt);

      IF (v_ret_cnt > 0) THEN
         FOR i IN v_coll_user_dn(1).attr_val.FIRST..v_coll_user_dn(1).attr_val.LAST LOOP
            v_user_dn  := v_coll_user_dn(1).attr_val(i);

            --Don't add to collection if user is in Disabled Staff OU.
            CONTINUE WHEN (INSTR(v_user_dn, 'Disabled Staff') > 0);

            v_username := com_utils.get_userPrincipalName (v_user_dn); --MOD:12

            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'user_dn='||v_user_dn||' user='||v_username);

            --Get the school code from the user DN
            IF (INSTR(v_user_dn, 'OU=Head Office,OU=CEWA') > 0) THEN
               v_main_school_code := VC_HO_CODE;
            ELSE
               --look for something like ',OU=8055 L' then substring to just the 4 digits
               v_main_school_code := TO_NUMBER(REGEXP_SUBSTR(REGEXP_SUBSTR(v_user_dn, ',OU=8\d\d\d\s[A-Z]', 1), '8\d\d\d', 1));
            END IF;

            --Don't add to collection if school code cannot be determined.
            CONTINUE WHEN (v_main_school_code IS NULL);

            APEX_COLLECTION.ADD_MEMBER(p_collection_name => GC_APX_COLL_GRP_USER
                                      ,p_c001 => v_username
                                      ,p_c002 => v_user_dn
                                      ,p_c003 => v_group_display
                                      ,p_n001 => v_main_school_code);
         END LOOP;
      END IF;

      IF (p_group_dn IS NOT NULL)
      OR (v_group_idx >= v_group_cnt) THEN
         v_group_dn := NULL;
      ELSE
         v_group_idx     := v_group_idx + 1;
         v_group_display := v_coll_group_display(v_group_idx);
         v_group_dn      := v_coll_group_dn(v_group_idx);
         v_coll_user_dn.DELETE;
      END IF;

   END LOOP group_loop;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_build_group_user_list;


/*****************************************************************************************
 PURPOSE: Build an Apex collection of the staff of a school.
 ****************************************************************************************/
PROCEDURE pr_build_user_list(p_school_id IN swd_application.school_id%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_build_user_list';

   v_coll_user_dn            common.com_utils.LDAPGroupColl;
   v_school_code             NUMBER(04);
   v_username                VARCHAR2(100);
   v_temp_username           VARCHAR2(100); -- MOD:12

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params school_id='||p_school_id);

   v_school_code := get_school_code (p_school_id); --MOD:07

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Get list of staff for school_code='||v_school_code);
   v_coll_user_dn := common.com_utils.get_school_member_list (v_school_code, 'T');

   --MOD:07 pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Create the Apex collection to store LDAP query result');
   APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION (p_collection_name => GC_APX_COLL_STAFF);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Staff count returned is '||v_coll_user_dn.COUNT);
   IF (v_coll_user_dn.COUNT > 0) THEN
      FOR i IN v_coll_user_dn.FIRST..v_coll_user_dn.LAST LOOP
         --> MOD:12 Start
         pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'v_coll_user_dn('||i||') :'||v_coll_user_dn(i));
         v_temp_username := SUBSTR(v_coll_user_dn(i),INSTR(v_coll_user_dn(i),com_utils.gc_concat_str)+LENGTH(com_utils.gc_concat_str));
         v_username := v_temp_username;
         pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'user_dn='||v_coll_user_dn(i)||' username='||v_username);
         APEX_COLLECTION.ADD_MEMBER(p_collection_name => GC_APX_COLL_STAFF
                                   ,p_c001 => v_username
                                   ,p_c002 => SUBSTR(v_coll_user_dn(i),1,INSTR(v_coll_user_dn(i),com_utils.gc_concat_str)-1));
         --< MOD:12 End
      END LOOP;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_build_user_list;


/*****************************************************************************************
 PURPOSE: Modify user access in Active Directory
 ****************************************************************************************/
PROCEDURE pr_assign_user_group(p_user_dn       IN VARCHAR2
                              ,p_original_list IN VARCHAR2
                              ,p_new_list      IN VARCHAR2) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_assign_user_group';

   v_coll_group_diff         common.com_utils.LDAPGroupColl;
   v_coll_user_dn            common.com_utils.LDAPGroupColl;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params original='||p_original_list||
      ' new='||p_new_list);

   assert((INSTR(p_new_list, ':') = 0), 'Only one group may be assigned.', 'Y');

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Determine what has been removed.');
   SELECT *
   BULK COLLECT INTO v_coll_group_diff
   FROM   (SELECT *
           FROM   TABLE(common.com_utils.get_piped_tab_from_delim_var(p_original_list, ':'))
           MINUS
           SELECT *
           FROM   TABLE(common.com_utils.get_piped_tab_from_delim_var(p_new_list, ':'))
          );

   v_coll_user_dn(1) := p_user_dn;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Remove '||v_coll_group_diff.COUNT||' groups.');
   IF (v_coll_group_diff.COUNT > 0) THEN
      --Apply the change
      FOR i IN 1..v_coll_group_diff.COUNT LOOP
         pr_debug (COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'REMOVE group '||v_coll_group_diff(i));
         common.com_utils.pr_ldap_attr_mod (p_dn         => v_coll_group_diff(i)
                                           ,p_attr       => 'member'
                                           ,p_attr_count => 1
                                           ,p_attr_vals  => v_coll_user_dn
                                           ,p_mod_op     => DBMS_LDAP.MOD_DELETE);
      END LOOP;
   END IF;

   --Reinitialise
   v_coll_group_diff.DELETE;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Determine what has been added.');
   SELECT *
   BULK COLLECT INTO v_coll_group_diff
   FROM   (SELECT *
           FROM   TABLE(common.com_utils.get_piped_tab_from_delim_var(p_new_list, ':'))
           MINUS
           SELECT *
           FROM   TABLE(common.com_utils.get_piped_tab_from_delim_var(p_original_list, ':'))
          );

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Add '||v_coll_group_diff.COUNT||' groups.');
   IF (v_coll_group_diff.COUNT > 0) THEN
      --Apply the change
      FOR i IN 1..v_coll_group_diff.COUNT LOOP
         pr_debug (COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'ADD group '||v_coll_group_diff(i));
         common.com_utils.pr_ldap_attr_mod (p_dn         => v_coll_group_diff(i)
                                           ,p_attr       => 'member'
                                           ,p_attr_count => 1
                                           ,p_attr_vals  => v_coll_user_dn
                                           ,p_mod_op     => DBMS_LDAP.MOD_ADD);
      END LOOP;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      pr_show_error (SQLERRM);
END pr_assign_user_group;


/*****************************************************************************************
 PURPOSE: Initialise application items.
 ****************************************************************************************/
PROCEDURE pr_init_app_items IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_init_app_items';
   VC_CE_OFFICE     CONSTANT NUMBER(04)   := 8445;

   v_open_dt                 DATE;
   v_close_dt                DATE;
   v_funding_yr              NUMBER(04);
   v_user_school_code        NUMBER(04);
   v_user_school_codes_all   VARCHAR2(20); --comma-delimited list
   v_user_school_ids_all     VARCHAR2(20); --comma-delimited list
   v_school_ceowa_flg        VARCHAR2(10);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   --Application statuses
   APEX_UTIL.SET_SESSION_STATE('F_APPLSTS_DRAFT',     GC_APPLSTS_DRAFT);
   APEX_UTIL.SET_SESSION_STATE('F_APPLSTS_SUBMIT',    GC_APPLSTS_SUBMIT);
   APEX_UTIL.SET_SESSION_STATE('F_APPLSTS_REVIEWED',  GC_APPLSTS_REVIEWED);
   APEX_UTIL.SET_SESSION_STATE('F_APPLSTS_PRINCAPPR', GC_APPLSTS_PRINCAPPR);
   APEX_UTIL.SET_SESSION_STATE('F_APPLSTS_FUNDAPPR',  GC_APPLSTS_FUNDAPPR);
   APEX_UTIL.SET_SESSION_STATE('F_APPLSTS_NE',        GC_APPLSTS_NE);

   --Default IAP level of adjustment
   APEX_UTIL.SET_SESSION_STATE('F_IAP_LOA_DEFAULT', 'SUPQDTP');

   --Funding application period.  Only one row expected,  not versioned.
   SELECT TO_CHAR(c.eff_from_date, 'DD-Mon-YYYY') appl_open_dt
         ,TO_CHAR(c.eff_to_date, 'DD-Mon-YYYY') appl_close_dt
   INTO   v_open_dt
         ,v_close_dt
   FROM   swd.swd_codes c
   WHERE  c.swd_code_type = 'APPCTRL'
   AND    c.swd_code      = 'OPNCLS';
   APEX_UTIL.SET_SESSION_STATE('F_APPL_DT_OPEN',  v_open_dt);
   APEX_UTIL.SET_SESSION_STATE('F_APPL_DT_CLOSE', v_close_dt);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, ':F_APPL_DT_OPEN='||v_open_dt||' :F_APPL_DT_CLOSE='||v_close_dt);
   APEX_UTIL.SET_SESSION_STATE('F_APPL_ISOPEN', is_swd_app_open);

   APEX_UTIL.SET_SESSION_STATE('F_APPL_CONSULT_RO', is_consultant_read_only); --MOD:07

   v_funding_yr := get_default_funding_year;
   APEX_UTIL.SET_SESSION_STATE('F_FUNDING_YEAR', v_funding_yr);
   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, ':F_FUNDING_YEAR='||v_funding_yr);

   --Is user from a school or the office?
   v_user_school_code := TO_NUMBER(com_utils.get_user_school_code(v('APP_USER'),'S'));
   IF (v_user_school_code = VC_CE_OFFICE) THEN
      v_school_ceowa_flg := 'CEOWA';
   ELSE
      v_school_ceowa_flg := 'SCHOOL';
   END IF;
   APEX_UTIL.SET_SESSION_STATE('F_SCHOOL_CEOWA', v_school_ceowa_flg);
   pr_debug(com_utils.gc_debug_lvl2, VC_SUBPROG_UNIT, ':F_SCHOOL_CEOWA='||v_school_ceowa_flg);

   --Get all schools that the user is associated with.
   v_user_school_codes_all := common.com_utils.get_user_school_code(v('APP_USER'), 'A');
   --Convert rows of school_id to a comma-delimited list.
   SELECT LISTAGG(gs.school_id, ',') WITHIN GROUP (ORDER BY gs.school_id) --MOD:09
   INTO   v_user_school_ids_all
   FROM  (--Convert comma-delimited school code list to rows.
          SELECT REGEXP_SUBSTR(v_user_school_codes_all, '[^,]+', 1, LEVEL) school_code
          FROM   DUAL
          CONNECT BY REGEXP_SUBSTR(v_user_school_codes_all, '[^,]+', 1, LEVEL) IS NOT NULL) b
          INNER JOIN education.school gs        --MOD:09
             ON b.school_code = gs.ceowa_nbr --MOD:09
   WHERE  TRUNC(SYSDATE) BETWEEN gs.eff_from_date AND NVL(gs.eff_to_date, TRUNC(SYSDATE)); --MOD:09
   APEX_UTIL.SET_SESSION_STATE('F_USER_SCHOOL_IDS_ALL', v_user_school_ids_all);

   --Set up Apex collection of SWD2 AD groups
   swd_funding_application.pr_build_swd2_group_list;

   --MOD:07 Initialise collection names
   APEX_UTIL.SET_SESSION_STATE('F_APX_COLL_GROUP_USER',  GC_APX_COLL_GRP_USER);
   APEX_UTIL.SET_SESSION_STATE('F_APX_COLL_ROLLPREV',    GC_APX_COLL_ROLLPREV);
   APEX_UTIL.SET_SESSION_STATE('F_APX_COLL_STAFF',       GC_APX_COLL_STAFF);
   APEX_UTIL.SET_SESSION_STATE('F_APX_COLL_STUDENTS',    GC_APX_COLL_STUDENTS);
   APEX_UTIL.SET_SESSION_STATE('F_APX_COLL_SWD2_GROUPS', GC_APX_COLL_SWD2_GRP);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_init_app_items;


/*****************************************************************************************
 PURPOSE: Build the header at the top of the page for page 10 - Create Application
 ****************************************************************************************/
PROCEDURE print_create_appl_hdr (p_appl_id IN NUMBER
                                ,p_page_id IN NUMBER) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'print_create_appl_hdr';
   VC_SPAN_LABEL    CONSTANT VARCHAR2(50) := '<span class="title_big">';
   VC_SPAN_DATA     CONSTANT VARCHAR2(50) := '<span class="title_big" style="color: #ec6e20;">';
   VC_SPACING       CONSTANT VARCHAR2(50) := '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp';

   v_stu_name                VARCHAR2(120); --MOD:07
   v_appl_sts                VARCHAR2(250);
   v_appl_date               VARCHAR2(20);
   v_related_appl_id         swd_application.related_appl_id%TYPE;
   v_hdr                     VARCHAR2(1000);
   v_inactive_date           swd_application.inactive_date%TYPE; --MOD:07

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   v_hdr := VC_SPAN_LABEL||'Application Id</span> '||VC_SPAN_DATA||p_appl_id||'</span>';

   IF (p_appl_id IS NOT NULL) THEN
      SELECT  a.student_first_name||' '||a.student_surname --MOD:07
             ,get_appl_sts_desc(p_appl_id)
             --MOD:07 ,TO_CHAR(a.created_date, 'DD-Mon-YYYY')
             ,a.related_appl_id
             ,a.inactive_date --MOD:07
      INTO    v_stu_name --MOD:07
             ,v_appl_sts
             --MOD:07 ,v_appl_date
             ,v_related_appl_id
             ,v_inactive_date --MOD:07
      FROM   swd_application a
      WHERE  a.appl_id = p_appl_id;

      v_hdr := v_hdr||
               VC_SPACING||VC_SPAN_LABEL||' Student</span> '||VC_SPAN_DATA||v_stu_name||'</span>'|| --MOD:07
               VC_SPACING||VC_SPAN_LABEL||' Status</span> '||VC_SPAN_DATA||v_appl_sts||'</span>';
               --MOD:07 VC_SPACING||VC_SPAN_LABEL||' Date</span> '  ||VC_SPAN_DATA||v_appl_date||'</span>';

      IF (v_related_appl_id IS NOT NULL) THEN
         v_hdr := v_hdr ||VC_SPACING||VC_SPAN_LABEL||' Related to application</span> '||VC_SPAN_DATA||v_related_appl_id||'</span>';
      END IF;

      --MOD:07
      IF (v_inactive_date IS NOT NULL) THEN
         v_hdr := v_hdr||VC_SPACING||VC_SPACING||'<span class="title_big blink_me" style="color: #ec6e20;">INACTIVE</span>';
      END IF;

   ELSE
      v_hdr := v_hdr||VC_SPACING||VC_SPAN_LABEL||' Status</span> '||VC_SPAN_DATA||'Draft</span>';
   END IF;

   htp.p(v_hdr);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      APEX_UTIL.CLEAR_PAGE_CACHE (p_page_id);

END print_create_appl_hdr;


/*****************************************************************************************
 PURPOSE: 'Page 10 - Create Application' has various sections that can be amended at
    different stages by different user roles.  Determine the status for the sections.
 ****************************************************************************************/
PROCEDURE pr_decide_upd_access_p10 (
   p_appl_id            IN     NUMBER
  ,p_username           IN     VARCHAR2
  ,p_upd_body_flg          OUT VARCHAR2
  ,p_upd_appl_sts_flg      OUT VARCHAR2
  ,p_upd_disabl_pts_flg    OUT VARCHAR2) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_decide_upd_access_p10';

   e_new_appl                EXCEPTION;
   e_superseded_appl         EXCEPTION;
   e_inactive_appl           EXCEPTION; --MOD:07

   v_appl_period_open_flg    VARCHAR2(01) := 'N';
   v_appl_consult_ro_flg     VARCHAR2(01) := 'Y'; --MOD:05
   v_appl_princ_ro_flg       VARCHAR2(01) := 'Y'; --MOD:07
   v_appl_revised_flg        VARCHAR2(01) := 'N';
   v_own_school_flg          VARCHAR2(01) := 'N';
   v_appl_sts                swd_appl_status.status_code%TYPE;
   v_appl_school_id          swd_application.school_id%TYPE;
   v_text                    VARCHAR2(200);
   v_upd_body_flg            VARCHAR2(01) := 'N';
   v_upd_appl_sts_flg        VARCHAR2(01) := 'N';
   v_upd_disabl_pts_flg      VARCHAR2(01) := 'N';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   pr_debug(com_utils.gc_debug_lvl2, VC_SUBPROG_UNIT, 'Initialise outbound parameters and internal flags.');
   p_upd_body_flg         := 'N';
   p_upd_appl_sts_flg     := 'N';
   p_upd_disabl_pts_flg   := 'N';
   v_appl_period_open_flg := is_swd_app_open;
   v_appl_consult_ro_flg  := is_consultant_read_only; --MOD:05
   v_appl_princ_ro_flg    := is_principal_read_only;  --MOD:07

   --MOD:03 Start
   IF (p_appl_id IS NULL) THEN
      IF  (v_appl_period_open_flg = 'N')
      AND (   (v('F_AUTH_TEACHER')   = 'Y')
           OR (v('F_AUTH_PRINCIPAL') = 'Y')
           OR (v_appl_consult_ro_flg = 'Y')) THEN --MOD:05
         NULL; --Use initialised values
      ELSE
         v_text := 'Null appl_id so must be a new application and period is open. Set all update flags to Y.';
         p_upd_body_flg       := 'Y';
         p_upd_appl_sts_flg   := 'Y';
         p_upd_disabl_pts_flg := 'Y';
      END IF;

      RAISE e_new_appl;
   END IF;
   --MOD:03 End

   v_appl_revised_flg := appl_been_revised (p_appl_id);
   --MOD:07 Moved from after is_user_school check.
   IF (v_appl_revised_flg = 'Y') THEN
      v_text := 'Application has been superseded by a revision. No amendment permitted.';
      RAISE e_superseded_appl;
   END IF;

   --MOD:07
   IF (get_inactive_date(p_appl_id) IS NOT NULL) THEN
      v_text := 'Application is inactive. No amendment permitted.';
      RAISE e_inactive_appl;
   END IF;

   v_appl_sts := get_appl_sts (p_appl_id);

   SELECT a.school_id
   INTO   v_appl_school_id
   FROM   swd_application a
   WHERE  a.appl_id = p_appl_id;

   v_own_school_flg := is_user_school (p_username, v_appl_school_id);

   pr_debug(com_utils.gc_debug_lvl2, VC_SUBPROG_UNIT, 'Determine which sections may be updated.');
   IF (v('F_AUTH_TEACHER') = 'Y')  THEN
      v_text := 'User is Teacher. ';
      IF  (v_appl_period_open_flg = 'Y')
      AND (v_own_school_flg       = 'Y')
      AND (v_appl_sts = GC_APPLSTS_DRAFT) THEN
         v_upd_body_flg     := 'Y';
         v_upd_appl_sts_flg := 'Y';
      END IF;

   ELSIF (v('F_AUTH_PRINCIPAL') = 'Y') THEN
      v_text := 'User is Principal. ';
      --MOD:07
      IF (v_own_school_flg = 'Y') THEN
         IF (v_appl_princ_ro_flg = 'N') THEN
            IF (v_appl_sts = GC_APPLSTS_DRAFT) THEN
               v_upd_body_flg     := 'Y';
               v_upd_appl_sts_flg := 'Y';

            ELSIF (v_appl_sts = GC_APPLSTS_REVIEWED) THEN
               v_upd_appl_sts_flg := 'Y';
            END IF;
         END IF;
      END IF;

   ELSIF (v('F_AUTH_CONSULT') = 'Y') THEN
      v_text := 'User is SWD Consultant. ';
      --MOD:05 Only need to check further if it is NOT read-only.
      IF (v_appl_consult_ro_flg = 'N') THEN
         IF  (v_own_school_flg = 'Y')
         AND (v_appl_sts IN (GC_APPLSTS_DRAFT, GC_APPLSTS_SUBMIT)) THEN
            v_upd_body_flg     := 'Y';
            v_upd_appl_sts_flg := 'Y';

         ELSIF (v_own_school_flg = 'N')
         AND   (v_appl_sts = GC_APPLSTS_PRINCAPPR) THEN
            v_upd_appl_sts_flg   := 'Y';
            v_upd_disabl_pts_flg := 'Y';
         END IF;
      END IF; --MOD:05

   ELSIF (v('F_AUTH_ADMIN') = 'Y') THEN
      v_text := 'User is SWD Admin. ';
      IF (v_appl_sts IN (GC_APPLSTS_DRAFT, GC_APPLSTS_SUBMIT)) THEN
         v_upd_body_flg       := 'Y';
         v_upd_appl_sts_flg   := 'Y';
         v_upd_disabl_pts_flg := 'Y';

      ELSIF (v_appl_sts IN (GC_APPLSTS_REVIEWED, GC_APPLSTS_PRINCAPPR)) THEN
         v_upd_appl_sts_flg   := 'Y';
         v_upd_disabl_pts_flg := 'Y';
      END IF;
   END IF;

   --Set outbound parameters.
   p_upd_body_flg       := v_upd_body_flg;
   p_upd_appl_sts_flg   := v_upd_appl_sts_flg;
   p_upd_disabl_pts_flg := v_upd_disabl_pts_flg;

   pr_debug(com_utils.gc_debug_lvl2, VC_SUBPROG_UNIT, v_text||'upd_body='||v_upd_body_flg||
      ' upd_appl_sts='||v_upd_appl_sts_flg||' upd_disabl_pts='||v_upd_disabl_pts_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_new_appl
   OR   e_superseded_appl
   OR   e_inactive_appl   THEN  --MOD:07
      pr_debug(com_utils.gc_debug_lvl2, VC_SUBPROG_UNIT, v_text);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   WHEN NO_DATA_FOUND THEN
      pr_debug(com_utils.gc_debug_lvl2, VC_SUBPROG_UNIT, 'Application not found.  Set all update flags to N.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_decide_upd_access_p10;


/*****************************************************************************************
 MOD:07
 Purpose: Log email details or error details when attempting to email notifications.
    If a previous email attempt encountered error, the log of the error will be overwritten.
    Otherwise, a new record will be created.
 ****************************************************************************************/
PROCEDURE pr_maintain_notif_log (
   p_notif_type     IN swd_notification_log.notif_type%TYPE
  ,p_src            IN swd_notification_log.notif_source%TYPE
  ,p_src_rec_id_num IN swd_notification_log.source_rec_id_num%TYPE DEFAULT NULL
  ,p_src_rec_id_chr IN swd_notification_log.source_rec_id_chr%TYPE DEFAULT NULL
  ,p_src_rec_id_col IN swd_notification_log.source_rec_id_col%TYPE
  ,p_notif_rcpts    IN swd_notification_log.notif_recipients%TYPE  DEFAULT NULL
  ,p_notif_comment  IN swd_notification_log.notif_comment%TYPE     DEFAULT NULL
  ,p_err_text       IN swd_notification_log.err_text%TYPE          DEFAULT NULL) IS

   PRAGMA AUTONOMOUS_TRANSACTION;

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maintain_notif_log';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params type='||p_notif_type||' src='||
      p_src||' src_rec_id_num='||p_src_rec_id_num||' src_rec_id_chr='||p_src_rec_id_chr||
      ' src_col='||p_src_rec_id_col||' recipients='||p_notif_rcpts||' comment(100)='||
      SUBSTR(p_notif_comment, 1, 100)||' err_text(100)='||SUBSTR(p_err_text, 1, 100));

   MERGE INTO swd_notification_log dest
   USING (SELECT UPPER(p_notif_type)     notif_type
                ,UPPER(p_src)            notif_src
                ,p_src_rec_id_num        src_rec_id_num
                ,p_src_rec_id_chr        src_rec_id_chr
                ,UPPER(p_src_rec_id_col) src_rec_id_col
                ,p_notif_rcpts           notif_rcpts
                ,p_notif_comment         notif_comment
                ,NVL2(p_err_text, SYSDATE, NULL) err_date
                ,p_err_text              err_text
           FROM  DUAL) data
   ON (    dest.notif_type   = data.notif_type
       AND dest.notif_source = data.notif_src
       AND (   dest.source_rec_id_num = data.src_rec_id_num
            OR dest.source_rec_id_chr = data.src_rec_id_chr
           )
       AND dest.source_rec_id_col = data.src_rec_id_col
       AND dest.notif_date IS NULL
      )
   WHEN MATCHED THEN
      UPDATE SET
         dest.notif_recipients = data.notif_rcpts
        ,dest.notif_comment    = data.notif_comment
        ,dest.err_date         = data.err_date
        ,dest.err_text         = data.err_text
   WHEN NOT MATCHED THEN
      INSERT (dest.notif_type
             ,dest.notif_source
             ,dest.source_rec_id_num
             ,dest.source_rec_id_chr
             ,dest.source_rec_id_col
             ,dest.notif_recipients
             ,dest.notif_comment
             ,dest.err_date
             ,dest.err_text)
      VALUES (data.notif_type
             ,data.notif_src
             ,data.src_rec_id_num
             ,data.src_rec_id_chr
             ,data.src_rec_id_col
             ,data.notif_rcpts
             ,data.notif_comment
             ,data.err_date
             ,data.err_text);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

   COMMIT;

END pr_maintain_notif_log;


/*****************************************************************************************
 MOD:07
 PURPOSE: Flag the current and future funding applications found for students in
    INTERFACE.STUDENT_MIM_DEACTIVATED as inactive, generate notifications for them and
    log the notifications.

    NB: Initially, SWD Consultants were to be emailed the deactivation notification but
        this was later cancelled in favour of an on-demand report in SWD2. However,
        code is left in place in case this changes.
 ****************************************************************************************/
PROCEDURE pr_notify_deactivated_appl IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_notify_deactivated_appl';

   TYPE NotifRecTyp IS RECORD (
      appl_id                swd_application.appl_id%TYPE
     ,consult_email          VARCHAR2(100)
     ,ssn                    swd_application.state_student_nbr%TYPE
   );
   TYPE NotifTab IS TABLE OF NotifRecTyp;

   v_coll_notif              NotifTab := NotifTab();
   v_prev_consultant         VARCHAR2(10) := 'NULL';
   v_consultant_email        VARCHAR2(100);
   v_email_hdr               VARCHAR2(500);
   v_email_body              VARCHAR2(3000);
   v_email_close             VARCHAR2(500);
   v_email_sender            swd_codes.short_description%TYPE;
   v_email_subject           swd_codes.short_description%TYPE;

   --!!Note!! ORDER BY clause matters for email consolidation by consultant.
   CURSOR c_deactivated IS
      SELECT  c.consult_emp_code   consult_emp_code
             ,c.consult_pref_name  consult_pref_name
             ,c.school_code        school_code
             ,c.school_name||', '||c.school_suburb school_name
             ,a.appl_id            appl_id
             ,a.funding_year       fund_year
             ,a.state_student_nbr  ssn
             ,a.student_first_name||' '||a.student_surname student_name
             ,a.funding_school_lvl fund_sch_lvl
             ,get_appl_sts_desc(a.appl_id)    appl_status
             ,TO_CHAR(SYSDATE, 'DD-MON-YYYY') inactive_date
      FROM  (SELECT DISTINCT wasn
             FROM   interface.student_mim_deactivated
             WHERE  excl_notif_ind = 'N'
             AND    notified_ind   = 'N'
            ) smd
             INNER JOIN swd_application a
                ON  smd.wasn = a.state_student_nbr
             INNER JOIN (SELECT gs.school_id         school_id         --MOD:09
                               ,gs.ceowa_nbr         school_code       --MOD:09
                               ,gs.school_name       school_name
                               ,gs.street_suburb     school_suburb
                               ,sc.employee#         consult_emp_code  --MOD:09
                               ,u.preferred_name     consult_pref_name --MOD:09
                               ,u.surname            consult_surname   --MOD:09
                         FROM   swd_consultant_school sc               --MOD:09
                                INNER JOIN education.school_profile_v gs
                                   ON  sc.school_id = gs.school_id
                                   AND TRUNC(SYSDATE) BETWEEN sc.eff_from_date AND NVL(sc.eff_to_date, TRUNC(SYSDATE)) --MOD:09
                                INNER JOIN education.employee_v u      --MOD:09
                                   ON  sc.employee# = u.employee#
                        ) c
                ON a.school_id = c.school_id
      WHERE  a.delete_date   IS NULL
      AND    a.inactive_date IS NULL
      AND    a.funding_year >= EXTRACT(YEAR FROM SYSDATE)
      AND    appl_been_revised (a.appl_id) = 'N'
      --> MOD:14 - Exclude Non dioscesan schools
      AND    a.school_id NOT IN (SELECT school_id
                                 FROM swd_nds_schools_v)
      --< MOD:14
      ORDER BY c.consult_emp_code, c.school_name, c.school_suburb, a.student_surname, a.student_first_name, a.funding_year;

   /**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
   PROCEDURE pr_close_and_send_email (p_email_sender     IN VARCHAR2
                                     ,p_consultant_email IN VARCHAR2
                                     ,p_email_subject    IN VARCHAR2
                                     ,p_email_content    IN VARCHAR2) IS

   BEGIN
      common.com_network_utils.pr_send_mail (p_sender     => p_email_sender
                                            ,p_recipients => p_consultant_email
                                            ,p_cc         => NULL
                                            ,p_subject    => p_email_subject
                                            ,p_body_text  => p_email_content
                                            ,p_mime_type  => 'text/html; charset="UTF-8"');

   END pr_close_and_send_email;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   --Set up email values.
   v_email_sender  := get_code_desc ('EMAIL', 'SENDER');
   v_email_subject := get_code_desc ('EMAIL', 'DEACTV_SUBJECT');
   v_email_hdr     := '
<html>
<head>
<style>
   #applications {
      font-family: Calibri, Arial, Helvetica, sans-serif;
      border-collapse: collapse;
      width: 80%;
   }

   #applications th {
      padding-top: 12px;
      padding-bottom: 12px;
      text-align: left;
      background-color: #3366ff;
      color: white;
   }

   #applications td, #applications th {
      border: 1px solid #ddd;
      padding: 8px;
   }
</style>
</head>';
   v_email_close   := '
</table><br><br>
Regards<br>
SWD2
</body></html>';

   FOR r IN c_deactivated
   LOOP
      pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Consultant='||r.consult_emp_code);

      IF (r.consult_emp_code <> v_prev_consultant) THEN
         pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'New consultant');

         IF (v_consultant_email IS NOT NULL) THEN
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, '     Close and send previous email');
            pr_close_and_send_email (v_email_sender, v_consultant_email, v_email_subject
                                    ,v_email_hdr || v_email_body || v_email_close);
         END IF;

         v_consultant_email := com_utils.get_email(com_utils.get_userprincipalnamefor_empno(r.consult_emp_code));--MOD:15
         pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, '     New consultant email is '||v_consultant_email);

         --Format email table header
         v_email_body := '
<body>
Hello '||r.consult_pref_name||'<br>

<p>The following applications have been deactivated due to student departure(s).</p>
<table id="applications">
   <tr>
      <th>School Code</th>
      <th>School Name</th>
      <th>Appl. Id</th>
      <th>Fund. Year</th>
      <th>WASN</th>
      <th>Student</th>
      <th>Funded School Lvl</th>
      <th>Status</th>
      <th>Inactive Date</th>
   </tr>';
      END IF;

      IF (v_consultant_email IS NOT NULL) THEN
         --Format email table data
         v_email_body := v_email_body||'
   <tr>
      <td>'||r.school_code||'</td>
      <td>'||r.school_name||'</td>
      <td>'||r.appl_id||'</td>
      <td>'||r.fund_year||'</td>
      <td>'||r.ssn||'</td>
      <td>'||r.student_name||'</td>
      <td>'||r.fund_sch_lvl||'</td>
      <td>'||r.appl_status||'</td>
      <td>'||r.inactive_date||'</td>
   </tr>';

         --Collect data for deactivation and logging notification.
         v_coll_notif.EXTEND;
         v_coll_notif(v_coll_notif.LAST).appl_id       := r.appl_id;
         v_coll_notif(v_coll_notif.LAST).consult_email := v_consultant_email;
         v_coll_notif(v_coll_notif.LAST).ssn           := r.ssn;

      ELSE
         pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Log missing email');
         pr_maintain_notif_log (
            p_notif_type     => 'DEACTIVATEAPPL'
           ,p_src            => 'SWD_APPLICATION'
           ,p_src_rec_id_num => r.appl_id
           ,p_src_rec_id_chr => NULL
           ,p_src_rec_id_col => 'APPL_ID'
           ,p_notif_rcpts    => NULL
           ,p_notif_comment  => NULL
           ,p_err_text       => 'Email address not found for application id '||r.appl_id||
               ' WASN '||r.ssn||' consultant '||r.consult_pref_name||' ('||r.consult_emp_code||')');
      END IF;

      v_prev_consultant := r.consult_emp_code;
   END LOOP;

   --Close and send email
   IF (v_consultant_email IS NOT NULL) THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, '     Close and send email');
      pr_close_and_send_email (v_email_sender, v_consultant_email, v_email_subject
                              ,v_email_hdr || v_email_body || v_email_close);
   END IF;

   IF (v_coll_notif.COUNT > 0) THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Log notifications');
      FORALL i IN v_coll_notif.FIRST..v_coll_notif.LAST
         INSERT INTO swd_notification_log n (
            n.notif_type
           ,n.notif_source
           ,n.source_rec_id_num
           ,n.source_rec_id_col
           ,n.notif_date
           ,n.notif_recipients
           ,n.notif_comment)
         VALUES (
            'DEACTIVATEAPPL'
           ,'SWD_APPLICATION'
           ,v_coll_notif(i).appl_id
           ,'APPL_ID'
           ,SYSDATE
           ,v_coll_notif(i).consult_email
           ,'WASN='||v_coll_notif(i).ssn);

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Flag notified');
      FORALL i IN v_coll_notif.FIRST..v_coll_notif.LAST
         UPDATE interface.student_mim_deactivated d
         SET    d.notified_ind = 'Y'
         WHERE  d.wasn           = v_coll_notif(i).ssn
         AND    d.excl_notif_ind = 'N'
         AND    d.notified_ind   = 'N';

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Deactivate applications');
      FORALL i IN v_coll_notif.FIRST..v_coll_notif.LAST
         UPDATE swd_application a
         SET    a.inactive_date = TRUNC(SYSDATE)
         WHERE  a.appl_id = v_coll_notif(i).appl_id;
   END IF;

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_notify_deactivated_appl;


/*****************************************************************************************
 MOD:07
 PURPOSE: Flag the current and future funding applications found for students in
    INTERFACE.STUDENT_MIM_DEACTIVATED as inactive.
 ****************************************************************************************/
PROCEDURE pr_deactivate_appl IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_deactivate_appl';

   TYPE DeactivateRecTyp IS RECORD (
      appl_id                swd_application.appl_id%TYPE
     ,ssn                    swd_application.state_student_nbr%TYPE
     ,inactive_date          swd_application.inactive_date%TYPE
   );
   TYPE DeactivateTab IS TABLE OF DeactivateRecTyp;

   v_coll_appl               DeactivateTab := DeactivateTab();

   CURSOR c_deactivated IS
      SELECT  a.appl_id            appl_id
             ,a.state_student_nbr  ssn
             ,TO_CHAR(SYSDATE, 'DD-MON-YYYY') inactive_date
      FROM  (SELECT DISTINCT wasn
             FROM   interface.student_mim_deactivated
             WHERE  excl_notif_ind = 'N'
             AND    notified_ind   = 'N'
            ) smd
             INNER JOIN swd_application a
                ON  smd.wasn = a.state_student_nbr
      WHERE  a.delete_date   IS NULL
      AND    a.inactive_date IS NULL
      AND    a.funding_year >= EXTRACT(YEAR FROM SYSDATE)
      --> MOD:14 - Exclude Non dioscesan schools
      AND    a.school_id NOT IN (SELECT school_id
                                 FROM swd_nds_schools_v);
      --< MOD:14

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   OPEN  c_deactivated;
   FETCH c_deactivated
   BULK COLLECT INTO v_coll_appl; --no more than 100 expected
   CLOSE c_deactivated;

   IF (v_coll_appl.COUNT > 0) THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Flag processed');
      FORALL i IN v_coll_appl.FIRST..v_coll_appl.LAST
         UPDATE interface.student_mim_deactivated d
         SET    d.notified_ind = 'Y'
         WHERE  d.wasn           = v_coll_appl(i).ssn
         AND    d.excl_notif_ind = 'N'
         AND    d.notified_ind   = 'N';

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Deactivate applications');
      FORALL i IN v_coll_appl.FIRST..v_coll_appl.LAST
         UPDATE swd_application a
         SET    a.inactive_date = v_coll_appl(i).inactive_date
         WHERE  a.appl_id = v_coll_appl(i).appl_id;
   END IF;

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_deactivate_appl;


/*****************************************************************************************
 MOD:07
 PURPOSE: Maintain document uploads.
 ****************************************************************************************/
PROCEDURE pr_maintain_appl_doc (p_doc_id          IN swd_document.doc_id%TYPE
                               ,p_unique_doc_name IN swd_document.unique_doc_name%TYPE
                               ,p_doc_comment     IN swd_document.doc_comment%TYPE     DEFAULT NULL
                               ,p_appl_id         IN swd_appl_document.appl_id%TYPE
                               ,p_delete_date     IN swd_document.delete_date%TYPE
                               ,p_doc_hide_date   IN swd_appl_document.doc_hide_date%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maintain_appl_doc';

   v_doc_id                  swd_document.doc_id%TYPE;

   CURSOR c_appl_doc(cp_doc_name IN swd_document.unique_doc_name%TYPE) IS
      SELECT LOWER(af.name)      unique_doc_name
            ,af.filename         filename
            ,af.mime_type        mime_type
            ,af.blob_content     the_blob
            ,DBMS_LOB.GETLENGTH(af.blob_content)   the_blob_size
      FROM   apex_application_temp_files af
      WHERE  af.name   = cp_doc_name;

   v_appl_doc_rec            c_appl_doc%ROWTYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL1, VC_SUBPROG_UNIT, 'Parameters are doc_id='||p_doc_id||
      ' unique_doc_name='||p_unique_doc_name||' appl_id='||p_appl_id||' delete_date='||
      TO_CHAR(p_delete_date,'DD-MON-YYYY')||' hide_date='||TO_CHAR(p_doc_hide_date,'DD-MON-YYYY'));

   v_doc_id := p_doc_id;

   IF  (p_doc_id IS NOT NULL)
   AND (p_delete_date IS NOT NULL) THEN
      UPDATE swd_document dest
      SET    dest.delete_date = p_delete_date
      WHERE  dest.doc_id = v_doc_id;

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Updated delete date');

   ELSIF (p_doc_id IS NOT NULL)
   AND   (p_doc_hide_date IS NOT NULL) THEN
      INSERT INTO swd_appl_document dest (
         dest.appl_id
        ,dest.doc_id
        ,dest.doc_hide_date)
      VALUES (
         p_appl_id
        ,p_doc_id
        ,TRUNC(p_doc_hide_date));

      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Inserted hide date');

   ELSE
      OPEN  c_appl_doc (p_unique_doc_name);
      FETCH c_appl_doc
      INTO  v_appl_doc_rec;
      CLOSE c_appl_doc;

      INSERT INTO swd_document dest (
         dest.unique_doc_name
        ,dest.filename
        ,dest.mime_type
        ,dest.blob_content
        ,dest.blob_size
        ,dest.doc_comment
        ,dest.delete_date)
      VALUES (
         v_appl_doc_rec.unique_doc_name
        ,v_appl_doc_rec.filename
        ,v_appl_doc_rec.mime_type
        ,v_appl_doc_rec.the_blob
        ,v_appl_doc_rec.the_blob_size
        ,p_doc_comment
        ,NULL)
      RETURNING dest.doc_id
      INTO v_doc_id;
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Inserted record. Doc_id='||v_doc_id);

      INSERT INTO swd_appl_document ad (
         ad.appl_id
        ,ad.doc_id
        ,ad.doc_hide_date)
      VALUES (
         p_appl_id
        ,v_doc_id
        ,p_doc_hide_date);
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_maintain_appl_doc;


/*****************************************************************************************
 MOD:07
 PURPOSE: Log document access.
 ****************************************************************************************/
PROCEDURE pr_log_document_access (p_doc_id   IN swd_doc_access_log.doc_id%TYPE
                                 ,p_user     IN swd_doc_access_log.accessed_by%TYPE) IS
   PRAGMA AUTONOMOUS_TRANSACTION;

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_log_document_access';

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL1, VC_SUBPROG_UNIT, 'AUTONOMOUS TRNXN. Parameters are doc_id='||
      p_doc_id||' user='||p_user);

   INSERT INTO swd_doc_access_log dal (
      dal.doc_id
     ,dal.accessed_by
     ,dal.accessed_date)
   VALUES (
      p_doc_id
     ,p_user
     ,SYSDATE);

   COMMIT;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_log_document_access;


/*****************************************************************************************
 MOD:07
 PURPOSE: Send reminder to principals to approve applications.
 ****************************************************************************************/
PROCEDURE pr_notify_principal (p_funding_year   IN swd_application.funding_year%TYPE
                              ,p_school_id      IN swd_application.school_id%TYPE
                              ,p_app_count      IN NUMBER) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_notify_principal';

   e_invalid_principal_info  EXCEPTION;

   v_school_code             NUMBER(04);
   v_email_hdr               VARCHAR2(500);
   v_email_body              VARCHAR2(3000);
   v_email_sender            swd_codes.short_description%TYPE;
   v_email_subject           swd_codes.short_description%TYPE;

   CURSOR c_principal_det (cp_school_code IN NUMBER) IS
      SELECT sd.principal_title||' '||sd.principal_name principal_name --MOD:09
            ,sd.principal_email
            ,'There '||DECODE(p_app_count, 1, 'is ', 'are ')||p_app_count||
             ' Students with Disability School Support Program '||DECODE(p_app_count, 1, 'Application ', 'Applications ')||
             'awaiting your approval. ' apprv_text
      FROM   education.school sd --MOD:09
      WHERE  sd.ceowa_nbr = cp_school_code;
BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL1, VC_SUBPROG_UNIT, 'Parameters are fund_yr='||p_funding_year||
      ' school_id='||p_school_id||' app_cnt='||p_app_count);

   --Set up email values
   v_email_sender  := get_code_desc('EMAIL', 'SENDER');
   v_email_subject := get_code_desc('EMAIL', 'PRINCAPPRV_SUBJECT');

   v_school_code := get_school_code(p_school_id);

   FOR r IN c_principal_det (v_school_code)
   LOOP
      IF r.principal_name  IS NULL
      OR r.principal_email IS NULL THEN
         RAISE e_invalid_principal_info;
      END IF;

      v_email_hdr  := '<html><head></head>';

      v_email_body :=
'<body>
<p>Hello '||r.principal_name||'</p>'||

'<p>'||r.apprv_text||' Please log into <a href="https://home.cewa.edu.au/">CEWA Home</a> and click on the Students with Disability tile
to review and approve the application(s).</p>'||

'<p>Thank you.</p><br>'||

'<p>Kind regards<br>
The Students with Disability Team</p>
</body></html>';

      common.com_network_utils.pr_send_mail (p_sender     => v_email_sender
                                            ,p_recipients => r.principal_email
                                            ,p_cc         => NULL
                                            ,p_subject    => v_email_subject
                                            ,p_body_text  => v_email_body
                                            ,p_mime_type  => 'text/html; charset="UTF-8"');
      pr_maintain_notif_log (p_notif_type     => 'REMINDPRINC'
                            ,p_src            => 'SWD_APPLICATION'
                            ,p_src_rec_id_num => p_school_id
                            ,p_src_rec_id_col => 'school_id'
                            ,p_notif_rcpts    => r.principal_email
                            ,p_notif_comment  => 'funding_year = '||p_funding_year);
   END LOOP;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_invalid_principal_info THEN
      pr_maintain_notif_log (p_notif_type     => 'REMINDPRINC'
                            ,p_src            => 'SWD_APPLICATION'
                            ,p_src_rec_id_num => p_school_id
                            ,p_src_rec_id_col => 'school_id'
                            ,p_notif_comment  => 'funding_year = '||p_funding_year
                            ,p_err_text       => 'Incomplete principal information.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

   WHEN OTHERS THEN
      pr_maintain_notif_log (p_notif_type     => 'REMINDPRINC'
                            ,p_src            => 'SWD_APPLICATION'
                            ,p_src_rec_id_num => p_school_id
                            ,p_src_rec_id_col => 'school_id'
                            ,p_notif_comment  => 'funding_year = '||p_funding_year
                            ,p_err_text       => 'Unable to send reminder to principal. '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_notify_principal;


/*****************************************************************************************
 MOD:07
 PURPOSE: Initialise school name and school id page items.
 ****************************************************************************************/
PROCEDURE pr_init_p1_items IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30)  := 'pr_init_p1_items';
   VC_PART_ITM_NAME CONSTANT VARCHAR2(20)  := 'P1_SCHOOL';

   v_item_name               VARCHAR2(50);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   APEX_UTIL.SET_SESSION_STATE ('P1_FUNDING_YEAR', v('F_FUNDING_YEAR'));

   FOR r IN (SELECT s.school_id  school_id   --MOD:09
                   ,s.ceowa_nbr  school_code --MOD:09
                   ,s.school_name||NVL2(sadr.suburb, ', '||sadr.suburb, NULL)||' ['||s.ceowa_nbr||']'  school_name_suburb
             FROM   education.school s --MOD:09
                    LEFT JOIN education.school_address sadr --MOD:09
                       ON  s.school_id = sadr.school_id     --MOD:09
                       AND sadr.main_addr_flg = 'Y'         --MOD:09
                       AND TRUNC(SYSDATE) BETWEEN sadr.eff_from_date AND NVL(sadr.eff_to_date, TRUNC(SYSDATE)) --MOD:09
             WHERE  TRUNC(SYSDATE) BETWEEN s.eff_from_date AND NVL(s.eff_to_date, TRUNC(SYSDATE))) --MOD:09
   LOOP
      v_item_name := VC_PART_ITM_NAME||'_NAME_'||r.school_code;
      IF APEX_CUSTOM_AUTH.APPLICATION_PAGE_ITEM_EXISTS(v_item_name) THEN
         APEX_UTIL.SET_SESSION_STATE (v_item_name, r.school_name_suburb);
      END IF;

      v_item_name := VC_PART_ITM_NAME||'_ID_'||r.school_code;
      IF APEX_CUSTOM_AUTH.APPLICATION_PAGE_ITEM_EXISTS(v_item_name) THEN
         APEX_UTIL.SET_SESSION_STATE (v_item_name, r.school_id);
      END IF;
   END LOOP;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;

END pr_init_p1_items;


/*****************************************************************************************
 MOD:07
 PURPOSE: Build and return the query for use by charts on the landing page.
 ****************************************************************************************/
FUNCTION get_school_appl_overview_qry (p_itm_funding_year IN VARCHAR2
                                      ,p_itm_school_id    IN VARCHAR2)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30)  := 'get_school_appl_overview_qry';
   VC_VALID_CHARS   CONSTANT VARCHAR2(100) := '-_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

   e_invalid_input           EXCEPTION;

   v_itm_funding_year        VARCHAR2(50) := UPPER(p_itm_funding_year);
   v_itm_school_id           VARCHAR2(50) := UPPER(p_itm_school_id);
   v_sql                     VARCHAR2(4000);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL1, VC_SUBPROG_UNIT, 'Parameters are funding year item name='
      ||p_itm_funding_year||' school id item name='||p_itm_school_id);

   --Verify input is clean.
   IF (TRANSLATE(v_itm_funding_year, VC_VALID_CHARS, '-') IS NOT NULL)
   OR (TRANSLATE(v_itm_school_id, VC_VALID_CHARS, '-') IS NOT NULL) THEN
      RAISE e_invalid_input;
   END IF;

   --Build query
   v_sql :=
   q'[SELECT aso.funding_year    funding_year
            ,aso.school_id       school_id
            ,aso.appl_sts        appl_sts
            ,c.short_description appl_sts_desc
            ,aso.appl_sts_cnt    appl_sts_cnt
            ,DECODE(aso.appl_sts
                   ,'DRAFT',     '#e85d88'
                   ,'SUBMIT',    '#5ea3e8'
                   ,'REVIEWED',  '#e8a35e'
                   ,'PRINCAPPR', '#e8e85e'
                   ,'FUNDAPPR',  '#97c639'
                   ,'NE',        '#a3a3a3') sts_colour
      FROM   swd_appl_status_overview_mv aso
             INNER JOIN swd_codes c
                ON  aso.appl_sts    = c.swd_code
                AND c.swd_code_type = 'APPLSTS'
      WHERE  aso.funding_year = :]'||v_itm_funding_year||
    ' AND    aso.school_id    = NVL(:'||v_itm_school_id||', aso.school_id)'||
   q'[--Restrict data visibility
      AND   (   (     :F_SCHOOL_CEOWA = 'SCHOOL'
                  AND aso.school_id IN (SELECT REGEXP_SUBSTR(:F_USER_SCHOOL_IDS_ALL, '[^,]+', 1, LEVEL)
                                        FROM   DUAL
                                        CONNECT BY REGEXP_SUBSTR(:F_USER_SCHOOL_IDS_ALL, '[^,]+', 1, LEVEL) IS NOT NULL))
             OR (:F_SCHOOL_CEOWA = 'CEOWA')
            )
      ORDER BY aso.funding_year, aso.school_id, c.sort_order DESC;]';

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, v_sql);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_sql;

EXCEPTION
   WHEN e_invalid_input THEN
      pr_show_error ('Invalid character found in input.');
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Invalid character found in input.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;

END get_school_appl_overview_qry;


/*****************************************************************************************
 MOD:09
 PURPOSE: Transfer a school from one consultant to another.
 ****************************************************************************************/
PROCEDURE pr_transfer_consult_school (
   p_consult_school_id IN swd_consultant_school.consult_school_id%TYPE
  ,p_to_emp_nbr        IN swd_consultant_school.employee#%TYPE
  ,p_new_from_date     IN swd_consultant_school.eff_from_date%TYPE) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_transfer_consult_school';

   e_invalid_date            EXCEPTION;

   v_old_end_date            DATE;
   v_invalid_date_flg        VARCHAR2(01);
   v_school_name             VARCHAR2(100);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params consult_school_id='||
      p_consult_school_id||' to_emp_nbr='||p_to_emp_nbr||' new_from_date='||p_new_from_date);

   v_old_end_date := p_new_from_date - 1;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'End-date consult_school_id='||
      p_consult_school_id||' with '||TO_CHAR(v_old_end_date, 'DD-MON-YYYY'));
   SELECT CASE
          WHEN (eff_from_date > v_old_end_date) THEN
             'Y'
          ELSE
             'N'
          END    date_valid_flg
         ,education.edu_utils.get_school_name_frm_id(school_id) school_name
   INTO   v_invalid_date_flg
         ,v_school_name
   FROM   swd_consultant_school
   WHERE  consult_school_id = p_consult_school_id;

   IF (v_invalid_date_flg = 'Y') THEN
      RAISE e_invalid_date;
   END IF;

   UPDATE swd_consultant_school
   SET    eff_to_date = v_old_end_date
   WHERE  consult_school_id = p_consult_school_id;

   IF (SQL%ROWCOUNT = 0) THEN
      RAISE NO_DATA_FOUND;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Merge into SWD_CONSULTANT_SCHOOL');
   MERGE INTO swd_consultant_school dest
   USING (SELECT p_to_emp_nbr    to_emp_nbr
                ,cs2.school_id   transf_school_id
                ,p_new_from_date eff_from_date
                ,NULL            eff_to_date
          FROM   swd_consultant_school cs2
          WHERE  cs2.consult_school_id = p_consult_school_id) src
   ON (    dest.employee# = src.to_emp_nbr
       AND dest.school_id = src.transf_school_id
       AND NVL(dest.eff_to_date, TRUNC(SYSDATE)) = NVL(src.eff_to_date, TRUNC(SYSDATE)))
   WHEN MATCHED THEN
      UPDATE
      SET    dest.eff_from_date = src.eff_from_date
   WHEN NOT MATCHED THEN
      INSERT (dest.employee#
             ,dest.school_id
             ,dest.eff_from_date
             ,dest.eff_to_date)
      VALUES (src.to_emp_nbr
             ,src.transf_school_id
             ,src.eff_from_date
             ,src.eff_to_date);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_invalid_date THEN
      pr_show_error ('Unable to transfer due to incompatible effective dates for '||
         v_school_name);
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Incompatible effective dates for '||
         v_school_name);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
   WHEN NO_DATA_FOUND THEN
      pr_show_error ('Transfer From record not found.');
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Transfer From record not found.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
   WHEN OTHERS THEN
      pr_show_error (SQLERRM);
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
END pr_transfer_consult_school;


/*****************************************************************************************
 MOD:09
 PURPOSE: Delete funding defaults, including state govt. rates.
 ****************************************************************************************/
PROCEDURE pr_delete_funding_defaults (p_year IN NUMBER) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_delete_funding_defaults';

   v_location                VARCHAR2(50);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params year='||p_year);

   DELETE FROM swd_state_per_capita_rate
   WHERE funding_year = p_year;

   DELETE FROM swd_funding_default
   WHERE funding_year = p_year;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_delete_funding_defaults;


/*****************************************************************************************
 MOD:09
 PURPOSE: Copy funding defaults, including state govt. rates, from one year to another.
          APPROVAL_DATE and PROVIS_PER_DED from SWD_FUNDING_DEFAULT are not copied.
 ****************************************************************************************/
PROCEDURE pr_copy_funding_defaults (p_year_from IN NUMBER
                                   ,p_year_to   IN NUMBER) IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_copy_funding_defaults';

   v_location                VARCHAR2(50);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params year_from='||p_year_from||
      ' year_to='||p_year_to);

   assert ((p_year_from IS NOT NULL), 'Year From is required', 'Y');
   assert ((p_year_to   IS NOT NULL), 'Year To is required', 'Y');

   v_location := 'Inserting SWD_FUNDING_DEFAULT';
   INSERT INTO swd_funding_default (
      funding_year
     ,dpts_cutoff
     ,dpts_value
     ,incentive_value
     ,wbl_value
     ,ta_main_value
     ,ta_unit_value
     ,grg_dpts_cutoff
     ,grg_value
     ,dpts_value_1
     ,dpts_value_1_1
     ,dpts_value_2
     ,dpts_value_2_1
     ,dpts_value_3
     ,dpts_value_3_1
     ,dpts_value_3_2
     ,dpts_value_3_3
     ,dpts_value_4
     ,dpts_value_4_1
     ,dpts_value_4_2_isn)
   SELECT p_year_to
         ,f.dpts_cutoff
         ,f.dpts_value
         ,f.incentive_value
         ,f.wbl_value
         ,f.ta_main_value
         ,f.ta_unit_value
         ,f.grg_dpts_cutoff
         ,f.grg_value
         ,f.dpts_value_1
         ,f.dpts_value_1_1
         ,f.dpts_value_2
         ,f.dpts_value_2_1
         ,f.dpts_value_3
         ,f.dpts_value_3_1
         ,f.dpts_value_3_2
         ,f.dpts_value_3_3
         ,f.dpts_value_4
         ,f.dpts_value_4_1
         ,f.dpts_value_4_2_isn
   FROM   swd_funding_default f
   WHERE  f.funding_year = p_year_from;

   v_location := 'Inserting SWD_STATE_PER_CAPITA_RATE';
   INSERT INTO swd_state_per_capita_rate (
      funding_year
     ,funding_type
     ,state_funding_catgy
     ,kindy_amt
     ,kindy_funded_flg
     ,primary_amt
     ,middle_amt
     ,secondary_amt)
   SELECT p_year_to
         ,s.funding_type
         ,s.state_funding_catgy
         ,s.kindy_amt
         ,s.kindy_funded_flg
         ,s.primary_amt
         ,s.middle_amt
         ,s.secondary_amt
   FROM   swd_state_per_capita_rate s
   WHERE  s.funding_year = p_year_from;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN DUP_VAL_ON_INDEX THEN
      pr_show_error ('Funding Defaults already exist for '||p_year_to||'. No change made.');
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Funding Defaults already exist for '||p_year_to);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, v_location||'  '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
END pr_copy_funding_defaults;


/*****************************************************************************************
 MOD:09
 PURPOSE: Maintains school and student grants.
 ****************************************************************************************/
PROCEDURE pr_maintain_grant (p_grant_id      IN swd_grant.swd_grant_id%TYPE
                            ,p_grant_year    IN swd_grant.grant_year%TYPE
                            ,p_rec_type      IN swd_grant.rec_type%TYPE
                            ,p_school_id     IN swd_grant.school_id%TYPE
                            ,p_appl_id       IN swd_grant.appl_id%TYPE
                            ,p_request_amt   IN swd_grant.request_amt%TYPE
                            ,p_actual_amt    IN swd_grant.actual_amt%TYPE
                            ,p_purpose       IN swd_grant.purpose%TYPE
                            ,p_grant_type    IN swd_grant.grant_type%TYPE
                            ,p_paid_date     IN swd_grant.paid_date%TYPE
                            ,p_comment       IN swd_grant.grant_comment%TYPE
                            ,p_delete_flg    IN VARCHAR2   DEFAULT 'N') IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'pr_maintain_grant';

   e_no_row_updated          EXCEPTION;

   v_grant_id                swd_grant.swd_grant_id%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params grant_id='||p_grant_id||
      ' grant_year='||p_grant_year||' rec_type='||p_rec_type||' school_id='||p_school_id||
      ' appl_id='||p_appl_id||' req_amt='||p_request_amt||' act_amt='||p_actual_amt||
      ' grant_type='||p_grant_type||' del_flg='||p_delete_flg);

   IF (p_delete_flg = 'Y') THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Updating SWD_GRANT with a delete date');
      UPDATE swd_grant
      SET    delete_date  = TRUNC(SYSDATE)
      WHERE  swd_grant_id = p_grant_id
      AND    grant_year  >= EXTRACT(YEAR FROM SYSDATE)
      AND    delete_date IS NULL;
      IF (SQL%ROWCOUNT = 0) THEN
         RAISE e_no_row_updated;
      END IF;

   ELSE
      v_grant_id := NVL(p_grant_id, swd_grant_seq.NEXTVAL);

      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Merging into SWD_GRANT');
      MERGE INTO swd_grant dest
      USING (SELECT v_grant_id          grant_id
                   ,p_grant_year        grant_year
                   ,p_rec_type          rec_type
                   ,p_school_id         school_id
                   ,p_appl_id           appl_id
                   ,TRIM(REPLACE(p_request_amt, ',')) request_amt
                   ,TRIM(REPLACE(p_actual_amt, ','))  actual_amt
                   ,TRIM(p_purpose)     purpose
                   ,UPPER(p_grant_type) grant_type
                   ,TRUNC(p_paid_date)  paid_date
                   ,TRIM(p_comment)     grant_comment
             FROM   DUAL) src
      ON (dest.swd_grant_id = src.grant_id)
      WHEN MATCHED THEN
         UPDATE
         SET    dest.request_amt   = src.request_amt
               ,dest.actual_amt    = src.actual_amt
               ,dest.purpose       = src.purpose
               ,dest.grant_type    = src.grant_type
               ,dest.paid_date     = src.paid_date
               ,dest.grant_comment = src.grant_comment
         WHERE  dest.delete_date IS NULL
      WHEN NOT MATCHED THEN
         INSERT (dest.swd_grant_id
                ,dest.grant_year
                ,dest.rec_type
                ,dest.school_id
                ,dest.appl_id
                ,dest.request_amt
                ,dest.actual_amt
                ,dest.purpose
                ,dest.grant_type
                ,dest.paid_date
                ,dest.grant_comment)
         VALUES (src.grant_id
                ,src.grant_year
                ,src.rec_type
                ,src.school_id
                ,src.appl_id
                ,src.request_amt
                ,src.actual_amt
                ,src.purpose
                ,src.grant_type
                ,src.paid_date
                ,src.grant_comment);
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_no_row_updated THEN
      pr_show_error ('Grant not found or ineligible for deletion.');
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Grant not found or ineligible for deletion.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'grant_id='||p_grant_id
         ||' school_id='||p_school_id||' appl_id='||p_appl_id||' '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;

END pr_maintain_grant;


/*****************************************************************************************
 MOD:09
 PURPOSE: Return the SQL to produce the diagnostician LOV (used on pages 10 and 11). Its
    size is due to traversing the parent-child trees to determine what is end-dated.

    **NB: Query length is very close to 4000 chars hence strange formatting.
 ****************************************************************************************/
FUNCTION get_lov_sql_diagnostician (p_disabl_type_item    IN VARCHAR2
                                   ,p_disabl_cond_id_item IN VARCHAR2)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_lov_sql_diagnostician';

   v_sql                     CLOB;
   v_sql_len                 INTEGER;

   v_disabl_type_item        VARCHAR2(30) := ':'||UPPER(p_disabl_type_item);
   v_disabl_cond_id_item     VARCHAR2(30) := ':'||UPPER(p_disabl_cond_id_item);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL1, VC_SUBPROG_UNIT, 'Params disabl_type_item='||
      p_disabl_type_item||' disabl_cond_id_item='||p_disabl_cond_id_item);

   v_sql :=
q'[WITH diag_types AS (
   SELECT c.* FROM swd.swd_codes c
   WHERE  c.swd_code_type = 'DIAGTYPE'
)
SELECT b.diag_desc d
      ,b.diag_type_code r
FROM  (--Active diagnosticians for the disability
   SELECT 1 active_sort, dt.short_description diag_desc, dd.diagnostician_type_code diag_type_code
   FROM   swd.swd_disabl_diagnostician dd
       INNER JOIN diag_types dt
          ON  dt.swd_code = dd.diagnostician_type_code
          AND TRUNC(SYSDATE) BETWEEN dt.eff_from_date AND NVL(dt.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
       INNER JOIN swd.disability_categories dc --Active disability type
          ON  dd.disability_type_code = dc.dis_cat_id
          AND TRUNC(SYSDATE) BETWEEN dc.eff_from_date AND NVL(dc.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
   WHERE  TRUNC(SYSDATE) BETWEEN dd.eff_from_date AND NVL(dd.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
   AND    dd.disability_type_code = ]'||v_disabl_type_item||
q'[ AND    NOT EXISTS (
       SELECT NULL FROM   swd_disabl_cond_diagnostician dcd
           INNER JOIN swd.sub_disability_categories sdc
              ON  dcd.disability_type_code = sdc.dis_cat_id
              AND dcd.disability_cond_code = sdc.sub_cat_id
              AND sdc.id = ]'||v_disabl_cond_id_item||
   q'[ WHERE  dcd.disability_type_code = dd.disability_type_code)
   UNION
   --Diagnosticians restricted by disabling cond
   SELECT 1, dt.short_description, cd.diagnostician_type_code
   FROM   swd.swd_disabl_cond_diagnostician cd
       INNER JOIN diag_types dt
          ON  dt.swd_code = cd.diagnostician_type_code
          AND TRUNC(SYSDATE) BETWEEN dt.eff_from_date AND NVL(dt.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
       INNER JOIN swd.sub_disability_categories sdc
          ON  cd.disability_type_code = sdc.dis_cat_id
          AND cd.disability_cond_code = sdc.sub_cat_id
          AND sdc.id = :P10_DISABLING_COND
          AND TRUNC(SYSDATE) BETWEEN sdc.eff_from_date AND NVL(sdc.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
   WHERE  cd.disability_type_code = ]'||v_disabl_type_item||
q'[   AND    TRUNC(SYSDATE) BETWEEN cd.eff_from_date AND NVL(cd.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
   UNION
   --Inactive diagnosticians for the disability
   SELECT 2, dt.short_description||'   *** INACTIVE', dd.diagnostician_type_code
   FROM   swd.swd_disabl_diagnostician dd
       INNER JOIN diag_types dt
          ON  dt.swd_code = dd.diagnostician_type_code
       INNER JOIN swd.disability_categories dc
          ON  dd.disability_type_code = dc.dis_cat_id
   WHERE (dd.eff_to_date < TRUNC(SYSDATE) OR dt.eff_to_date < TRUNC(SYSDATE) OR dc.eff_to_date < TRUNC(SYSDATE))
   AND    dd.disability_type_code = ]'||v_disabl_type_item||
q'[   AND    NOT EXISTS (
       SELECT NULL FROM   swd_disabl_cond_diagnostician dcd
           INNER JOIN swd.sub_disability_categories sdc
              ON  dcd.disability_type_code = sdc.dis_cat_id
              AND dcd.disability_cond_code = sdc.sub_cat_id
              AND sdc.id = ]'||v_disabl_cond_id_item||
  q'[ WHERE  dcd.disability_type_code = dd.disability_type_code)
   UNION
   --Inactive diagnosticians restricted by disabling cond
   SELECT 2, dt.short_description||'   *** INACTIVE', cd.diagnostician_type_code
   FROM   swd.swd_disabl_cond_diagnostician cd
       INNER JOIN diag_types dt
          ON  dt.swd_code = cd.diagnostician_type_code
          AND TRUNC(SYSDATE) BETWEEN dt.eff_from_date AND NVL(dt.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
       INNER JOIN swd.sub_disability_categories sdc
          ON  cd.disability_type_code = sdc.dis_cat_id
          AND cd.disability_cond_code = sdc.sub_cat_id
          AND sdc.id = ]'||v_disabl_cond_id_item||
q'[          AND TRUNC(SYSDATE) BETWEEN sdc.eff_from_date AND NVL(sdc.eff_to_date, TO_DATE(:F_END_OF_TIME,'DD-MON-YYYY'))
   WHERE  cd.disability_type_code = ]'||v_disabl_type_item||
q'[   AND    cd.eff_to_date < TRUNC(SYSDATE)
    ) b
ORDER BY b.active_sort, b.diag_desc]';

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Query length = '||LENGTH(v_sql));
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_sql;

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Return empty CLOB. '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN EMPTY_CLOB();

END get_lov_sql_diagnostician;


/*****************************************************************************************
 MOD:10
 PURPOSE: Return 'Y' if student is federally funded.
          Return 'N' if student is not federally funded.
          Return NULL otherwise.
          Funded status cannot be evaluated if the funding application has not reached
          a terminal status i.e. Funding Approval or Not Eligible.
****************************************************************************************/
FUNCTION is_federal_funded (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2 IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'is_federal_funded';

   v_appl_sts                swd_appl_status.status_code%TYPE;
   v_fed_funded_flg          VARCHAR2(01);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params appl_id='||p_appl_id);

   v_appl_sts := get_appl_sts(p_appl_id);

   SELECT CASE
          WHEN (v_appl_sts = GC_APPLSTS_NE) THEN
             'N'
          WHEN (v_appl_sts = GC_APPLSTS_FUNDAPPR)
          AND  (   (a.fed_govt_funding_excl_flg = 'Y')
                OR (a.appl_adj_lvl_code = '0.0')) THEN
             --A Funding Approved application with 0 application adjustment level is not expected
             --but happens
             'N'
          WHEN (v_appl_sts = GC_APPLSTS_FUNDAPPR) THEN
          --!! Be careful. This condition must come after checking
          --FED_GOVT_FUNDING_EXCL_FLG and APPL_ADJ_LVL_CODE.
             'Y'
          ELSE
             NULL
          END
   INTO  v_fed_funded_flg
   FROM  swd_application a
   WHERE a.appl_id = p_appl_id;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_fed_funded_flg);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_fed_funded_flg;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM||'.  Return '||v_fed_funded_flg);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN NULL;

END is_federal_funded;


END swd_funding_application;
/