CREATE OR REPLACE PACKAGE BODY swd_funding_calculation IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01     Date: 01-Jun-2021     Author: A Woo
 Created

 MOD:02     Date: 18-Jul-2021     Author: A Woo
 Rename function is_funded to is_federal_funded and move to package
 SWD_FUNDING_APPLICATION.
 Modify these functions following the dropping of virtual column
 SWD_APPLICATION.FUNDED_FLG_V:
 - get_elig_funding_count

 MOD:03     Date: 08-Sep-2021     Author: A Woo
 Move constants for gender and grade category from function get_student_count
 to global.
 Add global constants for school grades and end dates.
 Change Kindy code from 'K' to 'K4' and Pre-Primary from 'PP' to 'PS'.
 Change SWD_APPLICATION to SWD_ACTIVE_APPL_V where appropriate.
 In function get_elig_funding_count
 - add default value to parameter p_fed_funding_flg and
 - add parameter p_isn_flg and corresponding logic
 Add functions
 - get_isn_student_count
 - get_state_fund_rate
 - get_wspc_amt_school
 - get_isn_state_amt_school
******************************************************************************/
   GC_APP_ALIAS          CONSTANT VARCHAR2(10)  := 'SWD2';
   GC_PACKAGE            CONSTANT VARCHAR2(30)  := 'SWD.SWD_FUNDING_CALCULATION';
   GC_START              CONSTANT VARCHAR2(01)  := 'S';
   GC_END                CONSTANT VARCHAR2(01)  := 'E';

   --MOD:03
   GC_END_YEAR           CONSTANT NUMBER(04)    := 2049;
   GC_END_OF_TIME        CONSTANT DATE          := TO_DATE('31-DEC-2049','DD-MON-YYYY');

   --MOD:03
   GC_GENDER_MALE         CONSTANT VARCHAR2(01) := 'M';
   GC_GENDER_FEMALE       CONSTANT VARCHAR2(01) := 'F';
   GC_GENDER_UNSPECIFIED  CONSTANT VARCHAR2(01) := 'X';
   GC_GENDER_ALL          CONSTANT VARCHAR2(01) := 'A';

   --MOD:03
   GC_GRADE_CATGY_ALL     CONSTANT VARCHAR2(02) := 'A';
   GC_GRADE_CATGY_KINDY   CONSTANT VARCHAR2(02) := 'K';
   GC_GRADE_CATGY_PREPRIM CONSTANT VARCHAR2(02) := 'PP';
   GC_GRADE_CATGY_PRIM    CONSTANT VARCHAR2(02) := 'P';
   GC_GRADE_CATGY_MID     CONSTANT VARCHAR2(02) := 'M';
   GC_GRADE_CATGY_SEC     CONSTANT VARCHAR2(02) := 'S';

   --MOD:03
   GC_GRADE_3YO           CONSTANT VARCHAR2(03) := 'K3';
   GC_GRADE_KINDY         CONSTANT VARCHAR2(03) := 'K4';
   GC_GRADE_PRE_PRIM      CONSTANT VARCHAR2(03) := 'PS';
   GC_GRADE_Y01           CONSTANT VARCHAR2(03) := 'Y01';
   GC_GRADE_Y02           CONSTANT VARCHAR2(03) := 'Y02';
   GC_GRADE_Y03           CONSTANT VARCHAR2(03) := 'Y03';
   GC_GRADE_Y04           CONSTANT VARCHAR2(03) := 'Y04';
   GC_GRADE_Y05           CONSTANT VARCHAR2(03) := 'Y05';
   GC_GRADE_Y06           CONSTANT VARCHAR2(03) := 'Y06';
   GC_GRADE_Y07           CONSTANT VARCHAR2(03) := 'Y07';
   GC_GRADE_Y08           CONSTANT VARCHAR2(03) := 'Y08';
   GC_GRADE_Y09           CONSTANT VARCHAR2(03) := 'Y09';
   GC_GRADE_Y10           CONSTANT VARCHAR2(03) := 'Y10';
   GC_GRADE_Y11           CONSTANT VARCHAR2(03) := 'Y11';
   GC_GRADE_Y12           CONSTANT VARCHAR2(03) := 'Y12';

   GC_DEFAULT_SPC_CATGY   CONSTANT VARCHAR2(01) := 'F';

   g_indent_count                  INTEGER := 0;
   g_err_count                     INTEGER := 0;


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
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_student_count';

   v_cnt                      NUMBER(06) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (p_funding_year < 2016) THEN
      SELECT COUNT(*)
      INTO   v_cnt
      FROM   swd_active_appl_v aa
      WHERE  aa.appl_sts IN (GC_APPLSTS_FUNDAPPR, GC_APPLSTS_NE)
      AND    aa.funding_year = p_funding_year
      AND    aa.school_id    = p_school_id
      AND    aa.gender = DECODE(p_gender, GC_GENDER_MALE,   GC_GENDER_MALE
                                        , GC_GENDER_FEMALE, GC_GENDER_FEMALE
                                        , GC_GENDER_ALL,    aa.gender
                                        , '?')
      AND   (    (    p_grade_catgy        = GC_GRADE_CATGY_ALL)
             OR  (    p_grade_catgy        = GC_GRADE_CATGY_KINDY
                 AND aa.funding_school_lvl = GC_GRADE_KINDY)
             OR  (    p_grade_catgy        = GC_GRADE_CATGY_PREPRIM
                 AND aa.funding_school_lvl = GC_GRADE_PRE_PRIM)
             OR (    p_grade_catgy         = GC_GRADE_CATGY_PRIM
                 AND aa.funding_school_lvl IN (GC_GRADE_Y01, GC_GRADE_Y02, GC_GRADE_Y03, GC_GRADE_Y04, GC_GRADE_Y05, GC_GRADE_Y06, GC_GRADE_Y07))
             OR (    p_grade_catgy         = GC_GRADE_CATGY_SEC
                 AND aa.funding_school_lvl IN (GC_GRADE_Y08, GC_GRADE_Y09, GC_GRADE_Y10, GC_GRADE_Y11, GC_GRADE_Y12))
            );
   ELSE
      SELECT COUNT(*)
      INTO   v_cnt
      FROM   swd_active_appl_v aa
      WHERE  aa.appl_sts IN (GC_APPLSTS_FUNDAPPR, GC_APPLSTS_NE)
      AND    aa.funding_year = p_funding_year
      AND    aa.school_id    = p_school_id
      AND    aa.gender = DECODE(p_gender, GC_GENDER_MALE,        GC_GENDER_MALE
                                        , GC_GENDER_FEMALE,      GC_GENDER_FEMALE
                                        , GC_GENDER_UNSPECIFIED, GC_GENDER_UNSPECIFIED
                                        , GC_GENDER_ALL,         aa.gender
                                        , '?')
      AND   (   (    p_grade_catgy         = GC_GRADE_CATGY_ALL)
             OR (    p_grade_catgy         = GC_GRADE_CATGY_KINDY
                 AND aa.funding_school_lvl = GC_GRADE_KINDY)
             OR (    p_grade_catgy         = GC_GRADE_CATGY_PRIM
                 AND aa.funding_school_lvl IN (GC_GRADE_PRE_PRIM, GC_GRADE_Y01, GC_GRADE_Y02, GC_GRADE_Y03, GC_GRADE_Y04, GC_GRADE_Y05, GC_GRADE_Y06))
             OR (    p_grade_catgy         = GC_GRADE_CATGY_MID
                 AND aa.funding_school_lvl IN (GC_GRADE_Y07, GC_GRADE_Y08, GC_GRADE_Y09, GC_GRADE_Y10))
             OR (    p_grade_catgy         = GC_GRADE_CATGY_SEC
                 AND aa.funding_school_lvl IN (GC_GRADE_Y11, GC_GRADE_Y12))
            );
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_cnt);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_cnt;

END get_student_count;


/*****************************************************************************************
 MOD:03
 PURPOSE: Return ISN student count, with Funding Approval applications, summarised at the
    chosen level. A student is counted only if their application is eligible for state ISN
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
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_isn_student_count';

   v_cnt                     NUMBER(06) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (p_funding_year < 2016) THEN
      SELECT COUNT(*)
      INTO   v_cnt
      FROM   swd_active_appl_v aa
      WHERE  aa.appl_sts IN (GC_APPLSTS_FUNDAPPR)
      AND    aa.appl_adj_lvl_code = '4.2'
      AND    aa.funding_year = p_funding_year
      AND    aa.school_id    = p_school_id
      AND    aa.gender = DECODE(p_gender, GC_GENDER_MALE,   GC_GENDER_MALE
                                        , GC_GENDER_FEMALE, GC_GENDER_FEMALE
                                        , GC_GENDER_ALL,    aa.gender
                                        , '?')
      AND   (   (    p_grade_catgy         = GC_GRADE_CATGY_KINDY
                 AND aa.funding_school_lvl = '?') --No state funding, therefore no federal funding, for Kindy ISN prior to 2017
             OR  (    p_grade_catgy        = GC_GRADE_CATGY_PREPRIM
                  AND CASE
                      WHEN (p_funding_year < 2005) THEN
                         '?' --No state funding for Pre-Primary ISN prior to 2005
                      ELSE
                         GC_GRADE_PRE_PRIM
                      END = aa.funding_school_lvl)
             OR (    p_grade_catgy         = GC_GRADE_CATGY_PRIM
                 AND aa.funding_school_lvl IN (GC_GRADE_Y01, GC_GRADE_Y02, GC_GRADE_Y03, GC_GRADE_Y04, GC_GRADE_Y05, GC_GRADE_Y06, GC_GRADE_Y07))
             OR (    p_grade_catgy         = GC_GRADE_CATGY_SEC
                 AND aa.funding_school_lvl IN (GC_GRADE_Y08, GC_GRADE_Y09, GC_GRADE_Y10, GC_GRADE_Y11, GC_GRADE_Y12))
            );
   ELSE
      SELECT COUNT(*)
      INTO   v_cnt
      FROM   swd_active_appl_v aa
      WHERE  aa.appl_sts IN (GC_APPLSTS_FUNDAPPR)
      AND    aa.appl_adj_lvl_code = '4.2'
      AND    aa.funding_year = p_funding_year
      AND    aa.school_id    = p_school_id
      AND    aa.gender = DECODE(p_gender, GC_GENDER_MALE,        GC_GENDER_MALE
                                        , GC_GENDER_FEMALE,      GC_GENDER_FEMALE
                                        , GC_GENDER_UNSPECIFIED, GC_GENDER_UNSPECIFIED
                                        , GC_GENDER_ALL,         aa.gender
                                        , '?')
      AND   (   (    p_grade_catgy         = GC_GRADE_CATGY_KINDY
                 AND aa.funding_school_lvl = DECODE(p_funding_year, 2016, '?', GC_GRADE_KINDY)) --No state funding for Kindy ISN prior to 2017
             OR (    p_grade_catgy         = GC_GRADE_CATGY_PRIM
                 AND aa.funding_school_lvl IN (GC_GRADE_PRE_PRIM, GC_GRADE_Y01, GC_GRADE_Y02, GC_GRADE_Y03, GC_GRADE_Y04, GC_GRADE_Y05, GC_GRADE_Y06))
             OR (    p_grade_catgy         = GC_GRADE_CATGY_MID
                 AND aa.funding_school_lvl IN (GC_GRADE_Y07, GC_GRADE_Y08, GC_GRADE_Y09, GC_GRADE_Y10))
             OR (    p_grade_catgy         = GC_GRADE_CATGY_SEC
                 AND aa.funding_school_lvl IN (GC_GRADE_Y11, GC_GRADE_Y12))
            );
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_cnt);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_cnt;

END get_isn_student_count;


/*****************************************************************************************
 PURPOSE: Get the number of applications (or students) per school, or for all schools,
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
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_elig_funding_count';

   v_state_elig_flg          VARCHAR2(01) := UPPER(p_state_eligible_flg);
   v_fed_fund_flg            VARCHAR2(01) := UPPER(p_fed_funding_flg);
   v_isn_flg                 VARCHAR2(01) := UPPER(p_isn_flg);
   v_cnt                     NUMBER(06) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   SELECT COUNT(*)
   INTO   v_cnt
   FROM   swd_active_appl_v aa
   WHERE  aa.funding_year = p_funding_year
   AND    aa.school_id    = NVL(p_school_id, aa.school_id)
   AND   (   (    v_state_elig_flg   = 'N'
              AND aa.appl_sts        = GC_APPLSTS_NE)
          OR (    v_state_elig_flg   = 'Y'
              AND aa.appl_sts        = GC_APPLSTS_FUNDAPPR
              AND (   v_fed_fund_flg = 'A'
                   OR (    v_fed_fund_flg = 'Y'
                       AND aa.fed_govt_funding_excl_flg = 'N'
                       AND aa.appl_adj_lvl_code <> '0.0')
                   OR (    v_fed_fund_flg  = 'N'
                       AND aa.fed_govt_funding_excl_flg = 'Y')
                  )
              --MOD:03
              AND (   v_isn_flg = 'A'
                   OR (    v_isn_flg = 'Y'
                       AND aa.appl_adj_lvl_code  = '4.2')
                   OR (    v_isn_flg = 'N'
                       AND aa.appl_adj_lvl_code <> '4.2')
                  )
             ));

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_cnt);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_cnt;

END get_elig_funding_count;


/*****************************************************************************************
 MOD:03
 PURPOSE: Get the state funding rate.

    p_funding_type: R = Regular
                    I = Intensive Support Need
     p_grade_catgy: K = Kindy
                   PP = Pre-Primary
                    P = Primary
                    M = Middle
                    S = Secondary
 ****************************************************************************************/
FUNCTION get_state_fund_rate (p_funding_year     IN swd_state_per_capita_rate.funding_year%TYPE
                             ,p_funding_type     IN swd_state_per_capita_rate.funding_type%TYPE
                             ,p_grade_catgy      IN VARCHAR2
                             ,p_school_spc_catgy IN swd_state_per_capita_rate.state_funding_catgy%TYPE
                             ,p_school_id        IN NUMBER DEFAULT NULL)
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_state_fund_rate';

   v_fund_type               swd_state_per_capita_rate.funding_type%TYPE := UPPER(p_funding_type);
   v_grade_catgy             VARCHAR2(02) := UPPER(p_grade_catgy);
   v_school_spc_catgy        VARCHAR2(05) := UPPER(p_school_spc_catgy);
   v_rate                    swd_state_per_capita_rate.primary_amt%TYPE;

   CURSOR c_fund_rate (cp_fund_yr          IN NUMBER
                      ,cp_fund_type        IN VARCHAR2
                      ,cp_grade_catgy      IN VARCHAR2
                      ,cp_school_spc_catgy IN VARCHAR2) IS
      SELECT DECODE(cp_grade_catgy
                   ,GC_GRADE_CATGY_KINDY,   spcr.kindy_amt
                   ,GC_GRADE_CATGY_PREPRIM, spcr.primary_amt
                   ,GC_GRADE_CATGY_PRIM,    spcr.primary_amt
                   ,GC_GRADE_CATGY_MID,     spcr.middle_amt
                   ,GC_GRADE_CATGY_SEC,     spcr.secondary_amt) fund_rate
      FROM   swd_state_per_capita_rate spcr
      WHERE  spcr.funding_year = cp_fund_yr
      AND    spcr.funding_type = cp_fund_type
      AND    spcr.state_funding_catgy = cp_school_spc_catgy;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params fund_year='||p_funding_year||
      ' fund_type='||p_funding_type||' spc_catgy='||p_school_spc_catgy||' school_id='||
      p_school_id);

   IF (v_school_spc_catgy IS NULL) THEN
      v_school_spc_catgy := NVL(education.edu_utils.get_school_spc_catgy(p_school_id, p_funding_year), GC_DEFAULT_SPC_CATGY);
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'school SPC category='||v_school_spc_catgy);
   END IF;

   OPEN  c_fund_rate(p_funding_year, v_fund_type, v_grade_catgy, v_school_spc_catgy);
   FETCH c_fund_rate
   INTO  v_rate;
   IF c_fund_rate%NOTFOUND THEN
      pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No rate found');
      v_rate := 0;
   END IF;

   CLOSE c_fund_rate;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return rate='||v_rate);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_rate;

END get_state_fund_rate;


/*****************************************************************************************
 PURPOSE: Return the federal government funding amount for a student based on the
    allocated disability points and their FTE.
 ****************************************************************************************/
FUNCTION get_dpts_fte_amt_appl (p_funding_year  IN swd_application.funding_year%TYPE
                               ,p_appl_id       IN swd_application.appl_id%TYPE)
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_dpts_fte_amt_appl';

   v_dpts_amt                NUMBER (06) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params fund_year='||p_funding_year||
      ' appl_id='||p_appl_id);

   IF (p_funding_year < 2005) THEN
      SELECT TO_NUMBER(aa.appl_adj_lvl_code) / f.dpts_cutoff * f.dpts_value
      INTO   v_dpts_amt
      FROM   swd_active_appl_v aa
             INNER JOIN swd_funding_default f
                ON aa.funding_year = f.funding_year
      WHERE  aa.funding_year = p_funding_year
      AND    aa.appl_id      = p_appl_id
      AND    aa.appl_sts     = GC_APPLSTS_FUNDAPPR
      AND    aa.appl_adj_lvl_code <> '0.0'
      AND    aa.fed_govt_funding_excl_flg = 'N'
      AND    aa.funding_school_lvl NOT IN (GC_GRADE_3YO, GC_GRADE_KINDY);
   ELSE
      SELECT (DECODE (aa.appl_adj_lvl_code, '1.0', f.dpts_value_1
                                          , '1.1', f.dpts_value_1_1
                                          , '2.0', f.dpts_value_2
                                          , '2.1', f.dpts_value_2_1
                                          , '3.0', f.dpts_value_3
                                          , '3.1', f.dpts_value_3_1
                                          , '3.2', f.dpts_value_3_2
                                          , '3.3', f.dpts_value_3_3
                                          , '4.0', f.dpts_value_4
                                          , '4.1', f.dpts_value_4_1
                                          , '4.2', f.dpts_value_4_2_isn
                                          , 0)
              * aa.student_fte) dpts_value
      INTO   v_dpts_amt
      FROM   swd_active_appl_v aa
             INNER JOIN swd_funding_default f
                ON aa.funding_year = f.funding_year
      WHERE  aa.funding_year = p_funding_year
      AND    aa.appl_id      = p_appl_id
      AND    aa.appl_sts     = GC_APPLSTS_FUNDAPPR
      AND    aa.appl_adj_lvl_code <> '0.0' --unexpected value as meaning is 'Not Eligible'
      AND    aa.fed_govt_funding_excl_flg = 'N'
      AND    aa.funding_school_lvl NOT IN (GC_GRADE_3YO, GC_GRADE_KINDY);
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_dpts_amt);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN NVL(v_dpts_amt, 0);

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT
         ,'Application ineligible for funding calculation. Return 0');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;

END get_dpts_fte_amt_appl;


/*****************************************************************************************
 PURPOSE: Return the federal government funding amount for the selected disability point
    summarised at a school level.
    If p_dpts is null, calculate total federal funding. Only applicable from 2005.
 ****************************************************************************************/
FUNCTION get_dpts_fte_amt_school (p_funding_year IN swd_application.funding_year%TYPE
                                 ,p_school_id    IN swd_application.school_id%TYPE
                                 ,p_dpts         IN swd_application.appl_adj_lvl_code%TYPE)
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_dpts_fte_amt_school';

   v_dpts_amt                NUMBER (06) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   IF (p_funding_year < 2005) THEN
      SELECT SUM((TO_NUMBER(b.appl_adj_lvl_code) / f.dpts_cutoff * f.dpts_value)
                 * b.cnt)  dpts_amt
      INTO   v_dpts_amt
      FROM  (SELECT aa.funding_year
                   ,aa.appl_adj_lvl_code
                   ,COUNT(*) cnt
             FROM   swd_active_appl_v aa
             WHERE  aa.funding_year = p_funding_year
             AND    aa.school_id    = p_school_id
             AND    aa.appl_sts     = GC_APPLSTS_FUNDAPPR
             AND    aa.appl_adj_lvl_code <> '0.0' --unexpected value as meaning is 'Not Eligible'
             AND    aa.fed_govt_funding_excl_flg = 'N'
             AND    aa.funding_school_lvl NOT IN (GC_GRADE_3YO, GC_GRADE_KINDY)
             GROUP BY aa.funding_year, aa.appl_adj_lvl_code
            ) b
            INNER JOIN swd_funding_default f
                ON b.funding_year = f.funding_year;
   ELSE
      SELECT SUM((SELECT DECODE(b.appl_adj_lvl_code, '1.0', f.dpts_value_1
                                                   , '1.1', f.dpts_value_1_1
                                                   , '2.0', f.dpts_value_2
                                                   , '2.1', f.dpts_value_2_1
                                                   , '3.0', f.dpts_value_3
                                                   , '3.1', f.dpts_value_3_1
                                                   , '3.2', f.dpts_value_3_2
                                                   , '3.3', f.dpts_value_3_3
                                                   , '4.0', f.dpts_value_4
                                                   , '4.1', f.dpts_value_4_1
                                                   , '4.2', f.dpts_value_4_2_isn
                                                   , 0)
                  FROM   swd_funding_default f
                  WHERE  b.funding_year = f.funding_year)
                 * b.student_fte
                 * b.cnt)  dpts_amt
      INTO   v_dpts_amt
      FROM  (SELECT aa.funding_year
                   ,aa.appl_adj_lvl_code
                   ,aa.student_fte
                   ,COUNT(*) cnt
             FROM   swd_active_appl_v aa
             WHERE  aa.funding_year = p_funding_year
             AND    aa.school_id    = p_school_id
             AND    aa.appl_sts     = GC_APPLSTS_FUNDAPPR
             AND    aa.appl_adj_lvl_code = NVL(p_dpts, aa.appl_adj_lvl_code)
             AND    aa.appl_adj_lvl_code <> '0.0' --unexpected value as meaning is 'Not Eligible'
             AND    aa.fed_govt_funding_excl_flg = 'N'
             AND    aa.funding_school_lvl NOT IN (GC_GRADE_3YO, GC_GRADE_KINDY)
             GROUP BY aa.funding_year, aa.appl_adj_lvl_code, aa.student_fte
            ) b;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_dpts_amt);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN NVL(ROUND(v_dpts_amt), 0);

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No data found. Return 0');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;

END get_dpts_fte_amt_school;


/*****************************************************************************************
 MOD:03
 PURPOSE: Return the Weighted State Per Capita (WSPC) allocation amount for specified grade
    category in a school. Excludes Intensive Support Need (ISN) students by virtue of
    missing translation record in table SWD_APPL_ADJ_LVL_TRANSLATION.

    p_grade_catgy: K = Kindy
                  PP = Pre-Primary
                   P = Primary
                   M = Middle
                   S = Secondary
 ****************************************************************************************/
FUNCTION get_wspc_amt_school (p_funding_year  IN swd_application.funding_year%TYPE
                             ,p_school_id     IN swd_application.school_id%TYPE
                             ,p_grade_catgy   IN VARCHAR2)
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_wspc_amt_school';

   v_grade_catgy             VARCHAR2(02) := UPPER(p_grade_catgy);
   v_fund_type               VARCHAR2(01) := 'R'; --Regular
   v_school_spc_catgy        VARCHAR2(05);
   v_wspc_value              NUMBER (8,2) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params fund_year='||p_funding_year||
      ' school_id='||p_school_id||' grade_catgy='||v_grade_catgy);

   v_school_spc_catgy := NVL(education.edu_utils.get_school_spc_catgy(p_school_id, p_funding_year), GC_DEFAULT_SPC_CATGY);

   SELECT SUM(aalt.translation_lvl * r.spcr_rate) spc_tot_amt
   INTO   v_wspc_value
   FROM   swd_active_appl_v aa
          INNER JOIN swd_appl_adj_lvl_translation aalt
             ON  aa.appl_adj_lvl_code  = aalt.appl_adj_lvl_code
             AND aalt.translation_type = 'DPTS2SPC'
             AND p_funding_year BETWEEN EXTRACT(YEAR FROM aalt.eff_from_date) AND NVL(EXTRACT(YEAR FROM aalt.eff_to_date), GC_END_YEAR)
          INNER JOIN (SELECT ROWNUM
                            ,spcr.funding_year
                            ,spcr.state_funding_catgy
                            ,DECODE(v_grade_catgy, GC_GRADE_CATGY_KINDY,   spcr.kindy_amt
                                                 , GC_GRADE_CATGY_PREPRIM, spcr.primary_amt
                                                 , GC_GRADE_CATGY_PRIM,    spcr.primary_amt
                                                 , GC_GRADE_CATGY_MID,     spcr.middle_amt
                                                 , GC_GRADE_CATGY_SEC,     spcr.secondary_amt) spcr_rate
                      FROM   swd_state_per_capita_rate spcr
                      WHERE  spcr.funding_year = p_funding_year
                      AND    spcr.funding_type = v_fund_type) r
             ON  r.funding_year        = aa.funding_year
             AND r.state_funding_catgy = v_school_spc_catgy
   WHERE  aa.appl_sts     = GC_APPLSTS_FUNDAPPR
   AND    aa.funding_year = p_funding_year
   AND    aa.school_id    = p_school_id
   AND   (   (    p_funding_year < 2016
              AND REGEXP_INSTR(DECODE(v_grade_catgy, GC_GRADE_CATGY_KINDY,   'K4'
                                                   , GC_GRADE_CATGY_PREPRIM, 'PS'
                                                   , GC_GRADE_CATGY_PRIM,    'Y01, Y02, Y03, Y04, Y05, Y06, Y07'
                                                   , GC_GRADE_CATGY_SEC,     'Y08, Y09, Y10, Y11, Y12'
                                                   , NULL), '(^| )'||aa.funding_school_lvl||'($|,)', 1) > 0)
          OR (    p_funding_year >= 2016
              AND REGEXP_INSTR(DECODE(v_grade_catgy, GC_GRADE_CATGY_KINDY, 'K4'
                                                   , GC_GRADE_CATGY_PRIM,  'PS, Y01, Y02, Y03, Y04, Y05, Y06'
                                                   , GC_GRADE_CATGY_MID,   'Y07, Y08, Y09, Y10'
                                                   , GC_GRADE_CATGY_SEC,   'Y11, Y12'
                                                   , NULL), '(^| )'||aa.funding_school_lvl||'($|,)', 1) > 0)
         );

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||ROUND(v_wspc_value));
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN NVL(ROUND(v_wspc_value), 0);

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'No data found. Return 0.');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;
END get_wspc_amt_school;


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
RETURN NUMBER IS
   VC_SUBPROG_UNIT  CONSTANT VARCHAR2(30) := 'get_isn_state_amt_school';

   v_grade_catgy             VARCHAR2(02) := UPPER(p_grade_catgy);
   v_school_spc_catgy        VARCHAR2(05);
   v_isn_rate                swd_state_per_capita_rate.kindy_amt%TYPE := 0;
   v_reg_rate                swd_state_per_capita_rate.kindy_amt%TYPE := 0;
   v_isn_student_cnt         NUMBER(06)   := 0;
   v_isn_amt                 NUMBER(18,2) := 0;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Params fund_year='||p_funding_year||
      ' school_id='||p_school_id||' grade_catgy='||v_grade_catgy);

   --Order of evaluation matters!!
   IF  (v_grade_catgy = GC_GRADE_CATGY_KINDY)
   AND (p_funding_year < 2017) THEN
      v_isn_amt := 0; --No state funding for ISN Kindy prior to 2017

   ELSIF (v_grade_catgy = GC_GRADE_CATGY_PREPRIM)
   AND   (p_funding_year < 2005 OR p_funding_year > 2015) THEN
      --No state funding for ISN PP prior to 2005 and
      --PP rolled into Primary after 2015.
      v_isn_amt := 0;

   ELSIF (p_funding_year < 2015) THEN
      v_school_spc_catgy := NVL(education.edu_utils.get_school_spc_catgy(p_school_id, p_funding_year), GC_DEFAULT_SPC_CATGY);

      IF (v_grade_catgy = GC_GRADE_CATGY_ALL) THEN
         --Pre-Primary
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_PREPRIM);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_PREPRIM, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_student_cnt * v_isn_rate;
         --Primary
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_PRIM);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_PRIM, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_amt + (v_isn_student_cnt * v_isn_rate);
         --Secondary
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_SEC);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_SEC, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_amt + (v_isn_student_cnt * v_isn_rate);
      ELSE
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', v_grade_catgy);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', v_grade_catgy, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_student_cnt * v_isn_rate;
      END IF;

   ELSE
      v_school_spc_catgy := NVL(education.edu_utils.get_school_spc_catgy(p_school_id, p_funding_year), GC_DEFAULT_SPC_CATGY);

      IF (v_grade_catgy = GC_GRADE_CATGY_ALL) THEN
         --Kindy
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_KINDY);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_KINDY, v_school_spc_catgy, NULL);
         v_reg_rate := get_state_fund_rate (p_funding_year, 'R', GC_GRADE_CATGY_KINDY, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_student_cnt * (v_isn_rate - v_reg_rate);
         --Pre-Primary
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_PREPRIM);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_PREPRIM, v_school_spc_catgy, NULL);
         v_reg_rate := get_state_fund_rate (p_funding_year, 'R', GC_GRADE_CATGY_PREPRIM, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_amt + (v_isn_student_cnt * (v_isn_rate - v_reg_rate));
         --Primary
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_PRIM);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_PRIM, v_school_spc_catgy, NULL);
         v_reg_rate := get_state_fund_rate (p_funding_year, 'R', GC_GRADE_CATGY_PRIM, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_amt + (v_isn_student_cnt * (v_isn_rate - v_reg_rate));
         --Middle
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_MID);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_MID, v_school_spc_catgy, NULL);
         v_reg_rate := get_state_fund_rate (p_funding_year, 'R', GC_GRADE_CATGY_MID, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_amt + (v_isn_student_cnt * (v_isn_rate - v_reg_rate));
         --Secondary
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', GC_GRADE_CATGY_SEC);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', GC_GRADE_CATGY_SEC, v_school_spc_catgy, NULL);
         v_reg_rate := get_state_fund_rate (p_funding_year, 'R', GC_GRADE_CATGY_SEC, v_school_spc_catgy, NULL);
         v_isn_amt  := v_isn_amt + (v_isn_student_cnt * (v_isn_rate - v_reg_rate));
      ELSE
         v_isn_student_cnt := get_isn_student_count (p_funding_year, p_school_id, 'A', v_grade_catgy);
         v_isn_rate := get_state_fund_rate (p_funding_year, 'I', v_grade_catgy, v_school_spc_catgy, NULL);
         v_reg_rate := get_state_fund_rate (p_funding_year, 'R', v_grade_catgy, v_school_spc_catgy, NULL);
         v_isn_amt := v_isn_student_cnt * (v_isn_rate - v_reg_rate);
      END IF;
   END IF;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||ROUND(v_isn_amt));
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN NVL(ROUND(v_isn_amt), 0);

EXCEPTION
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Error! Returning 0. '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RETURN 0;
END get_isn_state_amt_school;


/*****************************************************************************************
 PURPOSE: Returns the total grant amount for a school in the selected year.

    p_rec_type: A = Student [A]pplication grant
                S = [S]chool grant
                E = [E]verything
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
RETURN NUMBER IS
   VC_SUBPROG_UNIT        CONSTANT VARCHAR2(30) := 'get_grant_total';

   VC_REC_TYPE_STU        CONSTANT VARCHAR2(01) := 'A';
   VC_REC_TYPE_SCHOOL     CONSTANT VARCHAR2(01) := 'S';
   VC_REC_TYPE_EVERYTHING CONSTANT VARCHAR2(01) := 'E';

   VC_GRANT_TYPE_CAPITAL  CONSTANT VARCHAR2(02) := 'CE';
   VC_GRANT_TYPE_DISC     CONSTANT VARCHAR2(02) := 'D';
   VC_GRANT_TYPE_SPG      CONSTANT VARCHAR2(02) := 'S';

   VC_AMT_TYPE_REQUEST    CONSTANT VARCHAR2(01) := 'R';
   VC_AMT_TYPE_ACTUAL     CONSTANT VARCHAR2(01) := 'A';

   v_grant_amt               swd_grant.request_amt%TYPE;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   SELECT NVL(SUM(b.grant_amt), 0)
   INTO   v_grant_amt
   FROM  (SELECT g.rec_type
                ,g.grant_year
                ,a.school_id
                ,DECODE(p_amt_type, VC_AMT_TYPE_REQUEST, g.request_amt
                                  , VC_AMT_TYPE_ACTUAL,  g.actual_amt) grant_amt
          FROM   swd_grant g
                 INNER JOIN swd_application a
                    ON  g.appl_id     = a.appl_id
                    AND g.rec_type    = 'A'
                    AND g.delete_date IS NULL
                    AND a.delete_date IS NULL
                    AND swd_funding_application.appl_been_revised(a.appl_id) = 'N' --MOD:03
                    AND g.grant_year  = p_grant_year
                    AND a.school_id   = p_school_id
                    AND p_rec_type IN (VC_REC_TYPE_STU, VC_REC_TYPE_EVERYTHING)
                    AND (   (    p_grant_type = VC_GRANT_TYPE_CAPITAL
                             AND g.grant_type IN ('C', 'E'))
                         OR (    p_grant_type = VC_GRANT_TYPE_DISC
                             AND g.grant_type = 'D')
                         OR (    p_grant_type = VC_GRANT_TYPE_SPG
                             AND g.grant_type = 'S'))
          UNION
          SELECT g.rec_type
                ,g.grant_year
                ,g.school_id
                ,DECODE(p_amt_type, VC_AMT_TYPE_REQUEST, g.request_amt
                                  , VC_AMT_TYPE_ACTUAL,  g.actual_amt) grant_amt
          FROM   swd_grant g
          WHERE  g.rec_type = 'S'
          AND    g.delete_date IS NULL
          AND    g.grant_year = p_grant_year
          AND    g.school_id  = p_school_id
          AND    p_rec_type IN (VC_REC_TYPE_SCHOOL, VC_REC_TYPE_EVERYTHING)
          AND   (   (    p_grant_type  = VC_GRANT_TYPE_CAPITAL
                      AND g.grant_type IN ('C', 'E'))
                 OR (    p_grant_type  = VC_GRANT_TYPE_DISC
                      AND g.grant_type = 'D')
                 OR (    p_grant_type  = VC_GRANT_TYPE_SPG
                      AND g.grant_type = 'S'))
         ) b;

   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Return '||v_grant_amt);
   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
   RETURN v_grant_amt;

END get_grant_total;


END swd_funding_calculation;
/
