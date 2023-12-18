CREATE OR REPLACE PACKAGE SWD.swd_funding_application IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01     Date: 29-May-2019     Author: A Woo
 Created
 
 MOD:02     Date: 04-May-2020     Author: A Woo
 Add global constants.
 Add procedures
 - pr_deactivate_appl
 - pr_maintain_appl_doc
 - pr_log_document_access
 - pr_notify_principal
 - pr_delete_appl
 - pr_init_p1_items
 Add functions
 - get_school_code
 - get_school_appl_overview_qry
 In procedure pr_maintain_appl,
 - add parameters p_review_date, p_review_comment and p_stu_fte
 - add review_date, review_comment and student_fte to merge statement
 In procedure pr_copy_appl, add parameter p_school_id
 In procedure pr_maintain_disabilities, change parameter p_appl_disabl_id to 
    IN OUT to cater for Interactive Grid processing.
 In procedure pr_increment_version_nbr, add parameter p_new_version_nbr.
 
 MOD:03     Date: 01-Jun-2021     Author: A Woo
 In function get_disabl_catgy_id change reference of CEODB.SUB_DISABILITY_CATEGORIES
 to the current schema.
 In procedure pr_maintain_appl,
 - add parameters p_fed_govt_fund_excl_flg, p_legacy_stu_id
 In procedure pr_maintain_disabilities,
 - add parameters p_disabl_lvl_code, p_disabl_comment.
 Add procedure and functions
 - pr_transfer_consult_school
 - pr_delete_funding_defaults
 - pr_copy_funding_defaults
 - pr_maintain_grant
 - get_lov_sql_diagnostician

 MOD:04     Date: 18-Jul-2021     Author: A Woo
 Add function is_federal_funded.
 ******************************************************************************/

   GC_APX_COLL_STUDENTS CONSTANT VARCHAR2(255) := 'STUDENT_SEARCH_RES';
   GC_APX_COLL_STAFF    CONSTANT VARCHAR2(255) := 'SCHOOL_STAFF';
   GC_APX_COLL_SWD2_GRP CONSTANT VARCHAR2(255) := 'SWD2_GROUPS';
   GC_APX_COLL_USER_GRP CONSTANT VARCHAR2(255) := 'USER_SWD2_GROUPS';
   GC_APX_COLL_ROLLPREV CONSTANT VARCHAR2(255) := 'ROLLOVER_PREV'; --MOD:02
   GC_APX_COLL_GRP_USER CONSTANT VARCHAR2(255) := 'SWD2_GROUP_USERS'; --MOD:02

   GC_APPLSTS_DRAFT     CONSTANT VARCHAR2(20)  := 'DRAFT';
   GC_APPLSTS_SUBMIT    CONSTANT VARCHAR2(20)  := 'SUBMIT';
   GC_APPLSTS_REVIEWED  CONSTANT VARCHAR2(20)  := 'REVIEWED';
   GC_APPLSTS_PRINCAPPR CONSTANT VARCHAR2(20)  := 'PRINCAPPR';
   GC_APPLSTS_FUNDAPPR  CONSTANT VARCHAR2(20)  := 'FUNDAPPR';
   GC_APPLSTS_NE        CONSTANT VARCHAR2(20)  := 'NE';


/*****************************************************************************************
 PURPOSE: Return 'Y' if funding application period is open.
          Return 'N' otherwise.
 ****************************************************************************************/
FUNCTION is_swd_app_open
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return Y if the school belong's to the SWD consultant.
          Return N otherwise.
 ****************************************************************************************/
FUNCTION is_consultant_school (p_username  IN VARCHAR2
                              ,p_school_id IN NUMBER)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return Y if the school belongs to the session user including an SWD consultant.
          Return N otherwise.
 ****************************************************************************************/
FUNCTION is_user_school (p_username       IN VARCHAR2
                        ,p_appl_school_id IN NUMBER)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return the current application status code.
 ****************************************************************************************/
FUNCTION get_appl_sts (p_appl_id IN swd_appl_status.appl_id%TYPE)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return the current application status description.
 ****************************************************************************************/
FUNCTION get_appl_sts_desc (p_appl_id IN swd_appl_status.appl_id%TYPE)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return the short description of the code.
 ****************************************************************************************/
FUNCTION get_code_desc (p_code_type IN swd_codes.swd_code_type%TYPE
                       ,p_code      IN swd_codes.swd_code%TYPE)
RETURN VARCHAR2;


/*****************************************************************************************
 MOD:02
 PURPOSE: Return a 4-digit school code given the EDUCATION.SCHOOL.SCHOOL_ID.
 ****************************************************************************************/
FUNCTION get_school_code (p_school_id IN education.school.school_id%TYPE) --MOD:03
RETURN education.school.ceowa_nbr%TYPE; --MOD:03


/*****************************************************************************************
 PURPOSE: Return the id given the EDUCATION.SCHOOL.CEOWA_NBR.
 ****************************************************************************************/
FUNCTION get_school_id (p_school_code IN education.school.ceowa_nbr%TYPE) --MOD:03
RETURN education.school.school_id%TYPE; --MOD:03


/*****************************************************************************************
 PURPOSE: Return the disablity category id given the sub-disability id.
 ****************************************************************************************/
FUNCTION get_disabl_catgy_id (p_sub_disabl_catgy_id IN sub_disability_categories.id%TYPE) --MOD:03
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return the next school level.
 ****************************************************************************************/
FUNCTION get_next_sch_lvl (p_sch_lvl IN swd_application.enrolled_school_lvl%TYPE)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return Y if an application for the given funding year already exists for 
    the student.
 ****************************************************************************************/
FUNCTION is_fund_year_appl_exist (p_appl_id      IN swd_application.appl_id%TYPE
                                 ,p_funding_year IN swd_application.funding_year%TYPE)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return Y if the application has been superseded by a revision.
          Return N otherwise.
 ****************************************************************************************/
FUNCTION appl_been_revised (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Return Y if the application status may be changed by the user.
          Return N otherwise.
          Uses Apex application items.
 ****************************************************************************************/
FUNCTION may_change_appl_sts (p_appl_id  IN swd_application.appl_id%TYPE
                             ,p_username IN VARCHAR2)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Search for a student in Active Directory.
 ****************************************************************************************/
PROCEDURE pr_student_search (p_school_id         IN education.school.school_id%TYPE --MOD:03
                            ,p_given_name        IN VARCHAR2 DEFAULT NULL
                            ,p_surname           IN VARCHAR2 DEFAULT NULL
                            ,p_state_student_nbr IN NUMBER   DEFAULT NULL
                            ,p_enrolld_sch_lvl   IN VARCHAR2 DEFAULT NULL);


/*****************************************************************************************
 PURPOSE: Attempt to update SWD_APPLICATION.VERSION_NBR with the version acquired on 
    reading the data.  Trigger will take care of the actual increment if the version
    has not changed.
 ****************************************************************************************/
PROCEDURE pr_increment_version_nbr (p_appl_id         IN     swd_application.appl_id%TYPE
                                   ,p_old_version_nbr IN     swd_application.version_nbr%TYPE
                                   ,p_new_version_nbr    OUT swd_application.version_nbr%TYPE); --MOD:02


/*****************************************************************************************
 PURPOSE: Maintain disabilities.
 ****************************************************************************************/
PROCEDURE pr_maintain_disabilities (
   p_appl_disabl_id     IN OUT swd_appl_disability.appl_disabl_id%TYPE --MOD:02
  ,p_appl_id            IN     swd_appl_disability.appl_id%TYPE
  ,p_appl_status        IN     swd_appl_status.status_code%TYPE
  ,p_disabl_cond_id     IN     swd_appl_disability.disability_cond_id%TYPE  DEFAULT NULL
  ,p_primary_flg        IN     swd_appl_disability.primary_cond_flg%TYPE    DEFAULT NULL
  ,p_diagnostician_type IN     swd_appl_disability.diagnostician_type_code%TYPE DEFAULT NULL
  ,p_diagnostician      IN     swd_appl_disability.diagnostician%TYPE       DEFAULT NULL
  ,p_diagnosis_date     IN     swd_appl_disability.diagnosis_date%TYPE      DEFAULT NULL
  ,p_diagnostician_text IN     swd_appl_disability.diagnostician_text%TYPE  DEFAULT NULL
  ,p_disabl_lvl_code    IN     swd_appl_disability.disability_lvl_code%TYPE DEFAULT NULL --MOD:03
  ,p_disabl_comment     IN     swd_appl_disability.disability_comment%TYPE  DEFAULT NULL --MOD:03
  ,p_delete_flg         IN     VARCHAR2 DEFAULT 'N');


/*****************************************************************************************
 PURPOSE: Maintain application status.
    Update occurs only when the application status matches the most recent status.
 ****************************************************************************************/
PROCEDURE pr_maintain_appl_sts (p_appl_id            IN swd_appl_status.appl_id%TYPE
                               ,p_appl_status        IN swd_appl_status.status_code%TYPE
                               ,p_appl_status_reason IN swd_appl_status.status_reason%TYPE);


/*****************************************************************************************
 PURPOSE: Maintain SWD_APPLICATION
 ****************************************************************************************/
PROCEDURE pr_maintain_appl (
   p_appl_id                IN OUT swd_appl_status.appl_id%TYPE
  ,p_appl_status            IN     swd_appl_status.status_code%TYPE
  ,p_appl_status_reason     IN     swd_appl_status.status_reason%TYPE
  ,p_funding_year           IN     swd_application.funding_year%TYPE
  ,p_school_id              IN     swd_application.school_id%TYPE
  ,p_ssn                    IN     swd_application.state_student_nbr%TYPE
  ,p_username               IN     swd_application.student_username%TYPE
  ,p_given_name             IN     swd_application.student_first_name%TYPE
  ,p_surname                IN     swd_application.student_surname%TYPE
  ,p_dob                    IN     swd_application.dob%TYPE
  ,p_gender                 IN     swd_application.gender%TYPE
  ,p_enrolld_sch_lvl        IN     swd_application.enrolled_school_lvl%TYPE
  ,p_funding_sch_lvl        IN     swd_application.funding_school_lvl%TYPE
  ,p_parent_consent_flg     IN     swd_application.parent_consent_flg%TYPE
  ,p_nccd_catgy             IN     swd_application.nccd_catgy_code%TYPE
  ,p_nccd_loa               IN     swd_application.nccd_adj_lvl_code%TYPE
  ,p_iap_curric_partcp_comm IN     swd_application.iap_curric_partcp_comment%TYPE
  ,p_iap_curric_partcp_loa  IN     swd_application.iap_curric_partcp_adj_lvl_code%TYPE
  ,p_iap_commun_partcp_comm IN     swd_application.iap_commun_partcp_comment%TYPE
  ,p_iap_commun_partcp_loa  IN     swd_application.iap_commun_partcp_adj_lvl_code%TYPE
  ,p_iap_mobility_comm      IN     swd_application.iap_mobility_comment%TYPE
  ,p_iap_mobility_loa       IN     swd_application.iap_mobility_adj_lvl_code%TYPE
  ,p_iap_personal_care_comm IN     swd_application.iap_personal_care_comment%TYPE
  ,p_iap_personal_care_loa  IN     swd_application.iap_personal_care_adj_lvl_code%TYPE
  ,p_iap_soc_skills_comm    IN     swd_application.iap_soc_skills_comment%TYPE
  ,p_iap_soc_skills_loa     IN     swd_application.iap_soc_skills_adj_lvl_code%TYPE
  ,p_iap_safety_comm        IN     swd_application.iap_safety_comment%TYPE
  ,p_iap_safety_loa         IN     swd_application.iap_safety_adj_lvl_code%TYPE
  ,p_delete_date            IN     swd_application.delete_date%TYPE
  ,p_appl_adj_lvl_comm      IN     swd_application.appl_adj_lvl_comment%TYPE
  ,p_appl_loa               IN     swd_application.appl_adj_lvl_code%TYPE
  ,p_read_version_nbr       IN     swd_application.version_nbr%TYPE
  ,p_related_appl_id        IN     swd_application.related_appl_id%TYPE
  ,p_review_date            IN     swd_application.review_date%TYPE    --MOD:02
  ,p_review_comment         IN     swd_application.review_comment%TYPE --MOD:02
  ,p_stu_fte                IN     swd_application.student_fte%TYPE    --MOD:02
  ,p_fed_govt_fund_excl_flg IN     swd_application.fed_govt_funding_excl_flg%TYPE   DEFAULT 'N' --MOD:03
  );


/*****************************************************************************************
 PURPOSE: Copy an existing application
 ****************************************************************************************/
PROCEDURE pr_copy_appl (p_appl_id          IN OUT swd_application.appl_id%TYPE
                       ,p_funding_year     IN     swd_application.funding_year%TYPE
                       ,p_funding_sch_lvl  IN     swd_application.funding_school_lvl%TYPE
                       ,p_school_id        IN     swd_application.school_id%TYPE --MOD:02
                       ,p_request          IN     VARCHAR2);


/*****************************************************************************************
 PURPOSE: Populate global temporary with rollover data for preview.
 ****************************************************************************************/
PROCEDURE pr_bulk_rollover_preview (p_fund_year_from IN swd_application.funding_year%TYPE
                                   ,p_fund_year_to   IN swd_application.funding_year%TYPE
                                   ,p_school_id_from IN swd_application.school_id%TYPE
                                   ,p_school_id_to   IN swd_application.school_id%TYPE);

/*****************************************************************************************
 PURPOSE: Rollover data
 ****************************************************************************************/
PROCEDURE pr_bulk_rollover;


/*****************************************************************************************
 PURPOSE: Build an Apex collection of SWD2 groups in Active Directory
 ****************************************************************************************/
PROCEDURE pr_build_swd2_group_list;


/*****************************************************************************************
 PURPOSE: Return a colon delimited list of the display value of SWD2 groups that are 
    assigned to the user.
 ****************************************************************************************/
FUNCTION get_user_group_list (p_user_dn IN VARCHAR2)
RETURN VARCHAR2;


/*****************************************************************************************
 PURPOSE: Build an Apex collection of the SWD2 groups that is assigned to the user.
 ****************************************************************************************/
PROCEDURE pr_build_user_group_list (p_username IN VARCHAR2);


/*****************************************************************************************
 MOD:02
 PURPOSE: Build an Apex collection of members of a group.
 ****************************************************************************************/
PROCEDURE pr_build_group_user_list (p_group_dn IN VARCHAR2);


/*****************************************************************************************
 PURPOSE: Build an Apex collection of the staff of a school.
 ****************************************************************************************/
PROCEDURE pr_build_user_list (p_school_id IN swd_application.school_id%TYPE);


/*****************************************************************************************
 PURPOSE: Modify user access in Active Directory
 ****************************************************************************************/
PROCEDURE pr_assign_user_group (p_user_dn       IN VARCHAR2
                               ,p_original_list IN VARCHAR2
                               ,p_new_list      IN VARCHAR2);


/*****************************************************************************************
 PURPOSE: Initialise application items.
 ****************************************************************************************/
PROCEDURE pr_init_app_items;


/*****************************************************************************************
 PURPOSE: Build the header at the top of the page for page 10 - Create Application
 ****************************************************************************************/
PROCEDURE print_create_appl_hdr (p_appl_id IN NUMBER
                                ,p_page_id IN NUMBER);


/*****************************************************************************************
 PURPOSE: 'Page 10 - Create Application' has various sections that can be amended at
    different stages by different user roles.  Determine the status for the sections.
 ****************************************************************************************/
PROCEDURE pr_decide_upd_access_p10 (
   p_appl_id            IN     NUMBER
  ,p_username           IN     VARCHAR2
  ,p_upd_body_flg          OUT VARCHAR2
  ,p_upd_appl_sts_flg      OUT VARCHAR2
  ,p_upd_disabl_pts_flg    OUT VARCHAR2);


/*****************************************************************************************
 MOD:02
 PURPOSE: Flag the current and future funding applications found for students in 
    INTERFACE.STUDENT_MIM_DEACTIVATED as inactive.
 ****************************************************************************************/
PROCEDURE pr_deactivate_appl;


/*****************************************************************************************
 MOD:02
 PURPOSE: Maintain document uploads. 
 ****************************************************************************************/
PROCEDURE pr_maintain_appl_doc (p_doc_id          IN swd_document.doc_id%TYPE
                               ,p_unique_doc_name IN swd_document.unique_doc_name%TYPE
                               ,p_doc_comment     IN swd_document.doc_comment%TYPE     DEFAULT NULL
                               ,p_appl_id         IN swd_appl_document.appl_id%TYPE                               
                               ,p_delete_date     IN swd_document.delete_date%TYPE
                               ,p_doc_hide_date   IN swd_appl_document.doc_hide_date%TYPE);


/*****************************************************************************************
 MOD:02
 PURPOSE: Log document access.
 ****************************************************************************************/
PROCEDURE pr_log_document_access (p_doc_id   IN swd_doc_access_log.doc_id%TYPE
                                 ,p_user     IN swd_doc_access_log.accessed_by%TYPE);


/*****************************************************************************************
 MOD:02
 PURPOSE: Send reminder to principals to approve applications.
 ****************************************************************************************/
PROCEDURE pr_notify_principal (p_funding_year   IN swd_application.funding_year%TYPE
                              ,p_school_id      IN swd_application.school_id%TYPE
                              ,p_app_count      IN NUMBER);


/*****************************************************************************************
 MOD:02
 PURPOSE: Logically delete an application. 
 ****************************************************************************************/
PROCEDURE pr_delete_appl (p_appl_id IN swd_application.appl_id%TYPE);


/*****************************************************************************************
 MOD:02
 PURPOSE: Initialise school name and school id page items.
 ****************************************************************************************/
PROCEDURE pr_init_p1_items;


/*****************************************************************************************
 MOD:02
 PURPOSE: Build and return the query for use by charts on the landing page.
 ****************************************************************************************/
FUNCTION get_school_appl_overview_qry (p_itm_funding_year IN VARCHAR2
                                      ,p_itm_school_id    IN VARCHAR2)
RETURN VARCHAR2;

/*****************************************************************************************
 MOD:03
 PURPOSE: Transfer a school from one consultant to another.
 ****************************************************************************************/
PROCEDURE pr_transfer_consult_school (
   p_consult_school_id IN swd_consultant_school.consult_school_id%TYPE
  ,p_to_emp_nbr        IN swd_consultant_school.employee#%TYPE
  ,p_new_from_date     IN swd_consultant_school.eff_from_date%TYPE);

/*****************************************************************************************
 MOD:03
 PURPOSE: Copy funding defaults, including state govt. rates, from one year to another.
          APPROVAL_DATE and PROVIS_PER_DED from SWD_FUNDING_DEFAULT are not copied.
 ****************************************************************************************/
PROCEDURE pr_copy_funding_defaults (p_year_from IN NUMBER
                                   ,p_year_to   IN NUMBER);

/*****************************************************************************************
 MOD:03
 PURPOSE: Delete funding defaults, including state govt. rates.
 ****************************************************************************************/
PROCEDURE pr_delete_funding_defaults (p_year IN NUMBER);

/*****************************************************************************************
 MOD:03
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
                            ,p_delete_flg    IN VARCHAR2   DEFAULT 'N');

/*****************************************************************************************
 MOD:03
 PURPOSE: Return the SQL to produce the diagnostician LOV (used on pages 10 and 11). 
 ****************************************************************************************/
FUNCTION get_lov_sql_diagnostician (p_disabl_type_item    IN VARCHAR2
                                   ,p_disabl_cond_id_item IN VARCHAR2)
RETURN VARCHAR2;

/*****************************************************************************************
 MOD:04
 PURPOSE: Return 'Y' if student is federally funded.
          Return 'N' if student is not federally funded.
          Return NULL otherwise. 
          Funded status cannot be evaluated if the funding application has not reached
          a terminal status i.e. Funding Approval or Not Eligible.
****************************************************************************************/
FUNCTION is_federal_funded (p_appl_id IN swd_application.appl_id%TYPE)
RETURN VARCHAR2;


END swd_funding_application;

/