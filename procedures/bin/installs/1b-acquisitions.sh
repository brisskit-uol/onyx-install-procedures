#!/bin/bash
#-----------------------------------------------------------------------------------------------
# Acquires install artifacts.
#
# Mandatory: the ONYX_INSTALL_PROCS_HOME environment variable to be set.
# Optional : the ONYX_INSTALL_WORKSPACE environment variable.
# The latter is an optional full path to a workspace area. If not set, defaults to a workspace
# within the install home.
#
# USAGE: {script-file-name}.sh job-name
# Where: 
#   job-name is a suitable tag to group all jobs associated with the overall workflow
# Notes:
#   The job-name is used to create a working directory for the overall workflow; eg:
#   ONYX_INSTALL_PROCS_HOME/job-name
#   This working directory is created if it does not exist.
#
# Further tailoring can be achieved via the defaults.sh script.
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
LOG_FILE=$ONYX_INSTALL_WORKSPACE/$JOB_NAME/$JOB_LOG_NAME

#
# If required, create a working directory for this job step.
ACQUISITIONS=$ONYX_INSTALL_WORKSPACE/$JOB_NAME/$ACQUISITIONS_DIRECTORY
if [ ! -d $ACQUISITIONS ]
then
	mkdir -p $ACQUISITIONS
	exit_if_bad $? "Failed to create working directory $ACQUISITIONS"
fi

#===========================================================================
# Print a banner for this step of the job.
#===========================================================================
print_banner $( basename $0 ) $JOB_NAME $LOG_FILE 

#===========================================================================
# The real work is about to start.
# Give the user a warning...
#=========================================================================== 
print_message "About to acquire prerequisite files for Onyx install" $LOG_FILE

print_message "" $LOG_FILE
print_message "Acquiring Java JDK..." $LOG_FILE
wget --user=$MVN_READONLY_USER \
     --password=$MVN_READONLY_PASSWORD \
     -O $ACQUISITIONS/$( basename $JDK_DOWNLOAD_PATH ) $JDK_DOWNLOAD_PATH
exit_if_bad $? "Failed to acquire Java JDK." $LOG_FILE
print_message "Success! Acquired Java JDK." $LOG_FILE

print_message "" $LOG_FILE
print_message "Acquiring Ant..." $LOG_FILE
wget --user=$MVN_READONLY_USER \
     --password=$MVN_READONLY_PASSWORD \
     -O $ACQUISITIONS/$( basename $ANT_DOWNLOAD_PATH ) $ANT_DOWNLOAD_PATH
exit_if_bad $? "Failed to acquire Ant." $LOG_FILE
print_message "Success! Acquired Ant." $LOG_FILE

print_message "" $LOG_FILE
print_message "Acquiring Tomcat..." $LOG_FILE
wget --user=$MVN_READONLY_USER \
     --password=$MVN_READONLY_PASSWORD \
     -O $ACQUISITIONS/$( basename $TOMCAT_DOWNLOAD_PATH ) $TOMCAT_DOWNLOAD_PATH
exit_if_bad $? "Failed to acquire Tomcat." $LOG_FILE
print_message "Success! Acquired Tomcat." $LOG_FILE

print_message "" $LOG_FILE
print_message "Acquiring Onyx..." $LOG_FILE
wget --user=$MVN_READONLY_USER \
     --password=$MVN_READONLY_PASSWORD \
     -O $ACQUISITIONS/$( basename $ONYX_DOWNLOAD_PATH ) $ONYX_DOWNLOAD_PATH
exit_if_bad $? "Failed to acquire Onyx." $LOG_FILE
print_message "Success! Acquired Onyx." $LOG_FILE

print_message "" $LOG_FILE
print_message "Acquiring Onyx integration web service..." $LOG_FILE
wget --user=$MVN_READONLY_USER \
     --password=$MVN_READONLY_PASSWORD \
     -O $ACQUISITIONS/$( basename $ONYX_INTEGRATION_WS_DOWNLOAD_PATH ) $ONYX_INTEGRATION_WS_DOWNLOAD_PATH
exit_if_bad $? "Failed to acquire Onyx integration web service." $LOG_FILE
print_message "Success! Acquired Onyx integration web service." $LOG_FILE

print_message "" $LOG_FILE
print_message "Acquiring Onyx procedures..." $LOG_FILE
wget --user=$MVN_READONLY_USER \
     --password=$MVN_READONLY_PASSWORD \
     -O $ACQUISITIONS/$( basename $ONYX_PROCEDURES_DOWNLOAD_PATH ) $ONYX_PROCEDURES_DOWNLOAD_PATH
exit_if_bad $? "Failed to acquire Onyx procedures." $LOG_FILE
print_message "Success! Acquired Onyx procedures." $LOG_FILE

#=========================================================================
# If we got this far, we must be successful...
#=========================================================================
print_footer $( basename $0 ) $JOB_NAME $LOG_FILE