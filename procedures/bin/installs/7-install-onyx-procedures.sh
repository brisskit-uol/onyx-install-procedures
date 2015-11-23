#!/bin/bash
#-----------------------------------------------------------------------------------------------
# Installs Onyx admin procedures (plus cronjob for periodic upload of exports to i2b2):
#
# Mandatory: the ONYX_INSTALL_PROCS_HOME environment variable to be set.
# Optional : the ONYX_INSTALL_WORKSPACE environment variable.
# The latter is an optional full path to a workspace area. If not set, defaults to a workspace
# within the install home.
#
# Pre-reqs:
#   1-acquisitions.sh has been run at some point to acquire the install artifacts.
#
# USAGE: {script-file-name}.sh job-name
# Where: 
#   job-name is a suitable tag to group all jobs associated with the overall workflow
# Notes:
#   The job-name is used to focus on a work directory for the overall workflow; eg:
#   ONYX_INSTALL_PROCS_HOME/job-name
#   This work directory must already exist.
#
#
# Author: Jeff Lusted (jl99@leicester.ac.uk)
#-----------------------------------------------------------------------------------------------
source $ONYX_INSTALL_PROCS_HOME/bin/common/setenv.sh
source $ONYX_INSTALL_PROCS_HOME/bin/common/functions.sh 

#=======================================================================
# First, some basic checks...
#=======================================================================
#
# Check on the usage...
if [ ! $# -eq 1 ]
then
	echo "Error! Incorrect number of arguments."
	echo ""
	print_usage
	exit 1
fi

#
# Retrieve job-name into its variable...
JOB_NAME=$1

#
# It is possible to set your own procedures workspace.
# But if it doesn't exist, we create one for you within the procedures home...
if [ -z $ONYX_INSTALL_WORKSPACE ]
then
	ONYX_INSTALL_WORKSPACE=$ONYX_INSTALL_PROCS_HOME/work
fi

#
# Establish a log file for the job...
WORK_DIR=$ONYX_INSTALL_WORKSPACE/$JOB_NAME
LOG_FILE=$WORK_DIR/$JOB_LOG_NAME

#
# We must already have a work directory for this job step
# (otherwise no acquisitions)...
if [ ! -d $WORK_DIR ]
then
	echo "Error! Could not find work directory."
	echo "Please check acquisitions step has been run and that job name \"$JOB_NAME\" is correct."
	exit 1
fi

#===========================================================================
# Print a banner for this step of the job.
#===========================================================================
print_banner $( basename $0 ) $JOB_NAME $LOG_FILE 

#===========================================================================
# The real work is about to start.
# Give the user a warning...
#=========================================================================== 
echo "About to install Onyx procedures"
echo ""
echo "   Please note detailed log messages are written to $LOG_FILE"
echo "   If you want to see this during execution, try: tail -f $LOG_FILE"
echo ""

#
# Create the standard install directory if it does not already exist...
if [ ! -d $ONYX_INSTALL_DIRECTORY ]
then
    mkdir $ONYX_INSTALL_DIRECTORY
    exit_if_bad $? "Failed to create install directory: $ONYX_INSTALL_DIRECTORY"
fi

#
# Unzip Onyx procedures file...
print_message "" $LOG_FILE
print_message "Unzipping  Onyx procedures file..." $LOG_FILE
unzip -o $WORK_DIR/$ACQUISITIONS_DIRECTORY/$( basename $ONYX_PROCEDURES_DOWNLOAD_PATH ) -d $ONYX_INSTALL_DIRECTORY >>$LOG_FILE 2>>$LOG_FILE
exit_if_bad $? "Failed to unzip Onyx procedures to $ONYX_INSTALL_DIRECTORY" $LOG_FILE

#
# Make them a little more restrictive...
chmod -R o-w,o+x $ONYX_INSTALL_DIRECTORY/onyx-admin-procedures*

#
# A couple of symbolic links makes things a little easier...
ln -s ${ONYX_INSTALL_DIRECTORY}/onyx*admin-procedures* ${ONYX_INSTALL_DIRECTORY}/onyx-admin-procedures
ln -s ${ONYX_INSTALL_DIRECTORY}/onyx*install-procedures* ${ONYX_INSTALL_DIRECTORY}/onyx-install-procedures

#
# Set up the cronjob for periodic uploads of export data to i2b2...
crontab ${ONYX_INSTALL_PROCS_HOME}/config/cron-params
exit_if_bad $? "Failed to set up crontab." $LOG_FILE

#=========================================================================
# If we got this far, we must be successful...
#=========================================================================
print_message "Onyx procedures installation completed." $LOG_FILE
print_footer $( basename $0 ) $JOB_NAME $LOG_FILE