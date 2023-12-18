CREATE OR REPLACE PACKAGE swd_security IS
/******************************************************************************

 Modification History
 --------------------
 MOD:01   Date: 18-Jun-2019   Author: A Woo
 Created
 MOD:02   Date: 13-JUL-2023   Author: K Samarasinghe
 #INC-15513 Introduced GC_ENVIRONMENT to record environment variable (P-Production, T-Testing, D-Development).
 ******************************************************************************/

  GC_ENVIRONMENT CONSTANT    VARCHAR2(10)  := CASE WHEN common.com_network_utils.get_env = 'P' THEN 'P' ELSE 'T' END; --MOD:02
/*****************************************************************************************
 PURPOSE: Set authorization flags which are declared as application items.
 ****************************************************************************************/
PROCEDURE pr_swd_authorizations;


END swd_security;
/
