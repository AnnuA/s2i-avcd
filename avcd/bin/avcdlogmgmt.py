#!/usr/bin/python
""" Tool to manage/replicate Logfiles stored in local machines """

import sys
import os
import argparse
import time
import logging
import getpass
from subprocess import Popen, PIPE, STDOUT
import smtplib
from email.mime.text import MIMEText

# global settings
DEFAULT_WAIT = 10 # check every N min., usually only in daemon mode
LOGFILE = "/tmp/avocado-logmgmt.log" # system log stored in OS's log area
DEFAULT_MIN = 40 # default is minimum 40% free space
AVCDADMIN = getpass.getuser() # or use fake ID "avocado-admin"/getpass.getuser() for current user
LOGEXT = "*.log"
DEFAULT_EXPIRATION = 10 # files expire after 10 min.

class AvocadoLog(object):
    """ object for each Avocado Logfiles area """
    def __init__(self, logdir, admin=None):
        """ init the object """
        self.directory = logdir
        self.daemon_mode = False
        self.admin = admin
        self.minfree = DEFAULT_MIN
        self.forceclean = False
        self.sshkey = None
        self.clean = False # default behavior to just notification
        self.filelist = []
        self.expiration_time = DEFAULT_EXPIRATION * 60 # 6000 sec = 10 min

    def set_minfreespace(self, minfree):
        """ set the min freespace if not using default """
        self.minfree = minfree

    def enable_clean(self):
        """ force clean allowed """
        self.clean = True

    def disable_clean(self):
        """ disallow clean """
        self.clean = False

    def set_daemon_mode(self, mode):
        """ set the daemon mode true/false """
        self.daemon_mode = mode

    def run_cleanup(self, filename=None):
        """ do the actual cleanup """
        if filename is None:
            # clean everything in the directory
            cmd = "rm -f " + self.directory + "/" + LOGEXT
            logging.info("Run: %s", cmd)
        else:
            # only clean the particular file
            cmd = "rm -f " + filename
            logging.info("Run: %s", cmd)
        result = run_cmd(cmd)
        logging.info("Output:\n%s", str(result))
        return result

    def set_sshkey(self, sshkey):
        """ setup to use SSH key for scp """
        self.sshkey = sshkey

    def replicate(self):
        """ use scp -r to replicate logs """
        print ("TBD")

    def set_expiration_time(self, exptime):
        """ setup the expiraiton time (in sec) """
        self.expiration_time = exptime

    def get_current_cutoff_time(self):
        """ get current time and return in epoch """
        current_time = time.time()
        current_epoch = int(current_time)
        logging.info("Current time in epoch: %s", str(current_epoch))
        cutoff_epoch = int(current_time - self.expiration_time)
        logging.info("Cut-off time in epoch: %s", str(cutoff_epoch))
        if self.daemon_mode is False:
            print ("Current epoch: " + str(current_epoch))
            print ("Cutoff epoch: " + str(cutoff_epoch))
        return cutoff_epoch

    def scan_dir(self):
        """ scan the dir and return timestamp of files inside """
        ftimestamp = {}
        for root, dirs, files in os.walk(self.directory):
            for thefile in files:
                filename = root + '/' + thefile
                mtime = os.path.getmtime(filename)
                ftimestamp[filename] = mtime
        return ftimestamp

    def clean_expired_files(self):
        """ scan dir and indicate what files are to be expired """
        # says, when is cut off time to delete file, 10 min? or earlier
        ftimestamp = self.scan_dir()
        cutoff_time = self.get_current_cutoff_time()
        for filename in sorted(ftimestamp):
            modtime = ftimestamp[filename]
            if modtime <= cutoff_time:
                logging.info("File: %s - %s - expired", str(modtime), filename)
                cmd = str(modtime) + ' ' + filename + " - need to delete"
                if self.clean is True:
                    logging.info("Removing file: %s", filename)
                    cmd = cmd + "\nRemoving file: " + filename + "\n"
                    cmd = cmd + "\n".join(self.run_cleanup(filename))
            else:
                logging.info("File: %s - %s", str(modtime), filename)
                cmd = str(modtime) + ' ' + filename
            if self.daemon_mode is False:
                print (cmd)
        if self.daemon_mode is False:
            print ("Cutoff time: " + str(cutoff_time))
        logging.info("Cutoff time in epoch: %s", str(cutoff_time))

    def health_check(self):
        """ check for health """
        health = directory_healthy(self.directory, self.minfree)
        # if healthy, do nothing
        if health is False:
            # something wrong....
            msg = "Running out of space in " + self.directory
            subject = "Alert: Low in disk space"
            # want to cleanup?
            logging.info("Scan the directory for expired files")
            msg = msg + "\nScan the directory for expired files"
            # selectively clean files based on mod time
            self.clean_expired_files()

            ### old codes for ref. uses
            # this next 2 lines will remove all .log files
            # if self.clean is True:
            #     self.run_cleanup()

            # generate a notification to admin
            if self.admin is not None:
                send_notification(AVCDADMIN, self.admin, subject, msg)

# utility functions
def send_notification(sender, recipient, subj, msg):
    """ send notification with customized subj and msg"""
    # need to know who will delivery the mail
    if 'SMTPSERVER' in os.environ:
        smtpserver = os.environ['SMTPSERVER']
    else:
        smtpserver = 'localhost'
    server = smtplib.SMTP(smtpserver)
    server.set_debuglevel(0)
    logging.info("Sending Mail notification")
    emailmsg = MIMEText(msg)
    emailmsg['Subject'] = subj
    server.sendmail(sender, recipient, emailmsg.as_string())
    server.quit()

def run_cmd(cmds):
    """ execute command(s) and return output """
    logging.info("Running cmds: %s", str(cmds))
    process = Popen(cmds, stdout=PIPE, stderr=STDOUT, shell=True)
    output = []
    with process.stdout:
        for line in iter(process.stdout.readline, b''):
            logging.info("output: %s", line.strip())
            output.append(line)
    return output

def get_usedspace(logdir):
    """ Determine how much free space left (in %) """
    outline = run_cmd(["df -h " + logdir])
    outs = outline[1].split()
    # return just numberic part
    return outs[4][:-1]

def directory_healthy(logdir, minfree):
    """ Check the directory disk usage """
    usedspace = get_usedspace(logdir)
    maxusage = 100 - int(minfree)
    if int(usedspace) > maxusage:
        logging.info("Warning Freespace is under the preset level at %s percent", minfree)
        logging.info("Currently used percentage: %s", usedspace)
        return False
    # nothing wrong
    return True

def main():
    """ main func """
    # check for command line argument
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--daemon", action='store_true', help="Run as daemon/service")
    parser.add_argument("-e", "--expiration", help="Expiration after N minutes")
    parser.add_argument("-m", "--min_freespace", help="Min. free space in percentage")
    parser.add_argument("-w", "--waitperiod", help="Wait Period (min.) to run health check")
    parser.add_argument("-d", "--directory", help="Directory to be monitored")
    parser.add_argument("-c", "--clean", action='store_true',
                        help="Cleanup when system hits the thershold. Default: notification only")
    parser.add_argument("-a", "--admin", help="Email address to notify Admin")
#    parser.add_argument("-r", "--replicate_target",
#                        help="Replicate logs to remote server path <host:/path>")
#    parser.add_argument("-k", "--keyfile", help="SSH privatekey for replication use")
    args = parser.parse_args()

    # start the log as syslog
    logging.basicConfig(filename=LOGFILE, filemode="a",
                        level=logging.DEBUG,
                        format='%(asctime)s %(message)s')
    logging.info("&&&& Running Avocado Log Management Utility")
    logging.info("\n")

    mylogdir = AvocadoLog(args.directory, args.admin)

    if args.expiration is not None:
        expiration_time = 60 * int(args.expiration)
        mylogdir.set_expiration_time(expiration_time)
        logging.info("Set new expiration time to %s seconds", str(expiration_time))

    if args.daemon:
        mylogdir.set_daemon_mode(args.daemon)

    if args.waitperiod:
        waittime = int(args.waitperiod) * 60
    else:
        waittime = DEFAULT_WAIT * 60

    if args.clean is True:
        mylogdir.enable_clean()

    if args.min_freespace:
        mylogdir.set_minfreespace(args.min_freespace)

    # main loop
    while True:
        #        directory_healthy(args.directory, args.min_freespace)
        mylogdir.health_check()
        if args.daemon is False:
            print ("Complete one round of checking.")
            break
        time.sleep(waittime)

# entry point
if __name__ == '__main__':
    main()

