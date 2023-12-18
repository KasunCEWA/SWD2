CREATE MATERIALIZED VIEW SWD_APPL_STATUS_OVERVIEW_MV
NOCACHE
LOGGING
NOCOMPRESS
NOPARALLEL
NO INMEMORY
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
WITH PRIMARY KEY
AS 
(
SELECT b.funding_year funding_year
      ,b.school_id    school_id
      ,b.appl_sts     appl_sts
      ,COUNT(*)       appl_sts_cnt
FROM  (SELECT a.funding_year  funding_year
             ,a.school_id     school_id
             ,swd_funding_application.get_appl_sts (a.appl_id)   appl_sts
       FROM  swd_application a
       WHERE a.funding_year >= (EXTRACT(YEAR FROM SYSDATE) - 2)  --MV is intended for frequent refreshes so limit data
       AND   a.delete_date   IS NULL
       AND   a.inactive_date IS NULL
       AND   NOT EXISTS (SELECT NULL
                         FROM   swd_application a2
                         WHERE  a2.related_appl_id = a.appl_id
                         AND    a2.delete_date IS NULL)
      ) b
GROUP BY b.funding_year, b.school_id, b.appl_sts
);
