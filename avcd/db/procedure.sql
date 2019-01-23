
/*
call AutoConfigServerGroup_SP();
*/
DELIMITER //
DROP PROCEDURE IF EXISTS AutoConfigServerGroup_SP //
DELIMITER //
CREATE PROCEDURE AutoConfigServerGroup_SP ()

BEGIN
DECLARE isDeleted_interval, delete_app_info_interval  INT;
SELECT ifnull( polling_interval *3, 120) INTO isDeleted_interval FROM process_management_tb LIMIT 1;
-- SELECT least(polling_interval *4, 300) INTO delete_app_info_interval FROM process_management_tb LIMIT 1;
SELECT least(1200, 1200) INTO delete_app_info_interval FROM process_management_tb LIMIT 1;

UPDATE app_info_tb SET isDeleted=1 WHERE isDeleted<>1 AND TIMESTAMPDIFF(SECOND, modify_on, now()) > isDeleted_interval;

DROP TEMPORARY TABLE IF EXISTS temp_app_info_tb;

CREATE TEMPORARY TABLE  temp_app_info_tb
SELECT DISTINCT ait.uuid, ait.socket_uuid FROM app_info_tb ait
WHERE isDeleted=1 AND TIMESTAMPDIFF(SECOND, modify_on, now()) > delete_app_info_interval;

DELETE sst FROM server_stats_tb sst 
WHERE (sst.uuid, sst.socket_uuid) IN (SELECT tait.uuid, tait.socket_uuid FROM temp_app_info_tb tait);

DELETE saspt FROM scheduled_application_security_policy_tb saspt
LEFT JOIN app_info_tb ait
ON saspt.dest_cust_id = ait.customer_id
AND saspt.dest_dept_id = ait.department_id
AND saspt.dest_port = ait.server_port
AND saspt.dest_protocol = ait.protocol
AND saspt.pid  = ait.pid
WHERE ait.uuid is null;

DELETE ait FROM app_info_tb ait 
WHERE (ait.uuid,ait.socket_uuid) IN (SELECT tait.uuid, tait.socket_uuid FROM temp_app_info_tb tait);

DROP TABLE IF EXISTS temp_app_info_tb;

UPDATE server_status_information_tb SET active=0,server_state=0 where TIMESTAMPDIFF(SECOND, modify_date, now()) > 15;

DELETE FROM docker_info_tb WHERE containerIP IN (select server_primary_ip FROM server_status_information_tb WHERE TIMESTAMPDIFF(SECOND, modify_date, now()) > 15);

DROP TABLE IF EXISTS temp_grp;
CREATE TEMPORARY TABLE temp_grp 
SELECT app_info_tb.id, grp_id, customer_id, department_id, protocol, server_port, app_info_tb.app_name 
FROM app_info_tb, server_group_tb WHERE 1=2;

DROP TABLE IF EXISTS temp_instance;
CREATE TEMPORARY TABLE temp_instance 
SELECT app_info_tb.id, grp_id, server_status_information_tb.id AS server_id, customer_id, department_id, protocol, server_port, server_ip
FROM app_info_tb, server_group_tb, server_status_information_tb WHERE 1=2;
-- select new app groups to be created
INSERT INTO temp_grp (id, customer_id, department_id, protocol, server_port, app_name )
SELECT DISTINCT max(id) AS id, customer_id, department_id, protocol, server_port, '' FROM app_info_tb
WHERE (customer_id, department_id, protocol, server_port) NOT IN (SELECT  cust_id, dept_id, trans_proto, serv_port  FROM server_group_tb)
GROUP BY customer_id, department_id, protocol, server_port;

UPDATE temp_grp SET app_name = (SELECT DISTINCT app_name from app_info_tb WHERE app_info_tb.id = temp_grp.id);

INSERT INTO temp_instance (id, customer_id, department_id, protocol, server_port, server_ip )
SELECT DISTINCT max(id) AS id, customer_id, department_id, protocol, server_port, server_ip 
FROM app_info_tb GROUP BY customer_id, department_id, protocol, server_port,server_ip;
/* WHERE (customer_id, department_id, protocol, server_port) NOT IN (SELECT  cust_id, dept_id, trans_proto, serv_port  FROM server_group_tb)
*/
INSERT INTO server_group_tb 
(cust_id, dept_id, trans_proto, serv_port, app_name,
grp_id,  own_name, own_accs_lev, create_state, create_date, max_no_mem_allow, no_curr_mem, no_ew_pol_apply, no_data_seq_pol_apply, owner_id, modify_on )
SELECT DISTINCT customer_id, department_id, protocol, server_port, ifnull(app_name,'Unknown App') AS app_name,
NULL , 'admin' , 'rw', 'dynamic', now() , 1000, 0, 0 , 0, NULL, now()   
FROM temp_grp
WHERE (customer_id, department_id, protocol, server_port) NOT IN 
(SELECT DISTINCT cust_id, dept_id, trans_proto, serv_port  FROM server_group_tb) ;

UPDATE temp_instance SET grp_id = (SELECT DISTINCT grp_id from server_group_tb 
WHERE server_group_tb.cust_id = temp_instance.customer_id
AND server_group_tb.dept_id = temp_instance.department_id
AND server_group_tb.serv_port = temp_instance.server_port
AND server_group_tb.trans_proto = temp_instance.protocol );

UPDATE temp_instance, server_status_information_tb SET temp_instance.server_id = server_status_information_tb.id   
WHERE server_status_information_tb.server_primary_ip = temp_instance.server_ip ;

INSERT INTO server_group_transaction_tb (server_id, grp_id, created_on, modify_on, created_by, modify_by)
SELECT DISTINCT server_id, grp_id, now(), now(), 'dynamic', 'dynamic' 
FROM  temp_instance WHERE temp_instance.server_id != 0 AND temp_instance.grp_id != 0 
AND (server_id, grp_id) NOT IN (SELECT server_id, grp_id FROM server_group_transaction_tb);

DROP TABLE IF EXISTS temp_grp;
DROP TABLE IF EXISTS temp_instance;

END //

-- ---------------------------------------------------------------------------------
/*
call Scheduled_Policies_List_SP();
*/
DELIMITER //
DROP PROCEDURE IF EXISTS Scheduled_Policies_List_SP //
DELIMITER //
CREATE  PROCEDURE Scheduled_Policies_List_SP()
BEGIN

declare currentTime  Timestamp;
select now() into currentTime;

DROP TABLE IF EXISTS temp_server_list;
CREATE TEMPORARY TABLE temp_server_list 
SELECT DISTINCT id, management_ip, server_primary_ip, server_status_changed FROM server_status_information_tb
WHERE active <> 0  AND server_state <> 0 
AND server_status_changed >= ( SELECT max(last_access_time) FROM last_access_info_tb);

update last_access_info_tb set last_access_time = currentTime;

DROP TABLE IF EXISTS temp_app_info_list;
CREATE TEMPORARY TABLE temp_app_info_list
SELECT DISTINCT app_name, server_port, protocol, customer_id, department_id , server_ip
FROM app_info_tb 
WHERE server_ip IN (SELECT server_primary_ip FROM temp_server_list);

DROP TABLE IF EXISTS temp_policy_list;
CREATE TEMPORARY TABLE temp_policy_list
SELECT dsp.policy_id, pst.policy_type ,
dest_app_name as app_name,
dest_port as server_port,
dest_cust_id as customer_id,
dest_dept_id as department_id,
dest_protocol as protocol
FROM scheduled_data_security_policy_tb dsp , policy_scheduler_tb pst
WHERE 1=2;

INSERT INTO temp_policy_list (policy_id, policy_type, app_name, server_port, customer_id, department_id, protocol)
SELECT  dsp.policy_id, 'secure-data' AS policy_type ,
dest_app_name as app_name,
dest_port as server_port,
dest_cust_id as customer_id,
dest_dept_id as department_id,
dest_protocol as protocol
FROM scheduled_data_security_policy_tb dsp 
WHERE lower(dsp.status) = 'scheduled'
and (dest_app_name,dest_port,dest_cust_id,dest_dept_id,dest_protocol)
in (select app_name,server_port,customer_id,department_id,protocol from temp_app_info_list);

INSERT INTO temp_policy_list (policy_id, policy_type, app_name, server_port, customer_id, department_id, protocol)
SELECT  asp.policy_id, 'application-security' AS policy_type ,
dest_app_name as app_name,
dest_port as server_port,
dest_cust_id as customer_id,
dest_dept_id as department_id,
dest_protocol as protocol
FROM scheduled_application_security_policy_tb asp 
WHERE lower(asp.status) = 'scheduled'
and (dest_app_name,dest_port,dest_cust_id,dest_dept_id,dest_protocol)
in (select app_name,server_port,customer_id,department_id,protocol from temp_app_info_list);

SELECT distinct  pschedule.schedule_id AS scheduleID, pschedule.policy_type AS policyType, pschedule.policy_id AS policyID, tail.server_ip AS serverIP
FROM policy_scheduler_tb pschedule , temp_policy_list tpl, temp_app_info_list tail
where pschedule.action = 0 
AND pschedule.end_time > UTC_TIMESTAMP()
AND pschedule.policy_id = tpl.policy_id 
AND pschedule.policy_type = tpl.policy_type
AND tail.app_name = tpl.app_name
AND tail.server_port = tpl.server_port
AND tail.protocol = tpl.protocol
AND tail.customer_id = tpl.customer_id
AND tail.department_id = tpl.department_id;

DROP TABLE IF EXISTS temp_policy_list;
DROP TABLE IF EXISTS temp_app_info_list;
DROP TABLE IF EXISTS temp_server_list;
END //

-- ---------------------------------------------------------------------------
-- Customer Names Top Box 1
/* 
call Dashboard_Cust_Names_SP (0);
call Dashboard_Cust_Names_SP (1);
*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Cust_Names_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Cust_Names_SP (IN CustID INT)
BEGIN

IF CustID = 0 THEN
	SELECT cust_id, customer_name FROM customer_tb;
ELSE	
	SELECT cust_id, customer_name FROM customer_tb WHERE cust_id = CustID ;
END IF;

END//	

-- ---------------------------------------------------------------------
-- Department Names Top Box 1
/* 
call Dashboard_Dept_Names_SP (0,0);
call Dashboard_Dept_Names_SP (1,0);
call Dashboard_Dept_Names_SP (1,2);
*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Dept_Names_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Dept_Names_SP (IN CustID INT, IN DeptID INT)
BEGIN

IF CustID = 0 THEN
	SELECT cust_id, dept_id, dept_name FROM department_tb ;

ELSEIF DeptID = 0 THEN
	SELECT cust_id, dept_id, dept_name FROM department_tb  WHERE cust_id = CustID ;

ELSE	
	SELECT cust_id, dept_id, dept_name FROM department_tb  WHERE cust_id = CustID  AND dept_id = DeptID;

END IF;

END//	

-- ---------------------------------------------------------------------
/* 
-- Dashboard Pico Segments Top Box 1
call Dashboard_Pico_Segments_SP (0,0,0);
call Dashboard_Pico_Segments_SP (1,0,0);
call Dashboard_Pico_Segments_SP (1,2,0);
call Dashboard_Pico_Segments_SP (1,2,34);
*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Pico_Segments_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Pico_Segments_SP (IN CustID INT, IN DeptID INT, IN GroupID INT )
BEGIN
IF CustID = 0 THEN
	SELECT DISTINCT cust_id, customer_name, dept_id, dept_name, grp_id, app_name, serv_port
	FROM V_SERVER_GROUP_INFO ORDER BY cust_id, dept_id, app_name;

ELSEIF DeptID = 0 THEN
	SELECT DISTINCT cust_id, customer_name, dept_id, dept_name, grp_id, app_name, serv_port
	FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID  ORDER BY cust_id, dept_id, app_name;

	ELSEIF GroupID = 0 THEN
		SELECT DISTINCT cust_id, customer_name, dept_id, dept_name, grp_id, app_name, serv_port
		FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID ORDER BY cust_id, dept_id, app_name;

		ELSE
			SELECT DISTINCT cust_id, customer_name, dept_id, dept_name, grp_id, app_name, serv_port
			FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID AND grp_id = GroupID ORDER BY cust_id, dept_id, app_name;

END IF;

END//		

-- ---------------------------------------------------------------------
/* 
-- Dashboard Application Instance Top Box 1
call Dashboard_App_Instance_SP (0,0,0,'');
call Dashboard_App_Instance_SP (1,0,0,'');
call Dashboard_App_Instance_SP (1,2,0,'');
call Dashboard_App_Instance_SP (1,2,34,NULL);
call Dashboard_App_Instance_SP (1,2,34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_App_Instance_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_App_Instance_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )
/*
V_SERVER_CLIENT_STATS
V_SERVER_GROUP_INFO
*/
BEGIN
IF CustID = 0 THEN
	SELECT DISTINCT vss.server_ip, vss.server_port  FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
	WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
	AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port 
	AND vss.server_ip = vgi.server_primary_ip;
	
	SELECT DISTINCT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port FROM V_SERVER_CLIENT_STATS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
	AND vscs.server_ip = vgi.server_primary_ip
	ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port ;

ELSEIF DeptID = 0 THEN
	SELECT DISTINCT vss.server_ip, vss.server_port  FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
	WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
	AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port 
	AND vss.server_ip = vgi.server_primary_ip AND vss.cust_id = CustID ;
		
	SELECT DISTINCT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port FROM V_SERVER_CLIENT_STATS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
	AND vscs.server_ip = vgi.server_primary_ip	AND vscs.cust_id = CustID
	ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port ;

	ELSEIF GroupID = 0 THEN
		SELECT DISTINCT vss.server_ip, vss.server_port  FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
		WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
		AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port 
		AND vss.server_ip = vgi.server_primary_ip

		AND vss.cust_id = CustID AND vss.dep_id = DeptID ;

		SELECT DISTINCT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port FROM V_SERVER_CLIENT_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
		AND vscs.server_ip = vgi.server_primary_ip

		AND vscs.cust_id = CustID AND vscs.dep_id = DeptID
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port ;
 
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN

			SELECT DISTINCT vss.server_ip, vss.server_port  FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
			WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
			AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port 
			AND vss.server_ip = vgi.server_primary_ip

			AND vss.cust_id = CustID AND vss.dep_id = DeptID AND vgi.grp_id = GroupID ;

			SELECT DISTINCT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port FROM V_SERVER_CLIENT_STATS vscs, V_SERVER_GROUP_INFO vgi
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
			AND vscs.server_ip = vgi.server_primary_ip

			AND vscs.cust_id = CustID AND vscs.dep_id = DeptID AND vgi.grp_id = GroupID

			ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port ;
			ELSE
				SELECT DISTINCT vss.server_ip, vss.server_port  FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
				WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
				AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port 
				AND vss.server_ip = vgi.server_primary_ip

				AND vss.cust_id = CustID AND vss.dep_id = DeptID
				AND vgi.grp_id = GroupID AND trim(vss.server_ip) = trim(ServerIP);

				SELECT DISTINCT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port FROM V_SERVER_CLIENT_STATS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID AND trim(vscs.server_ip) = trim(ServerIP)

				ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_ip, vscs.client_ip, vscs.client_port ;
END IF;

END//		

-- ---------------------------------------------------------------------
/* 
-- Dashboard Active Connections Master Top Box 1
call Dashboard_Active_Connections_Master_SP (0,0,0,'');
call Dashboard_Active_Connections_Master_SP (1,0,0,'');
call Dashboard_Active_Connections_Master_SP (1,2,0,'');
call Dashboard_Active_Connections_Master_SP (1,2,34,NULL);
call Dashboard_Active_Connections_Master_SP (1,2,34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Active_Connections_Master_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Active_Connections_Master_SP(IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80))
BEGIN
IF CustID = 0 OR DeptID = 0 OR GroupID = 0 OR isnull(ServerIP) OR trim(ServerIP) = '' THEN

	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
	vscs.server_port, vscs.protocol, 0 AS sess_allowed, 0 AS sess_rejected
	FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
	WHERE 1 = 2;
ELSE
	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid,vscs.socket_uuid, vscs.server_ip, 
	vscs.server_port, vscs.protocol, sum(vscs.sess_allowed) AS sess_allowed, sum(vscs.sess_rejected) AS sess_rejected, max(create_timestamp) as create_timestamp
	FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
	AND vscs.server_ip = vgi.server_primary_ip

	AND vscs.cust_id = CustID
	AND vscs.dep_id = DeptID
	AND vgi.grp_id = GroupID
	AND trim(vscs.server_ip) = trim(ServerIP)

	GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.socket_uuid, vscs.server_ip, vscs.server_port, vscs.protocol
	ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;
END IF;

END//

-- ---------------------------------------------------------------------
/* 
-- Dashboard Active Connections Details Top Box 1
CALL Dashboard_Active_Connections_Details_SP(0, 0, 0,NULL);
CALL Dashboard_Active_Connections_Details_SP(1, 1, 8,NULL);
CALL Dashboard_Active_Connections_Details_SP(1, 1, 8,'');
CALL Dashboard_Active_Connections_Details_SP(1, 1, 8,'172.31.44.123');
CALL Dashboard_Active_Connections_Details_SP(1, 1, 8,'0.0.0.0');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Active_Connections_Details_SP //
DELIMITER //

CREATE  PROCEDURE  Dashboard_Active_Connections_Details_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80), IN SESSUUID VARCHAR(36), IN SOCKUUID VARCHAR(36) )
BEGIN

IF CustID = 0 OR DeptID = 0 OR GroupID = 0 OR isnull(ServerIP) OR trim(ServerIP) = '' THEN
	SELECT vscs.uuid, vscs.client_ip, vscs.client_port, vscs.send_count, vscs.recv_count, vscs.pl_allowed, vscs.pl_rej_policies, vscs.pl_rej_custid, vscs.pl_rej_depid, vscs.pl_rej_secsig,
	vscs.send_bytes, vscs.recv_bytes, vscs.pl_bytes_rej_policies, vscs.pl_bytes_rej_custid, vscs.pl_bytes_rej_depid, vscs.pl_bytes_rej_secsig, vscs.pl_rej_sqlinj, vscs.pl_bytes_rej_sqlinj, vscs.close_reason
	FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
	WHERE 1 = 2;

ELSE
	SELECT vscs.uuid, vscs.client_ip, vscs.client_port, vscs.send_count, vscs.recv_count, vscs.pl_allowed, vscs.pl_rej_policies, vscs.pl_rej_custid, vscs.pl_rej_depid, vscs.pl_rej_secsig,
	vscs.send_bytes, vscs.recv_bytes, vscs.pl_bytes_rej_policies, vscs.pl_bytes_rej_custid, vscs.pl_bytes_rej_depid, vscs.pl_bytes_rej_secsig, ifnull(vscs.close_timestamp,vscs.create_timestamp) AS create_timestamp, vscs.pl_rej_sqlinj, vscs.pl_bytes_rej_sqlinj, vscs.close_reason
	FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
	AND vscs.server_ip = vgi.server_primary_ip
	AND ( vscs.client_ip IS NOT NULL AND trim(vscs.client_ip) <> "" )

	AND vscs.cust_id = CustID
	AND vscs.dep_id = DeptID
	AND vgi.grp_id = GroupID
	AND trim(vscs.server_ip) = trim(ServerIP)
	AND vscs.uuid = SESSUUID
	AND vscs.socket_uuid = SOCKUUID
	ORDER BY vscs.close_reason, vscs.client_ip, vscs.client_port;

END IF;

END //

-- ---------------------------------------------------------------------------------
/* 
-- Dashboard Top10 Defender & Offender Top Box 2 & Box 3
call Dashboard_Top10_Offender_Defender_SP (0,0,0,0,'',0);
call Dashboard_Top10_Offender_Defender_SP (1,0,0,'',10);
call Dashboard_Top10_Offender_Defender_SP (1,1,0,'',10);
call Dashboard_Top10_Offender_Defender_SP (1,1,33,NULL,0);
call Dashboard_Top10_Offender_Defender_SP (1,1,33,'195.172.5.45',0);

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Top10_Offender_Defender_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Top10_Offender_Defender_SP (IN CountOnly INT, IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80), IN LimitOnly INT )
BEGIN
DECLARE LimitValue INT DEFAULT 10000;
IF LimitOnly > 0 THEN
	SET LimitValue = LimitOnly;
END IF;
DROP TABLE IF EXISTS temp_top10_sessions ;
CREATE TEMPORARY TABLE temp_top10_sessions 
SELECT vscd.uuid, vscd.socket_uuid ,vscd.sess_rejected FROM V_SERVER_DESCRIPTORS vscd WHERE 1 = 2;
DROP TABLE IF EXISTS temp_top10_peers ;
CREATE TEMPORARY TABLE temp_top10_peers 
SELECT vscd.uuid, vscd.socket_uuid, vscd.pl_allowed AS pl_rejected FROM V_SERVER_CLIENT_DESCRIPTORS vscd WHERE 1 = 2;
-- INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) FROM V_SERVER_DESCRIPTORS vscd GROUP BY uuid, socket_uuid) ORDER BY sum(vscd.sess_rejected) DESC ;

-- INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
-- WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

-- select tts.uuid, tts.sess_rejected, ttp.pl_rejected from temp_top10_sessions tts, temp_top10_peers ttp where tts.uuid = ttp.uuid;
IF CustID = 0 THEN
	INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) FROM V_SERVER_DESCRIPTORS vscd GROUP BY uuid, socket_uuid) ORDER BY sum(vscd.sess_rejected) DESC LIMIT LimitValue;
	INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
	WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

    IF CountOnly = 0 THEN
        SELECT sum(sess_rejected) AS sum_sess_rejected FROM temp_top10_sessions WHERE sess_rejected <> 0;
    ELSE
        SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
        vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
        vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
        vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.pl_rej_secsig
        FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
        WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
        AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
        AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
        AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
        AND tts.sess_rejected <> 0
        ORDER BY tts.sess_rejected DESC ;
    END IF;
ELSEIF DeptID = 0 THEN
	INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) FROM V_SERVER_DESCRIPTORS vscd WHERE vscd.cust_id = CustID GROUP BY uuid, socket_uuid) ORDER BY sum(vscd.sess_rejected) DESC  LIMIT LimitValue;
	INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
	WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;
    IF CountOnly = 0 THEN
        SELECT sum(sess_rejected) AS sum_sess_rejected FROM temp_top10_sessions WHERE sess_rejected <> 0 ;
    ELSE
        SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
        vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
        vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
        vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.pl_rej_secsig
        FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
        WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
        AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
        AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
        AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
        AND tts.sess_rejected <> 0

        AND vscd.cust_id = CustID

        ORDER BY tts.sess_rejected DESC ;
    END IF;
	ELSEIF GroupID = 0 THEN
		INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) FROM V_SERVER_DESCRIPTORS vscd WHERE vscd.cust_id = CustID AND vscd.dep_id = DeptID GROUP BY uuid, socket_uuid) ORDER BY sum(vscd.sess_rejected) DESC LIMIT LimitValue;
		INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
		WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;
        IF CountOnly = 0 THEN
            SELECT sum(sess_rejected) AS sum_sess_rejected FROM temp_top10_sessions WHERE sess_rejected <> 0 ;
        ELSE
            SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
            vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
            vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
            vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.pl_rej_secsig
            FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
            WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
            AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
            AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
            AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
            AND tts.sess_rejected <> 0

            AND vscd.cust_id = CustID AND vscd.dep_id = DeptID

            ORDER BY tts.sess_rejected DESC ;
        END IF;
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi 
			WHERE vscd.cust_id = CustID AND vscd.dep_id = DeptID AND vgi.grp_id = GroupID 
			AND vscd.cust_id  =  vgi.cust_id AND vscd.dep_id = vgi.dept_id AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port AND vscd.server_ip = vgi.server_primary_ip 
			GROUP BY uuid, socket_uuid) ORDER BY sum(vscd.sess_rejected) DESC LIMIT LimitValue;
			INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
			WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

            IF CountOnly = 0 THEN
                SELECT sum(sess_rejected) AS sum_sess_rejected FROM temp_top10_sessions WHERE sess_rejected <> 0 ;
            ELSE
                SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
                vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
                vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
                vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.pl_rej_secsig
                FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
                WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
                AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
                AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
                AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
                AND tts.sess_rejected <> 0
                AND vscd.cust_id = CustID AND vscd.dep_id = DeptID AND vgi.grp_id = GroupID                
                ORDER BY tts.sess_rejected DESC ;
            END IF;
			ELSE
				INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi 
				WHERE vscd.cust_id = CustID AND vscd.dep_id = DeptID AND vgi.grp_id = GroupID  AND trim(ServerIP) = trim(vscd.server_ip)
				AND vscd.cust_id  =  vgi.cust_id AND vscd.dep_id = vgi.dept_id AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port AND vscd.server_ip = vgi.server_primary_ip 
				GROUP BY uuid, socket_uuid) ORDER BY sum(vscd.sess_rejected) DESC LIMIT 10;

				INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
				WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

                IF CountOnly = 0 THEN
                    SELECT sum(sess_rejected) AS sum_sess_rejected FROM temp_top10_sessions WHERE sess_rejected <> 0 ;
                ELSE
                    SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
                    vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
                    vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
                    vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.pl_rej_secsig
                    FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
                    WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
                    AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
                    AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
                    AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
                    AND tts.sess_rejected <> 0

                    AND vscd.cust_id = CustID AND vscd.dep_id = DeptID 
                    AND vgi.grp_id = GroupID AND trim(ServerIP) = trim(vscd.server_ip)

                    ORDER BY tts.sess_rejected DESC ;
                END IF;
END IF;

DROP TABLE IF EXISTS temp_top10_sessions ;
DROP TABLE IF EXISTS temp_top10_peers ;

END//		

-- ---------------------------------------------------------------------------------
		
/* 
-- Dashboard Top10 Defender Top Box 2
call Dashboard_Top10_Defender_SP (0,0,0,'');
call Dashboard_Top10_Defender_SP (1,0,0,'');
call Dashboard_Top10_Defender_SP (1,1,0,'');
call Dashboard_Top10_Defender_SP (1,1,33,NULL);
call Dashboard_Top10_Defender_SP (1,1,33,'195.172.5.45');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Top10_Defender_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Top10_Defender_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )

BEGIN
IF CustID = 0 THEN
	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
	vscd.server_ip, sum(vscd.sess_rejected) AS rejection_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
	FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
	WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
	AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
	AND vscd.server_ip = vgi.server_primary_ip

	GROUP BY  vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.server_ip 
	HAVING rejection_total <> 0
	ORDER BY rejection_total DESC LIMIT 10;
ELSEIF DeptID = 0 THEN
	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
	vscd.server_ip, ifnull( sum(vscd.sess_rejected) ,0) AS rejection_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
	FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
	WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
	AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
	AND vscd.server_ip = vgi.server_primary_ip

	AND vscd.cust_id = CustID
	GROUP BY  vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.server_ip 
	HAVING rejection_total <> 0
	ORDER BY rejection_total DESC LIMIT 10;

	ELSEIF GroupID = 0 THEN
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
		vscd.server_ip, ifnull( sum(vscd.sess_rejected) ,0) AS rejection_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
		FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
		WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
		AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
		AND vscd.server_ip = vgi.server_primary_ip

		AND vscd.cust_id = CustID AND vscd.dep_id = DeptID

		GROUP BY  vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.server_ip 
		HAVING rejection_total <> 0
		ORDER BY rejection_total DESC LIMIT 10;

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
			vscd.server_ip, ifnull( sum(vscd.sess_rejected) ,0) AS rejection_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
			FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
			WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
			AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
			AND vscd.server_ip = vgi.server_primary_ip

			AND vscd.cust_id = CustID AND vscd.dep_id = DeptID AND vgi.grp_id = GroupID

			GROUP BY  vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.server_ip 
			HAVING rejection_total <> 0
			ORDER BY rejection_total DESC LIMIT 10;

			ELSE
				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
				vscd.server_ip, ifnull( sum(vscd.sess_rejected) ,0) AS rejection_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
				FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
				WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
				AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
				AND vscd.server_ip = vgi.server_primary_ip

				AND vscd.cust_id = CustID AND vscd.dep_id = DeptID 
				AND vgi.grp_id = GroupID AND trim(ServerIP) = trim(vscd.server_ip)
				GROUP BY  vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.server_ip 
				HAVING rejection_total <> 0
				ORDER BY rejection_total DESC LIMIT 10;
END IF;

END//		

-- ---------------------------------------------------------------------------------
		
/* 
-- Dashboard Top10 Offender Top Box 3
call Dashboard_Top10_Offender_SP (0,0,0,'');
call Dashboard_Top10_Offender_SP (1,0,0,'');
call Dashboard_Top10_Offender_SP (1,1,0,'');
call Dashboard_Top10_Offender_SP (1,1,33,NULL);
call Dashboard_Top10_Offender_SP (1,1,33,'195.172.5.45');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Top10_Offender_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Top10_Offender_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )

BEGIN
IF CustID = 0 THEN
	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, 
	client_ip, ifnull( (sum(pl_rej_policies) + sum(pl_rej_custid) + sum(pl_rej_depid) + sum(pl_rej_secsig) ),0) AS pl_rej_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
	FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
	WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
	AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
	AND vscd.server_ip = vgi.server_primary_ip

	GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.client_ip 
	HAVING pl_rej_total <> 0
	ORDER BY pl_rej_total DESC LIMIT 10;
ELSEIF DeptID = 0 THEN
	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, 
	client_ip, ifnull( (sum(pl_rej_policies) + sum(pl_rej_custid) + sum(pl_rej_depid) + sum(pl_rej_secsig) ),0) AS pl_rej_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
	FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
	WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
	AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
	AND vscd.server_ip = vgi.server_primary_ip
	
	AND vscd.cust_id = CustID
	GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.client_ip 
	HAVING pl_rej_total <> 0
	ORDER BY pl_rej_total DESC LIMIT 10;

	ELSEIF GroupID = 0 THEN
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, 
		client_ip, ifnull( (sum(pl_rej_policies) + sum(pl_rej_custid) + sum(pl_rej_depid) + sum(pl_rej_secsig) ),0) AS pl_rej_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
		WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
		AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
		AND vscd.server_ip = vgi.server_primary_ip

		AND vscd.cust_id = CustID AND vscd.dep_id = DeptID

		GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.client_ip 
		HAVING pl_rej_total <> 0
		ORDER BY pl_rej_total DESC LIMIT 10;

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, 
			client_ip, ifnull( (sum(pl_rej_policies) + sum(pl_rej_custid) + sum(pl_rej_depid) + sum(pl_rej_secsig) ),0) AS pl_rej_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
			FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
			WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
			AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
			AND vscd.server_ip = vgi.server_primary_ip

			AND vscd.cust_id = CustID AND vscd.dep_id = DeptID AND vgi.grp_id = GroupID

			GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.client_ip 
			HAVING pl_rej_total <> 0
			ORDER BY pl_rej_total DESC LIMIT 10;

			ELSE
				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, 
				client_ip, ifnull( (sum(pl_rej_policies) + sum(pl_rej_custid) + sum(pl_rej_depid) + sum(pl_rej_secsig) ),0) AS pl_rej_total /* , ifnull(sum(sess_rejected),0) AS sess_rejected  */
				FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
				WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
				AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
				AND vscd.server_ip = vgi.server_primary_ip

				AND vscd.cust_id = CustID AND vscd.dep_id = DeptID 
				AND vgi.grp_id = GroupID AND trim(ServerIP) = trim(vscd.server_ip)
				GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscd.client_ip 
				HAVING pl_rej_total <> 0
				ORDER BY pl_rej_total DESC LIMIT 10;
END IF;

END//		


-- ---------------------------------------------------------------------------------

/* Unauthorized Apps Counts Top Box 5
call Dashboard_UnAuthorized_Apps_SP ();
*/
DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_UnAuthorized_Apps_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_UnAuthorized_Apps_SP()
BEGIN

	SELECT ifnull(count(id),0) count_sess_rej_sla FROM sla_failed_tb ;

	SELECT app_name,ifnull(count(id),0) count_sess_rej_sla 
	FROM sla_failed_tb GROUP BY app_name ORDER BY count_sess_rej_sla DESC;

END //
DELIMITER ;
	
-- ---------------------------------------------------------------------
/* 
-- Dashboard Rejected Connections Top Box 4
call Dashboard_Reject_Connections_SP (0,0,0,0,'');
call Dashboard_Reject_Connections_SP (1,0,0,0,'');
call Dashboard_Reject_Connections_SP (0,63,54,1,'172.16.1.65');
call Dashboard_Reject_Connections_SP (1,63,54,1,'172.16.1.65');
call Dashboard_Reject_Connections_SP (1,2,0,'');
call Dashboard_Reject_Connections_SP (1,2,34,NULL);
call Dashboard_Reject_Connections_SP (1,2,34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Reject_Connections_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Reject_Connections_SP (IN CountOnly INT, IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )
BEGIN

DROP TABLE IF EXISTS temp_server_stats ;
CREATE TEMPORARY TABLE temp_server_stats 
SELECT vss.uuid, vss.socket_uuid, vss.sess_rejected FROM V_SERVER_STATS vss WHERE 1 = 2;

INSERT INTO temp_server_stats (SELECT vss.uuid, vss.socket_uuid, sum(vss.sess_rejected) FROM V_SERVER_STATS vss GROUP BY uuid, socket_uuid ) ;

IF CustID = 0 THEN
	IF CountOnly = 0 THEN
		SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
		FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip;
	ELSE
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.server_port, 
		tss.sess_rejected, vscs.protocol, ifnull(vscs.client_ip,"N.A.") AS client_ip, ifnull(vscs.client_port, 0) AS client_port, vscs.create_timestamp, vscs.close_timestamp
		FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi, temp_server_stats tss
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip
		AND vscs.uuid = tss.uuid AND vscs.socket_uuid = tss.socket_uuid 
		AND tss.sess_rejected <> 0
		/* GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, tss.sess_rejected, vscs.protocol, vscs.client_ip, vscs.client_port
		HAVING sum(sess_rejected) <> 0 */
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, tss.sess_rejected, vscs.protocol, vscs.client_ip, vscs.client_port ;
	END IF;
ELSEIF DeptID = 0 THEN
	IF CountOnly = 0 THEN
		SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
		FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
		AND vscs.server_ip = vgi.server_primary_ip
		AND vscs.cust_id = CustID ;
	ELSE
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.server_port, 
		tss.sess_rejected, vscs.protocol, ifnull(vscs.client_ip,"N.A.") AS client_ip, ifnull(vscs.client_port, 0) AS client_port, vscs.create_timestamp, vscs.close_timestamp
		FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi, temp_server_stats tss
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip
		AND vscs.uuid = tss.uuid AND vscs.socket_uuid = tss.socket_uuid 
		AND tss.sess_rejected <> 0
		AND vscs.cust_id = CustID

		/* GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip
		HAVING sum(sess_rejected) <> 0 */
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, tss.sess_rejected, vscs.protocol, vscs.client_ip, vscs.client_port ;
	END IF;
	ELSEIF GroupID = 0 THEN
		IF CountOnly = 0 THEN
			SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
			FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
			AND vscs.server_ip = vgi.server_primary_ip
			AND vscs.cust_id = CustID
			AND vscs.dep_id = DeptID ;
		ELSE
			SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.server_port, 
			tss.sess_rejected, vscs.protocol, ifnull(vscs.client_ip,"N.A.") AS client_ip, ifnull(vscs.client_port, 0) AS client_port, vscs.create_timestamp, vscs.close_timestamp
			FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi, temp_server_stats tss
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
			AND vscs.server_ip = vgi.server_primary_ip
			AND vscs.uuid = tss.uuid AND vscs.socket_uuid = tss.socket_uuid 
			AND tss.sess_rejected <> 0
			AND vscs.cust_id = CustID
			AND vscs.dep_id = DeptID

			/* GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip
			HAVING sum(sess_rejected) <> 0 */
			ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, tss.sess_rejected, vscs.protocol, vscs.client_ip, vscs.client_port ;
		END IF;
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			IF CountOnly = 0 THEN
				SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
				FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
				AND vscs.server_ip = vgi.server_primary_ip
				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID ;
			ELSE
				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.server_port, 
				tss.sess_rejected, vscs.protocol, ifnull(vscs.client_ip,"N.A.") AS client_ip, ifnull(vscs.client_port, 0) AS client_port,vscs.create_timestamp, vscs.close_timestamp
				FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi, temp_server_stats tss
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
				AND vscs.server_ip = vgi.server_primary_ip
				AND vscs.uuid = tss.uuid AND vscs.socket_uuid = tss.socket_uuid 
				AND tss.sess_rejected <> 0
				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID

				/* GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip
				HAVING sum(sess_rejected) <> 0 */
				ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, tss.sess_rejected, vscs.protocol, vscs.client_ip, vscs.client_port ;
			END IF;
		ELSE
				IF CountOnly = 0 THEN
					SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
					FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
					WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
					AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
					AND vscs.server_ip = vgi.server_primary_ip
					AND vscs.cust_id = CustID
					AND vscs.dep_id = DeptID
					AND vgi.grp_id = GroupID
					AND trim(vscs.server_ip) = trim(ServerIP);
				ELSE
					SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip, vscs.server_port, 
					tss.sess_rejected, vscs.protocol, ifnull(vscs.client_ip,"N.A.") AS client_ip, ifnull(vscs.client_port, 0) AS client_port,vscs.create_timestamp, vscs.close_timestamp
					FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi, temp_server_stats tss
					WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
					AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
					AND vscs.server_ip = vgi.server_primary_ip
					AND vscs.uuid = tss.uuid AND vscs.socket_uuid = tss.socket_uuid 
					AND tss.sess_rejected <> 0
					AND vscs.cust_id = CustID
					AND vscs.dep_id = DeptID
					AND vgi.grp_id = GroupID
					AND trim(vscs.server_ip) = trim(ServerIP)

					/* GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.server_ip
					HAVING sum(sess_rejected) <> 0 */
					ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, tss.sess_rejected, vscs.protocol, vscs.client_ip, vscs.client_port ;
				END IF;
END IF;
DROP TABLE IF EXISTS temp_client_stats ;

END	//

-- ---------------------------------------------------------------------
/* 
-- Dashboard Rejected Connections Top Box 4
call Dashboard_Reject_Connections_Master_SP (0,0,0,0,'');
call Dashboard_Reject_Connections_Master_SP (0,1,0,0,'');
call Dashboard_Reject_Connections_Master_SP (0,1,2,0,'');
call Dashboard_Reject_Connections_Master_SP (0,1,2,34,NULL);
call Dashboard_Reject_Connections_Master_SP (0,1,2,34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Reject_Connections_Master_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Reject_Connections_Master_SP (IN CountOnly INT, IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )

BEGIN

IF CustID = 0 THEN
    IF CountOnly = 0 THEN
		SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
		FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip;
    ELSE
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
		vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected, max(vscs.create_timestamp) as create_timestamp
		FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip

		GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, vscs.sess_rejected
		HAVING sum(sess_rejected) <> 0 
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, vscs.sess_rejected ;
    END IF;
ELSEIF DeptID = 0 THEN
    IF CountOnly = 0 THEN
		SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
		FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
		AND vscs.server_ip = vgi.server_primary_ip
		AND vscs.cust_id = CustID ;
    ELSE
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
		vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
		FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip

		AND vscs.cust_id = CustID

		GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, vscs.sess_rejected
		HAVING sum(sess_rejected) <> 0 
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, vscs.sess_rejected ;
    END IF;
	ELSEIF GroupID = 0 THEN
        IF CountOnly = 0 THEN
			SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
			FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
			AND vscs.server_ip = vgi.server_primary_ip

			AND vscs.cust_id = CustID
			AND vscs.dep_id = DeptID ;
        ELSE
			SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
			vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
			FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
			AND vscs.server_ip = vgi.server_primary_ip

			AND vscs.cust_id = CustID
			AND vscs.dep_id = DeptID

			GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, vscs.sess_rejected
			HAVING sum(sess_rejected) <> 0 
			ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, vscs.sess_rejected ;
        END IF;
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
            IF CountOnly = 0 THEN
				SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
				FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID ;
            ELSE
				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
				vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
				FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID

				GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, vscs.sess_rejected
				HAVING sum(sess_rejected) <> 0 
				ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, vscs.sess_rejected ;
            END IF;
			ELSE
            IF CountOnly = 0 THEN
				SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
				FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID
				AND trim(vscs.server_ip) = trim(ServerIP);
            ELSE
				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
				vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
				FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID
				AND trim(vscs.server_ip) = trim(ServerIP)

				GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, vscs.sess_rejected
				HAVING sum(sess_rejected) <> 0 
				ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, vscs.sess_rejected ;
            END IF;
END IF;

END	//


-- ---------------------------------------------------------------------
/* 
-- Dashboard Rejected Connections Top Box 4
CALL Dashboard_Reject_Connections_Details_SP(0, 0, 0,NULL,NULL);
CALL Dashboard_Reject_Connections_Details_SP(1, 1, 8,NULL,NULL);
CALL Dashboard_Reject_Connections_Details_SP(1, 1, 8,'','');
CALL Dashboard_Reject_Connections_Details_SP(1, 1, 8,'172.31.44.123','');
CALL Dashboard_Reject_Connections_Details_SP(1, 1, 8,'0.0.0.0','');
CALL Dashboard_Reject_Connections_Details_SP(1, 1, 8,'172.31.44.123','');
*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Reject_Connections_Details_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Reject_Connections_Details_SP(IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) , IN SESSUUID VARCHAR(36))
BEGIN

IF CustID = 0 OR DeptID = 0 OR GroupID = 0 OR isnull(ServerIP) OR trim(ServerIP) = '' THEN
	SELECT vscs.uuid, vscs.client_ip, vscs.client_port, vscs.pl_allowed, vscs.pl_rej_policies, vscs.pl_rej_custid, vscs.pl_rej_depid, vscs.pl_rej_secsig,
	vscs.pl_bytes_rej_policies, vscs.pl_bytes_rej_custid, vscs.pl_bytes_rej_depid, vscs.pl_bytes_rej_secsig,vscs.pl_rej_sqlinj, vscs.pl_bytes_rej_sqlinj, vscs.close_timestamp, vscs.create_timestamp
	FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
	WHERE 1 = 2;

ELSE
	SELECT vscs.uuid, vscs.client_ip, vscs.client_port, vscs.pl_allowed, vscs.pl_rej_policies, vscs.pl_rej_custid, vscs.pl_rej_depid, vscs.pl_rej_secsig,
	vscs.pl_bytes_rej_policies, vscs.pl_bytes_rej_custid, vscs.pl_bytes_rej_depid, vscs.pl_bytes_rej_secsig,vscs.pl_rej_sqlinj, vscs.pl_bytes_rej_sqlinj, 
	vscs.close_reason, vscs.close_timestamp, vscs.create_timestamp
	FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
	AND vscs.server_ip = vgi.server_primary_ip
	AND ( vscs.client_ip IS NOT NULL AND trim(vscs.client_ip) <> "" )

	AND vscs.cust_id = CustID
	AND vscs.dep_id = DeptID
	AND vgi.grp_id = GroupID
	AND trim(vscs.server_ip) = trim(ServerIP)
	AND vscs.uuid = SESSUUID
	ORDER BY vscs.client_ip, vscs.client_port ;

END IF;

END //
-- ---------------------------------------------------------------------
/* 
-- Dashboard Rejected Connections Top Box 4
call Dashboard_Reject_ConnectionsHistory_Master_SP (0,0,0,'');
call Dashboard_Reject_ConnectionsHistory_Master_SP (1,0,0,'');
call Dashboard_Reject_ConnectionsHistory_Master_SP (1,2,0,'');
call Dashboard_Reject_ConnectionsHistory_Master_SP (1,2,34,NULL);
call Dashboard_Reject_ConnectionsHistory_Master_SP (1,2,34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Reject_ConnectionsHistory_Master_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Reject_ConnectionsHistory_Master_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )

BEGIN

IF CustID = 0 THEN
		SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
		FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip;

		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
		vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
		FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip

		GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, sess_rejected
		HAVING sum(sess_rejected) <> 0 
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;

ELSEIF DeptID = 0 THEN
		SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
		FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
		AND vscs.server_ip = vgi.server_primary_ip
		AND vscs.cust_id = CustID ;
		
		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
		vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected, max(vscs.create_timestamp) as create_timestamp
		FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
		WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
		AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
		AND vscs.server_ip = vgi.server_primary_ip

		AND vscs.cust_id = CustID

		GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, sess_rejected
		HAVING sum(sess_rejected) <> 0 
		ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;

	ELSEIF GroupID = 0 THEN
			SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
			FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
			AND vscs.server_ip = vgi.server_primary_ip

			AND vscs.cust_id = CustID
			AND vscs.dep_id = DeptID ;

			SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
			vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
			FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
			WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
			AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
			AND vscs.server_ip = vgi.server_primary_ip

			AND vscs.cust_id = CustID
			AND vscs.dep_id = DeptID

			GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, sess_rejected
			HAVING sum(sess_rejected) <> 0 
			ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;
 
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN

				SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
				FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID ;

				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
				vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
				FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID

				GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, sess_rejected
				HAVING sum(sess_rejected) <> 0 
				ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;

			ELSE
				SELECT ifnull(sum(sess_rejected),0) AS sess_rejected
				FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port 
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID
				AND trim(vscs.server_ip) = trim(ServerIP);

				SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
				vscs.server_port, vscs.protocol, sum(vscs.sess_rejected) AS sess_rejected,max(vscs.create_timestamp) as create_timestamp
				FROM V_SERVER_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
				WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
				AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
				AND vscs.server_ip = vgi.server_primary_ip

				AND vscs.cust_id = CustID
				AND vscs.dep_id = DeptID
				AND vgi.grp_id = GroupID
				AND trim(vscs.server_ip) = trim(ServerIP)

				GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, vscs.server_port, vscs.protocol, sess_rejected
				HAVING sum(sess_rejected) <> 0 
				ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;

END IF;

END //	


-- ---------------------------------------------------------------------
/* 
-- Dashboard Rejected Connections Top Box 4
CALL Dashboard_Reject_Connections_DetailsHistory_SP(0, 0, 0,NULL,NULL);
CALL Dashboard_Reject_Connections_DetailsHistory_SP(1, 1, 8,NULL,NULL);
CALL Dashboard_Reject_Connections_DetailsHistory_SP(1, 1, 8,'','');
CALL Dashboard_Reject_Connections_DetailsHistory_SP(1, 1, 8,'172.31.44.123','');
CALL Dashboard_Reject_Connections_DetailsHistory_SP(1, 1, 8,'0.0.0.0','');
CALL Dashboard_Reject_Connections_DetailsHistory_SP(1, 1, 8,'172.31.44.123','');
*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Reject_Connections_DetailsHistory_SP //
DELIMITER //
CREATE    PROCEDURE   Dashboard_Reject_Connections_DetailsHistory_SP  (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) , IN SESSUUID VARCHAR(36))
BEGIN

IF CustID = 0 OR DeptID = 0 OR GroupID = 0 OR isnull(ServerIP) OR trim(ServerIP) = '' THEN
	SELECT vscs.uuid, vscs.client_ip, vscs.client_port, vscs.pl_allowed, vscs.pl_rej_policies, vscs.pl_rej_custid, vscs.pl_rej_depid, vscs.pl_rej_secsig,
	vscs.pl_bytes_rej_policies, vscs.pl_bytes_rej_custid, vscs.pl_bytes_rej_depid, vscs.pl_bytes_rej_secsig, vscs.pl_rej_sqlinj, vscs.pl_bytes_rej_sqlinj
	FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
	WHERE 1 = 2;

ELSE
	SELECT vscs.uuid, vscs.client_ip, vscs.client_port, vscs.pl_allowed, vscs.pl_rej_policies, vscs.pl_rej_custid, vscs.pl_rej_depid, vscs.pl_rej_secsig,
	vscs.pl_bytes_rej_policies, vscs.pl_bytes_rej_custid, vscs.pl_bytes_rej_depid, vscs.pl_bytes_rej_secsig, 
	vscs.close_reason, vscs.close_timestamp, vscs.create_timestamp, vscs.pl_rej_sqlinj, vscs.pl_bytes_rej_sqlinj
	FROM V_SERVER_CLIENT_DESCRIPTORS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
	AND vscs.server_ip = vgi.server_primary_ip
	AND ( vscs.client_ip IS NOT NULL AND trim(vscs.client_ip) <> "" )

	AND vscs.cust_id = CustID
	AND vscs.dep_id = DeptID
	AND vgi.grp_id = GroupID
	AND trim(vscs.server_ip) = trim(ServerIP)
	AND vscs.uuid = SESSUUID
	ORDER BY vscs.client_ip, vscs.client_port ;

END IF;

END //


-- ---------------------------------------------------------------------
-- Customer, Department,Pico Segment, Server Counts Pico Org Menu Item 1
/* 
call PicoSegment_Organization_Counts_SP ();
*/

DELIMITER //
DROP PROCEDURE IF EXISTS PicoSegment_Organization_Counts_SP //
DELIMITER //
CREATE PROCEDURE PicoSegment_Organization_Counts_SP ()

BEGIN

DECLARE customer_count, department_count, pico_segment_count, server_count INT ;

SELECT ifnull(count(DISTINCT cust_id),0) INTO customer_count FROM V_APPLICATION_INFO WHERE server_state = 1 AND isDeleted = 0;

SELECT ifnull(count(DISTINCT dept_id),0) INTO department_count FROM  V_APPLICATION_INFO WHERE server_state = 1 AND isDeleted = 0; 

SELECT ifnull(count(DISTINCT grp_id),0) INTO pico_segment_count FROM V_APPLICATION_INFO WHERE server_state = 1 AND isDeleted = 0; 

SELECT ifnull(count(DISTINCT server_primary_ip, serv_port, pid),0) INTO server_count FROM V_APPLICATION_INFO WHERE server_state = 1 AND isDeleted = 0;


SELECT customer_count, department_count, pico_segment_count, server_count ;
END //  

-- ---------------------------------------------------------------------
-- SP for Dashboard Connection Allowed Rejected Count graph
/*
call DashBoard_Allowed_Dropped_Counts_SP (0, 0, 0,NULL);
call DashBoard_Allowed_Dropped_Counts_SP (1, 0, 0,NULL);
call DashBoard_Allowed_Dropped_Counts_SP (1, 2, 34,NULL);
call DashBoard_Allowed_Dropped_Counts_SP (1, 2, 34,'195.172.5.51');
*/

DELIMITER //
DROP PROCEDURE IF EXISTS DashBoard_Allowed_Dropped_Counts_SP //
DELIMITER //
CREATE PROCEDURE DashBoard_Allowed_Dropped_Counts_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )
BEGIN

IF CustID = 0 THEN
	SELECT create_timestamp, sum(sess_allowed) Conn_Allowed_Session, sum(sess_rejected) Conn_Rejected_Session
		FROM V_SERVER_STATS, V_SERVER_GROUP_INFO 
		WHERE V_SERVER_STATS.cust_id  =  V_SERVER_GROUP_INFO.cust_id
		AND	V_SERVER_STATS.dep_id = V_SERVER_GROUP_INFO.dept_id
		AND V_SERVER_STATS.protocol = V_SERVER_GROUP_INFO.trans_proto
		AND V_SERVER_STATS.server_port = V_SERVER_GROUP_INFO.serv_port
		AND V_SERVER_STATS.server_ip = V_SERVER_GROUP_INFO.server_primary_ip

		GROUP BY V_SERVER_STATS.create_timestamp 
		ORDER BY V_SERVER_STATS.create_timestamp ASC LIMIT 5000;
ELSEIF DeptID = 0 THEN
	SELECT create_timestamp, sum(sess_allowed) Conn_Allowed_Session, sum(sess_rejected) Conn_Rejected_Session
		FROM V_SERVER_STATS, V_SERVER_GROUP_INFO 
		WHERE V_SERVER_STATS.cust_id  =  V_SERVER_GROUP_INFO.cust_id
		AND	V_SERVER_STATS.dep_id = V_SERVER_GROUP_INFO.dept_id
		AND V_SERVER_STATS.protocol = V_SERVER_GROUP_INFO.trans_proto
		AND V_SERVER_STATS.server_port = V_SERVER_GROUP_INFO.serv_port
		AND V_SERVER_STATS.server_ip = V_SERVER_GROUP_INFO.server_primary_ip

		AND V_SERVER_STATS.cust_id = CustID

		GROUP BY V_SERVER_STATS.create_timestamp 
		ORDER BY V_SERVER_STATS.create_timestamp ASC LIMIT 5000;

ELSEIF GroupID = 0 THEN
	SELECT create_timestamp, sum(sess_allowed) Conn_Allowed_Session, sum(sess_rejected) Conn_Rejected_Session
		FROM V_SERVER_STATS, V_SERVER_GROUP_INFO 
		WHERE V_SERVER_STATS.cust_id  =  V_SERVER_GROUP_INFO.cust_id
		AND	V_SERVER_STATS.dep_id = V_SERVER_GROUP_INFO.dept_id
		AND V_SERVER_STATS.protocol = V_SERVER_GROUP_INFO.trans_proto
		AND V_SERVER_STATS.server_port = V_SERVER_GROUP_INFO.serv_port
		AND V_SERVER_STATS.server_ip = V_SERVER_GROUP_INFO.server_primary_ip

		AND V_SERVER_STATS.cust_id = CustID
		AND V_SERVER_STATS.dep_id = DeptID

		GROUP BY V_SERVER_STATS.create_timestamp 
		ORDER BY V_SERVER_STATS.create_timestamp ASC LIMIT 5000;
ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
	SELECT create_timestamp, sum(sess_allowed) Conn_Allowed_Session, sum(sess_rejected) Conn_Rejected_Session
		FROM V_SERVER_STATS, V_SERVER_GROUP_INFO 
		WHERE V_SERVER_STATS.cust_id  =  V_SERVER_GROUP_INFO.cust_id
		AND	V_SERVER_STATS.dep_id = V_SERVER_GROUP_INFO.dept_id
		AND V_SERVER_STATS.protocol = V_SERVER_GROUP_INFO.trans_proto
		AND V_SERVER_STATS.server_port = V_SERVER_GROUP_INFO.serv_port
		AND V_SERVER_STATS.server_ip = V_SERVER_GROUP_INFO.server_primary_ip

		AND V_SERVER_STATS.cust_id = CustID
		AND V_SERVER_STATS.dep_id = DeptID
		AND V_SERVER_GROUP_INFO.grp_id = GroupID

		GROUP BY V_SERVER_STATS.create_timestamp 
		ORDER BY V_SERVER_STATS.create_timestamp ASC LIMIT 5000;

	ELSE
	SELECT create_timestamp, sum(sess_allowed) Conn_Allowed_Session, sum(sess_rejected) Conn_Rejected_Session
		FROM V_SERVER_STATS, V_SERVER_GROUP_INFO 
		WHERE V_SERVER_STATS.cust_id  =  V_SERVER_GROUP_INFO.cust_id
		AND	V_SERVER_STATS.dep_id = V_SERVER_GROUP_INFO.dept_id
		AND V_SERVER_STATS.protocol = V_SERVER_GROUP_INFO.trans_proto
		AND V_SERVER_STATS.server_port = V_SERVER_GROUP_INFO.serv_port
		AND V_SERVER_STATS.server_ip = V_SERVER_GROUP_INFO.server_primary_ip

		AND V_SERVER_STATS.cust_id = CustID
		AND V_SERVER_STATS.dep_id = DeptID
		AND V_SERVER_GROUP_INFO.grp_id = GroupID
		AND trim(ServerIP) = trim(V_SERVER_STATS.server_ip)

		GROUP BY V_SERVER_STATS.create_timestamp 
		ORDER BY V_SERVER_STATS.create_timestamp ASC LIMIT 5000;

END IF;

END //

-- ---------------------------------------------------------------------

-- Drop Details counts graph.
/* 
call Dashboard_Drop_Details_SP (0,0,0,'');
call Dashboard_Drop_Details_SP (1,0,0,'');
call Dashboard_Drop_Details_SP (1,2,0,'');
call Dashboard_Drop_Details_SP (1,2,34,NULL);
call Dashboard_Drop_Details_SP (1, 2, 34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Drop_Details_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Drop_Details_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )
BEGIN
IF CustID = 0 THEN
	SELECT vss.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
	ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
	/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
	FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
	WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
	AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port
	AND vss.server_ip = vgi.server_primary_ip
	
	GROUP BY vss.create_timestamp 
	ORDER BY vss.create_timestamp ASC LIMIT 5000;

ELSEIF DeptID = 0 THEN
	SELECT vss.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
	ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
	/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
	FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
	WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
	AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port
	AND vss.server_ip = vgi.server_primary_ip
	
	AND vss.cust_id = CustID

	GROUP BY vss.create_timestamp
	ORDER BY vss.create_timestamp ASC LIMIT 5000;

	ELSEIF GroupID = 0 THEN
		SELECT vss.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
		ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
		/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
		FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
		WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
		AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port
		AND vss.server_ip = vgi.server_primary_ip

		AND vss.cust_id = CustID
		AND vss.dep_id = DeptID

		GROUP BY vss.create_timestamp 
		ORDER BY vss.create_timestamp ASC LIMIT 5000;

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT vss.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
			ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
			/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
			FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
			WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
			AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port
			AND vss.server_ip = vgi.server_primary_ip

			AND vss.cust_id = CustID
			AND vss.dep_id = DeptID
			AND vgi.grp_id = GroupID
			ORDER BY vss.create_timestamp ASC LIMIT 5000;

			ELSE
				SELECT vss.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
				ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
				/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
				FROM V_SERVER_STATS vss, V_SERVER_GROUP_INFO vgi
				WHERE vss.cust_id  =  vgi.cust_id AND	vss.dep_id = vgi.dept_id
				AND vss.protocol = vgi.trans_proto AND vss.server_port = vgi.serv_port
				AND vss.server_ip = vgi.server_primary_ip

				AND vss.cust_id = CustID
				AND vss.dep_id = DeptID
				AND vgi.grp_id = GroupID
				AND trim(ServerIP) = trim(vss.server_ip)

				GROUP BY vss.create_timestamp 
				ORDER BY vss.create_timestamp ASC LIMIT 5000;
END IF;

END//	

-- ---------------------------------------------------------------------------------

-- Drop Details history graph.
/* 
call Dashboard_Drop_Details_History_SP (0,0,0,'');
call Dashboard_Drop_Details_History_SP (1,0,0,'');
call Dashboard_Drop_Details_History_SP (1,2,0,'');
call Dashboard_Drop_Details_History_SP (1,2,34,NULL);
call Dashboard_Drop_Details_History_SP (1, 2, 34,'195.172.5.51');

*/

DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Drop_Details_History_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Drop_Details_History_SP(IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80) )
BEGIN
IF CustID = 0 THEN
	SELECT vsd.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
	ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
	/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
	FROM V_SERVER_DESCRIPTORS vsd, V_SERVER_GROUP_INFO vgi
	WHERE vsd.cust_id  =  vgi.cust_id AND	vsd.dep_id = vgi.dept_id
	AND vsd.protocol = vgi.trans_proto AND vsd.server_port = vgi.serv_port
	AND vsd.server_ip = vgi.server_primary_ip
	
	GROUP BY vsd.create_timestamp 
	ORDER BY vsd.create_timestamp ASC LIMIT 5000;

ELSEIF DeptID = 0 THEN
	SELECT vsd.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
	ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
	/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
	FROM V_SERVER_DESCRIPTORS vsd, V_SERVER_GROUP_INFO vgi
	WHERE vsd.cust_id  =  vgi.cust_id AND	vsd.dep_id = vgi.dept_id
	AND vsd.protocol = vgi.trans_proto AND vsd.server_port = vgi.serv_port
	AND vsd.server_ip = vgi.server_primary_ip
	
	AND vsd.cust_id = CustID

	GROUP BY vsd.create_timestamp
	ORDER BY vsd.create_timestamp ASC LIMIT 5000;

	ELSEIF GroupID = 0 THEN
		SELECT vsd.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
		ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
		/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
		FROM V_SERVER_DESCRIPTORS vsd, V_SERVER_GROUP_INFO vgi
		WHERE vsd.cust_id  =  vgi.cust_id AND	vsd.dep_id = vgi.dept_id
		AND vsd.protocol = vgi.trans_proto AND vsd.server_port = vgi.serv_port
		AND vsd.server_ip = vgi.server_primary_ip

		AND vsd.cust_id = CustID
		AND vsd.dep_id = DeptID

		GROUP BY vsd.create_timestamp 
		ORDER BY vsd.create_timestamp ASC LIMIT 5000;

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT vsd.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
			ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
			/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
			FROM V_SERVER_DESCRIPTORS vsd, V_SERVER_GROUP_INFO vgi
			WHERE vsd.cust_id  =  vgi.cust_id AND	vsd.dep_id = vgi.dept_id
			AND vsd.protocol = vgi.trans_proto AND vsd.server_port = vgi.serv_port
			AND vsd.server_ip = vgi.server_primary_ip

			AND vsd.cust_id = CustID
			AND vsd.dep_id = DeptID
			AND vgi.grp_id = GroupID
			ORDER BY vsd.create_timestamp ASC LIMIT 5000;

			ELSE
				SELECT vsd.create_timestamp, ifnull(sum(sess_rej_policies),0) AS sess_rej_policies, 
				ifnull(sum(sess_rej_custid),0) AS sess_rej_custid, ifnull(sum(sess_rej_depid),0) AS sess_rej_depid, ifnull(sum(sess_rej_osfails),0) AS sess_rej_osfails
				/*ifnull(sum(sess_rej_sla),0) AS sess_rej_sla, ifnull(sum(pl_rej_secsig),0) AS pl_rej_secsig */
				FROM V_SERVER_DESCRIPTORS vsd, V_SERVER_GROUP_INFO vgi
				WHERE vsd.cust_id  =  vgi.cust_id AND	vsd.dep_id = vgi.dept_id
				AND vsd.protocol = vgi.trans_proto AND vsd.server_port = vgi.serv_port
				AND vsd.server_ip = vgi.server_primary_ip

				AND vsd.cust_id = CustID
				AND vsd.dep_id = DeptID
				AND vgi.grp_id = GroupID
				AND trim(ServerIP) = trim(vsd.server_ip)

				GROUP BY vsd.create_timestamp 
				ORDER BY vsd.create_timestamp ASC LIMIT 5000;
END IF;

END//

-- -----------------------------------------------------------------------------------
/*
-- UNIT TESTS
 call DashBoard_Filters_SP (0, 0, 0);
 call DashBoard_Filters_SP (1, 0, 0);
 call DashBoard_Filters_SP (1, 2, 60767);
 call DashBoard_Filters_SP (3, 4, 0);
 call DashBoard_Filters_SP (0, 4, 0);
*/

-- SP for Dashboard Filters 
DELIMITER //
DROP PROCEDURE IF EXISTS DashBoard_Filters_SP //
DELIMITER //
CREATE PROCEDURE DashBoard_Filters_SP(IN CustID INT, IN DeptID INT, IN GroupID INT)
BEGIN
IF CustID = 0 THEN
	SELECT DISTINCT cust_id,customer_name FROM V_SERVER_GROUP_INFO;
	SELECT DISTINCT dept_id,dept_name FROM V_SERVER_GROUP_INFO;
	SELECT DISTINCT grp_id, app_name FROM V_SERVER_GROUP_INFO;
	SELECT DISTINCT server_id, management_ip, server_primary_ip, server_name FROM V_SERVER_GROUP_INFO;
ELSEIF DeptID = 0 THEN
		SELECT DISTINCT cust_id,customer_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID;
		SELECT DISTINCT dept_id,dept_name FROM V_SERVER_GROUP_INFO  WHERE cust_id = CustID;
		SELECT DISTINCT grp_id, app_name FROM V_SERVER_GROUP_INFO  WHERE cust_id = CustID;
		SELECT DISTINCT server_id, management_ip, server_primary_ip, server_name FROM V_SERVER_GROUP_INFO  WHERE cust_id = CustID;
	ELSEIF GroupID = 0 THEN
			SELECT DISTINCT cust_id,customer_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID;
			SELECT DISTINCT dept_id,dept_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID;
			SELECT DISTINCT grp_id, app_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID;
			SELECT DISTINCT server_id, management_ip, server_primary_ip, server_name FROM V_SERVER_GROUP_INFO  WHERE cust_id = CustID AND dept_id = DeptID;
		ELSE
			SELECT DISTINCT cust_id,customer_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID;
			SELECT DISTINCT dept_id,dept_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID;
			SELECT DISTINCT grp_id, app_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID AND grp_id = GroupID ;
			SELECT DISTINCT server_id, management_ip, server_primary_ip, server_name FROM V_SERVER_GROUP_INFO WHERE cust_id = CustID AND dept_id = DeptID AND grp_id = GroupID ;
END IF;

END //

-- --------------------------------------------------------------------------------------------------------------------------------------------
-- Save_Stats_History_SP
-- ---------------------------------------------------------------------------------------------------------------------------------------------

DELIMITER //
DROP PROCEDURE IF EXISTS Save_Stats_History_SP //
DELIMITER //
CREATE PROCEDURE  Save_Stats_History_SP (IN INUUID VARCHAR(36), IN INSOCKUUID VARCHAR(36) )
BEGIN
IF INUUID IS NOT NULL AND INSOCKUUID IS NOT NULL AND trim(INUUID) != '' AND trim(INSOCKUUID) != '' THEN
	IF EXISTS ( SELECT uuid FROM server_descriptor_tb WHERE trim(upper(server_descriptor_tb.uuid)) = trim(upper(INUUID)) AND trim(upper(server_descriptor_tb.socket_uuid)) = trim(upper(INSOCKUUID)) ) THEN	
		UPDATE server_stats_tb sst,server_descriptor_tb sdt
		SET 
		sdt.app_name =  sst.app_name ,
		sdt.process_name =  sst.process_name ,
		sdt.pid =  sst.pid ,
		sdt.cust_id =  sst.cust_id,
		sdt.dep_id =  sst.dep_id,
		sdt.adpl_app_id =  sst.adpl_app_id,
		sdt.server_count =  sst.server_count,
		sdt.count_max_client =  sst.count_max_client,
		sdt.protocol =  sst.protocol,
		sdt.server_port =  sst.server_port,
		sdt.server_ip =  sst.server_ip,
		sdt.conn_reject_count =  sst.conn_reject_count,
		sdt.create_timestamp =  sst.create_timestamp,
		sdt.client_count =  sst.client_count,
		sdt.sess_allowed =  sst.sess_allowed,
		sdt.sess_rejected =  sst.sess_rejected,
		sdt.sess_rej_policies =  sst.sess_rej_policies,
		sdt.sess_rej_custid =  sst.sess_rej_custid,
		sdt.sess_rej_depid =  sst.sess_rej_depid,
		sdt.sess_rej_sla =  sst.sess_rej_sla,
		sdt.sess_rej_osfails =  sst.sess_rej_osfails,
		sdt.server_status_id =  sst.server_status_id,
		sdt.close_reason =  sst.close_reason,    
		sdt.created_on =  sst.created_on,
		sdt.modify_on =  sst.modify_on
		WHERE sdt.uuid = INUUID AND sdt.socket_uuid = INSOCKUUID
		AND sst.uuid = sdt.uuid AND sst.socket_uuid = sdt.socket_uuid ;
		
		UPDATE client_stats_tb cst,  client_descriptor_tb cdt 
		SET
		cdt.send_count =  cst.send_count,
		cdt.recv_count =  cst.recv_count,
		cdt.send_bytes =  cst.send_bytes,
		cdt.recv_bytes =  cst.recv_bytes,
		cdt.recv_rejected_bytes =  cst.recv_rejected_bytes,
		cdt.cust_dept_mismatch_count =  cst.cust_dept_mismatch_count,
		cdt.sig_mismatch_count =  cst.sig_mismatch_count,
		cdt.security_prof_chng_count =  cst.security_prof_chng_count,
		cdt.pl_rej_policies =  cst.pl_rej_policies,
		cdt.pl_rej_custid =  cst.pl_rej_custid,
		cdt.pl_rej_depid =  cst.pl_rej_depid,
		cdt.pl_rej_secsig =  cst.pl_rej_secsig,
		cdt.pl_allowed_policies =  cst.pl_allowed_policies,
		cdt.pl_allowed =  cst.pl_allowed,
		cdt.pl_bytes_rej_policies =  cst.pl_bytes_rej_policies,
		cdt.pl_bytes_rej_custid =  cst.pl_bytes_rej_custid,
		cdt.pl_bytes_rej_depid =  cst.pl_bytes_rej_depid,
		cdt.pl_bytes_rej_secsig =  cst.pl_bytes_rej_secsig,
		cdt.created_on =  cst.created_on,
		cdt.modify_on =  cst.modify_on,
		cdt.close_reason =  cst.close_reason,
		cdt.close_timestamp =  cst.close_timestamp,
		cdt.pl_rej_sqlinj = cst.pl_rej_sqlinj,
		cdt.pl_bytes_rej_sqlinj = cst.pl_bytes_rej_sqlinj
		WHERE cdt.server_uuid = INUUID AND cdt.server_socket_uuid = INSOCKUUID
		AND cst.client_uuid = cdt.client_uuid;
		
		INSERT INTO client_descriptor_tb ( client_port,client_ip,client_uuid,server_uuid,server_socket_uuid,send_count,recv_count,send_bytes,recv_bytes,recv_rejected_bytes,
		cust_dept_mismatch_count,sig_mismatch_count,security_prof_chng_count,
		pl_rej_policies,pl_rej_custid,pl_rej_depid,pl_rej_secsig,pl_allowed_policies,pl_allowed,
		pl_bytes_rej_policies,pl_bytes_rej_custid,pl_bytes_rej_depid,pl_bytes_rej_secsig,created_on,modify_on,close_reason,close_timestamp,pl_rej_sqlinj,pl_bytes_rej_sqlinj)
		SELECT client_port,client_ip,client_uuid,server_uuid,server_socket_uuid,send_count,recv_count,send_bytes,recv_bytes,recv_rejected_bytes,
		cust_dept_mismatch_count,sig_mismatch_count,security_prof_chng_count,
		pl_rej_policies,pl_rej_custid,pl_rej_depid,pl_rej_secsig,pl_allowed_policies,pl_allowed,
		pl_bytes_rej_policies,pl_bytes_rej_custid,pl_bytes_rej_depid,pl_bytes_rej_secsig,created_on,modify_on,close_reason,close_timestamp,pl_rej_sqlinj,pl_bytes_rej_sqlinj
		FROM client_stats_tb cst WHERE cst.server_uuid = INUUID AND cst.server_socket_uuid = INSOCKUUID
		AND (cst.client_uuid) NOT IN (SELECT client_uuid FROM client_descriptor_tb WHERE server_uuid = INUUID AND server_socket_uuid = INSOCKUUID) ;
		
	ELSE
		INSERT INTO server_descriptor_tb ( app_name,process_name,pid,cust_id,dep_id,server_count,count_max_client,
		protocol,server_port,server_ip,conn_reject_count,create_timestamp,client_count,
		sess_allowed,sess_rejected,sess_rej_policies,sess_rej_custid,sess_rej_depid,sess_rej_sla,sess_rej_osfails,
		uuid,socket_uuid,created_on,modify_on,close_reason,adpl_app_id) 
		SELECT app_name,process_name,pid,cust_id,dep_id,server_count,count_max_client,
		protocol,server_port,server_ip,conn_reject_count,create_timestamp,client_count,
		sess_allowed,sess_rejected,sess_rej_policies,sess_rej_custid,sess_rej_depid,sess_rej_sla,sess_rej_osfails,
		uuid,socket_uuid, created_on,modify_on,close_reason,adpl_app_id
		FROM server_stats_tb sst WHERE trim(upper(sst.uuid)) = trim(upper(INUUID)) AND trim(upper(sst.socket_uuid)) = trim(upper(INSOCKUUID)) ;
		
		INSERT INTO client_descriptor_tb (client_port, client_ip,client_uuid,server_uuid,server_socket_uuid,send_count,recv_count,send_bytes,recv_bytes,recv_rejected_bytes,
		cust_dept_mismatch_count,sig_mismatch_count,security_prof_chng_count,
		pl_rej_policies,pl_rej_custid,pl_rej_depid,pl_rej_secsig,pl_allowed_policies,pl_allowed,
		pl_bytes_rej_policies,pl_bytes_rej_custid,pl_bytes_rej_depid,pl_bytes_rej_secsig,created_on,modify_on,close_reason,close_timestamp,pl_rej_sqlinj,pl_bytes_rej_sqlinj)
		SELECT client_port, client_ip,client_uuid,server_uuid,server_socket_uuid,send_count,recv_count,send_bytes,recv_bytes,recv_rejected_bytes,
		cust_dept_mismatch_count,sig_mismatch_count,security_prof_chng_count,
		pl_rej_policies,pl_rej_custid,pl_rej_depid,pl_rej_secsig,pl_allowed_policies,pl_allowed,
		pl_bytes_rej_policies,pl_bytes_rej_custid,pl_bytes_rej_depid,pl_bytes_rej_secsig,created_on,modify_on,close_reason,close_timestamp,pl_rej_sqlinj,pl_bytes_rej_sqlinj
		FROM client_stats_tb cst WHERE trim(upper(cst.server_uuid)) = trim(upper(INUUID)) AND trim(upper(cst.server_socket_uuid)) = trim(upper(INSOCKUUID)) ;

	END IF;
END IF;

END //
-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Save_Server_Stats_History_SP
-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DELIMITER //
DROP PROCEDURE IF EXISTS Save_Server_Stats_History_SP //
DELIMITER //
CREATE PROCEDURE Save_Server_Stats_History_SP (IN INUUID VARCHAR(36), IN INSOCKUUID VARCHAR(36))
BEGIN
	IF INUUID IS NOT NULL AND INSOCKUUID IS NOT NULL AND trim(INUUID) != '' AND trim(INSOCKUUID) != '' THEN
		IF EXISTS ( SELECT uuid FROM server_descriptor_tb WHERE trim(upper(server_descriptor_tb.uuid)) = trim(upper(INUUID)) AND trim(upper(server_descriptor_tb.socket_uuid)) = trim(upper(INSOCKUUID)) ) THEN
			UPDATE server_stats_tb sst,server_descriptor_tb sdt
			SET 
			sdt.app_name =  sst.app_name ,
			sdt.process_name =  sst.process_name,
        	sdt.cust_id =  sst.cust_id,
			sdt.dep_id =  sst.dep_id,
			sdt.server_ip =  sst.server_ip,
			sdt.server_port =  sst.server_port,
			sdt.protocol =  sst.protocol,
			sdt.adpl_app_id =  sst.adpl_app_id,
			sdt.pid =  sst.pid ,
			sdt.server_count =  sst.server_count,
			sdt.client_count =  sst.client_count,
			sdt.create_timestamp =  sst.create_timestamp,
			sdt.count_max_client =  sst.count_max_client,
			sdt.conn_reject_count =  sst.conn_reject_count,
			sdt.sess_allowed =  sst.sess_allowed,
			sdt.sess_rejected =  sst.sess_rejected,
			sdt.sess_rej_policies =  sst.sess_rej_policies,
			sdt.sess_rej_custid =  sst.sess_rej_custid,
			sdt.sess_rej_depid =  sst.sess_rej_depid,
			sdt.sess_rej_sla =  sst.sess_rej_sla,
			sdt.sess_rej_osfails =  sst.sess_rej_osfails,
			sdt.server_status_id =  sst.server_status_id,
			sdt.close_reason =  sst.close_reason,    
			sdt.modify_on =  sst.modify_on
			WHERE sdt.uuid = INUUID AND sdt.socket_uuid = INSOCKUUID
			AND sst.uuid = sdt.uuid AND sst.socket_uuid = sdt.socket_uuid ;
		
		ELSE
			INSERT INTO server_descriptor_tb ( app_name,process_name,cust_id,dep_id,server_ip,server_port,protocol,adpl_app_id,
        	pid,uuid,socket_uuid,server_count,client_count,create_timestamp,count_max_client,conn_reject_count,
			sess_allowed,sess_rejected,sess_rej_policies,sess_rej_custid,sess_rej_depid,sess_rej_sla,sess_rej_osfails,
			close_reason,created_on,modify_on) 
			SELECT app_name,process_name,cust_id,dep_id,server_ip,server_port,protocol,adpl_app_id,
        	pid,uuid,socket_uuid,server_count,client_count,create_timestamp,count_max_client,conn_reject_count,
			sess_allowed,sess_rejected,sess_rej_policies,sess_rej_custid,sess_rej_depid,sess_rej_sla,sess_rej_osfails,
			close_reason,created_on,modify_on
			FROM server_stats_tb sst WHERE trim(upper(sst.uuid)) = trim(upper(INUUID)) AND trim(upper(sst.socket_uuid)) = trim(upper(INSOCKUUID)) ;
		
		END IF;
	END IF;

END //

-- ------------------------------------------------------------------------------------------------------------------------------------------------------
-- Save_Client_Stats_History_SP
-- ------------------------------------------------------------------------------------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS Save_Client_Stats_History_SP //
DELIMITER //
CREATE PROCEDURE Save_Client_Stats_History_SP (IN INCLIENTUUID VARCHAR(36))
BEGIN
	IF INCLIENTUUID IS NOT NULL AND trim(INCLIENTUUID) != '' THEN
		IF EXISTS ( SELECT client_uuid FROM client_descriptor_tb WHERE trim(upper(client_descriptor_tb.client_uuid)) = trim(upper(INCLIENTUUID)) ) THEN
       		UPDATE client_stats_tb cst,  client_descriptor_tb cdt 
			SET
			cdt.send_count =  cst.send_count,
			cdt.recv_count =  cst.recv_count,
			cdt.send_bytes =  cst.send_bytes,
			cdt.recv_bytes =  cst.recv_bytes,
			cdt.recv_rejected_bytes =  cst.recv_rejected_bytes,
			cdt.cust_dept_mismatch_count =  cst.cust_dept_mismatch_count,
			cdt.sig_mismatch_count =  cst.sig_mismatch_count,
			cdt.security_prof_chng_count =  cst.security_prof_chng_count,
			cdt.pl_rej_policies =  cst.pl_rej_policies,
			cdt.pl_rej_custid =  cst.pl_rej_custid,
			cdt.pl_rej_depid =  cst.pl_rej_depid,
			cdt.pl_rej_secsig =  cst.pl_rej_secsig,
       		cdt.pl_rej_sqlinj = cst.pl_rej_sqlinj,
			cdt.pl_allowed_policies =  cst.pl_allowed_policies,
			cdt.pl_allowed =  cst.pl_allowed,
			cdt.pl_bytes_rej_policies =  cst.pl_bytes_rej_policies,
			cdt.pl_bytes_rej_custid =  cst.pl_bytes_rej_custid,
			cdt.pl_bytes_rej_depid =  cst.pl_bytes_rej_depid,
			cdt.pl_bytes_rej_secsig =  cst.pl_bytes_rej_secsig,
			cdt.pl_bytes_rej_sqlinj = cst.pl_bytes_rej_sqlinj,
			cdt.modify_on =  cst.modify_on,
			cdt.close_reason =  cst.close_reason,
			cdt.close_timestamp =  cst.close_timestamp
			WHERE cst.client_uuid = cdt.client_uuid
            AND cdt.client_uuid = INCLIENTUUID;
        
		ELSE
			INSERT INTO client_descriptor_tb (client_port, client_ip,client_uuid,server_uuid,server_socket_uuid,send_count,recv_count,
			send_bytes,recv_bytes,recv_rejected_bytes,cust_dept_mismatch_count,sig_mismatch_count,security_prof_chng_count,
			pl_rej_policies,pl_rej_custid,pl_rej_depid,pl_rej_secsig,pl_rej_sqlinj,pl_allowed_policies,pl_allowed,
			pl_bytes_rej_policies,pl_bytes_rej_custid,pl_bytes_rej_depid,pl_bytes_rej_secsig,pl_bytes_rej_sqlinj,close_reason,close_timestamp,created_on,modify_on)
			SELECT client_port, client_ip,client_uuid,server_uuid,server_socket_uuid,send_count,recv_count,send_bytes,recv_bytes,recv_rejected_bytes,
			cust_dept_mismatch_count,sig_mismatch_count,security_prof_chng_count,
			pl_rej_policies,pl_rej_custid,pl_rej_depid,pl_rej_secsig,pl_rej_sqlinj,pl_allowed_policies,pl_allowed,
			pl_bytes_rej_policies,pl_bytes_rej_custid,pl_bytes_rej_depid,pl_bytes_rej_secsig,pl_bytes_rej_sqlinj,close_reason,close_timestamp,created_on,modify_on
			FROM client_stats_tb cst WHERE trim(upper(cst.client_uuid)) = trim(upper(INCLIENTUUID)) ;
			
		END IF;
	END IF;
END //


-- ------------------------------------------------------------------------------------------------------------------------------------------------
-- Insert Server Stats
-- ------------------------------------------------------------------------------------------------------------------------------------------------
DELIMITER //
drop procedure if exists Insert_Server_Stats_SP //
DELIMITER //
create procedure Insert_Server_Stats_SP(in app_name_in varchar(256), in process_name_in varchar(4096), in pid_in int, in cust_id_in int, in dep_id_in int, in adpl_app_id_in int, in server_port_in int, in server_ip_in varchar(45), in protocol_in int, in uuid_in varchar(36), in socket_uuid_in varchar(36), in client_count_in int, in sess_allowed_in int, in sess_rejected_in int, in sess_rej_policies_in int, in sess_rej_custid_in int, in sess_rej_depid_in int, in sess_rej_osfails_in int, in pl_rejected_in int)
begin 
	declare exit handler for sqlexception
    begin
    rollback;
    resignal;
    end;
    start transaction;
	if exists(select 1 from app_info_tb where uuid = uuid_in and socket_uuid = socket_uuid_in) then
		INSERT INTO server_stats_tb (
			app_name, 
			process_name, 
			pid, 
			cust_id, 
			dep_id, 
			adpl_app_id, 
			server_port, 
			server_ip, 
			protocol, 
			uuid, 
			socket_uuid, 
			client_count, 
			sess_allowed, 
			sess_rejected, 
			sess_rej_policies, 
			sess_rej_custid, 
			sess_rej_depid, 
			sess_rej_osfails,
			pl_rejected,
			created_on, 
			modify_on ) 
		VALUES (
			app_name_in, 
			process_name_in, 
			pid_in, 
			cust_id_in, 
			dep_id_in, 
			adpl_app_id_in, 
			server_port_in, 
			server_ip_in, 
			protocol_in, 
			uuid_in, 
			socket_uuid_in, 
			client_count_in, 
			sess_allowed_in, 
			sess_rejected_in, 
			sess_rej_policies_in, 
			sess_rej_custid_in, 
			sess_rej_depid_in, 
			sess_rej_osfails_in, 
			pl_rejected_in,
			now(), 
			now() ) 
		ON DUPLICATE KEY UPDATE 
			app_name = app_name_in, 
			process_name = process_name_in, 
			pid = pid_in, 
			cust_id = cust_id_in, 
			dep_id = dep_id_in, 
			adpl_app_id = adpl_app_id_in, 
			server_port = server_port_in, 
			server_ip = server_ip_in, 
			protocol = protocol_in, 
			sess_allowed = sess_allowed_in, 
			sess_rejected = sess_rejected_in, 
			sess_rej_policies = sess_rej_policies_in, 
			sess_rej_custid = sess_rej_custid_in, 
			sess_rej_depid = sess_rej_depid_in, 
			sess_rej_osfails = sess_rej_osfails_in,
			pl_rejected = pl_rejected_in,
			modify_on = now();
        
        INSERT INTO server_descriptor_tb (
        	app_name, 
			process_name, 
			pid, 
			cust_id, 
			dep_id, 
			adpl_app_id, 
			server_port, 
			server_ip, 
			protocol, 
			uuid, 
			socket_uuid, 
			client_count, 
			sess_allowed, 
			sess_rejected, 
			sess_rej_policies, 
			sess_rej_custid, 
			sess_rej_depid, 
			sess_rej_osfails, 
			pl_rejected,
			created_on, 
			modify_on ) 
		VALUES (
			app_name_in, 
			process_name_in, 
			pid_in, 
			cust_id_in, 
			dep_id_in, 
			adpl_app_id_in, 
			server_port_in, 
			server_ip_in, 
			protocol_in, 
			uuid_in, 
			socket_uuid_in, 
			client_count_in, 
			sess_allowed_in, 
			sess_rejected_in, 
			sess_rej_policies_in, 
			sess_rej_custid_in, 
			sess_rej_depid_in, 
			sess_rej_osfails_in, 
			pl_rejected_in,
			now(), 
			now() ) 
		ON DUPLICATE KEY UPDATE 
			app_name = app_name_in, 
			process_name = process_name_in, 
			pid = pid_in, 
			cust_id = cust_id_in, 
			dep_id = dep_id_in, 
			adpl_app_id = adpl_app_id_in, 
			server_port = server_port_in, 
			server_ip = server_ip_in, 
			protocol = protocol_in, 
			sess_allowed = sess_allowed_in, 
			sess_rejected = sess_rejected_in, 
			sess_rej_policies = sess_rej_policies_in, 
			sess_rej_custid = sess_rej_custid_in, 
			sess_rej_depid = sess_rej_depid_in, 
			sess_rej_osfails = sess_rej_osfails_in, 
			pl_rejected = pl_rejected_in,
			modify_on = now();
    end if;
    commit;
end //


-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- Insert Client Stats SP
-- ----------------------------------------------------------------------------------------------------------------------------------------------
DELIMITER //
drop procedure if exists Insert_Client_Stats_SP //
DELIMITER //
create procedure Insert_Client_Stats_SP(
	in client_port_in int, 
    in client_ip_in varchar(45), 
    in client_uuid_in varchar(36), 
    in server_uuid_in varchar(36), 
    in server_socket_uuid_in varchar(36), 
    in send_count_in int, in recv_count_in int, 
    in send_bytes_in int, 
    in recv_bytes_in int, 
    in pl_allowed_in int, 
    in pl_rej_policies_in int, 
    in pl_rej_cust_id_in int, 
    in pl_rej_depid_in int, 
    in pl_rej_secsig_in int, 
    in pl_rej_sqlinj_in int, 
    in pl_bytes_rej_policies_in int, 
    in pl_bytes_rej_cust_id_in int, 
    in pl_bytes_rej_depid_in int, 
    in pl_bytes_rej_secsig_in int, 
    in pl_bytes_rej_sqlinj_in int, 
    in close_reason_in int, 
    in close_timestamp_in timestamp)
begin
	declare exit handler for sqlexception
    begin
    rollback;
    resignal;
    end;
    start transaction;
	insert into client_stats_tb (
		client_port, 
        client_ip, 
        client_uuid, 
        server_uuid, 
        server_socket_uuid, 
        send_count, 
        recv_count, 
        send_bytes, 
        recv_bytes, 
        pl_allowed, 
        pl_rej_policies, 
        pl_rej_custid, 
        pl_rej_depid, 
        pl_rej_secsig, 
        pl_rej_sqlinj, 
        pl_bytes_rej_policies, 
        pl_bytes_rej_custid, 
        pl_bytes_rej_depid, 
        pl_bytes_rej_secsig, 
        pl_bytes_rej_sqlinj, 
        close_reason, 
        close_timestamp, 
        created_on, 
        modify_on)
    values (
		client_port_in, 
        client_ip_in, 
        client_uuid_in, 
        server_uuid_in, 
        server_socket_uuid_in, 
        send_count_in, 
        recv_count_in, 
        send_bytes_in, 
        recv_bytes_in, 
        pl_allowed_in, 
        pl_rej_policies_in, 
        pl_rej_cust_id_in, 
        pl_rej_depid_in, 
        pl_rej_secsig_in, 
        pl_rej_sqlinj_in, 
        pl_bytes_rej_policies_in, 
        pl_bytes_rej_cust_id_in, 
        pl_bytes_rej_depid_in, 
        pl_bytes_rej_secsig_in, 
        pl_bytes_rej_sqlinj_in, 
        close_reason_in, 
        close_timestamp_in, 
        now(), 
        now())
    on duplicate key update 
		send_count = send_count_in, 
		recv_count = recv_count_in, 
        send_bytes = send_bytes_in, 
        recv_bytes = recv_bytes_in, 
        pl_allowed = pl_allowed_in, 
        pl_rej_policies = pl_rej_policies_in, 
        pl_rej_custid = pl_rej_cust_id_in, 
        pl_rej_depid = pl_rej_depid_in, 
        pl_rej_secsig = pl_rej_secsig_in, 
        pl_rej_sqlinj = pl_rej_sqlinj_in, 
		pl_bytes_rej_policies = pl_bytes_rej_policies_in,
        pl_bytes_rej_custid = pl_bytes_rej_cust_id_in,
        pl_bytes_rej_depid = pl_bytes_rej_depid_in,
        pl_bytes_rej_secsig = pl_bytes_rej_secsig_in,
        pl_bytes_rej_sqlinj = pl_bytes_rej_sqlinj_in,
        close_reason = close_reason_in,
        close_timestamp = close_timestamp_in,
        modify_on = now();
        
	insert into client_descriptor_tb (
		client_port, 
        client_ip, 
        client_uuid, 
        server_uuid, 
        server_socket_uuid, 
        send_count, 
        recv_count, 
        send_bytes, 
        recv_bytes, 
        pl_allowed, 
        pl_rej_policies, 
        pl_rej_custid, 
        pl_rej_depid, 
        pl_rej_secsig, 
        pl_rej_sqlinj, 
        pl_bytes_rej_policies, 
        pl_bytes_rej_custid, 
        pl_bytes_rej_depid, 
        pl_bytes_rej_secsig, 
        pl_bytes_rej_sqlinj, 
        close_reason, 
        close_timestamp, 
        created_on, 
        modify_on)
    values (
		client_port_in, 
        client_ip_in, 
        client_uuid_in, 
        server_uuid_in, 
        server_socket_uuid_in, 
        send_count_in, 
        recv_count_in, 
        send_bytes_in, 
        recv_bytes_in, 
        pl_allowed_in, 
        pl_rej_policies_in, 
        pl_rej_cust_id_in, 
        pl_rej_depid_in, 
        pl_rej_secsig_in, 
        pl_rej_sqlinj_in, 
        pl_bytes_rej_policies_in, 
        pl_bytes_rej_cust_id_in, 
        pl_bytes_rej_depid_in, 
        pl_bytes_rej_secsig_in, 
        pl_bytes_rej_sqlinj_in, 
        close_reason_in, 
        close_timestamp, 
        now(), 
        now())
    on duplicate key update 
		send_count = send_count_in, 
		recv_count = recv_count_in, 
        send_bytes = send_bytes_in, 
        recv_bytes = recv_bytes_in, 
        pl_allowed = pl_allowed_in, 
        pl_rej_policies = pl_rej_policies_in, 
        pl_rej_custid = pl_rej_cust_id_in, 
        pl_rej_depid = pl_rej_depid_in, 
        pl_rej_secsig = pl_rej_secsig_in, 
        pl_rej_sqlinj = pl_rej_sqlinj_in, 
		pl_bytes_rej_policies = pl_bytes_rej_policies_in,
        pl_bytes_rej_custid = pl_bytes_rej_cust_id_in,
        pl_bytes_rej_depid = pl_bytes_rej_depid_in,
        pl_bytes_rej_secsig = pl_bytes_rej_secsig_in,
        pl_bytes_rej_sqlinj = pl_bytes_rej_sqlinj_in,
        close_reason = close_reason_in,
        close_timestamp = close_timestamp_in,
        modify_on = now();

	if(close_reason_in <> 0) then
		delete from client_stats_tb where client_uuid = client_uuid_in;
	end if;
	commit;
end //
		
-- ---------------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------------
DELIMITER //
DROP TRIGGER IF EXISTS ins_cust_dept_TRG //

CREATE TRIGGER ins_cust_dept_TRG BEFORE INSERT ON app_info_tb FOR EACH ROW
BEGIN
IF NOT EXISTS (SELECT * FROM customer_tb where cust_id = NEW.customer_id) THEN
	INSERT INTO customer_tb ( cust_id, customer_name ) VALUES ( NEW.customer_id, CONCAT ("Customer ", NEW.customer_id) );
END IF;

IF NOT EXISTS (SELECT * FROM department_tb where cust_id = NEW.customer_id AND dept_id = NEW.department_id ) THEN
	INSERT INTO department_tb ( cust_id, dept_id, dept_name ) VALUES ( NEW.customer_id, NEW.department_id, CONCAT ("Department ", NEW.customer_id, " - ", NEW.department_id) );
END IF;

END; //

-- ---------------------------------------------------------------------------------
DELIMITER //
DROP TRIGGER IF EXISTS upd_cust_dept_TRG //

CREATE TRIGGER upd_cust_dept_TRG BEFORE UPDATE ON app_info_tb FOR EACH ROW
BEGIN
IF NOT EXISTS (SELECT * FROM customer_tb where cust_id = NEW.customer_id) THEN
	INSERT INTO customer_tb ( cust_id, customer_name ) VALUES ( NEW.customer_id, CONCAT ("Customer ", NEW.customer_id) );
END IF;

IF NOT EXISTS (SELECT * FROM department_tb where cust_id = NEW.customer_id AND dept_id = NEW.department_id ) THEN
	INSERT INTO department_tb ( cust_id, dept_id, dept_name ) VALUES ( NEW.customer_id, NEW.department_id, CONCAT ("Department ", NEW.customer_id, " - ", NEW.department_id) );
END IF;

END; //

-- ---------------------------------------------------------------------------------

DELIMITER //
DROP PROCEDURE IF EXISTS Suspend_Schedule_Policies_SP //
DELIMITER //
CREATE  PROCEDURE Suspend_Schedule_Policies_SP(IN adplAppId INT, IN cid INT, IN did INT)
BEGIN

drop table if exists temp_policy_list_tb;
create table temp_policy_list_tb
select asp.policy_id , pst.policy_type 
from application_security_policy_tb asp, policy_scheduler_tb pst
where 1=2;

insert into temp_policy_list_tb (policy_id, policy_type)
select asp.policy_id , 
'application-security' as policy_type 
from application_security_policy_tb asp
where (adpl_app1_id = adplAppId or adpl_app2_id = adplAppId)
and lower(asp.status) = 'scheduled'
and ((asp.cust_id1 = cid and asp.dept_id1 = did) or (asp.cust_id2 = cid and asp.dept_id2 = did));

insert into temp_policy_list_tb (policy_id, policy_type)
select dsp.policy_id , 
'data-security' as policy_type 
from data_security_policy_tb dsp
where (adpl_app1_id = adplAppId or adpl_app2_id = adplAppId)
and lower(dsp.status) = 'scheduled'
and ((dsp.cust_id1 = cid and dsp.dept_id1 = did) or (dsp.cust_id2 = cid and dsp.dept_id2 = did));

select pschedule.schedule_id, pschedule.policy_id, pschedule.policy_type
from policy_scheduler_tb pschedule, temp_policy_list_tb tpl
where pschedule.policy_id = tpl.policy_id
and pschedule.policy_type = tpl.policy_type
and pschedule.action = 0;


drop table temp_policy_list_tb;

END //
DELIMITER //

-- deleting history data 
DELIMITER //
drop procedure  if exists Delete_History_Data_SP //
DELIMITER //
CREATE  PROCEDURE  Delete_History_Data_SP (IN adplAppID INT, IN cid INT, IN did INT)
BEGIN

drop table if exists temp_policy_list_tb;
CREATE TABLE temp_policy_list_tb SELECT asp.policy_id, pst.policy_type FROM
    application_security_policy_tb asp,
    policy_scheduler_tb pst
WHERE
    1 = 2;
    


insert into temp_policy_list_tb (policy_id, policy_type)
select asp.policy_id , 
'application-security' as policy_type 
from application_security_policy_tb asp
where (adpl_app1_id = adplAppId and asp.cust_id1 = cid and asp.dept_id1 = did) 
or (adpl_app2_id = adplAppId and asp.cust_id2 = cid and asp.dept_id2 = did);

insert into temp_policy_list_tb (policy_id, policy_type)
select dsp.policy_id , 
'data-security' as policy_type 
from data_security_policy_tb dsp
where (adpl_app1_id = adplAppId and dsp.cust_id1 = cid and dsp.dept_id1 = did) 
or (adpl_app2_id = adplAppId and dsp.cust_id2 = cid and dsp.dept_id2 = did);


DELETE FROM policy_scheduler_tb 
WHERE
    (policy_id , policy_type) IN (SELECT 
        policy_id, policy_type
    FROM
        temp_policy_list_tb);

DELETE FROM scheduled_application_security_policy_tb 
WHERE
    policy_id IN (SELECT 
        policy_id
    FROM
        temp_policy_list_tb
    
    WHERE
        LOWER(policy_type) = 'application-security');

DELETE FROM scheduled_data_security_policy_tb 
WHERE
    policy_id IN (SELECT 
        policy_id
    FROM
        temp_policy_list_tb
    
    WHERE
        LOWER(policy_type) = 'data-security');

DELETE FROM application_security_policy_tb 
WHERE
    (adpl_app1_id = adplAppId
    AND cust_id1 = cid
    AND dept_id1 = did)
    OR (adpl_app2_id = adplAppId
    AND cust_id2 = cid
    AND dept_id2 = did);


DELETE FROM data_security_policy_tb 
WHERE
    (adpl_app1_id = adplAppId
    AND cust_id1 = cid
    AND dept_id1 = did)
    OR (adpl_app2_id = adplAppId
    AND cust_id2 = cid
    AND dept_id2 = did);

DELETE FROM server_stats_tb 
WHERE
    uuid IN (SELECT 
        uuid
    FROM
        app_info_tb
    
    WHERE
        adpl_app_id = adplAppID
        AND customer_id = cid
        AND department_id = did);

DELETE FROM app_info_tb 
WHERE
    adpl_app_id = adplAppID
    AND customer_id = cid
    AND department_id = did;
    
    DELETE FROM permanent_app_info_tb
WHERE
    adpl_app_id = adplAppID
    AND customer_id = cid
    AND department_id = did;



drop table if exists temp_policy_list_tb;


END //

-- generating unique application id 
delimiter //
DROP PROCEDURE IF EXISTS Generate_App_ID //
delimiter //
CREATE  PROCEDURE Generate_App_ID(IN custID int, IN deptID int)
BEGIN
declare adplAppId, appVerifyCount int;
 
set adplAppId = 1;
drop table if exists temp_IDSeq;
create temporary table temp_IDSeq
(
    appID int
);

select count(app_id) into appVerifyCount from application_verification_tb where cid = custID and did = deptID;

if appVerifyCount = 0 then
	set adplAppId = 1; 
elseif appVerifyCount = 255 then
	set adplAppId = 256;
else 

insert into temp_IDSeq (appID) values (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), (13), (14), (15), (16), (17), (18), (19), (20), (21), (22), (23), (24), (25), (26), (27), (28), (29), (30), (31), (32), (33), (34), (35), (36), (37), (38), (39), (40), (41), (42), (43), (44), (45), (46), (47), (48), (49), (50), (51), (52), (53), (54), (55), (56), (57), (58), (59), (60), (61), (62), (63), (64), (65), (66), (67), (68), (69), (70), (71), (72), (73), (74), (75), (76), (77), (78), (79), (80), (81), (82), (83), (84), (85), (86), (87), (88), (89), (90), (91), (92), (93), (94), (95), (96), (97), (98), (99), (100), (101), (102), (103), (104), (105), (106), (107), (108), (109), (110), (111), (112), (113), (114), (115), (116), (117), (118), (119), (120), (121), (122), (123), (124), (125), (126), (127), (128), (129), (130), (131), (132), (133), (134), (135), (136), (137), (138), (139), (140), (141), (142), (143), (144), (145), (146), (147), (148), (149), (150), (151), (152), (153), (154), (155), (156), (157), (158), (159), (160), (161), (162), (163), (164), (165), (166), (167), (168), (169), (170), (171), (172), (173), (174), (175), (176), (177), (178), (179), (180), (181), (182), (183), (184), (185), (186), (187), (188), (189), (190), (191), (192), (193), (194), (195), (196), (197), (198), (199), (200), (201), (202), (203), (204), (205), (206), (207), (208), (209), (210), (211), (212), (213), (214), (215), (216), (217), (218), (219), (220), (221), (222), (223), (224), (225), (226), (227), (228), (229), (230), (231), (232), (233), (234), (235), (236), (237), (238), (239), (240), (241), (242), (243), (244), (245), (246), (247), (248), (249), (250), (251), (252), (253), (254), (255);
select ifnull(min(appID),1) into adplAppId from temp_IDSeq where appID not in  
(select adpl_app_id from application_verification_tb where cid = custID and did = deptID); 

end if;

select adplAppId;

drop table if exists temp_IDSeq;
END //

-- checking running applications before deleting map entry
delimiter //
DROP PROCEDURE IF EXISTS Check_Running_Applications //
delimiter //
CREATE PROCEDURE Check_Running_Applications(IN managementIP varchar(55), IN appID int)

BEGIN

drop temporary table if exists temp_app_info_list;

create temporary table temp_app_info_list
select server_ip from app_info_tb
where (app_name, proces_name, customer_id, department_id) in
(select app_name, app_path, cid, did from application_verification_tb where app_id = appID)
and isDeleted = 0;

select ssit.server_primary_ip
from server_status_information_tb ssit, temp_app_info_list tail
where ssit.server_primary_ip = tail.server_ip
and ssit.management_ip = managementIP;

drop temporary table temp_app_info_list;

END //

-- To access all management IPs which are not in management pool range

delimiter //
DROP PROCEDURE IF EXISTS ManagementIP_Not_In_Range_SP //
delimiter //
CREATE  PROCEDURE ManagementIP_Not_In_Range_SP(IN oldStart varchar(50), IN oldEnd varchar(50),IN newStart varchar(50), IN newEnd varchar(50))
BEGIN

drop table if exists temp_old_range_tb;
create TEMPORARY table temp_old_range_tb
select management_ip from server_status_information_tb
where INET6_ATON(management_ip) between INET6_ATON(oldStart) and INET6_ATON(oldEnd);

if newStart = 'null' and newEnd = 'null' then
SELECT 
    management_ip
FROM
    temp_old_range_tb
WHERE
    INET6_ATON(management_ip) NOT IN (SELECT 
            INET6_ATON(management_ip)
        FROM
            server_status_information_tb where INET6_ATON(management_ip) between INET6_ATON(null) and INET6_ATON(null));
else 
SELECT 
    management_ip
FROM
    temp_old_range_tb
WHERE
    INET6_ATON(management_ip) NOT IN (SELECT 
            INET6_ATON(management_ip)
        FROM
            server_status_information_tb where INET6_ATON(management_ip) between INET6_ATON(newStart) and INET6_ATON(newEnd));
end if;

drop table if exists temp_old_range_tb;

END //

-- To delete history data once management pool range deleted or updated

delimiter //
DROP PROCEDURE IF EXISTS Delete_History_Data_By_ManagementIP_SP //
delimiter //
CREATE  PROCEDURE Delete_History_Data_By_ManagementIP_SP(IN varManagementIP varchar(50))
BEGIN

drop table if exists temp_serverip_list_tb;
CREATE temporary table temp_serverip_list_tb SELECT server_primary_ip FROM
    server_status_information_tb
WHERE
    management_ip = varManagementIP;


drop table if exists temp_app_info_list_tb;
CREATE temporary table temp_app_info_list_tb SELECT app_name, customer_id, department_id, adpl_app_id, uuid, server_ip FROM
    app_info_tb
WHERE
    server_ip IN (SELECT 
            server_primary_ip
        FROM
            temp_serverip_list_tb);


DELETE FROM scheduled_application_security_policy_tb 
WHERE (source_cust_id, source_dept_id, source_app_name, source_app_data_ip, source_app_adpl_id) 
in (SELECT  customer_id, department_id, app_name,  server_ip, adpl_app_id FROM
    temp_app_info_list_tb);
    
DELETE FROM scheduled_application_security_policy_tb 
WHERE (dest_cust_id, dest_dept_id, dest_app_name, dest_app_data_ip, dest_app_adpl_id) 
in (SELECT  customer_id, department_id, app_name,  server_ip, adpl_app_id FROM
    temp_app_info_list_tb);
    
DELETE FROM scheduled_data_security_policy_tb
WHERE (source_cust_id, source_dept_id, source_app_name, source_app_data_ip, source_app_adpl_id) 
in (SELECT  customer_id, department_id, app_name,  server_ip, adpl_app_id FROM
    temp_app_info_list_tb);
    
DELETE FROM scheduled_data_security_policy_tb
WHERE (dest_cust_id, dest_dept_id, dest_app_name, dest_app_data_ip, dest_app_adpl_id) 
in (SELECT  customer_id, department_id, app_name,  server_ip, adpl_app_id FROM
    temp_app_info_list_tb);


        
DELETE FROM server_stats_tb 
WHERE
    uuid IN (SELECT 
        uuid
    FROM
        temp_app_info_list_tb);
       
DELETE FROM app_info_tb 
WHERE
    (app_name , customer_id, department_id, adpl_app_id) IN (SELECT 
        app_name, customer_id, department_id, adpl_app_id
    FROM
        temp_app_info_list_tb);
        
delete FROM
    server_status_information_tb
WHERE
    management_ip = varManagementIP;
 
delete from application_licence_manager_tb 
where managementIP = varManagementIP;

drop table if exists temp_app_info_list_tb;
drop table if exists temp_serverip_list_tb;

END //

-- To delete history data when server pool range is deleted
delimiter //
DROP PROCEDURE IF EXISTS Delete_ServerIP_Not_In_Range_SP //
delimiter //
CREATE  PROCEDURE Delete_ServerIP_Not_In_Range_SP(IN oldStart varchar(50), IN oldEnd varchar(50),IN newStart varchar(50), IN newEnd varchar(50))
BEGIN
drop table if exists temp_old_range_tb;
create TEMPORARY table temp_old_range_tb
select server_primary_ip from server_status_information_tb
where INET6_ATON(server_primary_ip) between INET6_ATON(oldStart) and INET6_ATON(oldEnd);

drop table if exists temp_new_range_tb;
create TEMPORARY table temp_new_range_tb
select server_primary_ip from server_status_information_tb
where INET6_ATON(server_primary_ip) between INET6_ATON(newStart) and INET6_ATON(newEnd);

delete from app_info_tb
where server_ip in (
select server_primary_ip from temp_old_range_tb
where INET6_ATON(server_primary_ip) not in (select INET6_ATON(server_primary_ip) from temp_new_range_tb));

drop table if exists temp_new_range_tb;
drop table if exists temp_old_range_tb;
END //

-- To check duplicate application entry
delimiter //
DROP PROCEDURE IF EXISTS Check_For_Duplicate_Application_SP //
delimiter //
CREATE  PROCEDURE Check_For_Duplicate_Application_SP(IN appNameVar varchar(256), IN appPathVar varchar(4096), IN md5Var varchar(512),IN sha256Var varchar(512))
BEGIN
if isnull(md5Var) OR trim(md5Var) = '' OR lower(md5Var) = lower('null') then

select * from detected_application_tb dat where dat.appName = appNameVar and dat.appPath = appPathVar and (dat.sha256 IS NULL OR trim(dat.sha256) = '' OR dat.sha256 = sha256Var);

else if isnull(sha256Var) OR trim(sha256Var) = '' or lower(sha256Var) = lower('null') then

select * from detected_application_tb dat where dat.appName = appNameVar and dat.appPath = appPathVar and (dat.mdCheckSum IS NULL OR trim(dat.mdCheckSum) = '' OR dat.mdCheckSum = md5Var);

else 

select * from detected_application_tb dat where dat.appName = appNameVar and dat.appPath = appPathVar and 
(dat.mdCheckSum IS NULL OR trim(dat.mdCheckSum) = '' OR dat.mdCheckSum = md5Var) and 
(dat.sha256 IS NULL OR trim(dat.sha256) = '' OR dat.sha256 = sha256Var);

end if;
end if;
END //

-- To soft delete app info and deletes its stats
DELIMITER //
drop procedure if exists App_Manager_Deregistration //
CREATE  PROCEDURE  App_Manager_Deregistration (IN managementIP varchar(55))
BEGIN

update server_status_information_tb set active=0,server_state=0,modify_date=now() where management_ip = managementIP;

drop temporary table if exists temp_app_info_tb;
create temporary table temp_app_info_tb
select ait.uuid from app_info_tb ait
where server_ip  IN (select ssit.server_primary_ip from server_status_information_tb ssit where management_ip = managementIP);

DELETE sst FROM server_stats_tb sst 
WHERE
    sst.uuid IN (SELECT 
        tait.uuid
    FROM
        temp_app_info_tb tait);

delete from app_info_tb  where  server_ip  IN (select server_primary_ip from server_status_information_tb where management_ip=managementIP);

END //

DELIMITER //


-- To check diff in two IPs
delimiter //
DROP procedure IF EXISTS  IP_Range_Diff //
delimiter //
CREATE  PROCEDURE  IP_Range_Diff (startipstr VARCHAR(55), endipstr VARCHAR(55))
BEGIN
declare startIP INT UNSIGNED;
declare endIP INT UNSIGNED;
declare diffVal LONG;

set startIP = inet_aton(startipstr);
set endIP = inet_aton(endipstr);

	if endIP = startIP then
		set diffVal = 0 ;
	end if;

	if endIP > startIP then
		-- set diffVal = 1 ;
        set diffVal = endIP - startIP ;
	end if;

	if endIP < startIP then
		-- set diffVal = -1 ;
        set diffVal = startIP - endIP;
        set diffVal = diffVal * -1 ;
	end if;

	select diffVal;
END //

DELIMITER //

-- To check duplicate app with name, path, md5, sha256, cid and did
DELIMITER //
DROP PROCEDURE IF EXISTS Check_For_Duplicate_Application_With_Cid_Did_SP //
DELIMITER //
CREATE  PROCEDURE  Check_For_Duplicate_Application_With_Cid_Did_SP (IN appNameVar varchar(256), IN appPathVar varchar(4096), IN md5Var varchar(512),IN sha256Var varchar(512), IN custID INT, IN deptID INT)
BEGIN
if isnull(md5Var) OR trim(md5Var) = '' OR lower(md5Var) = lower('null') then

select * from detected_application_tb dat where dat.cid = custID and dat.did = deptID and dat.appName = appNameVar and dat.appPath = appPathVar and (dat.sha256 IS NULL OR trim(dat.sha256) = '' OR dat.sha256 = sha256Var);

else if isnull(sha256Var) OR trim(sha256Var) = '' or lower(sha256Var) = lower('null') then

select * from detected_application_tb dat where dat.cid = custID and dat.did = deptID and dat.appName = appNameVar and dat.appPath = appPathVar and (dat.mdCheckSum IS NULL OR trim(dat.mdCheckSum) = '' OR dat.mdCheckSum = md5Var);

else 

select * from detected_application_tb dat where dat.cid = custID and dat.did = deptID and dat.appName = appNameVar and dat.appPath = appPathVar and 
(dat.mdCheckSum IS NULL OR trim(dat.mdCheckSum) = '' OR dat.mdCheckSum = md5Var) and 
(dat.sha256 IS NULL OR trim(dat.sha256) = '' OR dat.sha256 = sha256Var);

end if;
end if;
END //

-- To get container by AppId 


DELIMITER //
DROP procedure IF EXISTS Get_App_Info_By_AppId_SP //
DELIMITER //
CREATE PROCEDURE Get_App_Info_By_AppId_SP (IN appID INT,IN serverIp VARCHAR(80))
BEGIN
IF isnull(serverIP) OR trim(serverIP) = '' THEN
	select ait.app_name,ait.proces_name,ait.server_port,ait.customer_id,ait.department_id,ait.protocol,ait.server_ip from app_info_tb ait
	where (customer_id,department_id,adpl_app_id) in (select cid,did,adpl_app_id from application_verification_tb where app_id = appID)
	and isDeleted = 0;
ELSE
	select ait.app_name,ait.proces_name,ait.server_port,ait.customer_id,ait.department_id,ait.protocol,ait.server_ip from app_info_tb ait
	where (customer_id,department_id,adpl_app_id) in (select cid,did,adpl_app_id from application_verification_tb where app_id = appID)
	and isDeleted = 0 and server_ip in (select server_primary_ip from server_status_information_tb where management_ip = serverIp);
END IF;
END //

-- To get active connection details when user come from visualization to dashboard
DELIMITER //
DROP procedure IF EXISTS Dashboard_Active_Connections_Master_With_Pid_SP //
DELIMITER //
CREATE   PROCEDURE  Dashboard_Active_Connections_Master_With_Pid_SP (IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80), IN PID INT )
BEGIN
IF CustID = 0 OR DeptID = 0 OR GroupID = 0 OR isnull(ServerIP) OR trim(ServerIP) = '' OR PID = 0 THEN

	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.server_ip, 
	vscs.server_port, vscs.protocol, 0 AS sess_allowed, 0 AS sess_rejected, 0 AS client_count
	FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
	WHERE 1 = 2;
ELSE
	SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.socket_uuid, vscs.server_ip, 
	vscs.server_port, vscs.protocol, sum(vscs.sess_allowed) AS sess_allowed, sum(vscs.sess_rejected) AS sess_rejected, sum(vscs.client_count) AS client_count, max(create_timestamp) as create_timestamp
	FROM V_SERVER_STATS vscs, V_SERVER_GROUP_INFO vgi
	WHERE vscs.cust_id  =  vgi.cust_id AND	vscs.dep_id = vgi.dept_id
	AND vscs.protocol = vgi.trans_proto AND vscs.server_port = vgi.serv_port
	AND vscs.server_ip = vgi.server_primary_ip

	AND vscs.cust_id = CustID
	AND vscs.dep_id = DeptID
	AND vgi.grp_id = GroupID
	AND trim(vscs.server_ip) = trim(ServerIP)
    AND vscs.pid = PID

	GROUP BY vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name, vscs.uuid, vscs.socket_uuid, vscs.server_ip, vscs.server_port, vscs.protocol
	ORDER BY vgi.customer_name, vgi.dept_name,vgi.app_name, vscs.server_port, vscs.protocol, sess_rejected ;
END IF;
END //

-- ---------------------------------------------------------------------
/* 
To filter the visualization data
call Visualization_Filter_SP (0,0,0,0,'');
call Visualization_Filter_SP (1,0,0,0,'');
call Visualization_Filter_SP (2,0,0,0,'');
*/
--

DELIMITER //
DROP PROCEDURE IF EXISTS Visualization_Filter_SP //
DELIMITER //
CREATE PROCEDURE Visualization_Filter_SP(IN Optn INT, IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80), IN isContainer INT, IN aliasAppNameVar VARCHAR(256) )
BEGIN
DROP TABLE IF EXISTS temp_session_details;
CREATE TEMPORARY TABLE temp_session_details
SELECT vscd.server_ip, vscd.server_port, vscd.pid FROM V_SERVER_CLIENT_DESCRIPTORS vscd WHERE 1=2;
	IF CustID = 0 THEN
		INSERT INTO temp_session_details (server_ip,server_port,pid)
		SELECT vscd.server_ip, vscd.server_port, vscd.pid 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
			WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
			AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
			AND vscd.server_ip = vgi.server_primary_ip
			AND vscd.sess_rejected <> 0;
	ELSEIF DeptID = 0 THEN
		INSERT INTO temp_session_details (server_ip,server_port,pid)
		SELECT vscd.server_ip, vscd.server_port, vscd.pid 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
			WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
			AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
			AND vscd.server_ip = vgi.server_primary_ip
			AND vscd.sess_rejected <> 0
			AND vscd.cust_id = CustID;		
	ELSEIF GroupID = 0 THEN
		INSERT INTO temp_session_details (server_ip,server_port,pid)
		SELECT vscd.server_ip, vscd.server_port, vscd.pid 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
		WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
		AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
		AND vscd.server_ip = vgi.server_primary_ip
		AND vscd.sess_rejected <> 0
		AND vscd.cust_id = CustID
		AND vscd.dep_id = DeptID;
	ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		INSERT INTO temp_session_details (server_ip,server_port,pid)
		SELECT vscd.server_ip, vscd.server_port, vscd.pid 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
		WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
		AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
		AND vscd.server_ip = vgi.server_primary_ip
		AND vscd.sess_rejected <> 0
		AND vscd.cust_id = CustID
		AND vscd.dep_id = DeptID
		AND vgi.grp_id = GroupID;	
	ELSE
		IF isContainer <> 2 then
			INSERT INTO temp_session_details (server_ip,server_port,pid)
			SELECT vscd.server_ip, vscd.server_port, vscd.pid 
			FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
			WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
			AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
			AND vscd.server_ip = vgi.server_primary_ip
			AND vscd.sess_rejected <> 0
			AND vscd.cust_id = CustID
			AND vscd.dep_id = DeptID
			AND vgi.grp_id = GroupID
			AND trim(ServerIP) = trim(vscd.server_ip);
		ELSE 
			INSERT INTO temp_session_details (server_ip,server_port,pid)
			SELECT vscd.server_ip, vscd.server_port, vscd.pid 
			FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi
			WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
			AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
			AND vscd.server_ip = vgi.server_primary_ip
			AND vscd.sess_rejected <> 0
			AND trim(ServerIP) = trim(vscd.server_ip);
		END IF;
	END IF;	

IF isnull(aliasAppNameVar) OR trim(aliasAppNameVar)='' then
IF Optn = 0 then
	IF isContainer <> 2 then
		IF CustID = 0 then
				SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0;
		ELSEIF DeptID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID;
		ELSEIF GroupID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND dept_id=DeptID;
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
				SELECT * FROM V_APPLICATION_INFO
				WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID;
		ELSE
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP);
		END IF;
	ELSE
		IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0;
		ELSE
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND trim(server_primary_ip) = trim(ServerIP) AND container = '2';
		END IF;
	END IF;
ELSEIF Optn = 1 then 
	IF isContainer <> 2 then 
		IF CustID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0;

		ELSEIF DeptID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID;

		ELSEIF GroupID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID;

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID;
		ELSE
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP);
		END IF;
ELSE
	IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0;
	ELSE
		SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND trim(server_primary_ip) = trim(ServerIP) AND container = '2';
	END IF;
END IF;
ELSEIF Optn = 2 then
	IF isContainer <> 2 then 
		IF CustID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0;

		ELSEIF DeptID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID;

		ELSEIF GroupID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID;

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID;
		ELSE
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP);
		END IF;
 ELSE
	IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0;
	ELSE
		SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0  AND trim(server_primary_ip) = trim(ServerIP) AND container = '2';
	END IF;
 END IF;
ELSEIF Optn = 5 then
	IF CustID = 0 then
		SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0;

	ELSEIF DeptID = 0 then
		SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID;

	ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID;
	
	ELSEIF GroupID=0 THEN
		SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND trim(server_primary_ip) = trim(ServerIP) ;

	ELSE
		SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND trim(server_primary_ip) = trim(ServerIP) AND grp_id=GroupID ;
	
END IF;
ELSE
  IF isContainer <> 2 then 
		IF CustID = 0 then
				SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND compliance <> "Default";
		ELSEIF DeptID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND compliance <> "Default";
		ELSEIF GroupID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND dept_id=DeptID AND compliance <> "Default";
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
				SELECT * FROM V_APPLICATION_INFO
				WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND compliance <> "Default";
		ELSE
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP) AND compliance <> "Default";
		END IF;
	ELSE
		IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND compliance <> "Default";
		ELSE
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND trim(server_primary_ip) = trim(ServerIP) AND container = '2' AND compliance <> "Default";
		END IF;
END IF;
END IF;
ELSE 
IF Optn = 0 then
	IF isContainer <> 2 then
		IF CustID = 0 then
				SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSEIF DeptID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSEIF GroupID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND dept_id=DeptID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
				SELECT * FROM V_APPLICATION_INFO
				WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP) AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		END IF;
	ELSE
		IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND trim(server_primary_ip) = trim(ServerIP) AND container = '2' AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		END IF;
	END IF;
ELSEIF Optn = 1 then 
	IF isContainer <> 2 then 
		IF CustID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

		ELSEIF DeptID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

		ELSEIF GroupID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP) AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		END IF;
	ELSE
		IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
			WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
			SELECT * FROM V_APPLICATION_INFO
			WHERE (server_primary_ip, serv_port, pid) IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND trim(server_primary_ip) = trim(ServerIP) AND container = '2' AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
	END IF;
END IF;
ELSEIF Optn = 2 then
	IF isContainer <> 2 then 
		IF CustID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

		ELSEIF DeptID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

		ELSEIF GroupID = 0 then
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
			SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP) AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		END IF;
 ELSE
	IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
	ELSE
		SELECT * FROM V_APPLICATION_INFO
		WHERE (server_primary_ip, serv_port, pid) NOT IN (SELECT server_ip,server_port,pid FROM temp_session_details) AND server_state=1 AND isDeleted=0  AND trim(server_primary_ip) = trim(ServerIP) AND container = '2' AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
	END IF;
 END IF;
ELSEIF Optn = 5 then
	IF CustID = 0 then
			SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
	ELSEIF DeptID = 0 then
		SELECT * FROM V_APPLICATION_INFO
	WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

	ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		SELECT * FROM V_APPLICATION_INFO
	WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
	
	ELSEIF GroupID=0 THEN
		SELECT * FROM V_APPLICATION_INFO
	WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND trim(server_primary_ip) = trim(ServerIP) AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');

	ELSE
		SELECT * FROM V_APPLICATION_INFO
	WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND trim(server_primary_ip) = trim(ServerIP) AND grp_id=GroupID AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
END IF;
ELSE
  IF isContainer <> 2 then 
		IF CustID = 0 then
				SELECT * FROM V_APPLICATION_INFO WHERE server_state=1 AND isDeleted=0 AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSEIF DeptID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSEIF GroupID = 0 then
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0  AND cust_id=CustID AND dept_id=DeptID AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
				SELECT * FROM V_APPLICATION_INFO
				WHERE server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
				SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND cust_id=CustID AND dept_id=DeptID AND grp_id=GroupID AND trim(server_primary_ip) = trim(ServerIP) AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		END IF;
	ELSE
		IF isnull(ServerIP) OR trim(ServerIP) = '' THEN
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		ELSE
			SELECT * FROM V_APPLICATION_INFO
				WHERE  server_state=1 AND isDeleted=0 AND trim(server_primary_ip) = trim(ServerIP) AND container = '2' AND compliance <> "Default" AND aliasAppName LIKE CONCAT('%',aliasAppNameVar,'%');
		END IF;
END IF;
END IF;
END IF;
DROP TABLE IF EXISTS temp_session_details;
END //

-- --------------------------------------------------------------------------------------------


DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_Top10_Offender_Defender_Report_SP //
DELIMITER //
CREATE PROCEDURE Dashboard_Top10_Offender_Defender_Report_SP(IN CountOnly INT, IN CustID INT, IN DeptID INT, IN GroupID INT, IN ServerIP VARCHAR(80), IN startDate timestamp, IN endDate timestamp)
BEGIN

	DROP TABLE IF EXISTS temp_top10_sessions ;
CREATE TEMPORARY TABLE temp_top10_sessions 
SELECT vscd.uuid, vscd.socket_uuid ,vscd.sess_rejected FROM V_SERVER_DESCRIPTORS vscd WHERE 1 = 2;

DROP TABLE IF EXISTS temp_top10_peers ;
CREATE TEMPORARY TABLE temp_top10_peers 
SELECT vscd.uuid, vscd.socket_uuid, vscd.pl_allowed AS pl_rejected FROM V_SERVER_CLIENT_DESCRIPTORS vscd WHERE 1 = 2;
 
IF CustID = 0 THEN

	if DeptID = 0 THEN

		-- consider nothing (maybe IP)

		INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) 
		FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi 
		WHERE (ServerIP IS NULL OR vscd.server_ip LIKE concat(trim(ServerIP),'%'))
		AND vscd.cust_id  =  vgi.cust_id 
		AND vscd.dep_id = vgi.dept_id 
		AND vscd.protocol = vgi.trans_proto 
		AND vscd.server_port = vgi.serv_port 
		AND vscd.server_ip = vgi.server_primary_ip 
		GROUP BY uuid, socket_uuid);

				
		INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
		WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
                vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
                vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
                vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.close_reason,vscd.close_timestamp,vscd.pl_rej_secsig
                FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
                WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
                AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
                AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
                AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
                AND tts.sess_rejected <> 0
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(trim(ServerIP),'%'))
		AND vscd.modify_on >= startDate
              	AND vscd.modify_on <= endDate
		ORDER BY tts.sess_rejected DESC ;
		
	else -- deptid 0 if cha else
		
		-- consider did and maybe IP

		INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) 
		FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi 
		WHERE vscd.dep_id = DeptID 
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(trim(ServerIP),'%'))
		AND vscd.cust_id  =  vgi.cust_id 
		AND vscd.dep_id = vgi.dept_id 
		AND vscd.protocol = vgi.trans_proto 
		AND vscd.server_port = vgi.serv_port 
		AND vscd.server_ip = vgi.server_primary_ip 
		GROUP BY uuid, socket_uuid);

				
		INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
		WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
                vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
                vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
                vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.close_reason,vscd.close_timestamp,vscd.pl_rej_secsig
                FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
                WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
                AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
                AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
                AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
                AND tts.sess_rejected <> 0
		AND vscd.dep_id = DeptID 
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(trim(ServerIP),'%'))
		AND vscd.modify_on >= startDate
              	AND vscd.modify_on <= endDate
		ORDER BY tts.sess_rejected DESC ;

	end if; -- deptid 0 if close

else -- cid 0 if cha else
	
	if DeptID = 0 THEN
		-- consider cid (maybe IP)

		INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) 
		FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi 
		WHERE vscd.cust_id = CustID 
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(trim(ServerIP),'%'))
		AND vscd.cust_id  =  vgi.cust_id 
		AND vscd.dep_id = vgi.dept_id 
		AND vscd.protocol = vgi.trans_proto 
		AND vscd.server_port = vgi.serv_port 
		AND vscd.server_ip = vgi.server_primary_ip 
		GROUP BY uuid, socket_uuid);

				
		INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
		WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
                vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
                vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
                vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.close_reason,vscd.close_timestamp,vscd.pl_rej_secsig
                FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
                WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
                AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
                AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
                AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
                AND tts.sess_rejected <> 0
		AND vscd.cust_id = CustID
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(ServerIP,'%') )
		AND vscd.modify_on >= startDate
              	AND vscd.modify_on <= endDate
		ORDER BY tts.sess_rejected DESC ;

	else -- DeptId 0 if cha else
		
		-- consider cid and did (maybe IP)

		INSERT INTO temp_top10_sessions (SELECT vscd.uuid, vscd.socket_uuid, sum(vscd.sess_rejected) 
		FROM V_SERVER_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi 
		WHERE vscd.cust_id = CustID 
		AND vscd.dep_id = DeptID 
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(trim(ServerIP),'%'))
		AND vscd.cust_id  =  vgi.cust_id 
		AND vscd.dep_id = vgi.dept_id 
		AND vscd.protocol = vgi.trans_proto 
		AND vscd.server_port = vgi.serv_port 
		AND vscd.server_ip = vgi.server_primary_ip 
		GROUP BY uuid, socket_uuid);

				
		INSERT INTO temp_top10_peers (SELECT vscd.uuid, vscd.socket_uuid, sum((vscd.pl_rej_policies+vscd.pl_rej_custid+vscd.pl_rej_depid+vscd.pl_rej_secsig)) 
		FROM V_SERVER_CLIENT_DESCRIPTORS vscd 
		WHERE (uuid, socket_uuid) IN (SELECT uuid, socket_uuid FROM temp_top10_sessions) GROUP BY uuid, vscd.socket_uuid) ;

		SELECT vgi.cust_id, vgi.customer_name, vgi.dept_id, vgi.dept_name, vgi.grp_id, vgi.app_name,
                vscd.server_ip, vscd.server_port, tts.sess_rejected AS sess_rejection_total , 
                vscd.pid, vscd.client_ip, vscd.client_port, /*ttp.pl_rejected AS pl_rejection_total , */
                vscd.pl_rej_policies,vscd.pl_rej_custid,vscd.pl_rej_depid,vscd.close_reason,vscd.close_timestamp,vscd.pl_rej_secsig
                FROM V_SERVER_CLIENT_DESCRIPTORS vscd, V_SERVER_GROUP_INFO vgi, temp_top10_sessions tts, temp_top10_peers ttp
                WHERE vscd.cust_id  =  vgi.cust_id AND	vscd.dep_id = vgi.dept_id
                AND vscd.protocol = vgi.trans_proto AND vscd.server_port = vgi.serv_port
                AND vscd.server_ip = vgi.server_primary_ip AND tts.uuid = ttp.uuid AND tts.uuid = vscd.uuid
                AND tts.socket_uuid = ttp.socket_uuid AND tts.socket_uuid = vscd.socket_uuid 
                AND tts.sess_rejected <> 0
		AND vscd.cust_id = CustID
		AND vscd.dep_id = DeptID 
		AND (ServerIP IS NULL OR vscd.server_ip LIKE concat(ServerIP,'%'))
		AND vscd.modify_on >= startDate
              	AND vscd.modify_on <= endDate
		ORDER BY tts.sess_rejected DESC ;

	end if; -- deptid 0 if close

end if; -- cid 0 if close

DROP TABLE IF EXISTS temp_top10_sessions ;
DROP TABLE IF EXISTS temp_top10_peers ;

	
END //


-- ------------------------------------------------------------------------------------------------------

DELIMITER //
DROP PROCEDURE IF EXISTS App_Info_By_ServerIP_Report_SP //
DELIMITER //
CREATE PROCEDURE App_Info_By_ServerIP_Report_SP(IN CustID INT, IN DeptID INT, IN ServerIP VARCHAR(80), IN MgmtIP VARCHAR(80), IN startDate timestamp, IN endDate timestamp)
BEGIN

DROP TABLE IF EXISTS temp_app_info_tb;

IF CustID = 0 THEN 
	IF DeptID = 0 THEN 
		CREATE TEMPORARY TABLE  temp_app_info_tb
		SELECT app_name,app_id,app_path,cust_id,dept_id,serv_port,trans_proto,server_primary_ip,management_ip,isDeleted,md_checksum,sha2 , 0 AS app_instance_count
		FROM V_APPLICATION_INFO AS vscd
		where 
		(ServerIP IS NULL OR server_primary_ip LIKE concat(trim(ServerIP),'%')) AND
		(MgmtIP IS NULL OR management_ip LIKE concat(trim(MgmtIP),'%')) AND
		create_date >= startDate AND 
		create_date <= endDate;
	ELSE
		CREATE TEMPORARY TABLE  temp_app_info_tb
		SELECT app_name,app_id,app_path,cust_id,dept_id,serv_port,trans_proto,server_primary_ip,management_ip,isDeleted,md_checksum,sha2 , 0 AS app_instance_count
		FROM V_APPLICATION_INFO AS vscd
		where
		(ServerIP IS NULL OR server_primary_ip LIKE concat(trim(ServerIP),'%')) AND
		(MgmtIP IS NULL OR management_ip LIKE concat(trim(MgmtIP),'%')) AND		
		vscd.dept_id = DeptID AND
		create_date >= startDate AND 
		create_date <= endDate;
END IF;
ELSEIF DeptID = 0 THEN
	CREATE TEMPORARY TABLE  temp_app_info_tb
	SELECT app_name,app_id,app_path,cust_id,dept_id,serv_port,trans_proto,server_primary_ip,management_ip,isDeleted,md_checksum,sha2 , 0 AS app_instance_count
	FROM V_APPLICATION_INFO AS vscd
	where 
	(ServerIP IS NULL OR server_primary_ip LIKE concat(trim(ServerIP),'%') ) AND
	(MgmtIP IS NULL OR management_ip LIKE concat(trim(MgmtIP),'%') ) AND
	vscd.cust_id = CustID AND
	create_date >= startDate AND 
	create_date <= endDate;
ELSE
	CREATE TEMPORARY TABLE  temp_app_info_tb
	SELECT app_name,app_id,app_path,cust_id,dept_id,serv_port,trans_proto,server_primary_ip,management_ip,isDeleted,md_checksum,sha2 , 0 AS app_instance_count
	FROM V_APPLICATION_INFO AS vscd
	where
	(ServerIP IS NULL OR server_primary_ip LIKE concat(trim(ServerIP),'%')) AND
	(MgmtIP IS NULL OR management_ip LIKE concat(trim(MgmtIP),'%')) AND
	vscd.cust_id = CustID AND
	vscd.dept_id = DeptID AND
	create_date >= startDate AND 
	create_date <= endDate;
END IF;

SELECT * FROM temp_app_info_tb 
order by app_id,cust_id,dept_id,serv_port,trans_proto,server_primary_ip;

DROP TABLE IF EXISTS temp_app_info_tb;
DROP TABLE IF EXISTS temp_count;

END //


-- ----------------------------------------------------------------------------------------------------

DELIMITER //
drop function if exists  SLA_CHECK //
DELIMITER //
CREATE  FUNCTION SLA_CHECK(appNameVar varchar(256), appPathVar varchar(4096), md5Var varchar(512), sha256Var varchar(512), custID INT, deptID INT, complianceVar varchar(256)) RETURNS int(11)
BEGIN
if exists (select malware_sha256 from malware_sha256_tb where malware_sha256 = sha256Var) then
	return 6 ; -- sha match with malware;
end if;

if exists (select malware_checksum from malware_checksum_tb where malware_checksum = md5Var) then
	return 7; -- md5 match with malware
end if;

	if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar) then
		return 0; -- No record in db
    end if;
    
   if (md5Var is not null and trim(md5Var) <> '' and  lower(md5Var) <> lower('null')) and (sha256Var is not null and trim(sha256Var) <> '' and  lower(sha256Var) <> lower('null')) then
		
        if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (md_checksum IS NULL OR trim(md_checksum) = '' OR md_checksum = md5Var) and (sha2 IS NULL OR trim(sha2) = '' OR sha2 = sha256Var)) then
			return 1; -- sha mismatch
		end if;
        
        if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (md_checksum IS NULL OR trim(md_checksum) = '' OR md_checksum = md5Var) and (sha2 IS NULL OR trim(sha2) = '' OR sha2 = sha256Var) and cid = custID and did = deptID and compliance = complianceVar) then
			return 3; -- cid did compliance mismatch
		end if;
        
        if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (md_checksum IS NULL OR trim(md_checksum) = '' OR md_checksum = md5Var) and (sha2 IS NULL OR trim(sha2) = '' OR sha2 = sha256Var) and cid = custID and did = deptID and lower(action) = 'enable') then
			return 4; -- valid but not protected
		else	
			return 5; -- valid and protected
        end if;
        
   end if;
   
   if isnull(md5Var) OR trim(md5Var) = '' OR lower(md5Var) = lower('null') then
		
        if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (sha2 IS NULL OR trim(sha2) = '' OR sha2 = sha256Var)) then
			return 1; -- sha mismatch
        end if;
        
		if not exists(select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (sha2 IS NULL OR trim(sha2) = '' OR sha2 = sha256Var) and cid = custID and did = deptID and compliance = complianceVar) then
			return 3; -- cid did compliance mismatch
		end if;
        
		if not exists(select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (sha2 IS NULL OR trim(sha2) = '' OR sha2 = sha256Var) and cid = custID and did = deptID and lower(action) = 'enable') then
			return 4; -- valid but not protected
		else	
			return 5; -- valid and protected
        end if;
        
   end if;
   
   if isnull(sha256Var) OR trim(sha256Var) = '' OR lower(sha256Var) = lower('null') then
		
        if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (md_checksum IS NULL OR trim(md_checksum) = '' OR md_checksum = md5Var)) then
			return 2; -- md5 mismatch
        end if;
        
		if not exists (select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (md_checksum IS NULL OR trim(md_checksum) = '' OR md_checksum = md5Var) and cid = custID and did = deptID and compliance = complianceVar) then
			return 3; -- cid did compliance mismatch
        end if;
        
        if not exists(select * from application_verification_tb where app_name = appNameVar and app_path = appPathVar and (md_checksum IS NULL OR trim(md_checksum) = '' OR md_checksum = md5Var) and cid = custID and did = deptID and lower(action) = 'enable') then
			return 4; -- valid but not protected
		else	
			return 5; -- valid and protected
        end if;
        
   end if;
RETURN 0;
END //

-- -------------------------------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS Dashboard_UnAuthorized_Apps_Details_SP //
DELIMITER //

CREATE PROCEDURE Dashboard_UnAuthorized_Apps_Details_SP(IN app_name VARCHAR(256))
BEGIN
	SELECT sla.md_checksum,sla.app_path,sla.pid,sla.server_ip,sla.sha2,sla.comment,sla.created_on FROM sla_failed_tb sla 
	WHERE trim(lower(sla.app_name))  = trim(lower(app_name));

END //

-- ---------------------------------------------------------------------------------------------------alter
DELIMITER //
DROP PROCEDURE IF EXISTS Permanant_App_Info_Store_SP //
DELIMITER //
CREATE PROCEDURE Permanant_App_Info_Store_SP (in custIdVar int, in deptIdVar int, in adplAppIdVar int, in portNoVar int, in protocolVar int,in serverIpVar varchar(80), in pidVar int, in appNameVar varchar(256), in appPathVar varchar(4096), in isDeletedVar int, in uuidVar varchar(36), in socket_uuidVar varchar(45), in isChildVar int)
BEGIN
declare updateid int;
set updateid = 0;
start transaction ;
	if exists (select app_id from application_verification_tb where cid = custIdVar and did = deptIdVar and adpl_app_id = adplAppIdVar) then
		select id into updateid from app_info_tb where server_port= portNoVar AND protocol= protocolVar AND customer_id= custIdVar AND department_id= deptIdVar and server_ip= serverIpVar and adpl_app_id = adplAppIdVar and pid = pidVar and uuid = uuidVar and socket_uuid = socket_uuidVar;
			if (updateid <= 0) then 
				insert into app_info_tb(app_name,proces_name,pid,server_port,customer_id,department_id,protocol,created_on,modify_on,server_ip,isDeleted,uuid,adpl_app_id,socket_uuid,is_child) values(appNameVar,appPathVar,pidVar,portNoVar,custIdVar,deptIdVar,protocolVar,now(),now(),serverIpVar,isDeletedVar,uuidVar,adplAppIdVar,socket_uuidVar,isChildVar);
			else
				update app_info_tb set isDeleted = isDeletedVar, modify_on = now() where id = updateid;
			end if;
		if not exists(select app_name from permanent_app_info_tb where server_port= portNoVar AND protocol= protocolVar AND customer_id= custIdVar AND department_id= deptIdVar and adpl_app_id = adplAppIdVar and server_ip = serverIpVar) then
			insert into permanent_app_info_tb(app_name,proces_name,customer_id,department_id,server_ip,server_port,protocol,adpl_app_id,created_on,modify_on) values(appNameVar,appPathVar,custIdVar,deptIdVar,serverIpVar,portNoVar,protocolVar,adplAppIdVar,now(),now());
		else
			update permanent_app_info_tb set modify_on = now() where server_port= portNoVar AND protocol= protocolVar AND customer_id= custIdVar AND department_id= deptIdVar and adpl_app_id = adplAppIdVar and server_ip = serverIpVar;
		end if;
    end if;
    commit;
END //

-- ------------------------------------------------------------------------------------------------------
-- Application group creation SP
-- ------------------------------------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS Create_Application_Group_SP //
DELIMITER //
CREATE PROCEDURE Create_Application_Group_SP(in appName varchar(256),in appId int, in cid int, in did int, in adplAppId int)
BEGIN
	insert into application_group_tb (appl_group_id,appl_group_name) values (null,appName);
    insert into application_group_transaction_tb (appl_group_id,cust_id,dept_id,app_id,adpl_app_id) values (LAST_INSERT_ID(),cid,did,appId,adplAppId);
END //

-- ------------------------------------------------------------------------------------------------------------------
-- Check_For_New_App_Info_SP
-- ------------------------------------------------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS Check_For_New_App_Info_SP //
DELIMITER //
CREATE PROCEDURE Check_For_New_App_Info_SP()
BEGIN
SELECT * FROM app_info_tb ait WHERE ((ait.created_on)IS NOT NULL 
	AND (ait.modify_on)IS NOT NULL 
	AND ait.created_on = ait.modify_on);
END //

-- ------------------------------------------------------------------------------------------------------------------
-- Application_Group_Filter_SP
-- ------------------------------------------------------------------------------------------------------------------

DELIMITER //
DROP PROCEDURE IF EXISTS Application_Group_Filter_SP //
DELIMITER //
CREATE PROCEDURE Application_Group_Filter_SP(IN CustID INT, IN DeptID INT, IN ServerIP VARCHAR(256))
BEGIN
	IF CustID = 0 THEN
		SELECT * FROM V_SERVER_GROUP_INFO;
	ELSEIF DeptID = 0 THEN 
		SELECT * FROM V_SERVER_GROUP_INFO WHERE cust_id=CustID;
	ELSEIF isnull(ServerIP) OR trim(ServerIP) = '' THEN
		SELECT * FROM V_SERVER_GROUP_INFO WHERE cust_id=CustID AND dept_id=DeptID;
	ELSE 
		SELECT * FROM V_SERVER_GROUP_INFO WHERE cust_id=CustID AND dept_id=DeptID AND server_primary_ip=ServerIP;
	END IF;
END //

-- -------------------------------------------------------------------------------------------------------------
-- New Stored Procedures for New UI
-- -------------------------------------------------------------------------------------------------------------
DELIMITER //
drop procedure if exists Dashboard_Application_Summary_SP //
DELIMITER //
create procedure Dashboard_Application_Summary_SP(out reg_app_count int, out running_app_count int, out healthy_app_count int, out customer_count int)
begin
	select count(app_id) from application_verification_tb into reg_app_count;
	
    select count(distinct uuid, socket_uuid) from app_info_tb
    where isDeleted <> 1
	into running_app_count;
    
    select count(distinct sst.uuid, sst.socket_uuid) 
    from server_stats_tb sst
    join app_info_tb ait
    on sst.uuid = ait.uuid
    and sst.socket_uuid = ait.socket_uuid
    and ait.isDeleted <> 1
    and (sst.sess_rejected + sst.pl_rejected) = 0
    into healthy_app_count;
  
    select count(cust_id) into customer_count from customer_tb;
end //


DELIMITER //
drop procedure if exists Dashboard_Threat_Summary_SP //
DELIMITER //
create procedure Dashboard_Threat_Summary_SP (out threats_detected_count int, out processes_attacked_count int, out unauth_apps_count int)
begin    
	select 
		ifnull(sum(sst.sess_rejected) + sum(sst.pl_rejected), 0) as threats_detected_count,
        ifnull(count(distinct sst.socket_uuid), 0) as processes_attacked_count
        from app_info_tb ait 
        join server_stats_tb sst
        on ait.uuid = sst.uuid
        and ait.socket_uuid = sst.socket_uuid
        and ait.isDeleted <> 1
        and (sst.sess_rejected + sst.pl_rejected) > 0
        into threats_detected_count, processes_attacked_count;
        
	select count(*) from detected_application_tb where isRegister <> 1 into unauth_apps_count;
end //


DELIMITER //
drop procedure if exists Dashboard_Threat_Type_Summary_SP //
DELIMITER //
create procedure Dashboard_Threat_Type_Summary_SP (in lower_date date, in upper_date date, out sess_rejected_osfails_count int, out sess_rejected_policies_count int, out sess_rejected_cid_count int, out sess_rejected_did_count int, out pl_rej_sqlinj_count int)
begin
	select 
		ifnull(count(case when close_reason = 1 then 1 end), 0), 
        ifnull(count(case when close_reason = 2 then 1 end), 0),
        ifnull(count(case when close_reason = 3 then 1 end), 0),
        ifnull(count(case when close_reason = 4 then 1 end), 0), 
        ifnull(sum(pl_rej_sqlinj), 0)
	from client_descriptor_tb
    where date(close_timestamp) >= lower_date
    and date(close_timestamp) <= upper_date
	into 
		sess_rejected_osfails_count,
		sess_rejected_policies_count,
		sess_rejected_cid_count,
		sess_rejected_did_count,
		pl_rej_sqlinj_count;
end //

DELIMITER //
drop procedure if exists Dashboard_Domain_Subdomain_Details_SP //
DELIMITER //
create procedure Dashboard_Domain_Subdomain_Details_SP()
begin
	drop table if exists customer_temp_tb;
    create temporary table customer_temp_tb (
		cust_id int not null,
        cust_name varchar(256) not null,
        dept_count int default 0);
    
    insert into customer_temp_tb
    select ct.cust_id, ct.customer_name, count(dt.dept_id) 
    from customer_tb ct left join department_tb dt
		on ct.cust_id = dt.cust_id
	group by ct.cust_id, ct.customer_name;

	select 
		ct.cust_id,
        ct.cust_name,
        ct.dept_count,
        dt.dept_id,
        dt.dept_name,
		count(distinct avt.app_id) as reg_app,
        ifnull(count(distinct ait.uuid, ait.socket_uuid), 0) as active_processes,
		ifnull(sst.sess_rejected + sst.pl_rejected, 0) as threats_detected

	from customer_temp_tb ct left join department_tb dt 
		on ct.cust_id = dt.cust_id
    left join application_verification_tb avt
		on dt.cust_id = avt.cid and dt.dept_id = avt.did
	left join app_info_tb ait
		on dt.cust_id = ait.customer_id
        and  dt.dept_id = ait.department_id
        and ait.isDeleted <> 1
	left join server_stats_tb sst
		on ait.uuid = sst._uuid
        and ait.socket_uuid = sst.socket_uuid
	group by ct.cust_id, ct.cust_name, ct.dept_count, dt.dept_id, dt.dept_name
	order by ct.cust_id, dt.dept_id;

	drop table if exists customer_temp_tb;
end //

DELIMITER //
drop procedure if exists Dashboard_Threat_Count_By_Date_SP //
DELIMITER //
create procedure Dashboard_Threat_Count_By_Date_SP (in lower_date date, in upper_date date)
begin
	declare d date;
    drop table if exists date_range_tb;
    create temporary table date_range_tb (d date not null);
    set d = lower_date;
    while (d <= upper_date) do
		insert into date_range_tb (d) values (d);
        set d = date_add(d, interval 1 day);
	end while;
    
	select 
		drt.d as dates,
		ifnull(count(case when close_reason <> 5 and close_reason <> 0 then 1 end) + sum(pl_rej_sqlinj), 0) as threat_counts,
        ifnull(count(distinct vscs.socket_uuid), 0) as apps_attacked 
	from date_range_tb drt left join V_SERVER_CLIENT_DESCRIPTORS vscs 
		on drt.d = date(vscs.close_timestamp)
        and (vscs.close_reason <> 5 or pl_rej_sqlinj <> 0)
        and (vscs.close_reason <> 0 or pl_rej_sqlinj <> 0)
	group by drt.d
	order by drt.d desc;
 	drop table if exists date_range_tb;
end //


DELIMITER //
drop procedure if exists Dashboard_Application_Donought_Dependency_Map_SP //
DELIMITER //
create procedure Dashboard_Application_Donought_Dependency_Map_SP(in cust_id_in int)
begin
set @row_number = 0;
set @group_number = 0;
set @uuid = '';
drop table if exists nodes_temp_tb;
create temporary table nodes_temp_tb(
	node_id int primary key,
    group_id int,
    app_name varchar(256),
    process_name varchar(4096),
    alias_app_name varchar(256),
    app_image_id int,
    cust_id int,
    cust_name varchar(256),
    dept_id int,
    dept_name varchar(256),
    adpl_app_id int,
    ip varchar(45),
    port int,
    protocol int,
    pid int,
    uuid varchar(36),
    socket_uuid varchar(36),
    threats_detected int);

insert into nodes_temp_tb
select
	@row_number:=@row_number + 1,
    0,
    avt.app_name,
    avt.app_path,
    avt.aliasAppName,
    avt.appImageId,
    ct.cust_id,
	ct.customer_name,
    dt.dept_id,
	dt.dept_name,
    avt.adpl_app_id,
    ait.server_ip,
    ifnull(ait.server_port, 0),
    ifnull(ait.protocol, 0),
    ifnull(ait.pid, 0),
    ifnull(@uuid:= ait.uuid, ''),
    ifnull(ait.socket_uuid, ''),
    ifnull(sst.sess_rejected + sst.pl_rejected, 0)
from application_verification_tb avt join (
customer_tb ct join department_tb dt
on ct.cust_id = dt.cust_id)
on avt.cid = dt.cust_id
and avt.did = dt.dept_id
left join app_info_tb ait
on avt.cid = ait.customer_id
and avt.did = ait.department_id
and avt.adpl_app_id = ait.adpl_app_id
and ait.isDeleted <> 1
left join server_stats_tb sst
on ait.uuid = sst.uuid
and ait.socket_uuid = sst.socket_uuid
order by avt.cid, avt.did, avt.adpl_app_id, ait.uuid, ait.socket_uuid;
    
drop table if exists nodes_group_temp_tb;
create temporary table nodes_group_temp_tb(
    group_id int auto_increment,
    cust_id int,
    dept_id int,
    adpl_app_id int,
    uuid varchar(36),
    primary key (group_id)
);

insert into nodes_group_temp_tb
(cust_id, dept_id, adpl_app_id, uuid)
select cust_id, dept_id, adpl_app_id, uuid from nodes_temp_tb
group by cust_id, dept_id, adpl_app_id, uuid;

update nodes_temp_tb ntt left join nodes_group_temp_tb ngtt
using (cust_id, dept_id, adpl_app_id, uuid)
set ntt.group_id = ngtt.group_id;

drop table if exists nodes_req_temp_tb;
create temporary table nodes_req_temp_tb(
	node_id int primary key,
    group_id int,
    app_name varchar(256),
    process_name varchar(4096),
    alias_app_name varchar(256),
    app_image_id int,
    cust_id int,
    cust_name varchar(256),
    dept_id int,
    dept_name varchar(256),
    adpl_app_id int,
    ip varchar(45),
    port int,
    protocol int,
    pid int,
    uuid varchar(36),
    socket_uuid varchar(36),
    threats_detected int
);

insert into nodes_req_temp_tb 
select * from nodes_temp_tb ntt
where cust_id = cust_id_in;

drop table if exists nodes_relation_temp_tb;
create temporary table nodes_relation_temp_tb(
	target_id int,
    source_id int,
    primary key (target_id, source_id)
);

insert ignore into nodes_relation_temp_tb
select nrtt.group_id, ntt.group_id
from nodes_req_temp_tb nrtt left join client_stats_tb cst
on nrtt.uuid = cst.server_uuid and nrtt.socket_uuid = cst.server_socket_uuid
join nodes_temp_tb ntt
on cst.client_uuid = ntt.socket_uuid;

insert ignore into nodes_relation_temp_tb
select  ntt.group_id, nrtt.group_id
from nodes_req_temp_tb nrtt left join client_stats_tb cst
on nrtt.socket_uuid = cst.client_uuid
join nodes_temp_tb ntt
on cst.server_uuid = ntt.uuid
and cst.server_socket_uuid = ntt.socket_uuid;

select * from nodes_relation_temp_tb;

insert ignore into nodes_req_temp_tb
select *
from nodes_temp_tb
where group_id in
(select distinct target_id from nodes_relation_temp_tb);

insert ignore into nodes_req_temp_tb
select *
from nodes_temp_tb
where group_id in
(select distinct source_id from nodes_relation_temp_tb);

select * from nodes_req_temp_tb order by group_id;

drop table if exists nodes_req_temp_tb;
drop table if exists nodes_temp_tb;
drop table if exists nodes_group_temp_tb;
drop table if exists nodes_relation_temp_tb;

end //

DELIMITER //
drop procedure if exists Dashboard_Application_Client_Details_SP //
DELIMITER //
create procedure Dashboard_Application_Client_Details_SP(in uuid_in varchar(36), socket_uuid_in varchar(36), in offset_in int)
begin
	select
    sst.app_name,
    ct.customer_name,
    dt.dept_name,
    cst.client_ip,
    cst.client_port,
    cst.send_count,
    cst.recv_count,
    cst.pl_rej_policies,
    cst.pl_rej_custid,
    cst.pl_rej_depid,
    cst.pl_rej_sqlinj,
    cst.pl_rej_secsig,
    cst.close_reason,
    cst.close_timestamp
    from client_stats_tb cst left join server_stats_tb sst
    on cst.client_uuid = sst.socket_uuid
    left join (customer_tb ct join department_tb dt
    on ct.cust_id = dt.cust_id)
    on sst.cust_id = dt.cust_id
    and sst.dep_id = dt.dept_id
	where cst.server_uuid = uuid_in
    and cst.server_socket_uuid = socket_uuid_in
    order by cst.close_timestamp, cst.client_uuid desc
    limit offset_in, 10;
end //

DELIMITER //
drop procedure if exists Dashboard_Application_Client_History_Details_SP //
DELIMITER //
create procedure Dashboard_Application_Client_History_Details_SP(in uuid_in varchar(36), socket_uuid_in varchar(36), in offset_in int)
begin
	select
    sst.app_name,
    ct.customer_name,
    dt.dept_name,
    cst.client_ip,
    cst.client_port,
    cst.send_count,
    cst.recv_count,
    cst.pl_rej_policies,
    cst.pl_rej_custid,
    cst.pl_rej_depid,
    cst.pl_rej_sqlinj,
    cst.pl_rej_secsig,
    cst.close_reason,
    cst.close_timestamp
    from client_descriptor_tb cst left join server_descriptor_tb sst
    on cst.client_uuid = sst.socket_uuid
    left join (customer_tb ct join department_tb dt
    on ct.cust_id = dt.cust_id)
    on sst.cust_id = dt.cust_id
    and sst.dep_id = dt.dept_id
	where cst.server_uuid = uuid_in
    and cst.server_socket_uuid = socket_uuid_in
    order by cst.close_timestamp, cst.client_uuid desc
    limit offset_in, 10;
end //

DELIMITER //
drop procedure if exists Dashboard_Threat_Notification_SP //
DELIMITER //
create procedure Dashboard_Threat_Notification_SP (in username_in varchar(256), in lower_date_in date, in upper_date_in date, out threats_detected_count_out int)
begin 
	declare last_logout_time_var timestamp;
    
    drop temporary table if exists temp_app_info_tb;
    create temporary table  temp_app_info_tb
    select uuid, socket_uuid FROM app_info_tb ait
	where isDeleted <> 1;
    
    if(lower_date_in is null and upper_date_in is null) then
		select last_logout_time into last_logout_time_var from users_tb where username = username_in;
        select ifnull(count(case when close_reason <> 5 and close_reason <> 0 then 1 end) + sum(pl_rej_sqlinj), 0) as threats_detected_count into threats_detected_count_out
		from client_descriptor_tb
		where close_timestamp >= last_logout_time_var
        and close_timestamp <= now()
        and (server_uuid, server_socket_uuid) in (select uuid, socket_uuid from temp_app_info_tb);
        
	else 
		select ifnull(count(case when close_reason <> 5 and close_reason <> 0 then 1 end) + sum(pl_rej_sqlinj), 0) as threats_detected_count into threats_detected_count_out
		from client_descriptor_tb
		where close_timestamp >= lower_date_in
        and close_timestamp <= upper_date_in
        and (server_uuid, server_socket_uuid) in (select uuid, socket_uuid from temp_app_info_tb);
    end if;
    
end //

