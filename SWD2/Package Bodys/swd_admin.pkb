CREATE OR REPLACE PACKAGE BODY swd_admin IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01     Date: 12-Mar-2021     Author: A Woo
 Created
 ******************************************************************************/

   GC_APP_ALIAS     CONSTANT VARCHAR2(10) := 'SWD2';
   GC_PACKAGE       CONSTANT VARCHAR2(30) := 'SWD.SWD_ADMIN';
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
 PURPOSE: Build the repeat interval string for creating schedules.

 p_frequency  = (from Oracle documentation) YEARLY | MONTHLY | WEEKLY | DAILY | HOURLY |
                 MINUTELY | SECONDLY
 p_interval   = (positive integer representing recurrence) 1..99
 p_bymonthday = (day of the month) 1..31.
                Negative number counts backward e.g. "BYMONTHDAY=-1 means the last day of
                the month and BYMONTHDAY=-2 means the next to last day of the month".
 p_byday      = (day of the week) MON | TUE | WED | THU | FRI | SAT | SUN  or
                (number and day of the week) e.g 26 FRI with YEARLY frequency means
                26th Friday of the year or 4 THU with MONTHLY frequency means fourth
                Thursday of the month.
                Negative number counts backward e.g. -1 SUN with MONTHLY frequency means
                last Sunday of the month.
 p_byhour     = (the hour to run job) 0..23
 p_byminute   = (the minute to run job) 0..59
 ****************************************************************************************/
FUNCTION build_schedule_interval (p_frequency      IN VARCHAR2
                                 ,p_interval       IN INTEGER   DEFAULT 1
                                 ,p_bymonthday     IN INTEGER   DEFAULT NULL
                                 ,p_byday          IN VARCHAR2  DEFAULT NULL
                                 ,p_byhour         IN NUMBER    DEFAULT NULL
                                 ,p_byminute       IN NUMBER    DEFAULT NULL)
RETURN VARCHAR2 IS

   VC_SUBPROG_UNIT   CONSTANT VARCHAR2(30)  := 'build_schedule_interval';

   e_invalid_input            EXCEPTION;

   v_rpt_interval             VARCHAR2(200);

BEGIN
   --Validate frequency
   IF (UPPER(p_frequency) NOT IN ('YEARLY', 'MONTHLY', 'WEEKLY', 'DAILY', 'HOURLY'
                                 ,'MINUTELY', 'SECONDLY')) THEN
      RAISE e_invalid_input;
   END IF;

   --Validate repeat interval
   IF  (p_interval   IS NULL)
   AND (p_bymonthday IS NULL)
   AND (p_byday      IS NULL)
   AND (p_byhour     IS NULL)
   AND (p_byminute   IS NULL) THEN
      RAISE e_invalid_input;
   END IF;

   SELECT 'FREQ='||UPPER(p_frequency)||
          DECODE(NVL(p_interval, 0), 0, NULL, ';INTERVAL='||p_interval)||
          NVL2(p_bymonthday, ';BYMONTHDAY='||UPPER(p_bymonthday), NULL)||
          NVL2(p_byday,      ';BYDAY='||UPPER(p_byday), NULL)||
          NVL2(p_byhour,     ';BYHOUR='||p_byhour, NULL)||
          NVL2(p_byminute,   ';BYMINUTE='||p_byminute, NULL)
   INTO   v_rpt_interval
   FROM   DUAL;
   pr_debug (COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'repeat_interval='||v_rpt_interval);

   RETURN v_rpt_interval;

EXCEPTION
   WHEN e_invalid_input THEN
      RETURN NULL;
END build_schedule_interval;


/*****************************************************************************************
 PURPOSE: Create a schedule for refreshing materialized views.

 NB: See Oracle document on DBMS_SCHEDULER
    (https://docs.oracle.com/database/121/ARPLS/d_sched.htm) for valid parameter values.
 ****************************************************************************************/
PROCEDURE pr_sched_mv_refresh (p_mv_name        IN VARCHAR2
                              ,p_refresh_method IN VARCHAR2
                              ,p_start_date     IN TIMESTAMP WITH TIME ZONE DEFAULT TRUNC(SYSDATE, 'MON')
                              ,p_frequency      IN VARCHAR2
                              ,p_interval       IN INTEGER   DEFAULT NULL
                              ,p_bymonthday     IN INTEGER   DEFAULT NULL
                              ,p_byday          IN VARCHAR2  DEFAULT NULL
                              ,p_byhour         IN NUMBER    DEFAULT NULL
                              ,p_byminute       IN NUMBER    DEFAULT NULL) IS

   VC_SUBPROG_UNIT   CONSTANT VARCHAR2(30)  := 'pr_sched_mv_refresh';
   VC_SCHED_JOB_NAME CONSTANT VARCHAR2(128) := 'refresh_'||LOWER(p_mv_name);
   VC_PROC_NAME      CONSTANT VARCHAR2(60)  := 'dbms_mview.refresh';

   e_invalid_input            EXCEPTION;

   v_text                     VARCHAR2(200);
   v_rpt_interval             VARCHAR2(200);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);
   pr_debug (COM_UTILS.GC_DEBUG_LVL1, VC_SUBPROG_UNIT, 'Parameters are mv_name='
      ||p_mv_name||' method='||p_refresh_method
      ||' start_date='||TO_CHAR(p_start_date, 'DD-MON-YYYY HH24:MI:SS')
      ||' frequency='||p_frequency||' interval='||p_interval||' bymonthday='||p_bymonthday
      ||' byday='||p_byday||' byhour='||p_byhour||' byminute='||p_byminute);

   --Validate materialised view in the SWD schema.
   SELECT uo.object_name
   INTO   v_text
   FROM   user_objects uo
   WHERE  uo.object_type = 'MATERIALIZED VIEW'
   AND    uo.object_name = UPPER(p_mv_name);

   --Validate refresh method
   IF (UPPER(p_refresh_method) NOT IN ('A','C','F','P','?')) THEN
      v_text := 'Invalid refresh method. Valid methods are A, C, F, P or ?';
      RAISE e_invalid_input;
   END IF;

   --Build the repeat interval string
   v_rpt_interval := build_schedule_interval (p_frequency, p_interval
                        ,p_bymonthday, p_byday, p_byhour, p_byminute);

   DBMS_SCHEDULER.CREATE_JOB (job_name   => VC_SCHED_JOB_NAME
                             ,job_type   => 'STORED_PROCEDURE'
                             ,job_action => VC_PROC_NAME
                             ,number_of_arguments => 2
                             ,start_date => NVL(p_start_date, TRUNC(SYSDATE, 'MON'))
                             ,repeat_interval     => v_rpt_interval
                             ,enabled    => FALSE
                             ,auto_drop  => FALSE
                             ,comments   => 'Refresh materialized view '||UPPER(p_mv_name));

   --Set the refresh parameters.
   DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE (job_name          => VC_SCHED_JOB_NAME
                                         ,argument_position => 1
                                         ,argument_value    => p_mv_name);
   DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE (job_name          => VC_SCHED_JOB_NAME
                                         ,argument_position => 2
                                         ,argument_value    => p_refresh_method);

   --job will stop running when consecutive failure count reaches max_failures
   DBMS_SCHEDULER.SET_ATTRIBUTE (name=>VC_SCHED_JOB_NAME, attribute=>'max_failures', value=>3);

   DBMS_SCHEDULER.ENABLE (name=>VC_SCHED_JOB_NAME);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN e_invalid_input THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, v_text);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE_APPLICATION_ERROR (-20001, v_text);
   WHEN NO_DATA_FOUND THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Materialized View '||p_mv_name||' does not exist');
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE_APPLICATION_ERROR (-20002, 'Materialized View '||p_mv_name||' does not exist');
   WHEN OTHERS THEN
      pr_debug (COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);
      RAISE;
END pr_sched_mv_refresh;

/*****************************************************************************************
 PURPOSE: Create a schedule for running pr_deactivate_appl.

 NB: See Oracle document on DBMS_SCHEDULER
    (https://docs.oracle.com/database/121/ARPLS/d_sched.htm) for valid parameter values.
 ****************************************************************************************/
PROCEDURE pr_sched_deactivation (p_byday    IN VARCHAR2
                                ,p_byhour   IN NUMBER
                                ,p_byminute IN NUMBER) IS

   VC_SUBPROG_UNIT   CONSTANT VARCHAR2(30)  := 'pr_sched_deactivation';
   VC_SCHED_JOB_NAME CONSTANT VARCHAR2(128) := 'deactivate_swd_applications';
   VC_PROC_NAME      CONSTANT VARCHAR2(60)  := 'swd_funding_application.pr_deactivate_appl';

   v_rpt_interval             VARCHAR2(200);

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   --Build the repeat interval string
   v_rpt_interval := build_schedule_interval (p_frequency => 'WEEKLY'
                                             ,p_byday     => p_byday
                                             ,p_byhour    => p_byhour
                                             ,p_byminute  => p_byminute);

   DBMS_SCHEDULER.CREATE_JOB (job_name   => VC_SCHED_JOB_NAME
                             ,job_type   => 'STORED_PROCEDURE'
                             ,job_action => VC_PROC_NAME
                             ,number_of_arguments => 0
                             ,start_date => TRUNC(SYSDATE, 'MON')
                             ,repeat_interval     => v_rpt_interval
                             ,enabled    => TRUE
                             ,auto_drop  => FALSE
                             ,comments   => 'Deactivate SWD funding applications based on student account deprovisioning.');

   --job will stop running when consecutive failure count reaches max_failures
   DBMS_SCHEDULER.SET_ATTRIBUTE (name=>VC_SCHED_JOB_NAME, attribute=>'max_failures', value=>3);

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_sched_deactivation;

END swd_admin;
/
