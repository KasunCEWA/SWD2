CREATE OR REPLACE PACKAGE swd_admin IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01     Date: 12-Mar-2021     Author: A Woo
 Created
 ******************************************************************************/

/*****************************************************************************************
 PURPOSE: Create a schedule for refreshing materialized views.
 ****************************************************************************************/
PROCEDURE pr_sched_mv_refresh (p_mv_name        IN VARCHAR2
                              ,p_refresh_method IN VARCHAR2
                              ,p_start_date     IN TIMESTAMP WITH TIME ZONE DEFAULT TRUNC(SYSDATE, 'MON')
                              ,p_frequency      IN VARCHAR2
                              ,p_interval       IN INTEGER   DEFAULT NULL
                              ,p_bymonthday     IN INTEGER   DEFAULT NULL
                              ,p_byday          IN VARCHAR2  DEFAULT NULL
                              ,p_byhour         IN NUMBER    DEFAULT NULL
                              ,p_byminute       IN NUMBER    DEFAULT NULL);

/*****************************************************************************************
 PURPOSE: Create a schedule for running pr_deactivate_appl.

 ****************************************************************************************/
PROCEDURE pr_sched_deactivation (p_byday    IN VARCHAR2
                                ,p_byhour   IN NUMBER
                                ,p_byminute IN NUMBER);

END swd_admin;
/
