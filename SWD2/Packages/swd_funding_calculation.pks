CREATE OR REPLACE PACKAGE swd_funding_calculation IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01     Date: 01-Jun-2021     Author: A Woo
 Created

 MOD:02     Date: 18-Jul-2021     Author: A Woo
 Add global constants for application statuses.
 Remove function is_funded.
 Rename parameters in function get_elig_funding_count.

 MOD:03     Date: 08-Sep-2021     Author: A Woo
 In function get_elig_funding_count
 - add default value to parameter p_fed_funding_flg and
 - add parameter p_isn_flg
 Add functions
 - get_isn_student_count
 - get_wspc_amt_school
 - get_isn_state_amt_school
 ******************************************************************************/

   GC_APPLSTS_DRAFT     CONSTANT VARCHAR2(20)  := 'DRAFT';
   GC_APPLSTS_SUBMIT    CONSTANT VARCHAR2(20)  := 'SUBMIT';
   GC_APPLSTS_REVIEWED  CONSTANT VARCHAR2(20)  := 'REVIEWED';
   GC_APPLSTS_PRINCAPPR CONSTANT VARCHAR2(20)  := 'PRINCAPPR';
   GC_APPLSTS_FUNDAPPR  CONSTANT VARCHAR2(20)  := 'FUNDAPPR';
   GC_APPLSTS_NE        CONSTANT VARCHAR2(20)  := 'NE';


/*****************************************************************************************
 PURPOSE: Return student count, with Funding Approval and Not Eligible applications,
    summarised at the chosen level. Includes ISN students.

     p_gender:     A = All
                   M = Male
                   F = Female
                   X = Unspecified
    p_grade_catgy: A = All
                   K = Kindy
                  PP = Pre-Primary
                   P = Primary
                   M = Middle
                   S = Secondary
 ****************************************************************************************/
FUNCTION get_student_count (p_funding_year  IN swd_application.funding_year%TYPE
                           ,p_school_id     IN swd_application.appl_id%TYPE
                           ,p_gender        IN VARCHAR2
                           ,p_grade_catgy   IN VARCHAR2)
RETURN NUMBER;


/*****************************************************************************************
 MOD:03
 PURPOSE: Return ISN student count, with Funding Approval applications, summarised at the
    chosen level. A student is counted only if their application is eligible for ISN
    funding.

     p_gender:     A = All
                   M = Male
                   F = Female
                   X = Unspecified
    p_grade_catgy: K = Kindy
                  PP = Pre-Primary
                   P = Primary
                   M = Middle
                   S = Secondary
                ** No All option due to complexity of when ISN funding was available
                   to which grade.
 ****************************************************************************************/
FUNCTION get_isn_student_count (p_funding_year  IN swd_application.funding_year%TYPE
                               ,p_school_id     IN swd_application.appl_id%TYPE
                               ,p_gender        IN VARCHAR2
                               ,p_grade_catgy   IN VARCHAR2)
RETURN NUMBER;


/*****************************************************************************************
 PURPOSE:  Get the number of applications (or students) per school, or for all schools,
    per year that has
    i.   the chosen state govt. funding eligibility status (Y/N),
    ii.  federal govt. funding status (Y/N/A) and
    iii. the ISN status (Y/N/A).

    p_fed_funding_flg A = All statuses
                      Y = has federal funding
                      N = excluded from federal funding
            p_isn_flg A = All application adjustment levels
                      Y = has application adjustment level 4.2
                      N = has application adjstment level other than 4.2
 ****************************************************************************************/
FUNCTION get_elig_funding_count (p_funding_year       IN swd_application.funding_year%TYPE
                                ,p_school_id          IN swd_application.school_id%TYPE
                                ,p_state_eligible_flg IN VARCHAR2
                                ,p_fed_funding_flg    IN VARCHAR2 DEFAULT 'A'  --MOD:03
                                ,p_isn_flg            IN VARCHAR2 DEFAULT 'A') --MOD:03
RETURN NUMBER;


/*****************************************************************************************
 PURPOSE: Return the federal government funding amount for a student based on the
    allocated disability points and their FTE.
 ****************************************************************************************/
FUNCTION get_dpts_fte_amt_appl (p_funding_year  IN swd_application.funding_year%TYPE
                               ,p_appl_id       IN swd_application.appl_id%TYPE)
RETURN NUMBER;


/*****************************************************************************************
 PURPOSE: Return the federal government funding amount for the selected disability point
    summarised at a school level.
    If p_dpts is null, calculate total federal funding. Only applicable from 2005.
 ****************************************************************************************/
FUNCTION get_dpts_fte_amt_school (p_funding_year  IN swd_application.funding_year%TYPE
                                 ,p_school_id     IN swd_application.school_id%TYPE
                                 ,p_dpts          IN swd_application.appl_adj_lvl_code%TYPE DEFAULT NULL)
RETURN NUMBER;


/*****************************************************************************************
 MOD:03
 PURPOSE: Return the Weighted State Per Capita (WSPC) allocation amount for specified grade
    category in a school. Excludes Intensive Support Need (ISN) students by virtue of
    missing translation record in table SWD_APPL_ADJ_LVL_TRANSLATION.

    p_grade_catgy: A = All
                   K = Kindy
                  PP = Pre-Primary
                   P = Primary
                   M = Middle
                   S = Secondary
 ****************************************************************************************/
FUNCTION get_wspc_amt_school (p_funding_year  IN swd_application.funding_year%TYPE
                             ,p_school_id     IN swd_application.school_id%TYPE
                             ,p_grade_catgy   IN VARCHAR2)
RETURN NUMBER;


/*****************************************************************************************
 MOD:03
 PURPOSE: Return the Intensive Support Need (ISN) state amount for specified grade
    category in a school.

    p_grade_catgy: K = Kindy
                  PP = Pre-Primary
                   P = Primary
                   M = Middle
                   S = Secondary
 ****************************************************************************************/
FUNCTION get_isn_state_amt_school (p_funding_year  IN swd_application.funding_year%TYPE
                                  ,p_school_id     IN swd_application.school_id%TYPE
                                  ,p_grade_catgy   IN VARCHAR2)
RETURN NUMBER;


/*****************************************************************************************
 PURPOSE:  Returns the total grant amount for a school in the selected year.

    p_rec_type: A = Student application
                S = School
                E = Everything
 p_grant_type: CE = Capital
                D = Discretionary / contextual
                S = SPG
    p_amt_type: R = Requested
                A = Actual
 ****************************************************************************************/
FUNCTION get_grant_total (p_grant_year  IN swd_grant.grant_year%TYPE
                         ,p_school_id   IN swd_grant.school_id%TYPE
                         ,p_rec_type    IN swd_grant.rec_type%TYPE   DEFAULT 'E'
                         ,p_grant_type  IN VARCHAR2
                         ,p_amt_type    IN VARCHAR2)
RETURN NUMBER;


END swd_funding_calculation;
/
