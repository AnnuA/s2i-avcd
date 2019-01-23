drop DATABASE if exists avocado_db;
CREATE DATABASE  avocado_db /*!40100 DEFAULT CHARACTER SET latin1 */;
USE avocado_db;

CREATE USER 'avocado'@'%' IDENTIFIED BY 'Avocado_db_93549';
GRANT ALL PRIVILEGES on *.* to 'avocado'@'%'  ;
FLUSH PRIVILEGES ;

-- MySQL dump 10.13  Distrib 5.5.43, for debian-linux-gnu (x86_64)
--
-- Host: 127.0.0.1    Database: avocado_db
-- ------------------------------------------------------
-- Server version	5.5.43-0ubuntu0.14.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

DROP TABLE IF EXISTS customer_tb ;
CREATE TABLE customer_tb (
  cust_id int auto_increment,
  customer_name varchar(256) DEFAULT NULL,
  created_on TIMESTAMP NULL,
  modify_on TIMESTAMP NULL,
  PRIMARY KEY (cust_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS department_tb ;
CREATE TABLE department_tb (
  dept_id INT auto_increment ,
  cust_id INT NOT NULL,
  dept_name VARCHAR(256) NULL,
  created_on TIMESTAMP NULL,
  modify_on TIMESTAMP NULL,
  PRIMARY KEY (dept_id, cust_id),
  INDEX fk_department_tb_1_idx (cust_id ASC),
  CONSTRAINT fk_department_tb_1
    FOREIGN KEY (cust_id)
    REFERENCES customer_tb (cust_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE);

--
-- Table structure for table Users
--

DROP TABLE IF EXISTS users_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE users_tb (
  user_id int(11) NOT NULL AUTO_INCREMENT,
  first_name varchar(20) DEFAULT NULL,
  last_name varchar(20) DEFAULT NULL,
  email_id varchar(70) NOT NULL,
  username varchar(255) NOT NULL,
  password varchar(60) DEFAULT NULL,
  role varchar(12) DEFAULT NULL,
  isActive tinyint(4) DEFAULT NULL,
  status varchar(8) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  last_logout_time timestamp NULL DEFAULT NULL,
  contactNo varchar(20) NOT NULL,
  created_by varchar(45) DEFAULT NULL,
  modify_by varchar(45) DEFAULT NULL,
  ldapId int(11) DEFAULT NULL,
  isLDAPAuthenticate tinyint(4) DEFAULT NULL,
  PRIMARY KEY (user_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table app_info_tb
--

DROP TABLE IF EXISTS app_info_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE  app_info_tb  (
   app_name  varchar(256) NOT NULL,
   proces_name  varchar(4096) DEFAULT NULL,
   pid  int(11) DEFAULT NULL,
   server_port  int(11) NOT NULL,
   customer_id  int(100) NOT NULL,
   department_id  int(11) NOT NULL,
   protocol  int(11) NOT NULL,
   id  int(11) NOT NULL AUTO_INCREMENT,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   server_ip  varchar(50) DEFAULT NULL,
   isDeleted  tinyint(4) DEFAULT '1',
   uuid  varchar(36) DEFAULT NULL,
   adpl_app_id INT DEFAULT NULL,
   socket_uuid VARCHAR(45) NULL,
   is_child TINYINT NULL DEFAULT 0,
  PRIMARY KEY ( id )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table application_atrributes_stat_tb
--

DROP TABLE IF EXISTS application_atrributes_stat_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE application_atrributes_stat_tb (
  app_id int(11) NOT NULL,
  app_name varchar(30) DEFAULT NULL,
  own_name varchar(30) DEFAULT NULL,
  owner_id int(11) NOT NULL,
  owner_access varchar(4) DEFAULT NULL,
  server_group_id int(11) NOT NULL,
  server_data_ip_interface varchar(10) DEFAULT NULL,
  server_mgmt_ip_interface varchar(10) DEFAULT NULL,
  date_time_discovery timestamp NULL DEFAULT NULL,
  curr_health_status varchar(10) DEFAULT NULL,
  base_process_id int(11) DEFAULT NULL,
  total_no_req int(11) DEFAULT NULL,
  total_accepts int(11) DEFAULT NULL,
  total_rejects int(11) DEFAULT NULL,
  policy_base_rejects int(11) DEFAULT NULL,
  cust_id_missmatch_reject int(11) DEFAULT NULL,
  dept_id_missmatch_rejects int(11) DEFAULT NULL,
  secsign_mismatch_rejects int(11) DEFAULT NULL,
  rete_limit_rejects int(11) DEFAULT NULL,
  source_ip_add_of_last_reject varchar(15) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (app_id),
  KEY owner_id (owner_id),
  KEY server_group_id (server_group_id),
  CONSTRAINT application_atrributes_stat_tb_ibfk_1 FOREIGN KEY (owner_id) REFERENCES owner_tb (owner_id),
  CONSTRAINT application_atrributes_stat_tb_ibfk_2 FOREIGN KEY (server_group_id) REFERENCES server_group_tb (grp_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table application_security_ewpolicy_tb
--

DROP TABLE IF EXISTS application_security_ewpolicy_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE application_security_ewpolicy_tb (
  policy_id int(11) NOT NULL AUTO_INCREMENT,
  server_grp_id int(11) DEFAULT NULL,
  owner_id int(11) NOT NULL,
  time_stamp_create timestamp NULL DEFAULT NULL,
  server_source_ip varchar(15) DEFAULT NULL,
  server_dest_ip varchar(15) DEFAULT NULL,
  source_client_id int(11) DEFAULT NULL,
  source_dept_id int(11) DEFAULT NULL,
  destination_transport_port_descriptor int(11) DEFAULT NULL,
  source_transport_port_descriptor int(11) DEFAULT NULL,
  transport_protocol int(11) DEFAULT NULL,
  base_sign_enforcement varchar(10) DEFAULT NULL,
  source_app_buffer_size int(11) DEFAULT NULL,
  action int(11) DEFAULT NULL,
  sub_action int(11) DEFAULT NULL,
  policy_name varchar(256) DEFAULT NULL,
  status tinyint(4) DEFAULT NULL,
  policy_no int(10) DEFAULT NULL,
  mtu int(11) DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  policy_status varchar(25) DEFAULT NULL,
  PRIMARY KEY (policy_id),
  KEY application_security_ewpolicy_tb_ibfk_2 (owner_id),
  KEY fk_application_security_ewpolicy_tb_1_idx (action),
  KEY fk_application_security_ewpolicy_tb_1 (server_grp_id),
  KEY fk_application_security_ewpolicy_tb_2_idx (sub_action),
  CONSTRAINT application_security_ewpolicy_tb_ibfk_2 FOREIGN KEY (owner_id) REFERENCES owner_tb (owner_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_application_security_ewpolicy_tb_1 FOREIGN KEY (server_grp_id) REFERENCES server_group_tb (grp_id) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table application_security_nspolicy_tb
--

DROP TABLE IF EXISTS application_security_nspolicy_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE application_security_nspolicy_tb (
  policy_id int(11) NOT NULL AUTO_INCREMENT,
  server_grp_id int(11) DEFAULT NULL,
  owner_id int(11) NOT NULL,
  time_stamp_create timestamp NULL DEFAULT NULL,
  server_source_ip varchar(15) DEFAULT NULL,
  server_dest_ip varchar(15) DEFAULT NULL,
  source_client_id int(11) DEFAULT NULL,
  source_dept_id int(11) DEFAULT NULL,
  destination_transport_port_descriptor int(11) DEFAULT NULL,
  source_transport_port_descriptor int(11) DEFAULT NULL,
  transport_protocol int(11) DEFAULT NULL,
  base_sign_enforcement varchar(10) DEFAULT NULL,
  source_app_buffer_size int(11) DEFAULT NULL,
  action int(11) DEFAULT NULL,
  sub_action int(11) DEFAULT NULL,
  policy_name varchar(256) DEFAULT NULL,
  status tinyint(4) DEFAULT NULL,
  policy_no int(10) DEFAULT NULL,
  mtu int(11) DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  policy_status varchar(25) DEFAULT NULL,
  PRIMARY KEY (policy_id),
  KEY fk_application_security_nspolicy_tb_1 (server_grp_id),
  KEY fk_application_security_nspolicy_tb_2 (owner_id),
  KEY action (action),
  KEY sub_action (sub_action),
  CONSTRAINT application_security_nspolicy_tb_ibfk_1 FOREIGN KEY (action) REFERENCES policy_action_tb (action_id),
  CONSTRAINT application_security_nspolicy_tb_ibfk_2 FOREIGN KEY (sub_action) REFERENCES policy_subaction_tb (subaction_id),
  CONSTRAINT fk_application_security_nspolicy_tb_1 FOREIGN KEY (server_grp_id) REFERENCES server_group_tb (grp_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_application_security_nspolicy_tb_2 FOREIGN KEY (owner_id) REFERENCES owner_tb (owner_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table application_verification_tb
--

DROP TABLE IF EXISTS application_verification_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE  application_verification_tb  (
   app_id  int(11) NOT NULL AUTO_INCREMENT,
   app_name  varchar(256) DEFAULT NULL,
   md_checksum  varchar(512) DEFAULT NULL,
   app_path  varchar(4096) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   adpl_enabled  tinyint(4) DEFAULT NULL,
   sha2  varchar(512) DEFAULT NULL,
   isMalware  tinyint(4) DEFAULT NULL,
   isMannual  tinyint(4) DEFAULT NULL,
   action  varchar(45) DEFAULT NULL,
   cid  int(11) DEFAULT NULL,
   did  int(11) DEFAULT NULL,
   protocol  int(11) DEFAULT NULL,
   pid  int(11) DEFAULT NULL,
   container  varchar(45) DEFAULT '0',
   avcdLicence  varchar(45) DEFAULT NULL,
   port  int(11) DEFAULT NULL,
   aliasAppName  varchar(256) DEFAULT NULL,
   adpl_app_id  int(11) DEFAULT NULL,
   appImageId  int(11) DEFAULT NULL,
   hostInfo  varchar(256) DEFAULT NULL,
   compliance  varchar(45) DEFAULT 'Default',
   certificateNickname  varchar(256) DEFAULT NULL,
   certificateContent  varchar(4096) DEFAULT NULL,
   certificateHostName  varchar(256) DEFAULT NULL,
   nssDBDir  varchar(512) DEFAULT NULL,
   nssDBPassword  varchar(256) DEFAULT NULL,
   argTokens varchar(4096) DEFAULT NULL,
   customTokens varchar(4096) DEFAULT NULL,
  PRIMARY KEY ( app_id )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table client_stats_tb
--
DROP TABLE IF EXISTS client_stats_tb ;

CREATE TABLE  client_stats_tb  (
   client_port  int(11) NOT NULL,
   client_ip  varchar(80) DEFAULT NULL,
   client_uuid varchar(36) NOT NULL,
   server_uuid  varchar(36) NOT NULL,
   server_socket_uuid varchar(36) NOT NULL,
   send_count  int(11) DEFAULT NULL,
   recv_count  int(11) DEFAULT NULL,
   send_bytes  BIGINT(20) DEFAULT NULL,
   recv_bytes  BIGINT(20) DEFAULT NULL,
   recv_rejected_bytes  BIGINT(20) DEFAULT NULL,
   cust_dept_mismatch_count  int(11) DEFAULT NULL,
   sig_mismatch_count  int(11) DEFAULT NULL,
   security_prof_chng_count  int(11) DEFAULT NULL,
   pl_rej_policies  int(11) DEFAULT NULL,
   pl_rej_custid  int(11) DEFAULT NULL,
   pl_rej_depid  int(11) DEFAULT NULL,
   pl_rej_secsig  int(11) DEFAULT NULL,
   pl_allowed_policies  int(11) DEFAULT NULL,
   pl_allowed  int(11) DEFAULT NULL,
   pl_bytes_rej_policies  int(11) DEFAULT NULL,
   pl_bytes_rej_custid  int(11) DEFAULT NULL,
   pl_bytes_rej_depid  int(11) DEFAULT NULL,
   pl_bytes_rej_secsig  int(11) DEFAULT NULL,
   pl_rej_sqlinj  int(11) DEFAULT NULL,
   pl_bytes_rej_sqlinj  int(11) DEFAULT NULL,
   close_reason  int(11) DEFAULT NULL,
   close_timestamp  timestamp NULL DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   PRIMARY KEY ( client_uuid,client_port ),
  KEY  fk_ClientStats_1  ( server_uuid, server_socket_uuid ),
  CONSTRAINT  fk_ClientStats_1  FOREIGN KEY ( server_uuid, server_socket_uuid ) REFERENCES  server_stats_tb  ( uuid, socket_uuid ) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



--
-- Table structure for table config_tb
--

DROP TABLE IF EXISTS config_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE config_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  name varchar(45) DEFAULT NULL,
  path varchar(45) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table data_security_policy_tb
--


DROP TABLE IF EXISTS data_security_policy_tb1;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE data_security_policy_tb1 (
  policy_id int(11) NOT NULL AUTO_INCREMENT,
  policy_name varchar(256) NOT NULL,
  server_group_id int(11) DEFAULT NULL,
  owner_id int(11) NOT NULL,
  time_stamp_create timestamp NULL DEFAULT NULL,
  server_source_ip varchar(15) DEFAULT NULL,
  server_dest_ip varchar(15) DEFAULT NULL,
  source_client_id int(11) DEFAULT NULL,
  source_dept_id int(11) DEFAULT NULL,
  destination_transport_port_descriptor int(11) DEFAULT NULL,
  source_transport_port_descriptor int(11) DEFAULT NULL,
  source_app_buffer_size int(11) DEFAULT NULL,
  profile_source varchar(7) DEFAULT NULL,
  profile_type int(11) DEFAULT NULL,
  action int(11) DEFAULT NULL,
  redaction_policy varchar(70) DEFAULT NULL,
  protocol int(11) DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  policy_status varchar(25) DEFAULT NULL,
  profile_types_array varchar(85) DEFAULT NULL,
  PRIMARY KEY (policy_id),
  KEY server_group_id (server_group_id),
  KEY owner_id (owner_id),
  KEY action (action),
  CONSTRAINT data_security_policy_tb1_ibfk_1 FOREIGN KEY (server_group_id) REFERENCES server_group_tb (grp_id),
  CONSTRAINT data_security_policy_tb1_ibfk_2 FOREIGN KEY (owner_id) REFERENCES owner_tb (owner_id),
  CONSTRAINT data_security_policy_tb1_ibfk_3 FOREIGN KEY (action) REFERENCES policy_action_tb (action_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table last_access_info_tb
--

DROP TABLE IF EXISTS last_access_info_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE last_access_info_tb (
  last_access_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
--
-- Table structure for table log_files_prop_tb
--

DROP TABLE IF EXISTS log_files_prop_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE log_files_prop_tb (
  max_log_file_size int(11) DEFAULT NULL,
  log_file_prefix varchar(20) DEFAULT NULL,
  log_server_IP varchar(30) DEFAULT NULL,
  log_server_port int(11) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  is_log_to_orchestrator tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

/*!40101 SET character_set_client = @saved_cs_client */;

DROP TABLE IF EXISTS malware_checksum_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE malware_checksum_tb (
  malware_checksum varchar(256) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table management_server_stats_tb
--

DROP TABLE IF EXISTS management_server_stats_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE management_server_stats_tb (
  manag_server_stat_id int(11) NOT NULL AUTO_INCREMENT,
  count_max_client int(11) DEFAULT NULL,
  manag_stat_id int(11) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (manag_server_stat_id),
  KEY fk_ManagementServerStats_1_idx (manag_stat_id),
  CONSTRAINT fk_ManagementServerStats_1 FOREIGN KEY (manag_stat_id) REFERENCES management_stats_tb (manag_stat_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table management_stats_tb
--

DROP TABLE IF EXISTS management_stats_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE management_stats_tb (
  manag_stat_id int(11) NOT NULL AUTO_INCREMENT,
  process_name varchar(4096) DEFAULT NULL,
  dep_id int(11) DEFAULT NULL,
  pid int(11) DEFAULT NULL,
  server_count int(11) DEFAULT NULL,
  cust_id int(11) DEFAULT NULL,
  app_name varchar(256) DEFAULT NULL,
   created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (manag_stat_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table managment_pool_tb
--

DROP TABLE IF EXISTS managment_pool_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE managment_pool_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  managment_IP_start varchar(55) DEFAULT NULL,
  managment_IP_end varchar(55) DEFAULT NULL,
  is_used smallint(6) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  managment_IP_start_int int(11) DEFAULT NULL,
  managment_IP_end_int int(11) DEFAULT NULL,
  isIPv6 TINYINT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table owner_tb
--

DROP TABLE IF EXISTS owner_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE owner_tb (
  owner_id int(11) NOT NULL,
  own_name varchar(30) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table policy_action_tb
--

DROP TABLE IF EXISTS policy_action_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE policy_action_tb (
  action_id int(11) NOT NULL AUTO_INCREMENT,
  action_name varchar(80) NOT NULL,
  action_description varchar(128) DEFAULT NULL,
  enabled tinyint(4) NOT NULL,
  create_date date NOT NULL,
  modify_date date NOT NULL,
  PRIMARY KEY (action_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table policy_redaction_tb
--

DROP TABLE IF EXISTS policy_redaction_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE policy_redaction_tb (
  redaction_id int(11) NOT NULL AUTO_INCREMENT,
  action_name varchar(128) DEFAULT NULL,
  action_description varchar(128) DEFAULT NULL,
  enable tinyint(4) DEFAULT NULL,
  create_date date DEFAULT NULL,
  modify_date date DEFAULT NULL,
  PRIMARY KEY (redaction_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table policy_schedule_transaction_tb
--
DROP TABLE IF EXISTS  policy_schedule_transaction_tb ;
CREATE TABLE  policy_schedule_transaction_tb  (
  schedule_id  int(11) NOT NULL,
  next_schedule_time  timestamp NULL DEFAULT NULL,
  repeat_count  int(11) DEFAULT NULL,
  `repeat`  int(11) DEFAULT NULL,
  end_time  timestamp NULL DEFAULT NULL,
 KEY  fk_policy_schedule_transaction_tb_1_idx  ( schedule_id ),
 CONSTRAINT  fk_policy_schedule_transaction_tb_1  FOREIGN KEY ( schedule_id ) REFERENCES  policy_scheduler_tb  ( schedule_id ) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table policy_scheduler_tb
--

DROP TABLE IF EXISTS policy_scheduler_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE policy_scheduler_tb (
  schedule_id int(11) NOT NULL AUTO_INCREMENT,
  start_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  end_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  action int(11) DEFAULT NULL,
  misc varchar(256) DEFAULT NULL,
  comment varchar(256) DEFAULT NULL,
  policy_type varchar(80) NOT NULL,
  policy_id int(11) NOT NULL,
  repeat_by int(11) DEFAULT NULL,
  repeat_count int(11) DEFAULT NULL,
  next_schedule_time timestamp NULL DEFAULT NULL,
  schedule_state tinyint(4) DEFAULT NULL,
  time_zone VARCHAR(256) DEFAULT NULL, 
  active_period  VARCHAR(256) NULL,
  PRIMARY KEY (schedule_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table policy_subaction_tb
--

DROP TABLE IF EXISTS policy_subaction_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE policy_subaction_tb (
  subaction_id int(11) NOT NULL AUTO_INCREMENT,
  subaction_name varchar(80) NOT NULL,
  subaction_description varchar(128) DEFAULT NULL,
  enabled tinyint(4) NOT NULL,
  create_date date NOT NULL,
  modify_date date NOT NULL,
  is_ew_enable smallint(6) DEFAULT NULL,
  is_ns_enable smallint(6) DEFAULT NULL,
  is_sd_enable smallint(6) DEFAULT NULL,
  PRIMARY KEY (subaction_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table process_management_tb
--

DROP TABLE IF EXISTS process_management_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE process_management_tb (
  check_app_health tinyint(4) NOT NULL,
  polling_interval int(11) NOT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table profile_source_tb
--

DROP TABLE IF EXISTS profile_source_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE profile_source_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  server_group_id int(11) DEFAULT NULL,
  profile_name_1 varchar(45) DEFAULT NULL,
  profile_per_1 int(11) DEFAULT NULL,
  profile_name_2 varchar(45) DEFAULT NULL,
  profile_per_2 int(11) DEFAULT NULL,
  profile_name_3 varchar(45) DEFAULT NULL,
  profile_per_3 int(11) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (id),
  KEY fk_profile_source_tb_1_idx (server_group_id),
  CONSTRAINT fk_profile_source_tb_1 FOREIGN KEY (server_group_id) REFERENCES server_group_tb (grp_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table protocol_tb
--

DROP TABLE IF EXISTS protocol_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE protocol_tb (
  protocol_id int(11) NOT NULL AUTO_INCREMENT,
  protocol_name varchar(75) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (protocol_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table server_group_prop_tb
--

DROP TABLE IF EXISTS server_group_prop_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE server_group_prop_tb (
  max_server_group int(11) DEFAULT NULL,
  max_server_per_group int(11) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table server_group_tb
--
DROP TABLE IF EXISTS server_group_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;

CREATE TABLE server_group_tb (
  grp_id int(11) NOT NULL AUTO_INCREMENT,
  app_name varchar(256) NOT NULL,
  serv_port int(11) NOT NULL,
  trans_proto int(11) NOT NULL,
  cust_id int(11) NOT NULL,
  dept_id int(11) NOT NULL,
  own_name varchar(30) DEFAULT NULL,
  own_accs_lev char(2) DEFAULT NULL,
  create_state varchar(10) DEFAULT NULL,
  create_date timestamp NULL DEFAULT NULL,
  max_no_mem_allow int(11) DEFAULT NULL,
  no_curr_mem int(11) DEFAULT NULL,
  no_ew_pol_apply int(11) DEFAULT NULL,
  no_data_seq_pol_apply int(11) DEFAULT NULL,
  owner_id int(11) DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  no_ns_pol_apply int(11) DEFAULT NULL,
  PRIMARY KEY (grp_id),
  KEY fk_server_group_tb_1_idx (owner_id)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;


--
-- Table structure for table server_group_transaction_tb
--

DROP TABLE IF EXISTS server_group_transaction_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE server_group_transaction_tb (
  server_id int(11) NOT NULL,
  grp_id int(11) NOT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  created_by varchar(45) DEFAULT NULL,
  modify_by varchar(45) DEFAULT NULL,
  KEY fk_server_group_transaction_tb_1_idx (grp_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table server_pool_tb
--

DROP TABLE IF EXISTS server_pool_tb;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE server_pool_tb (
  server_pool_id int(11) NOT NULL AUTO_INCREMENT,
  server_IP_start varchar(55) DEFAULT NULL,
  server_IP_end varchar(55) DEFAULT NULL,
  is_used tinyint(4) DEFAULT NULL,
  create_date date DEFAULT NULL,
  modify_date date DEFAULT NULL,
  no_ew_policy int(11) DEFAULT NULL,
  no_ns_policy int(11) DEFAULT NULL,
  no_data_policy int(11) DEFAULT NULL,
  server_IP_start_int_value int(11) DEFAULT NULL,
  server_IP_end_int_value int(11) DEFAULT NULL,
  isIPv6 TINYINT NULL,
  PRIMARY KEY (server_pool_id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table server_stats_tb
--

DROP TABLE IF EXISTS server_stats_tb ;

CREATE TABLE  server_stats_tb  (
   app_name  varchar(256) DEFAULT NULL,
   process_name  varchar(4096) DEFAULT NULL,
   pid  int(11) DEFAULT NULL,
   cust_id  int(11) DEFAULT NULL,
   dep_id  int(11) DEFAULT NULL,
   adpl_app_id  INT DEFAULT NULL,
   server_ip  varchar(80) DEFAULT NULL,
   server_port  int(11) DEFAULT NULL,
   protocol  int(11) DEFAULT NULL,
   uuid  varchar(36) NOT NULL,
   socket_uuid  varchar(36) NOT NULL,
   server_count  int(11) DEFAULT NULL,
   count_max_client  int(11) DEFAULT NULL,
   conn_reject_count  int(11) DEFAULT NULL,
   create_timestamp  timestamp NULL DEFAULT NULL,
   client_count  int(11) DEFAULT NULL,
   sess_allowed  int(11) DEFAULT NULL,
   sess_rejected  int(11) DEFAULT NULL,
   sess_rej_policies  int(11) DEFAULT NULL,
   sess_rej_custid  int(11) DEFAULT NULL,
   sess_rej_depid  int(11) DEFAULT NULL,
   sess_rej_sla  int(11) DEFAULT NULL,
   sess_rej_osfails  int(11) DEFAULT NULL,
   pl_rejected int(11) DEFAULT NULL,
   server_status_id  bigint(20) DEFAULT NULL,
   close_reason  int(11) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
  PRIMARY KEY ( uuid, socket_uuid )
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table server_status_information_tb
--

DROP TABLE IF EXISTS server_status_information_tb ;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE  server_status_information_tb  (
   id  bigint(20) NOT NULL AUTO_INCREMENT,
   management_ip  varchar(128) DEFAULT NULL,
   server_name  varchar(256) DEFAULT NULL,
   app_group_name  varchar(256) DEFAULT NULL,
   active  tinyint(4) DEFAULT NULL,
   server_state  tinyint(4) DEFAULT NULL,
   create_date  timestamp NULL DEFAULT NULL,
   modify_date  timestamp NULL DEFAULT NULL,
   server_primary_ip  varchar(60) DEFAULT NULL,
   server_secondary_ip1  varchar(60) DEFAULT NULL,
   server_secondary_ip2  varchar(60) DEFAULT NULL,
   server_secondary_ip3  varchar(60) DEFAULT NULL,
   server_secondary_ip4  varchar(60) DEFAULT NULL,
   server_secondary_ip5  varchar(60) DEFAULT NULL,
   server_secondary_ip6  varchar(60) DEFAULT NULL,
   server_secondary_ip7  varchar(45) DEFAULT NULL,
   server_status_changed  timestamp NULL DEFAULT NULL,
   management_ip_int  int(11) DEFAULT NULL,
   management_pool_id  int DEFAULT NULL,
  PRIMARY KEY ( id ),
  UNIQUE KEY  unique_index  ( management_ip , server_primary_ip )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

--
-- Table structure for table server_descriptor_tb
--

DROP TABLE IF EXISTS server_descriptor_tb;
CREATE TABLE  server_descriptor_tb  (
   app_name  varchar(256) DEFAULT NULL,
   process_name  varchar(4096) DEFAULT NULL,
   pid  int(11) DEFAULT NULL,
   cust_id  int(11) DEFAULT NULL,
   dep_id  int(11) DEFAULT NULL,
   adpl_app_id  INT DEFAULT NULL,
   server_ip  varchar(80) DEFAULT NULL,
   server_port  int(11) DEFAULT NULL,
   protocol  int(11) DEFAULT NULL,
   uuid  varchar(36) NOT NULL,
   socket_uuid  varchar(36) NOT NULL,
   server_count  int(11) DEFAULT NULL,
   count_max_client  int(11) DEFAULT NULL,
   conn_reject_count  int(11) DEFAULT NULL,
   create_timestamp  timestamp NULL DEFAULT NULL,
   client_count  int(11) DEFAULT NULL,
   sess_allowed  int(11) DEFAULT NULL,
   sess_rejected  int(11) DEFAULT NULL,
   sess_rej_policies  int(11) DEFAULT NULL,
   sess_rej_custid  int(11) DEFAULT NULL,
   sess_rej_depid  int(11) DEFAULT NULL,
   sess_rej_sla  int(11) DEFAULT NULL,
   sess_rej_osfails  int(11) DEFAULT NULL,
   pl_rejected int(11) DEFAULT NULL,
   server_status_id  bigint(20) DEFAULT NULL,
   close_reason  int(11) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
  PRIMARY KEY ( uuid, socket_uuid )
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


--
-- Table structure for table client_descriptor_tb
--

DROP TABLE IF EXISTS client_descriptor_tb;
CREATE TABLE  client_descriptor_tb  (
   client_port  int(11) NOT NULL,
   client_ip  varchar(80) DEFAULT NULL,
   client_uuid varchar(36) NOT NULL,
   server_uuid  varchar(36) NOT NULL,
   server_socket_uuid varchar(36) NOT NULL,
   send_count  int(11) DEFAULT NULL,
   recv_count  int(11) DEFAULT NULL,
   send_bytes  BIGINT(20) DEFAULT NULL,
   recv_bytes  BIGINT(20) DEFAULT NULL,
   recv_rejected_bytes  BIGINT(20) DEFAULT NULL,
   cust_dept_mismatch_count  int(11) DEFAULT NULL,
   sig_mismatch_count  int(11) DEFAULT NULL,
   security_prof_chng_count  int(11) DEFAULT NULL,
   pl_rej_policies  int(11) DEFAULT NULL,
   pl_rej_custid  int(11) DEFAULT NULL,
   pl_rej_depid  int(11) DEFAULT NULL,
   pl_rej_secsig  int(11) DEFAULT NULL,
   pl_allowed_policies  int(11) DEFAULT NULL,
   pl_allowed  int(11) DEFAULT NULL,
   pl_bytes_rej_policies  int(11) DEFAULT NULL,
   pl_bytes_rej_custid  int(11) DEFAULT NULL,
   pl_bytes_rej_depid  int(11) DEFAULT NULL,
   pl_bytes_rej_secsig  int(11) DEFAULT NULL,
   pl_rej_sqlinj  int(11) DEFAULT NULL,
   pl_bytes_rej_sqlinj  int(11) DEFAULT NULL,
   close_reason  int(11) DEFAULT NULL,
   close_timestamp  timestamp NULL DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
  PRIMARY KEY ( client_uuid, client_port ),
  KEY  fk_ClientDescriptor_1  ( server_uuid, server_socket_uuid ),
  CONSTRAINT  fk_ClientDescriptor_1  FOREIGN KEY ( server_uuid, server_socket_uuid ) REFERENCES  server_descriptor_tb  ( uuid, socket_uuid ) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS sla_failed_tb;
CREATE TABLE sla_failed_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  app_name varchar(256) DEFAULT NULL,
  md_checksum varchar(256) DEFAULT NULL,
  app_path varchar(4096) DEFAULT NULL,
  apdl_enabled smallint(6) DEFAULT NULL,
  pid int(11) DEFAULT NULL,
  failure_cause int(11) DEFAULT NULL,
  process_name varchar(256) DEFAULT NULL,
  server_port int(11) DEFAULT NULL,
  customer_id int(11) DEFAULT NULL,
  department_id int(11) DEFAULT NULL,
  protocol int(11) DEFAULT NULL,
  server_ip varchar(256) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  comment varchar(256) DEFAULT NULL,
  sha2 varchar(512) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS malware_sha256_tb;
CREATE TABLE malware_sha256_tb (
  malware_sha256 VARCHAR(256) NULL);
  
DROP TABLE IF EXISTS detected_application_tb;
CREATE TABLE  detected_application_tb  (
   id  int(11) NOT NULL AUTO_INCREMENT,
   appName  varchar(256) DEFAULT NULL,
   appPath  varchar(4096) DEFAULT NULL,
   mdCheckSum  varchar(512) DEFAULT NULL,
   sha256  varchar(512) DEFAULT NULL,
   action  varchar(45) DEFAULT NULL,
   serverIp  varchar(256) DEFAULT NULL,
   hostname  varchar(256) DEFAULT NULL,
   nssDBDir  varchar(512) DEFAULT NULL,
   nssDBPassword  varchar(256) DEFAULT NULL,
   pid  int(11) DEFAULT NULL,
   cid  int(11) DEFAULT NULL,
   did  int(11) DEFAULT NULL,
   protocol  int(11) DEFAULT NULL,
   port  int(11) DEFAULT NULL,
   isADPLEnabled  tinyint(4) DEFAULT NULL,
   isMalware  tinyint(4) DEFAULT NULL,
   isRegister  tinyint(4) DEFAULT NULL,
   isDuplicate  tinyint(4) DEFAULT NULL,
   isByPass  tinyint(4) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   container  varchar(45) DEFAULT '0',
   avcdLicence  varchar(45) DEFAULT NULL,
   aliasAppName  varchar(256) DEFAULT NULL,
   adplAppId  int(11) DEFAULT NULL,
   appImageId  int(11) DEFAULT NULL,
   hostInfo  varchar(256) DEFAULT NULL,
   compliance  varchar(45) DEFAULT 'Default',
   certificateNickname  varchar(256) DEFAULT NULL,
   certificateContent  varchar(4096) DEFAULT NULL,
   certificateHostName  varchar(256) DEFAULT NULL,
   argTokens varchar(4096) DEFAULT NULL,
   customTokens varchar(4096) DEFAULT NULL,
  PRIMARY KEY ( id )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS discover_only_tb;
CREATE TABLE discover_only_tb (
  discover_only_mode tinyint(4) DEFAULT NULL,
  isTookActionBefore tinyint(4) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


  
 -- User Role Define Table
 DROP TABLE IF EXISTS user_role_based_access_tb;
 CREATE TABLE user_role_based_access_tb (
  accessId int(11) NOT NULL AUTO_INCREMENT,
  accessRole varchar(4096) NOT NULL,
  accessURL varchar(100) NOT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (accessId)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

 
  -- create table for user_roles_tb
 DROP TABLE IF EXISTS user_roles_tb;
 CREATE TABLE user_roles_tb (
  roleID INT NOT NULL,
  role VARCHAR(45) NOT NULL,
  created_on TIMESTAMP NULL,
  modify_on TIMESTAMP NULL,
 PRIMARY KEY (roleID),
 UNIQUE INDEX role_UNIQUE (role ASC));

 DROP TABLE IF EXISTS  data_security_policy_tb;
 CREATE TABLE  data_security_policy_tb  (
   policy_id  int(11) NOT NULL AUTO_INCREMENT,
   policy_name  varchar(75) DEFAULT NULL,
   action  int(11) DEFAULT NULL,
   redaction  int(11) DEFAULT NULL,
   cust_id1  int(11) DEFAULT NULL,
   dept_id1  int(11) DEFAULT NULL,
   cust_id2  int(11) DEFAULT NULL,
   dept_id2  int(11) DEFAULT NULL,
   app_name1  varchar(256) DEFAULT NULL,
   app_name2  varchar(256) DEFAULT NULL,
   app_ip1  varchar(50) DEFAULT NULL,
   app_ip2  varchar(50) DEFAULT NULL,
   port1  int(11) DEFAULT NULL,
   port2  int(11) DEFAULT NULL,
   protocol1  int(11) DEFAULT NULL,
   protocol2  int(11) DEFAULT NULL,
   direction  varchar(45) DEFAULT NULL,
   isAdvance  tinyint(4) DEFAULT NULL,
   app1_isIPv6  tinyint(4) DEFAULT NULL,
   app2_isIPv6  tinyint(4) DEFAULT NULL,
   profile_source  varchar(7) DEFAULT NULL,
   profile_type  int(11) DEFAULT NULL,
   profile_types_array  varchar(85) DEFAULT NULL,
   status  varchar(45) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   app1_ports  varchar(512) DEFAULT NULL,
   app2_ports  varchar(512) DEFAULT NULL,
   adpl_app1_id  int(11) DEFAULT NULL,
   adpl_app2_id  int(11) DEFAULT NULL,
   app1_alias_name  varchar(256) DEFAULT NULL,
   app2_alias_name  varchar(256) DEFAULT NULL,
   created_by  VARCHAR(256) DEFAULT NULL,
   modified_by  VARCHAR(256) DEFAULT NULL,
  PRIMARY KEY ( policy_id )
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


  
DROP TABLE IF EXISTS  application_security_policy_tb;
CREATE TABLE  application_security_policy_tb  (
   policy_id  int(11) NOT NULL AUTO_INCREMENT,
   policy_name  varchar(75) DEFAULT NULL,
   action  int(11) DEFAULT NULL,
   subaction  int(11) DEFAULT NULL,
   cust_id1  int(11) DEFAULT NULL,
   dept_id1  int(11) DEFAULT NULL,
   cust_id2  int(11) DEFAULT NULL,
   dept_id2  int(11) DEFAULT NULL,
   app_name1  varchar(256) DEFAULT NULL,
   app_name2  varchar(256) DEFAULT NULL,
   app_ip1  varchar(50) DEFAULT NULL,
   app_ip2  varchar(50) DEFAULT NULL,
   port1  int(11) DEFAULT NULL,
   port2  int(11) DEFAULT NULL,
   protocol1  int(11) DEFAULT NULL,
   protocol2  int(11) DEFAULT NULL,
   direction  varchar(45) DEFAULT NULL,
   isAdvance  tinyint(4) DEFAULT NULL,
   status  varchar(45) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   app1_isIPv6  tinyint(4) DEFAULT NULL,
   app2_isIPv6  tinyint(4) DEFAULT NULL,
   app1_ports  varchar(512) DEFAULT NULL,
   app2_ports  varchar(512) DEFAULT NULL,
   adpl_app1_id  int(11) DEFAULT NULL,
   adpl_app2_id  int(11) DEFAULT NULL,
   app1_alias_name  varchar(256) DEFAULT NULL,
   app2_alias_name  varchar(256) DEFAULT NULL,
   created_by  VARCHAR(256) DEFAULT NULL,
   modified_by  VARCHAR(256) DEFAULT NULL,
  PRIMARY KEY ( policy_id )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


/*!40101 SET character_set_client = @saved_cs_client */;

-- create script user_role_based_ui_access_tb
DROP TABLE IF EXISTS user_role_based_ui_access_tb;
CREATE TABLE user_role_based_ui_access_tb (
uiAccessID INT NOT NULL AUTO_INCREMENT,
uiAction VARCHAR(255) NOT NULL,
accessRole VARCHAR(4096) NOT NULL,
created_on TIMESTAMP NULL,
modify_on TIMESTAMP NULL,
PRIMARY KEY (uiAccessID),
UNIQUE INDEX uiAction_UNIQUE (uiAction ASC));


DROP TABLE IF EXISTS scheduled_application_security_policy_tb;
CREATE TABLE  scheduled_application_security_policy_tb  (
   policy_id  int(11) NOT NULL,
   policy_name  varchar(75) DEFAULT NULL,
   action_id  int(11) DEFAULT NULL,
   subaction_id  int(11) DEFAULT NULL,
   source_cust_id  int(11) DEFAULT NULL,
   source_dept_id  int(11) DEFAULT NULL,
   dest_cust_id  int(11) DEFAULT NULL,
   dest_dept_id  int(11) DEFAULT NULL,
   source_port  int(11) DEFAULT NULL,
   source_protocol  int(11) DEFAULT NULL,
   dest_port  int(11) DEFAULT NULL,
   dest_protocol  int(11) DEFAULT NULL,
   source_app_adpl_id  int(11) DEFAULT NULL,
   dest_app_adpl_id  int(11) DEFAULT NULL,
   source_app_name  varchar(256) DEFAULT NULL,
   dest_app_name  varchar(256) DEFAULT NULL,
   source_app_ip  varchar(50) DEFAULT NULL,
   source_app_data_ip  varchar(50) DEFAULT NULL,
   source_app_management_ip  varchar(50) DEFAULT NULL,
   dest_app_ip  varchar(50) DEFAULT NULL,
   dest_app_data_ip  varchar(50) DEFAULT NULL,
   dest_app_management_ip  varchar(50) DEFAULT NULL,   
   pid  int(11) DEFAULT NULL,
   isAdvance TINYINT(4) NULL,
   policy_type  varchar(45) DEFAULT NULL,
   app1_isIPv6 TINYINT(4) NULL,
   app2_isIPv6 TINYINT(4) NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table scheduled_data_security_policy_tb
--

DROP TABLE IF EXISTS scheduled_data_security_policy_tb;
CREATE TABLE  scheduled_data_security_policy_tb  (
   policy_id  int(11) NOT NULL,
   policy_name  varchar(75) DEFAULT NULL,
   action  int(11) DEFAULT NULL,
   redaction  int(11) DEFAULT NULL,
   source_cust_id  int(11) DEFAULT NULL,
   source_dept_id  int(11) DEFAULT NULL,
   dest_cust_id  int(11) DEFAULT NULL,
   dest_dept_id  int(11) DEFAULT NULL,
   source_app_name  varchar(256) DEFAULT NULL,
   dest_app_name  varchar(256) DEFAULT NULL,
   source_app_ip  varchar(50) DEFAULT NULL,
   source_app_data_ip  varchar(50) DEFAULT NULL,
   source_app_management_ip  varchar(50) DEFAULT NULL,
   dest_app_ip  varchar(50) DEFAULT NULL,
   dest_app_data_ip  varchar(50) DEFAULT NULL,
   dest_app_management_ip  varchar(50) DEFAULT NULL,
   dest_port  int(11) DEFAULT NULL,
   dest_protocol  int(11) DEFAULT NULL,
   status  varchar(45) DEFAULT NULL,
   pid  int(11) DEFAULT NULL,
   profile_source  varchar(7) DEFAULT NULL,
   profile_type  int(11) DEFAULT NULL,
   profile_types_array  varchar(85) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   source_app_adpl_id  int(11) DEFAULT NULL,
   dest_app_adpl_id  int(11) DEFAULT NULL,
   policy_type  int(11) DEFAULT NULL,
   source_port  int(11) DEFAULT NULL,
   source_protocol  int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



DROP TABLE IF EXISTS application_licence_manager_tb;
CREATE TABLE application_licence_manager_tb (
  managementIP varchar(80) NOT NULL,
  applicationID int(11) NOT NULL,
  isSend tinyint(4) DEFAULT NULL,
  isRegister tinyint(4) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on varchar(45) DEFAULT NULL,
  PRIMARY KEY (managementIP,applicationID)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- service now config table
drop table if exists service_now_config;
CREATE TABLE service_now_config  (
   id  int(11) NOT NULL AUTO_INCREMENT,
   url  varchar(100) DEFAULT NULL,
   user_name  varchar(45) DEFAULT NULL,
   password  varchar(45) DEFAULT NULL,
   active_user  tinyint(4) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   confirm_password  varchar(45) DEFAULT NULL,
   instance_name  varchar(45) DEFAULT NULL,
   created_by  varchar(256) DEFAULT NULL,
   modify_by  varchar(256) DEFAULT NULL,
  PRIMARY KEY ( id )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- service now incident table
drop table if exists service_now_incident;
CREATE TABLE  service_now_incident  (
   id  int(11) NOT NULL AUTO_INCREMENT,
   short_description  varchar(256) DEFAULT NULL,
   description  varchar(1000) DEFAULT NULL,
   priority  int(11) DEFAULT NULL,
   category  varchar(256) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
   state  int(11) DEFAULT NULL,
   is_logged  tinyint(4) DEFAULT NULL,
   incident_type  int(11) DEFAULT NULL,
  PRIMARY KEY ( id )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


-- encrypt alog table
drop table if exists encrypt_algorithm_tb;
CREATE TABLE  encrypt_algorithm_tb  (
   encypt_key  varchar(512) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- LDAP Configuration table
DROP TABLE IF EXISTS ldap_configuration_tb;
CREATE TABLE ldap_configuration_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  ldapAddress varchar(255) DEFAULT NULL,
  ldapPort varchar(255) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- application_image_tb
DROP TABLE IF EXISTS application_image_tb;
CREATE TABLE application_image_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  imageName varchar(255) DEFAULT NULL,
  imagePath varchar(255) DEFAULT NULL,
  created_on datetime DEFAULT NULL,
  modify_on datetime DEFAULT NULL,
  PRIMARY KEY (id)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

 -- -------------------------------------------------------

DROP TABLE IF EXISTS customer_license_tb;
CREATE TABLE customer_license_tb (
  id int(11) NOT NULL,
  customerID int(45) DEFAULT NULL,
  customerKey varchar(150) NOT NULL,
  startedOn timestamp NOT NULL,
  expiredOn timestamp NOT NULL,
  licenseType varchar(45) DEFAULT NULL,
  expired tinyint(4) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  licenseKey varchar(255) DEFAULT NULL,
  licenseCount int(11) DEFAULT NULL,
  licenseVersion varchar(150) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- ------------------------------------------------------------------------------------

DROP TABLE IF EXISTS docker_info_tb ;
CREATE TABLE  docker_info_tb  (
   dockerDaemonIP  varchar(55) NOT NULL,
   containerIP  varchar(55) NOT NULL,
   portNumber int(11) NOT NULL,
   containerID  varchar(255) NOT NULL,
   apiCall  varchar(255) NOT NULL,
   isProtected  tinyint(4) NOT NULL,
   appId  int(11) NOT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
  PRIMARY KEY ( containerID )
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS notification_status_tb ;
CREATE TABLE  notification_status_tb  (
   statusID  bigint(20) NOT NULL AUTO_INCREMENT,
   notificationID  bigint(20) DEFAULT NULL,
   seenOn  timestamp NULL DEFAULT NULL,
   seenMsg  tinyint(4) DEFAULT NULL,
   userID  int(11) DEFAULT NULL,
   keepNotification  tinyint(4) DEFAULT NULL,
   notificationMsg  varchar(4096) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL,
  PRIMARY KEY ( statusID )
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- -------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS report_download_file_properties_tb ;
CREATE TABLE report_download_file_properties_tb  (
   fileID  INT NOT NULL AUTO_INCREMENT,
   fileName  VARCHAR(256) NULL,
   notificationStatusID  BIGINT NULL,
   fileDonlowURL  VARCHAR(512) NULL,
   fileDirPath  VARCHAR(512) NULL,
   created_on  TIMESTAMP NULL,
   modify_on  TIMESTAMP NULL,
   created_by varchar(256) DEFAULT NULL,
   modify_by varchar(256) DEFAULT NULL,
  PRIMARY KEY ( fileID ));
  
-- ------------------------------------------------------------------------------------------------
  DROP TABLE IF EXISTS permanent_app_info_tb ;
  CREATE TABLE  permanent_app_info_tb  (
   app_name  varchar(256) DEFAULT NULL,
   proces_name  varchar(4096) DEFAULT NULL,
   customer_id  int(11) DEFAULT NULL,
   department_id  int(11) DEFAULT NULL,
   server_ip  varchar(50) DEFAULT NULL,
   server_port  int(11) DEFAULT NULL,
   protocol  int(11) DEFAULT NULL,
   adpl_app_id  int(11) DEFAULT NULL,
   created_on  timestamp NULL DEFAULT NULL,
   modify_on  timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ------------------------------------------------------------------------------------------------
-- Application Group Tb
-- ------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS application_group_tb;
CREATE TABLE application_group_tb (
  appl_group_id int(11) NOT NULL AUTO_INCREMENT,
  appl_group_name varchar(45) DEFAULT NULL,
  PRIMARY KEY (appl_group_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ------------------------------------------------------------------------------------------------
-- Application Group Transaction Tb
-- ------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS application_group_transaction_tb;
CREATE TABLE application_group_transaction_tb (
  appl_group_id int(11) DEFAULT NULL,
  cust_id int(11) DEFAULT NULL,
  dept_id int(11) DEFAULT NULL,
  app_id int(11) DEFAULT NULL,
  adpl_app_id int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ------------------------------------------------------------------------------------------------
-- Docker Image Tb
-- ------------------------------------------------------------------------------------------------
CREATE TABLE docker_image_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  imageName varchar(255) DEFAULT NULL,
  imageId varchar(4096) DEFAULT NULL,
  sha varchar(4096) DEFAULT NULL,
  isExecutable tinyint(4) DEFAULT NULL,
  createdOn timestamp NULL DEFAULT NULL,
  modifyOn timestamp NULL DEFAULT NULL,
  hostIp varchar(45) DEFAULT NULL,
  hostPort int(11) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ------------------------------------------------------------------------------------------------
-- Mail Configuration Tb
-- ------------------------------------------------------------------------------------------------
CREATE TABLE mailconfig_tb (
  mail_id int(11) NOT NULL,
  event_type varchar(50) DEFAULT NULL,
  mail_content text,
  mail_subject varchar(255) DEFAULT NULL,
  PRIMARY KEY (mail_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE mail_transaction_tb (
  mail_id int(11) NOT NULL,
  mid int(11) NOT NULL AUTO_INCREMENT,
  mail_from varchar(255) DEFAULT NULL,
  mail_password varchar(255) DEFAULT NULL,
  mail_to text,
  mail_cc text,
  mail_subject varchar(255) DEFAULT NULL,
  cid int(11) DEFAULT NULL,
  did int(11) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  created_by varchar(45) DEFAULT NULL,
  modify_by varchar(45) DEFAULT NULL,
  isActive tinyint(4) DEFAULT NULL,
  PRIMARY KEY (mid,mail_id),
  KEY fk_mail_transaction_tb_1_idx (mail_id),
  CONSTRAINT fk_mail_transaction_tb_1 FOREIGN KEY (mail_id) REFERENCES mailconfig_tb (mail_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=latin1;

CREATE TABLE email_notification_user_tb (
  id int(11) NOT NULL AUTO_INCREMENT,
  email varchar(255) DEFAULT NULL,
  password varchar(60) DEFAULT NULL,
  created_on timestamp NULL DEFAULT NULL,
  modify_on timestamp NULL DEFAULT NULL,
  created_by varchar(45) DEFAULT NULL,
  modify_by varchar(45) DEFAULT NULL,
  host varchar(255) DEFAULT NULL,
  port int(11) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;

