CREATE OR REPLACE PACKAGE swd_migration IS
/******************************************************************************

 Modification History
 --------------------
 MOD:02     Date: 08-Jun-2021     Author: A Woo
 Created. Package name repurposed from INTERIM to SWD2 migration.
 
 MOD:03     Date: 10-Aug-2021     Author: A Woo
 Add procedures
 - pr_upd_legacy_student_id
 - pr_upd_scio_swd
 - pr_ins_scio_swd
 
 MOD:04     Date: 19-Oct-2021     Author: A Woo
 Add procedure pr_ins_swd2.
******************************************************************************/

/*****************************************************************************************
 PURPOSE: Log any application that exists in SCIO but not found in SWD2 for the given year.
    If year = 0, reconcile all.

    Data between the 2 systems will be matched on the following
    - First name
    - Surname
    - DOB
    - Gender
    - School
    - Academic year
 ****************************************************************************************/
PROCEDURE pr_log_missing_swd2_appl (p_recon_year IN NUMBER DEFAULT 0);

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
    - Academic year
    - Disabling condition id
    - Primary condition ind
 ****************************************************************************************/
PROCEDURE pr_log_missing_swd2_disabl (p_recon_year IN NUMBER DEFAULT 0);

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
    - Academic year
    - School
    Populate SWD.SWD_APPLICATION.LEGACY_STUDENT_ID for any matches.
    
    mode R = report only
         U = update
 ****************************************************************************************/
PROCEDURE pr_migrate_new_cols_to_swd2 (p_migrate_year IN NUMBER DEFAULT 0
                                      ,p_mode         IN VARCHAR2);

/*****************************************************************************************
 MOD:03
 PURPOSE: Update LEGACY_STUDENT_ID and STATE_STUDENT_NBR in SWD_APPLICATION using mappings
     provided in STG_DATA_CORRECTION.
 ****************************************************************************************/
PROCEDURE pr_upd_legacy_student_id (p_disable_trigger IN VARCHAR2 DEFAULT 'N');

/*****************************************************************************************
 MOD:03
 PURPOSE: Integrate to SCIO SWD funding year 2022 applications at Funding Approval or
    Not Eligible status that are either for new applicants or have been modified since
    being rolled over from 2021 applications.
    
    NB: Disable these triggers first:
        - CEODB.TRG_STUDENT_SCHOOLS_BIU
        - CEODB.TRG_STUDENT_DISABILITIES_BIU
 ****************************************************************************************/
PROCEDURE pr_upd_scio_swd;

/*****************************************************************************************
 MOD:03
 PURPOSE: Integrate to SCIO SWD funding year 2022 applications at Funding Approval or
    Not Eligible status for new applicants.
    
    NB: Disable these triggers first:
        - CEODB.TRG_STUDENT_SCHOOLS_BIU
        - CEODB.TRG_STUDENT_DISABILITIES_BIU
 ****************************************************************************************/
PROCEDURE pr_ins_scio_swd;

/*****************************************************************************************
 MOD:04
 PURPOSE: Migrate legacy data from SCIO SWD to SWD2.
 
    p_excl_stu_list is a colon delimited list of legacy student ids NOT to migrate
 ****************************************************************************************/
PROCEDURE pr_ins_swd2 (p_max_fund_year IN NUMBER
                      ,p_excl_stu_list IN VARCHAR2 DEFAULT '1');

END swd_migration;
/
