CREATE OR REPLACE VIEW CEODB_DISABILITIES_V
BEQUEATH DEFINER
AS 
SELECT "STUDENT#","DIS_CAT_ID","SUB_CAT_ID","COMMENTS","DIS_LEVEL","PRIMARY_CONDITION","ID"
FROM   ceodb.disabilities@scioprod3;

CREATE OR REPLACE VIEW CEODB_STUDENTS_V
BEQUEATH DEFINER
AS 
SELECT "STUDENT#","SURNAME","FIRST_NAME","DOB","GENDER","CATHOLIC","STU_TYPE","ARCHIVED","ARCHIVE_DATE","CLOSE_DATE","NOTES"
FROM   ceodb.students@scioprod3;

CREATE OR REPLACE VIEW CEODB_STUDENT_DISABILITIES_V
BEQUEATH DEFINER
AS 
SELECT "STUDENT#","YEAR","DPTS","DPTS_STAR","PLACEMENT","HSN","TA_FTE","SHARED","SHARED_TA_INITIAL","SESA_SCORE","ID"
FROM   ceodb.student_disabilities@scioprod3;

CREATE OR REPLACE VIEW CEODB_STUDENT_SCHOOLS_V
BEQUEATH DEFINER
AS 
SELECT "SCHOOL#","STUDENT#","GRADE","START_DATE","END_DATE","ELIGIBLE","FUNDED","WBL","STU_FTE","STU_SUPPORT","ID"
FROM   ceodb.student_schools@scioprod3;

CREATE OR REPLACE VIEW CEODB_STUDENT_TEMP_V
BEQUEATH DEFINER
AS 
(
   SELECT s.student#            student#
         ,INITCAP(s.first_name) first_name
         ,UPPER(s.surname)      surname
         ,s.dob                 dob
         ,s.gender              gender
         ,s.notes               stu_notes
         ,(SELECT sc.school_id
           FROM   education.school sc
           WHERE  sc.ceowa_nbr = ss.school#) school_id
         ,EXTRACT(YEAR FROM ss.start_date)   school_year
         ,DECODE(ss.grade, 'PP', 'PP'
                         ,  'K',  'K'
                         ,  'Y'||LPAD(ss.grade, 2, '0')) grade
   FROM   ceodb.students s
          INNER JOIN ceodb.student_schools ss
             ON  s.student# = ss.student#
             AND ss.grade  <> 'EXIT'
);

CREATE OR REPLACE VIEW CEODB_SUB_DISABILITY_CATG_V
BEQUEATH DEFINER
AS 
SELECT "DIS_CAT_ID","SUB_CAT_ID","DESCRIPTION","ADDITIONAL_INFO","ID"
FROM   ceodb.sub_disability_categories@scioprod3;

CREATE OR REPLACE VIEW SWD_ACTIVE_APPL_V
BEQUEATH DEFINER
AS 
SELECT
/****************************************************************************************
 View of active applications only. Truncate CREATED_DATE to get application date.
 --
 Modification History
 --------------------
 MOD:01     Date: 13-SEP-2021     Author: A Woo
 Created
****************************************************************************************/
       a.appl_id
      ,a.funding_year
      ,a.state_student_nbr
      ,a.student_first_name
      ,a.student_surname
      ,a.dob
      ,a.gender
      ,a.school_id
      ,a.funding_school_lvl
      ,a.parent_consent_flg
      ,a.appl_adj_lvl_code
      ,a.appl_adj_lvl_comment
      ,a.nccd_catgy_code
      ,a.nccd_adj_lvl_code
      ,a.iap_curric_partcp_comment
      ,a.iap_curric_partcp_adj_lvl_code
      ,a.iap_commun_partcp_comment
      ,a.iap_commun_partcp_adj_lvl_code
      ,a.iap_mobility_comment
      ,a.iap_mobility_adj_lvl_code
      ,a.iap_personal_care_comment
      ,a.iap_personal_care_adj_lvl_code
      ,a.iap_soc_skills_comment
      ,a.iap_soc_skills_adj_lvl_code
      ,a.iap_safety_comment
      ,a.iap_safety_adj_lvl_code
      ,a.delete_date
      ,a.related_appl_id
      ,a.created_date
      ,a.inactive_date
      ,a.review_date
      ,a.review_comment
      ,a.student_fte
      ,a.fed_govt_funding_excl_flg
      ,a.legacy_student_id
      ,swd_funding_application.get_appl_sts(a.appl_id) appl_sts
FROM   swd_application a
WHERE  a.delete_date   IS NULL
AND    a.inactive_date IS NULL
AND    swd_funding_application.appl_been_revised(a.appl_id) = 'N';

CREATE OR REPLACE VIEW SWD_NDS_SCHOOLS_V
BEQUEATH DEFINER
AS 
SELECT SCHOOL_ID, SCHOOL_CODE
/****************************************************************************************
 View of Non-Diocesan Schools.
 --
 Modification History
 --------------------
 MOD:01     Date: 01-AUG-2023     Author: K Samarasinghe
 Created    #INC-23450,#INC-24279 To list Non-Diocesan Schools
****************************************************************************************/
FROM (
SELECT '47'  AS SCHOOL_ID, '8640' AS SCHOOL_CODE FROM DUAL -- Mercedes College
UNION
SELECT '107' AS SCHOOL_ID, '8030' AS SCHOOL_CODE FROM DUAL -- Santa Maria College
UNION
SELECT '19'  AS SCHOOL_ID, '8456' AS SCHOOL_CODE FROM DUAL -- St Brigid's College
UNION                             
SELECT '71'  AS SCHOOL_ID, '8191' AS SCHOOL_CODE FROM DUAL -- Newman College
UNION                             
SELECT '17'  AS SCHOOL_ID, '8450' AS SCHOOL_CODE FROM DUAL -- Mazenod College
UNION                             
SELECT '62'  AS SCHOOL_ID, '8745' AS SCHOOL_CODE FROM DUAL -- Servite College
UNION                             
SELECT '50'  AS SCHOOL_ID, '8660' AS SCHOOL_CODE FROM DUAL -- St Norbert College
UNION                             
SELECT '179' AS SCHOOL_ID, '8485' AS SCHOOL_CODE FROM DUAL -- Aquinas College
UNION                             
SELECT '153' AS SCHOOL_ID, '8270' AS SCHOOL_CODE FROM DUAL -- Christian Brothers College
UNION                             
SELECT '121' AS SCHOOL_ID, '8125' AS SCHOOL_CODE FROM DUAL -- Edmund Rice College
UNION                             
SELECT '197' AS SCHOOL_ID, '8288' AS SCHOOL_CODE FROM DUAL -- Geraldton Flexible Learning Centre
UNION                             
SELECT '86'  AS SCHOOL_ID, '8260' AS SCHOOL_CODE FROM DUAL -- Trinity College
UNION                             
SELECT '36'  AS SCHOOL_ID, '8550' AS SCHOOL_CODE FROM DUAL -- John XXIII College
UNION
SELECT '40'  AS SCHOOL_ID, '8580' AS SCHOOL_CODE FROM DUAL -- Loreto Nedlands;
);
