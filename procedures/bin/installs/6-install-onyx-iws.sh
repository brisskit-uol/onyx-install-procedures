#!/bin/bash
#-----------------------------------------------------------------------------------------------
# Installs the 'Onyx' WS that acts as an interface between CiviCRM and Onyx.:
#
# Mandatory: the ONYX_INSTALL_PROCS_HOME environment variable to be set.
# Optional : the ONYX_INSTALL_WORKSPACE environment variable.
# The latter is an optional full path to a workspace area. If not set, defaults to a workspace
# within the install home.
#
# Pre-reqs:
#   1-acquisitions.sh has been run at some point to acquire the install artifacts.
#   2-install-jdk.sh has been run to install the Java sdk.
#   3-install-mysql.sh has been run to install MySql database.
#   4-install-tomcat.sh has been run to install the Tomcat web server.
#
# USAGE: {script-file-name}.sh job-name
# Where: 
#   job-name is a suitable tag to group all jobs associated with the overall workflow
# Notes:
#   The job-name is used to create a work directory for the overall workflow; eg:
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
echo "About to install the 'Onyx' web service within the Tomcat web server..."
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
# Create the PDO audit directory if it does not already exist...
if [ ! -d $PDO_AUDIT_DIRECTORY ]
then
    mkdir $PDO_AUDIT_DIRECTORY
    exit_if_bad $? "Failed to create PDO audit directory: $PDO_AUDIT_DIRECTORY"
fi

TOMCAT_INSTALL_DIRECTORY_NAME=$( basename $TOMCAT_DOWNLOAD_PATH .zip )
#
# Create temp directory if required...
# (clean it down if it exists)
if [ ! -d $WORK_DIR/temp ]
then
    mkdir $WORK_DIR/temp
    exit_if_bad $? "Failed to create working directory: $WORK_DIR/temp"
else
    rm -Rf $WORK_DIR/temp/*
fi

#
# Stopping tomcat...
print_message "" $LOG_FILE
$ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/bin/shutdown.sh >>/dev/null 2>>/dev/null
sleep 60

#
# Remove old attempts if they exist...
rm $WORK_DIR/$( basename $ONYX_DOWNLOAD_PATH ) >>/dev/null 2>>/dev/null
rm $WORK_DIR/$( basename $ONYX_INTEGRATION_WS_DOWNLOAD_PATH ) >>/dev/null 2>>/dev/null

#
# Unzip onyxWS war file into temp directory...
print_message "" $LOG_FILE
print_message "Unzipping  onyxWS war file into temp directory..." $LOG_FILE
unzip -o $WORK_DIR/$ACQUISITIONS_DIRECTORY/$( basename $ONYX_INTEGRATION_WS_DOWNLOAD_PATH ) -d $WORK_DIR/temp >>$LOG_FILE 2>>$LOG_FILE
exit_if_bad $? "Failed to unzip onyxWS war file to $WORK_DIR/temp" $LOG_FILE

#
# Overwrite config files...
print_message "" $LOG_FILE
print_message "Overwriting onyxWS config files in expanded war" $LOG_FILE
cp $ONYX_INSTALL_PROCS_HOME/config/onyxWS/* $WORK_DIR/temp/WEB-INF
exit_if_bad $? "Could not overwrite config files in $WORK_DIR/temp/WEBINF" $LOG_FILE

#
# Rezip the war file...
print_message "" $LOG_FILE
print_message "Rezipping the war file from temp directory..." $LOG_FILE
cd $WORK_DIR/temp
zip -r $WORK_DIR/$( basename $ONYX_INTEGRATION_WS_DOWNLOAD_PATH ) * >>$LOG_FILE 2>>$LOG_FILE
exit_if_bad $? "Failed to zip temp files back into an Onyx war file." $LOG_FILE
#rm -Rf *
cd $ONYX_INSTALL_PROCS_HOME/bin/installs

#
# Copy the war file into tomcat...
print_message "" $LOG_FILE
print_message "Deploying into tomcat..." $LOG_FILE
TOMCAT_INSTALL_DIRECTORY_NAME=$( basename $TOMCAT_DOWNLOAD_PATH .zip )
cp $WORK_DIR/$( basename $ONYX_INTEGRATION_WS_DOWNLOAD_PATH ) $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/webapps/$ONYXWS_WAR
exit_if_bad $? "Could not copy onyxWS war into  $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/webapps" $LOG_FILE

#
# Start tomcat...
print_message "" $LOG_FILE
#service start tomcat
cd $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME
./bin/startup.sh
cd $ONYX_INSTALL_PROCS_HOME/bin/installs
sleep 120

#=========================================================================
# If we got this far, we must be successful...
#=========================================================================
print_message "Onyx WS installation completed." $LOG_FILE
print_footer $( basename $0 ) $JOB_NAME $LOG_FILE