
-- ----------------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW   V_SERVER_GROUP_AND_SERVER_TRANSACTION   AS
    SELECT 
          sgt  .  grp_id   AS   grp_id  ,
          sgt  .  app_name   AS   app_name  ,
          sgt  .  serv_port   AS   serv_port  ,
          sgt  .  trans_proto   AS   trans_proto  ,
          sgt  .  cust_id   AS   cust_id  ,
          sgt  .  dept_id   AS   dept_id  ,
          ssit  .  management_ip   AS   management_ip  ,
          ssit  .  server_primary_ip   AS   server_primary_ip  
    FROM
        ((  server_group_tb     sgt  
        JOIN   server_group_transaction_tb     sgtt  )
        JOIN   server_status_information_tb     ssit  )
    WHERE
        ((  sgt  .  grp_id   =   sgtt  .  grp_id  )
            AND (  sgtt  .  server_id   =   ssit  .  id  ));
-- ----------------------------------------------------------------------------------------------------
CREATE 
    OR REPLACE
VIEW  V_PERMANENT_APPLICATION_INFO  AS
    SELECT DISTINCT
         avt . app_id  AS  app_id ,
         avt . app_name  AS  app_name ,
         avt . app_path  AS  app_path ,
         avt . compliance  AS  compliance ,
         avt . aliasAppName  AS  aliasAppName ,
         avt . md_checksum  AS  md_checksum ,
         avt . sha2  AS  sha2 ,
         avt . adpl_app_id  AS  adpl_app_id ,
         avt . container  AS  container ,
         aimgt . imageName  AS  app_image_name ,
         aimgt . imagePath  AS  app_image_path ,
         ct . cust_id  AS  cust_id ,
         ct . customer_name  AS  customer_name ,
         dt . dept_id  AS  dept_id ,
         dt . dept_name  AS  dept_name ,
         pait . server_port  AS  serv_port ,
         pait . protocol  AS  trans_proto ,
         pait . server_ip  AS  server_primary_ip ,
         avt . created_on  AS  create_date ,
         avt . modify_on  AS  modify_date ,
         ait . pid  AS  pid ,
         ait . isDeleted  AS  isDeleted ,
         sgto . grp_id  AS  grp_id ,
         sgto . app_name  AS  grp_name ,
         sgtt . server_id  AS  server_id ,
         ssit . management_ip  AS  management_ip ,
         ssit . server_name  AS  server_name ,
         ssit . app_group_name  AS  app_group_name ,
         ssit . active  AS  active ,
         ssit . server_state  AS  server_state ,
         ssit . server_secondary_ip1  AS  server_secondary_ip1 
    FROM
        ((((((((( customer_tb   ct 
        JOIN  department_tb   dt )
        JOIN  application_image_tb   aimgt )
        JOIN  application_verification_tb   avt )
        LEFT JOIN  permanent_app_info_tb   pait  ON ((( avt . cid  =  pait . customer_id )
            AND ( avt . did  =  pait . department_id )
            AND ( avt . adpl_app_id  =  pait . adpl_app_id ))))
        LEFT JOIN  server_group_tb   sgto  ON ((( pait . customer_id  =  sgto . cust_id )
            AND ( pait . department_id  =  sgto . dept_id )
            AND ( pait . server_port  =  sgto . serv_port )
            AND ( pait . protocol  =  sgto . trans_proto ))))
        LEFT JOIN  app_info_tb   ait  ON ((( pait . customer_id  =  ait . customer_id )
            AND ( pait . department_id  =  ait . department_id )
            AND ( pait . adpl_app_id  =  ait . adpl_app_id )
            AND ( pait . server_port  =  ait . server_port ))))
        LEFT JOIN  server_status_information_tb   ssit  ON (( pait . server_ip  =  ssit . server_primary_ip )))
        LEFT JOIN  server_group_transaction_tb   sgtt  ON (( ssit . id  =  sgtt . server_id )))
        LEFT JOIN  server_group_tb   sgt  ON (( sgtt . grp_id  =  sgt . grp_id )))
    WHERE
        (( ct . cust_id  =  avt . cid )
            AND ( dt . dept_id  =  avt . did )
            AND ( dt . cust_id  =  ct . cust_id )
            AND ( aimgt . id  =  avt . appImageId ));

-- ---------------------------------------------------------------------
CREATE OR REPLACE
VIEW V_APPLICATION_INFO AS
    select 
        sgt.grp_id AS grp_id,
        sgt.app_name AS grp_name,
        ait.customer_id AS cust_id,
        ct.customer_name AS customer_name,
        ait.department_id AS dept_id,
        dt.dept_name AS dept_name,
        ait.protocol AS trans_proto,
        ait.app_name AS app_name,
        ait.server_ip AS server_primary_ip,
        ait.server_port AS serv_port,
        ait.created_on AS create_date,
        ait.modify_on AS modify_date,
        ait.pid AS pid,
        ait.isDeleted AS isDeleted,
        ait.uuid AS uuid,
        ait.socket_uuid AS socket_uuid,
        sgtt.server_id AS server_id,
        ssit.management_ip AS management_ip,
        ssit.server_name AS server_name,
        ssit.app_group_name AS app_group_name,
        ssit.active AS active,
        ssit.server_state AS server_state,
        ssit.server_secondary_ip1 AS server_secondary_ip1,
        avt.aliasAppName AS aliasAppName,
        avt.md_checksum AS md_checksum,
        avt.sha2 AS sha2,
        avt.adpl_app_id AS adpl_app_id,
        avt.container AS container,
		aimgt.imageName AS app_image_name,
		aimgt.imagePath AS app_image_path,
		avt.app_id AS app_id,
		ait.proces_name AS app_path,
		avt.compliance AS compliance		
    from
        (((((((server_group_tb sgt
        join app_info_tb ait)
        join application_verification_tb avt)
        join server_status_information_tb ssit)
        join server_group_transaction_tb sgtt)
        join customer_tb ct)
        join department_tb dt)
		join application_image_tb aimgt)
    where  (
			(sgt.grp_id = sgtt.grp_id)
            and (sgtt.server_id = ssit.id)
            and (ct.cust_id = dt.cust_id)
            and (ct.cust_id = sgt.cust_id)
            and (dt.dept_id = sgt.dept_id)
            and (ait.customer_id = sgt.cust_id)
            and (ait.department_id = sgt.dept_id)
            and (ait.server_port = sgt.serv_port)
            and (ait.protocol = sgt.trans_proto)
            and (ait.server_ip = ssit.server_primary_ip)
            and (ait.adpl_app_id = avt.adpl_app_id)
            and (ait.customer_id = avt.cid)
            and (ait.department_id = avt.did)
			and (aimgt.id = avt.appImageId)
			);

-- server_group_transaction_tb
-- server_id, grp_id, created_on, modify_on, created_by, modify_by

CREATE OR REPLACE VIEW V_SERVER_GROUP_INFO AS 
select 
    sgt.grp_id AS grp_id,
    ct.cust_id AS cust_id,
    ct.customer_name AS customer_name,
    dt.dept_id AS dept_id,
    dt.dept_name AS dept_name,
    sgt.serv_port AS serv_port,
    sgt.trans_proto AS trans_proto,
    sgt.app_name AS app_name,
    sgtt.server_id AS server_id,
    ssit.management_ip AS management_ip,
    ssit.server_name AS server_name,
    ssit.app_group_name AS app_group_name,
    ssit.active AS active,
    ssit.server_state AS server_state,
    ssit.create_date AS create_date,
    ssit.modify_date AS modify_date,
    ssit.server_primary_ip AS server_primary_ip,
    ssit.server_secondary_ip1 AS server_secondary_ip1
from
    ((server_group_tb sgt join server_status_information_tb ssit) join server_group_transaction_tb sgtt) 
    join ( customer_tb ct join department_tb dt) 
ON
    ((sgt.grp_id = sgtt.grp_id)
        and (sgtt.server_id = ssit.id)
        and (ct.cust_id = dt.cust_id)
        and (ct.cust_id = sgt.cust_id)
        and (dt.dept_id = sgt.dept_id))
ORDER BY ct.cust_id, dt.dept_id,sgt.app_name,ssit.server_primary_ip;

-- client_stats_tb
-- client_stat_id, client_port, client_ip, send_count, recv_count, send_bytes, recv_bytes, recv_rejected_bytes, cust_dept_mismatch_count, sig_mismatch_count, security_prof_chng_count, manag_server_stat_id, pl_rej_policies, pl_rej_custid, pl_rej_depid, pl_rej_secsig, pl_allowed_policies, pl_allowed, pl_bytes_rej_policies, pl_bytes_rej_custid, pl_bytes_rej_depid, pl_bytes_rej_secsig, created_on, modify_on
CREATE OR REPLACE VIEW  V_SERVER_DESCRIPTORS  AS
    SELECT 
         sdt . dep_id  AS  dep_id ,
         sdt . cust_id  AS  cust_id ,
         sdt . adpl_app_id  AS  adpl_app_id ,
         sdt . app_name  AS  app_name ,
         sdt . process_name  AS  process_name ,
         sdt . pid  AS  pid ,
         sdt . server_count  AS  server_count ,
         sdt . created_on  AS  created_on ,
         sdt . modify_on  AS  modify_on ,
         sdt . uuid  AS  uuid ,
         sdt . socket_uuid  AS  socket_uuid ,
         sdt . protocol  AS  protocol ,
         sdt . server_port  AS  server_port ,
         sdt . server_ip  AS  server_ip ,
         sdt . conn_reject_count  AS  conn_reject_count ,
         sdt . create_timestamp  AS  create_timestamp ,
         sdt . client_count  AS  client_count ,
         sdt . sess_allowed  AS  sess_allowed ,
         sdt . sess_rejected  AS  sess_rejected ,
         sdt . sess_rej_policies  AS  sess_rej_policies ,
         sdt . sess_rej_custid  AS  sess_rej_custid ,
         sdt . sess_rej_depid  AS  sess_rej_depid ,
         sdt . sess_rej_sla  AS  sess_rej_sla ,
         sdt . sess_rej_osfails  AS  sess_rej_osfails ,
         sdt . close_reason  AS  close_reason
    FROM
         server_descriptor_tb   sdt ;

CREATE OR REPLACE VIEW  V_SERVER_CLIENT_DESCRIPTORS  AS
    SELECT 
         sdt . dep_id  AS  dep_id ,
         sdt . cust_id  AS  cust_id ,
         sdt . app_name  AS  app_name ,
         sdt . process_name  AS  process_name ,
         sdt . pid  AS  pid ,
         sdt . server_count  AS  server_count ,
         sdt . protocol  AS  protocol ,
         sdt . server_port  AS  server_port ,
         sdt . server_ip  AS  server_ip ,
         sdt . conn_reject_count  AS  conn_reject_count ,
         sdt . create_timestamp  AS  create_timestamp ,
         sdt . client_count  AS  client_count ,
         sdt . sess_allowed  AS  sess_allowed ,
         sdt . sess_rejected  AS  sess_rejected ,
         sdt . sess_rej_policies  AS  sess_rej_policies ,
         sdt . sess_rej_custid  AS  sess_rej_custid ,
         sdt . sess_rej_depid  AS  sess_rej_depid ,
         sdt . sess_rej_sla  AS  sess_rej_sla ,
         sdt . sess_rej_osfails  AS  sess_rej_osfails ,
         sdt . adpl_app_id  AS  adpl_app_id ,
         cdt . client_port  AS  client_port ,
         cdt . client_ip  AS  client_ip ,
         cdt . send_count  AS  send_count ,
         cdt . recv_count  AS  recv_count ,
         cdt . send_bytes  AS  send_bytes ,
         cdt . recv_bytes  AS  recv_bytes ,
         cdt . recv_rejected_bytes  AS  recv_rejected_bytes ,
         cdt . cust_dept_mismatch_count  AS  cust_dept_mismatch_count ,
         cdt . sig_mismatch_count  AS  sig_mismatch_count ,
         cdt . security_prof_chng_count  AS  security_prof_chng_count ,
         cdt . pl_rej_policies  AS  pl_rej_policies ,
         cdt . pl_rej_custid  AS  pl_rej_custid ,
         cdt . pl_rej_depid  AS  pl_rej_depid ,
         cdt . pl_rej_secsig  AS  pl_rej_secsig ,
         cdt . pl_allowed_policies  AS  pl_allowed_policies ,
         cdt . pl_allowed  AS  pl_allowed ,
         cdt . pl_bytes_rej_policies  AS  pl_bytes_rej_policies ,
         cdt . pl_bytes_rej_custid  AS  pl_bytes_rej_custid ,
         cdt . pl_bytes_rej_depid  AS  pl_bytes_rej_depid ,
         cdt . pl_bytes_rej_secsig  AS  pl_bytes_rej_secsig ,
         sdt . created_on  AS  created_on ,
         sdt . modify_on  AS  modify_on ,
         sdt . uuid  AS  uuid ,
         sdt . socket_uuid  AS  socket_uuid ,
         cdt . client_uuid AS client_uuid ,
         cdt . close_reason  AS  close_reason ,
         cdt . close_timestamp  AS  close_timestamp ,
         cdt . pl_rej_sqlinj  AS  pl_rej_sqlinj ,
         cdt . pl_bytes_rej_sqlinj  AS  pl_bytes_rej_sqlinj 
    FROM
        ( server_descriptor_tb   sdt 
        LEFT JOIN `client_descriptor_tb` `cdt` ON (((`sdt`.`uuid` = `cdt`.`server_uuid`)
            AND (`sdt`.`socket_uuid` = `cdt`.`server_socket_uuid`)))) ;


CREATE OR REPLACE VIEW  V_SERVER_STATS  AS
    SELECT 
         sst . dep_id  AS  dep_id ,
         sst . cust_id  AS  cust_id ,
         sst . app_name  AS  app_name ,
         sst . process_name  AS  process_name ,
         sst . pid  AS  pid ,
         sst . adpl_app_id  AS  adpl_app_id ,
         sst . server_count  AS  server_count ,
         sst . created_on  AS  created_on ,
         sst . modify_on  AS  modify_on ,
         sst . uuid  AS  uuid ,
         sst . socket_uuid  AS  socket_uuid ,
         sst . protocol  AS  protocol ,
         sst . server_port  AS  server_port ,
         sst . server_ip  AS  server_ip ,
         sst . conn_reject_count  AS  conn_reject_count ,
         sst . create_timestamp  AS  create_timestamp ,
         sst . client_count  AS  client_count ,
         sst . sess_allowed  AS  sess_allowed ,
         sst . sess_rejected  AS  sess_rejected ,
         sst . sess_rej_policies  AS  sess_rej_policies ,
         sst . sess_rej_custid  AS  sess_rej_custid ,
         sst . sess_rej_depid  AS  sess_rej_depid ,
         sst . sess_rej_sla  AS  sess_rej_sla ,
         sst . sess_rej_osfails  AS  sess_rej_osfails ,
         sst . close_reason  AS  close_reason  
    FROM
         server_stats_tb   sst ;

CREATE OR REPLACE VIEW  V_SERVER_CLIENT_STATS  AS
    SELECT 
         sst . dep_id  AS  dep_id ,
         sst . cust_id  AS  cust_id ,
         sst . app_name  AS  app_name ,
         sst . process_name  AS  process_name ,
         sst . pid  AS  pid ,
         sst . server_count  AS  server_count ,
         sst . protocol  AS  protocol ,
         sst . server_port  AS  server_port ,
         sst . server_ip  AS  server_ip ,
         sst . conn_reject_count  AS  conn_reject_count ,
         sst . create_timestamp  AS  create_timestamp ,
         sst . client_count  AS  client_count ,
         sst . sess_allowed  AS  sess_allowed ,
         sst . sess_rejected  AS  sess_rejected ,
         sst . sess_rej_policies  AS  sess_rej_policies ,
         sst . sess_rej_custid  AS  sess_rej_custid ,
         sst . sess_rej_depid  AS  sess_rej_depid ,
         sst . sess_rej_sla  AS  sess_rej_sla ,
         sst . sess_rej_osfails  AS  sess_rej_osfails ,
         sst . adpl_app_id  AS  adpl_app_id ,
         cst . client_port  AS  client_port ,
         cst . client_ip  AS  client_ip ,
         cst . send_count  AS  send_count ,
         cst . recv_count  AS  recv_count ,
         cst . send_bytes  AS  send_bytes ,
         cst . recv_bytes  AS  recv_bytes ,
         cst . recv_rejected_bytes  AS  recv_rejected_bytes ,
         cst . cust_dept_mismatch_count  AS  cust_dept_mismatch_count ,
         cst . sig_mismatch_count  AS  sig_mismatch_count ,
         cst . security_prof_chng_count  AS  security_prof_chng_count ,
         cst . pl_rej_policies  AS  pl_rej_policies ,
         cst . pl_rej_custid  AS  pl_rej_custid ,
         cst . pl_rej_depid  AS  pl_rej_depid ,
         cst . pl_rej_secsig  AS  pl_rej_secsig ,
         cst . pl_allowed_policies  AS  pl_allowed_policies ,
         cst . pl_allowed  AS  pl_allowed ,
         cst . pl_bytes_rej_policies  AS  pl_bytes_rej_policies ,
         cst . pl_bytes_rej_custid  AS  pl_bytes_rej_custid ,
         cst . pl_bytes_rej_depid  AS  pl_bytes_rej_depid ,
         cst . pl_bytes_rej_secsig  AS  pl_bytes_rej_secsig ,
         sst . created_on  AS  created_on ,
         sst . modify_on  AS  modify_on ,
         sst . uuid  AS  uuid ,
         sst . socket_uuid  AS  socket_uuid ,
         cst . client_uuid AS client_uuid ,
         cst . close_reason  AS  close_reason ,
         cst . close_timestamp  AS  close_timestamp ,
         cst . pl_rej_sqlinj  AS  pl_rej_sqlinj ,
         cst . pl_bytes_rej_sqlinj  AS  pl_bytes_rej_sqlinj 
    FROM
        ( server_stats_tb   sst 
        LEFT JOIN `client_stats_tb` `cst` ON (((`sst`.`uuid` = `cst`.`server_uuid`)
            AND (`sst`.`socket_uuid` = `cst`.`server_socket_uuid`)))) ;


CREATE OR REPLACE VIEW  V_SERVER_GROUP_AND_STATS  AS
    SELECT 
         SERVERS . grp_id  AS  grp_id ,
         SERVERS . server_id  AS  server_id ,
         SERVERS . management_ip  AS  management_ip ,
         SERVERS . server_name  AS  server_name ,
         SERVERS . app_group_name  AS  app_group_name ,
         SERVERS . active  AS  active ,
         SERVERS . server_state  AS  server_state ,
         SERVERS . server_primary_ip  AS  server_primary_ip ,
         SERVERS . server_secondary_ip1  AS  server_secondary_ip1 ,
         STATS . dep_id  AS  dep_id ,
         STATS . cust_id  AS  cust_id ,
         STATS . app_name  AS  app_name ,
         STATS . process_name  AS  process_name ,
         STATS . pid  AS  pid ,
         STATS . server_count  AS  server_count ,
         STATS . protocol  AS  protocol ,
         STATS . server_port  AS  server_port ,
         STATS . server_ip  AS  server_ip ,
         STATS . conn_reject_count  AS  conn_reject_count ,
         STATS . create_timestamp  AS  create_timestamp ,
         STATS . client_count  AS  client_count ,
         STATS . sess_allowed  AS  sess_allowed ,
         STATS . sess_rejected  AS  sess_rejected ,
         STATS . sess_rej_policies  AS  sess_rej_policies ,
         STATS . sess_rej_custid  AS  sess_rej_custid ,
         STATS . sess_rej_depid  AS  sess_rej_depid ,
         STATS . sess_rej_sla  AS  sess_rej_sla ,
         STATS . sess_rej_osfails  AS  sess_rej_osfails ,
         STATS . client_port  AS  client_port ,
         STATS . client_ip  AS  client_ip ,
         STATS . send_count  AS  send_count ,
         STATS . recv_count  AS  recv_count ,
         STATS . send_bytes  AS  send_bytes ,
         STATS . recv_bytes  AS  recv_bytes ,
         STATS . recv_rejected_bytes  AS  recv_rejected_bytes ,
         STATS . cust_dept_mismatch_count  AS  cust_dept_mismatch_count ,
         STATS . sig_mismatch_count  AS  sig_mismatch_count ,
         STATS . security_prof_chng_count  AS  security_prof_chng_count ,
         STATS . pl_rej_policies  AS  pl_rej_policies ,
         STATS . pl_rej_custid  AS  pl_rej_custid ,
         STATS . pl_rej_depid  AS  pl_rej_depid ,
         STATS . pl_rej_secsig  AS  pl_rej_secsig ,
         STATS . pl_allowed_policies  AS  pl_allowed_policies ,
         STATS . pl_allowed  AS  pl_allowed ,
         STATS . pl_bytes_rej_policies  AS  pl_bytes_rej_policies ,
         STATS . pl_bytes_rej_custid  AS  pl_bytes_rej_custid ,
         STATS . pl_bytes_rej_depid  AS  pl_bytes_rej_depid ,
         STATS . pl_bytes_rej_secsig  AS  pl_bytes_rej_secsig ,
         STATS . created_on  AS  created_on ,
         STATS . modify_on  AS  modify_on ,
         STATS . uuid  AS  uuid ,
         STATS . socket_uuid  AS  socket_uuid ,
         STATS . client_uuid AS client_uuid ,
         STATS . close_reason  AS  close_reason ,
         STATS . close_timestamp  AS  close_timestamp ,
         STATS . pl_rej_sqlinj  AS  pl_rej_sqlinj ,
         STATS . pl_bytes_rej_sqlinj  AS  pl_bytes_rej_sqlinj 
    FROM
        ( V_SERVER_CLIENT_STATS   STATS 
        JOIN  V_SERVER_GROUP_INFO   SERVERS )
    WHERE
        (( STATS . cust_id  =  SERVERS . cust_id )
            AND ( STATS . dep_id  =  SERVERS . dept_id )
            AND ( STATS . protocol  =  SERVERS . trans_proto )
            AND ( STATS . server_port  =  SERVERS . serv_port )
            AND ( STATS . server_ip  =  SERVERS . server_primary_ip ))
    ORDER BY  STATS . create_timestamp ;


CREATE OR REPLACE VIEW V_SERVER_LIST_FOR_POLICY AS
SELECT sgt.grp_id, sgt.cust_id, sgt.dept_id, sgt.serv_port, sgt.trans_proto,
sgtt.server_id, ssit.server_state , ssit.management_ip, ssit.server_primary_ip, 
ssit.server_secondary_ip1, ssit.server_secondary_ip2, ssit.server_secondary_ip3, ssit.server_secondary_ip4, 
ssit.server_secondary_ip5, ssit.server_secondary_ip6, ssit.server_secondary_ip7,
ait.id, ait.app_name, ait.pid, ait.isDeleted, ait.adpl_app_id
FROM server_group_tb sgt, server_status_information_tb ssit, server_group_transaction_tb sgtt, app_info_tb ait
WHERE sgt.grp_id = sgtt.grp_id
AND sgtt.server_id = ssit.id
AND sgt.cust_id = ait.customer_id 
AND sgt.dept_id = ait.department_id 
AND sgt.serv_port = ait.server_port 
AND sgt.trans_proto = ait.protocol 
AND ssit.server_primary_ip = ait.server_ip;

CREATE OR REPLACE VIEW  V_MANAGEMENT_IP_RANGE_INFO  AS
    SELECT 
         mpt . id  AS  id ,
         mpt . managment_IP_start  AS  managment_IP_start ,
         mpt . managment_IP_end  AS  managment_IP_end ,
         mpt . is_used  AS  is_used ,
         mpt . created_on  AS  created_on ,
         mpt . modify_on  AS  modify_on ,
         mpt . managment_IP_start_int  AS  managment_IP_start_int ,
         mpt . managment_IP_end_int  AS  managment_IP_end_int ,
         mpt . isIPv6  AS  isIPv6 ,
        COUNT(DISTINCT  ssit . management_ip ) AS  cnt 
    FROM
        ( managment_pool_tb   mpt 
        LEFT JOIN  server_status_information_tb   ssit  ON (( mpt . id  =  ssit . management_pool_id )))
    GROUP BY  mpt . id;

-- ------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW V_RPT_APP_INFO_AND_DATA_SECURITY_POLICY AS
    select 
        avt.app_id AS app_id,
        avt.app_name AS app_name,
        avt.md_checksum AS md_checksum,
        avt.app_path AS app_path,
        avt.adpl_enabled AS adpl_enabled,
        avt.sha2 AS sha2,
        avt.isMalware AS isMalware,
        avt.isMannual AS isMannual,
        avt.action AS action,
        avt.cid AS cid,
        avt.did AS did,
        avt.container AS container,
        avt.aliasAppName AS aliasAppName,
        avt.adpl_app_id AS adpl_app_id,
        avt.appImageId AS appImageId,
        avt.hostInfo AS hostInfo,
        dsp.policy_id AS policy_id,
        dsp.policy_name AS policy_name,
        dsp.action AS policy_action,
        dsp.status AS status,
        dsp.created_on AS created_on,
        dsp.modify_on AS modify_on,
        dsp.direction AS direction,
        dsp.app_name1 AS app_name1,
        dsp.app_name2 AS app_name2,
		ct.customer_name AS customer_name,
        dt.dept_name AS dept_name,
        ps.start_time AS policy_schedule_start_time,
        ps.end_time AS policy_schedule_end_time,
        ps.repeat_by AS policy_schedule_repeat_by,
        ps.repeat_count AS policy_schedule_repeat_count,
        ps.active_period AS active_period
    from
        ((((application_verification_tb avt
        join data_security_policy_tb dsp)
        join customer_tb ct)
        join department_tb dt)
        join policy_scheduler_tb ps ON ((dsp.policy_id = ps.policy_id)))
    where
        (((dsp.cust_id1 = avt.cid)
            and (dsp.dept_id1 = avt.did)
            and (dsp.adpl_app1_id = avt.adpl_app_id)
            and (dsp.cust_id1 = ct.cust_id)
            and (dsp.dept_id1 = dt.dept_id))
            or ((dsp.cust_id2 = avt.cid)
            and (dsp.dept_id2 = avt.did)
            and (dsp.adpl_app2_id = avt.adpl_app_id)
            and (dsp.cust_id2 = ct.cust_id)));
            
-- ---------------------------------------------------------------------------------

CREATE OR REPLACE VIEW V_RPT_APP_INFO_AND_APP_SECURE_POLICY AS
     select 
        avt.app_id AS app_id,
        avt.app_name AS app_name,
        avt.md_checksum AS md_checksum,
        avt.app_path AS app_path,
        avt.adpl_enabled AS adpl_enabled,
        avt.sha2 AS sha2,
        avt.isMalware AS isMalware,
        avt.isMannual AS isMannual,
        avt.action AS action,
        avt.cid AS cid,
        avt.did AS did,
        avt.container AS container,
        avt.aliasAppName AS aliasAppName,
        avt.adpl_app_id AS adpl_app_id,
        avt.appImageId AS appImageId,
        avt.hostInfo AS hostInfo,
        asp.policy_id AS policy_id,
        asp.policy_name AS policy_name,
        asp.action AS policy_action,
        asp.created_on AS created_on,
        asp.modify_on AS modify_on,
        asp.subaction AS subaction,
        asp.status AS status,
        asp.direction AS direction,
        asp.app_name1 AS app_name1,
        asp.app_name2 AS app_name2,
        ct.customer_name AS customer_name,
        dt.dept_name AS dept_name,
        ps.start_time AS policy_schedule_start_time,
        ps.end_time AS policy_schedule_end_time,
        ps.repeat_by AS policy_schedule_repeat_by,
        ps.repeat_count AS policy_schedule_repeat_count,
        ps.active_period AS active_period
    from
        ((((application_verification_tb avt
        join application_security_policy_tb asp)
        join customer_tb ct)
        join department_tb dt)
        left join policy_scheduler_tb ps ON ((asp.policy_id = ps.policy_id)))
    where
        (((asp.cust_id1 = avt.cid)
            and (asp.dept_id1 = avt.did)
            and (asp.adpl_app1_id = avt.adpl_app_id)
            and (asp.cust_id1 = ct.cust_id)
            and (asp.dept_id1 = dt.dept_id))
            or ((asp.cust_id2 = avt.cid)
            and (asp.dept_id2 = avt.did)
            and (asp.adpl_app2_id = avt.adpl_app_id)
            and (asp.cust_id2 = ct.cust_id)
            and (asp.dept_id2 = dt.dept_id)));
            
-- ---------------------------------------------------------------------------------

    CREATE OR REPLACE VIEW  V_RPT_DATA_SECURE_POLICY_SCHEDULE  AS
    SELECT 
         dsp . policy_id  AS  policy_id ,
         dsp . policy_name  AS  policy_name ,
         dsp . action  AS  policy_action ,
         dsp . cust_id1  AS  cust_id1 ,
         dsp . dept_id1  AS  dept_id1 ,
         dsp . cust_id2  AS  cust_id2 ,
         dsp . dept_id2  AS  dept_id2 ,
         dsp . app_name1  AS  app_name1 ,
         dsp . app_name2  AS  app_name2 ,
         dsp . app_ip1  AS  app_ip1 ,
         dsp . app_ip2  AS  app_ip2 ,
         dsp . app1_ports  AS  app1_ports ,
         dsp . app2_ports  AS  app2_ports ,
         dsp . protocol1  AS  protocol1 ,
         dsp . protocol2  AS  protocol2 ,
         dsp . direction  AS  direction ,
         dsp . status  AS  policy_status ,
         dsp . created_on  AS  created_on ,
         dsp . modify_on  AS  modify_on ,
         dsp . adpl_app1_id  AS  adpl_app1_id ,
         dsp . adpl_app2_id  AS  adpl_app2_id ,
         dsp . app1_alias_name  AS  app1_alias_name ,
         dsp . app2_alias_name  AS  app2_alias_name ,
         dsp . created_by AS created_by,
         dsp . modified_by AS modified_by,
         ps . schedule_id  AS  schedule_id ,
         ps . start_time  AS  policy_schedule_start_time ,
         ps . end_time  AS  policy_schedule_end_time ,
         ps . action  AS  schedule_action ,
         ps . misc  AS  misc ,
         ps . comment  AS  schedule_comment ,
         ps . policy_type  AS  policy_type ,
         ps . repeat_by  AS  policy_schedule_repeat_by ,
         ps . repeat_count  AS  policy_schedule_repeat_count ,
         ps . next_schedule_time  AS  next_schedule_time ,
         ps . schedule_state  AS  schedule_state ,
         ps . time_zone  AS  time_zone ,
         ps . active_period  AS  active_period 
    FROM
        ( data_security_policy_tb   dsp 
        LEFT JOIN  policy_scheduler_tb   ps  ON ((( dsp . policy_id  =  ps . policy_id )
            AND (LOWER( ps . policy_type ) = 'secure-data'))));
            
-- --------------------------------------------------------------------------------

    CREATE OR REPLACE VIEW  V_RPT_APP_SECURE_POLICY_SCHEDULE  AS
    SELECT 
         asp . policy_id  AS  policy_id ,
         asp . policy_name  AS  policy_name ,
         asp . action  AS  policy_action ,
         asp . subaction  AS  subaction ,
         asp . cust_id1  AS  cust_id1 ,
         asp . dept_id1  AS  dept_id1 ,
         asp . cust_id2  AS  cust_id2 ,
         asp . dept_id2  AS  dept_id2 ,
         asp . app_name1  AS  app_name1 ,
         asp . app_name2  AS  app_name2 ,
         asp . app_ip1  AS  app_ip1 ,
         asp . app_ip2  AS  app_ip2 ,
         asp . app1_ports  AS  app1_ports ,
         asp . app2_ports  AS  app2_ports ,
         asp . protocol1  AS  protocol1 ,
         asp . protocol2  AS  protocol2 ,
         asp . direction  AS  direction ,
         asp . status  AS  policy_status ,
         asp . created_on  AS  created_on ,
         asp . modify_on  AS  modify_on ,
         asp . adpl_app1_id  AS  adpl_app1_id ,
         asp . adpl_app2_id  AS  adpl_app2_id ,
         asp . app1_alias_name  AS  app1_alias_name ,
         asp . app2_alias_name  AS  app2_alias_name ,
         asp . created_by AS created_by,
         asp . modified_by AS modified_by,
         ps . schedule_id  AS  schedule_id ,
         ps . start_time  AS  policy_schedule_start_time ,
         ps . end_time  AS  policy_schedule_end_time ,
         ps . action  AS  schedule_action ,
         ps . misc  AS  misc ,
         ps . comment  AS  schedule_comment ,
         ps . policy_type  AS  policy_type ,
         ps . repeat_by  AS  policy_schedule_repeat_by ,
         ps . repeat_count  AS  policy_schedule_repeat_count ,
         ps . next_schedule_time  AS  next_schedule_time ,
         ps . schedule_state  AS  schedule_state ,
         ps . time_zone  AS  time_zone ,
         ps . active_period  AS  active_period 
    FROM
        ( application_security_policy_tb   asp 
        LEFT JOIN  policy_scheduler_tb   ps  ON ((( asp . policy_id  =  ps . policy_id )
            AND (LOWER( ps . policy_type ) = 'application-security'))));
            
            
-- --------------------------------------------------------------------------------------
 
CREATE 
   OR REPLACE
VIEW  V_RPT_APP_STAT_BY_APP_INFO  AS
    SELECT 
         vai . grp_id  AS  grp_id ,
         vai . cust_id  AS  cust_id ,
         vai . app_id  AS  app_id ,
         vai . customer_name  AS  customer_name ,
         vai . dept_id  AS  dept_id ,
         vai . dept_name  AS  dept_name ,
         vai . trans_proto  AS  trans_proto ,
         vai . app_name  AS  app_name ,
         vai . app_path  AS  app_path ,
         vai . server_primary_ip  AS  server_primary_ip ,
         vai . serv_port  AS  serv_port ,
         vai . pid  AS  pid ,
         vai . isDeleted  AS  isDeleted ,
         vai . management_ip  AS  management_ip ,
         vai . aliasAppName  AS  aliasAppName ,
         vai . md_checksum  AS  md_checksum ,
         vai . sha2  AS  sha2 ,
         vai . adpl_app_id  AS  adpl_app_id ,
         vai . container  AS  container ,
         vai . app_image_name  AS  app_image_name ,
         vai . app_image_path  AS  app_image_path ,
         vscd . conn_reject_count  AS  conn_reject_count ,
         vscd . client_count  AS  client_count ,
         vscd . sess_allowed  AS  sess_allowed ,
         vscd . sess_rejected  AS  sess_rejected ,
         vscd . sess_rej_policies  AS  sess_rej_policies ,
         vscd . sess_rej_custid  AS  sess_rej_custid ,
         vscd . sess_rej_depid  AS  sess_rej_depid ,
         vscd . sess_rej_sla  AS  sess_rej_sla ,
         vscd . sess_rej_osfails  AS  sess_rej_osfails ,
         vscd . client_port  AS  client_port ,
         vscd . client_ip  AS  client_ip ,
         vscd . send_count  AS  send_count ,
         vscd . recv_count  AS  recv_count ,
         vscd . send_bytes  AS  send_bytes ,
         vscd . recv_bytes  AS  recv_bytes ,
         vscd . recv_rejected_bytes  AS  recv_rejected_bytes ,
         vscd . cust_dept_mismatch_count  AS  cust_dept_mismatch_count ,
         vscd . sig_mismatch_count  AS  sig_mismatch_count ,
         vscd . security_prof_chng_count  AS  security_prof_chng_count ,
         vscd . pl_rej_policies  AS  pl_rej_policies ,
         vscd . pl_rej_custid  AS  pl_rej_custid ,
         vscd . pl_rej_depid  AS  pl_rej_depid ,
         vscd . pl_rej_secsig  AS  pl_rej_secsig ,
         vscd . pl_rej_sqlinj  AS  pl_rej_sqlinj ,
         vscd . pl_allowed_policies  AS  pl_allowed_policies ,
         vscd . pl_allowed  AS  pl_allowed ,
         vscd . pl_bytes_rej_policies  AS  pl_bytes_rej_policies ,
         vscd . pl_bytes_rej_custid  AS  pl_bytes_rej_custid ,
         vscd . pl_bytes_rej_depid  AS  pl_bytes_rej_depid ,
         vscd . pl_bytes_rej_secsig  AS  pl_bytes_rej_secsig ,
         vscd . pl_bytes_rej_sqlinj  AS  pl_bytes_rej_sqlinj ,
         vscd . close_reason  AS  close_reason ,
         vscd . close_timestamp  AS  close_timestamp ,
         vscd . created_on  AS  created_on ,
         vscd . modify_on  AS  modify_on ,
         vscd . uuid  AS  uuid ,
         vscd . socket_uuid  AS  socket_uuid ,
         vscd . client_uuid AS client_uuid 
    FROM
        ( V_PERMANENT_APPLICATION_INFO   vai 
        LEFT JOIN  V_SERVER_CLIENT_DESCRIPTORS   vscd  ON ((( vscd . cust_id  =  vai . cust_id )
            AND ( vscd . dep_id  =  vai . dept_id )
            AND ( vscd . server_port  =  vai . serv_port )
            AND ( vscd . protocol  =  vai . trans_proto )
            AND ( vscd . adpl_app_id  =  vai . adpl_app_id ))));
-- ---------------------------------------------------------------------------------

            CREATE OR REPLACE VIEW  V_DETECTED_REGISTERED_APPS  AS
    		SELECT 
		         dat . id  AS  id ,
		         dat . appName  AS  appName ,
		         dat . appPath  AS  appPath ,
		         dat . mdCheckSum  AS  mdCheckSum ,
		         dat . sha256  AS  sha256 ,
		         dat . action  AS  action ,
		         dat . serverIp  AS  serverIp ,
		         dat . hostname  AS  hostname ,
		         dat . pid  AS  pid ,
		         dat . cid  AS  cid ,
		         dat . did  AS  did ,
		         dat . protocol  AS  protocol ,
		         dat . port  AS  port ,
		         dat . isADPLEnabled  AS  isADPLEnabled ,
		         dat . isMalware  AS  isMalware ,
		         dat . isRegister  AS  isRegister ,
		         dat . isDuplicate  AS  isDuplicate ,
		         dat . isByPass  AS  isByPass ,
		         dat . created_on  AS  created_on ,
		         dat . modify_on  AS  modify_on ,
		         dat . container  AS  container ,
		         dat . avcdLicence  AS  avcdLicence ,
		         dat . aliasAppName  AS  aliasAppName ,
		         dat . adplAppId  AS  adplAppId ,
		         dat . appImageId  AS  appImageId ,
		         dat . hostInfo  AS  hostInfo ,
		         dat . compliance  AS  compliance ,
		        IFNULL( avt . isMannual , 0) AS  isMannual 
		    FROM
		        ( detected_application_tb   dat 
		        LEFT JOIN  application_verification_tb   avt  ON (( dat . id  =  avt . app_id )));
		        
-- ---------------------------------------------------------------------------------------------

CREATE OR REPLACE
VIEW  V_APP_INFO_AND_APP_INFO_INSTANCE  AS
    SELECT 
         pait . app_name  AS  app_name ,
         pait . proces_name  AS  proces_name ,
         pait . server_port  AS  server_port ,
         pait . customer_id  AS  customer_id ,
         pait . department_id  AS  department_id ,
         pait . protocol  AS  protocol ,
         pait . adpl_app_id  AS  adpl_app_id ,
         pait . server_ip  AS  server_ip ,
         ait . pid  AS  pid ,
         ait . uuid  AS  uuid ,
         ait . socket_uuid  AS  socket_uuid ,
         ait . isDeleted  AS  isDeleted ,
         ait . is_child  AS  is_child ,
         cit . customer_name  AS  customer_name ,
         dit . dept_name  AS  dept_name 
    FROM
        (( customer_tb   cit 
        JOIN  department_tb   dit  ON (cit.cust_id = dit.cust_id))
        JOIN ( permanent_app_info_tb   pait 
        LEFT JOIN  app_info_tb   ait  ON (( pait . customer_id  =  ait . customer_id )
            AND ( pait . department_id  =  ait . department_id )
            AND ( pait . adpl_app_id  =  ait . adpl_app_id )
            AND ( pait . server_ip = ait . server_ip)
            AND ( pait . server_port = ait . server_port)
            AND ( pait . protocol = ait . protocol))))
    WHERE
        (( cit . cust_id  =  pait . customer_id )
            AND ( dit . dept_id  =  pait . department_id ));
            
-- -----------------------------------------------------------------------------------------------

            
            
-- ---------------------------------------------------------------------------------
/* Below VIEWS are no longer used 
   Will be removed in next release
*/
-- ---------------------------------------------------------------------------------
/*
-- Connection Allowed Rejected Count
CREATE OR REPLACE VIEW V_CONN_ALLOWED_REJECTED_COUNT AS
SELECT 
	create_timestamp,
	sum(sess_allowed) Conn_Allowed_Session,
	sum(sess_rejected) Conn_Rejected_Session
		FROM V_SERVER_STATS, V_SERVER_GROUP_INFO 
		WHERE V_SERVER_STATS.cust_id  =  V_SERVER_GROUP_INFO.cust_id
		AND	V_SERVER_STATS.dep_id = V_SERVER_GROUP_INFO.dept_id
		AND V_SERVER_STATS.protocol = V_SERVER_GROUP_INFO.trans_proto
		AND V_SERVER_STATS.server_port = V_SERVER_GROUP_INFO.serv_port
		
		AND V_SERVER_STATS.manag_stat_id IN (SELECT max(V_SERVER_STATS.manag_stat_id) manag_stat_id FROM V_SERVER_STATS GROUP BY V_SERVER_STATS.cust_id, V_SERVER_STATS.dep_id, V_SERVER_STATS.protocol, V_SERVER_STATS.server_port, V_SERVER_STATS.server_ip, V_SERVER_STATS.pid)
		GROUP BY V_SERVER_STATS.create_timestamp 
		ORDER BY V_SERVER_STATS.create_timestamp DESC;

-- Connection Rejected Count
CREATE OR REPLACE VIEW V_CONN_REJECTED_COUNT AS
select 
	create_timestamp,
	sum(server_stats_tb.sess_rejected) Conn_Rejected_Session
		from server_stats_tb 
		group by create_timestamp ;

-- Connection Allowed Count
CREATE OR REPLACE VIEW V_CONN_ALLOWED_COUNT AS
select 
	create_timestamp,
	sum(sess_allowed) Conn_Allowed_Session
		from server_stats_tb 
		group by create_timestamp ;

-- Top 10 Connection Rejected Count
CREATE OR REPLACE VIEW V_TOP10_CONN_REJECTED_COUNT AS
select 
	create_timestamp,
	sum(sess_rejected) Conn_Rejected_Session
		from server_stats_tb 
		group by create_timestamp 
		order by Conn_Rejected_Session desc LIMIT 10;

-- Top 10 Connection Allowed Count
CREATE OR REPLACE VIEW V_TOP10_CONN_ALLOWED_COUNT AS
select 
	create_timestamp,
	sum(sess_allowed) Conn_Allowed_Session
		from server_stats_tb 
		group by create_timestamp 
		order by Conn_Allowed_Session desc LIMIT 10;


-- Donut Chart Protected Servers Data
CREATE OR REPLACE VIEW V_DONUT_CHART_TOTAL_PROTECTED_COUNT AS
select count(active) Total_Servers, sum(active) Protected_Servers from server_status_information_tb;

-- Events Query
CREATE OR REPLACE VIEW V_CONN_EVENTS_COUNT AS
select  
app_name, id, management_ip, sum(sess_allowed) allowed, sum(sess_rejected) blocked
from server_status_information_tb, server_group_tb, server_group_transaction_tb, server_stats_tb
where server_group_tb.grp_id = server_group_transaction_tb.grp_id 
AND server_status_information_tb.id = server_group_transaction_tb.server_id
AND server_ip = management_ip 
GROUP BY app_name ;

-- Latest STATS ID per Session
CREATE OR REPLACE VIEW V_LATEST_SERVER_STATSID_SESSION AS
SELECT cust_id, dep_id, protocol, server_port, server_ip, pid, max(manag_stat_id) manag_stat_id FROM V_SERVER_STATS 
GROUP BY cust_id, dep_id, protocol, server_port, server_ip, pid;

-- Latest STATS ID per Server
CREATE OR REPLACE VIEW V_LATEST_SERVER_STATSID_SERVER AS
SELECT cust_id, dep_id, protocol, server_port, server_ip, max(manag_stat_id) manag_stat_id FROM V_SERVER_STATS 
GROUP BY cust_id, dep_id, protocol, server_port, server_ip;

-- Latest STATS ID per Application Server Group
CREATE OR REPLACE VIEW V_LATEST_SERVER_STATSID_GROUP AS
SELECT cust_id, dep_id, protocol, server_port,  max(manag_stat_id) manag_stat_id FROM V_SERVER_STATS 
GROUP BY cust_id, dep_id, protocol, server_port;

-- Latest STATS ID per Application Dept
CREATE OR REPLACE VIEW V_LATEST_SERVER_STATSID_DEPT AS
SELECT cust_id, dep_id, max(manag_stat_id) manag_stat_id FROM V_SERVER_STATS 
GROUP BY cust_id, dep_id;

-- Latest STATS ID per Application Cust
CREATE OR REPLACE VIEW V_LATEST_SERVER_STATSID_CUST AS
SELECT cust_id, max(manag_stat_id) manag_stat_id FROM V_SERVER_STATS 
GROUP BY cust_id;

-- Latest STATS ID per Session - Client
CREATE OR REPLACE VIEW V_LATEST_SERVER_CLIENT_STATSID_SESSION AS
SELECT cust_id, dep_id, protocol, server_port, server_ip, pid, max(manag_stat_id) manag_stat_id 
FROM V_SERVER_CLIENT_STATS GROUP BY cust_id, dep_id, protocol, server_port, server_ip, pid;

-- Latest STATS ID per Server - Client
CREATE OR REPLACE VIEW V_LATEST_SERVER_CLIENT_STATSID_SERVER AS
SELECT cust_id, dep_id, protocol, server_port, server_ip, max(manag_stat_id) manag_stat_id 
FROM V_SERVER_CLIENT_STATS GROUP BY cust_id, dep_id, protocol, server_port, server_ip;

-- Latest STATS ID per Application Server Group - Client
CREATE OR REPLACE VIEW V_LATEST_SERVER_CLIENT_STATSID_GROUP AS
SELECT cust_id, dep_id, protocol, server_port,  max(manag_stat_id) manag_stat_id 
FROM V_SERVER_CLIENT_STATS GROUP BY cust_id, dep_id, protocol, server_port;

-- Latest STATS ID per Application Dept - Client
CREATE OR REPLACE VIEW V_LATEST_SERVER_CLIENT_STATSID_DEPT AS
SELECT cust_id, dep_id, max(manag_stat_id) manag_stat_id 
FROM V_SERVER_CLIENT_STATS GROUP BY cust_id, dep_id;

-- Latest STATS ID per Application Cust - Client
CREATE OR REPLACE VIEW V_LATEST_SERVER_CLIENT_STATSID_CUST AS
SELECT cust_id, max(manag_stat_id) manag_stat_id 
FROM V_SERVER_CLIENT_STATS GROUP BY cust_id;
*/

-- ---------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------
-- view for application forensic session details report 
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE VIEW V_APP_STATS_SESSION_HISTORY AS
    select 
        sdt.cust_id AS cust_id,
        c.customer_name AS customer_name,
        sdt.dep_id AS dep_id,
        d.dept_name AS dept_name,
        sdt.adpl_app_id AS adpl_app_id,
        sdt.app_name AS app_name,
        sdt.process_name AS process_name,
        sdt.protocol AS protocol,
        sdt.server_port AS server_port,
        sdt.server_ip AS server_ip,
        sdt.pid AS pid,
        sdt.uuid AS uuid,
        sdt.socket_uuid AS socket_uuid,
        sdt.sess_allowed AS sess_allowed,
        sdt.sess_rejected AS sess_rejected,
        sdt.sess_rej_policies AS sess_rej_policies,
        sdt.sess_rej_custid AS sess_rej_custid,
        sdt.sess_rej_depid AS sess_rej_depid,
        sdt.sess_rej_sla AS sess_rej_sla,
        sdt.sess_rej_osfails AS sess_rej_osfails,
        sdt.created_on AS created_on,
        sdt.modify_on AS modify_on,
        sdt.server_count AS server_count,
        sdt.count_max_client AS count_max_client,
        sdt.conn_reject_count AS conn_reject_count,
        sdt.create_timestamp AS create_timestamp,
        sdt.client_count AS client_count,
        cdt.client_ip AS client_ip,
        cdt.client_port AS client_port,
        cdt.send_count AS send_count,
        cdt.recv_count AS recv_count,
        cdt.send_bytes AS send_bytes,
        cdt.recv_bytes AS recv_bytes,
        cdt.recv_rejected_bytes AS recv_rejected_bytes,
        cdt.cust_dept_mismatch_count AS cust_dept_mismatch_count,
        cdt.sig_mismatch_count AS sig_mismatch_count,
        cdt.security_prof_chng_count AS security_prof_chng_count,
        cdt.pl_rej_policies AS pl_rej_policies,
        cdt.pl_rej_custid AS pl_rej_custid,
        cdt.pl_rej_depid AS pl_rej_depid,
        cdt.pl_rej_secsig AS pl_rej_secsig,
        cdt.pl_allowed_policies AS pl_allowed_policies,
        cdt.pl_allowed AS pl_allowed,
        cdt.pl_rej_sqlinj AS pl_rej_sqlinj,
        cdt.pl_bytes_rej_policies AS pl_bytes_rej_policies,
        cdt.pl_bytes_rej_custid AS pl_bytes_rej_custid,
        cdt.pl_bytes_rej_depid AS pl_bytes_rej_depid,
        cdt.pl_bytes_rej_secsig AS pl_bytes_rej_secsig,
        cdt.pl_bytes_rej_sqlinj AS pl_bytes_rej_sqlinj,
        cdt.close_timestamp AS close_timestamp,
        cdt.client_uuid AS client_uuid,
        cdt.close_reason AS close_reason
    from
        (((server_descriptor_tb sdt
        join client_descriptor_tb cdt)
        join customer_tb c)
        join department_tb d)
    where
        ((sdt.uuid = cdt.server_uuid)
        	and sdt.socket_uuid = cdt.server_socket_uuid
            and (sdt.cust_id = c.cust_id)
            and (d.cust_id = c.cust_id)
            and (sdt.dep_id = d.dept_id))
    order by sdt.cust_id , sdt.dep_id , sdt.app_name , sdt.protocol , sdt.server_port , sdt.server_ip , sdt.pid;
  
-- ---------------------------------------------------------------------------------
-- view for mail configuration 
-- --------------------------------------------------------------------------------- 
   
  CREATE OR REPLACE VIEW V_MAIL_CONFIG_TRANSACTION AS
	select 
		mct.mail_id AS mail_id,
		mct.event_type AS event_type,
		mct.mail_content AS mail_content,
		mtt.mail_from AS mail_from,
		enut.password AS mail_password,
		mtt.mail_to AS mail_to,
		mtt.mail_cc AS mail_cc,
		mtt.mail_subject AS mail_subject,
		mtt.cid AS cid,mtt.did AS did,
		mtt.created_on AS created_on,
		mtt.modify_on AS modify_on,
		mtt.created_by AS created_by,
		mtt.modify_by AS modify_by,
		mtt.isActive AS isActive,
		mtt.mid AS mid,
		ct.customer_name AS customer_name,
		dt.dept_name AS dept_name,
		enut.host AS host,
		enut.port AS port from 
		((((mailconfig_tb mct join mail_transaction_tb mtt on((mct.mail_id = mtt.mail_id))) 
		left join customer_tb ct on((mtt.cid = ct.cust_id))) 
		left join department_tb dt on(((mtt.did = dt.dept_id) 
		and (mtt.cid = dt.cust_id))))
		left join email_notification_user_tb enut on((mtt.mail_from = enut.email)));

    