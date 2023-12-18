CREATE OR REPLACE PACKAGE BODY swd_security IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01   Date: 18-Jun-2019   Author: A Woo
 Created
 MOD:02     Date: 13-JUL-2023     Author: K Samarasinghe
 #INC-15513 Incorporated with environment based LDAP security groups.
 ******************************************************************************/

   GC_APP_ALIAS      CONSTANT VARCHAR2(10) := 'SWD2';
   GC_PACKAGE        CONSTANT VARCHAR2(30) := 'SWD.SWD_SECURITY';
   GC_START          CONSTANT VARCHAR2(01) := 'S';
   GC_END            CONSTANT VARCHAR2(01) := 'E';
   --> MOD:02
   /*
   GC_AUTH_TEACHER   CONSTANT VARCHAR2(100) := 'cn=sg-8445-swd-teachers';
   GC_AUTH_PRINCIPAL CONSTANT VARCHAR2(100) := 'cn=sg-8445-swd-principals';
   GC_AUTH_CONSULT   CONSTANT VARCHAR2(100) := 'cn=sg-8445-swd-consultants';
   GC_AUTH_ADMIN     CONSTANT VARCHAR2(100) := 'cn=sg-8445-swd-administrators';
   */

   GC_AUTH_TEACHER   VARCHAR2(100) := CASE WHEN GC_ENVIRONMENT = 'P' THEN 'cn=sg-8445-swd-teachers'       ELSE 'cn=sg-8445-tst-swd-teachers'       END;
   GC_AUTH_PRINCIPAL VARCHAR2(100) := CASE WHEN GC_ENVIRONMENT = 'P' THEN 'cn=sg-8445-swd-principals'     ELSE 'cn=sg-8445-tst-swd-principals'     END;
   GC_AUTH_CONSULT   VARCHAR2(100) := CASE WHEN GC_ENVIRONMENT = 'P' THEN 'cn=sg-8445-swd-consultants'    ELSE 'cn=sg-8445-tst-swd-consultants'    END;
   GC_AUTH_ADMIN     VARCHAR2(100) := CASE WHEN GC_ENVIRONMENT = 'P' THEN 'cn=sg-8445-swd-administrators' ELSE 'cn=sg-8445-tst-swd-administrators' END;

   --< MOD:02
   g_indent_count             INTEGER := 0;


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
 PURPOSE: Set authorization flags which are declared as application items.
 ****************************************************************************************/
PROCEDURE pr_swd_authorizations IS

   VC_SUBPROG_UNIT   CONSTANT VARCHAR2(30)  := 'pr_swd_authorizations';

   v_groups                  com_utils.LDAPGroupColl;

BEGIN
   pr_debug_start_end (GC_START, VC_SUBPROG_UNIT);

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Default authorization flags to N');
   APEX_UTIL.SET_SESSION_STATE('F_AUTH_TEACHER','N');
   APEX_UTIL.SET_SESSION_STATE('F_AUTH_PRINCIPAL','N');
   APEX_UTIL.SET_SESSION_STATE('F_AUTH_CONSULT', 'N');
   APEX_UTIL.SET_SESSION_STATE('F_AUTH_ADMIN', 'N');

   pr_debug(COM_UTILS.GC_DEBUG_LVL2, VC_SUBPROG_UNIT, 'Get membership list for '||v('APP_USER'));
   v_groups := com_utils.get_member_of(v('APP_USER'));

   IF (v_groups.COUNT > 0) THEN
      FOR i IN v_groups.FIRST..v_groups.LAST LOOP
         pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Member of '||v_groups(i));

         --Expected group DNS format: cn=group name,ou=org_1,ou=org_2,ou=org_3,dc=cewa,dc=edu,dc=au
         CASE LOWER(SUBSTR(v_groups(i), 1, INSTR(v_groups(i), ',')-1))
         WHEN (GC_AUTH_TEACHER) THEN
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Set F_AUTH_TEACHER to Y');
            APEX_UTIL.SET_SESSION_STATE('F_AUTH_TEACHER','Y');

         WHEN (GC_AUTH_PRINCIPAL) THEN
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Set F_AUTH_PRINCIPAL to Y');
            APEX_UTIL.SET_SESSION_STATE('F_AUTH_PRINCIPAL','Y');

         WHEN (GC_AUTH_CONSULT) THEN
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Set F_AUTH_CONSULT to Y');
            APEX_UTIL.SET_SESSION_STATE('F_AUTH_CONSULT','Y');

         WHEN (GC_AUTH_ADMIN) THEN
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Set F_AUTH_ADMIN to Y');
            APEX_UTIL.SET_SESSION_STATE('F_AUTH_ADMIN','Y');

         ELSE
            pr_debug(COM_UTILS.GC_DEBUG_LVL3, VC_SUBPROG_UNIT, 'Not an applicable group');
         END CASE;
      END LOOP;
   END IF;

   pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

EXCEPTION
   WHEN OTHERS THEN
      pr_debug(COM_UTILS.GC_ERROR_LVL, VC_SUBPROG_UNIT, 'Exception! '||SQLERRM);
      pr_debug_start_end (GC_END, VC_SUBPROG_UNIT);

END pr_swd_authorizations;

END swd_security;
/
