BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DEACTIVATE_SWD_APPLICATIONS'
      ,start_date      => TO_TIMESTAMP_TZ('2021/03/01 00:00:00.000000 +08:00','yyyy/mm/dd hh24:mi:ss.ff tzh:tzm')
      ,repeat_interval => 'FREQ=WEEKLY;INTERVAL=1;BYDAY=TUE,SAT;BYHOUR=5;BYMINUTE=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'swd_funding_application.pr_deactivate_appl'
      ,comments        => 'Deactivate SWD funding applications based on student account deprovisioning.'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'MAX_FAILURES'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DEACTIVATE_SWD_APPLICATIONS'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DEACTIVATE_SWD_APPLICATIONS');
END;
/

BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
      ,start_date      => TO_TIMESTAMP_TZ('2021/03/19 13:00:00.000000 +08:00','yyyy/mm/dd hh24:mi:ss.ff tzh:tzm')
      ,repeat_interval => 'FREQ=MINUTELY;INTERVAL=30'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'dbms_mview.refresh'
      ,comments        => 'Refresh materialized view SWD_APPL_STATUS_OVERVIEW_MV'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'MAX_FAILURES'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,attribute => 'number_of_arguments'
     ,value     => 2);

  SYS.DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE
    ( job_name             => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,argument_position    => 1
     ,argument_value       => 'swd_appl_status_overview_mv');

  SYS.DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE
    ( job_name             => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV'
     ,argument_position    => 2
     ,argument_value       => '?');

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'REFRESH_SWD_APPL_STATUS_OVERVIEW_MV');
END;
/
