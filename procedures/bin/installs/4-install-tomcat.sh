#!/bin/bash
#-----------------------------------------------------------------------------------------------
# Installs and tailors Tomcat:
#   (i)   Installs tomcat
#   (ii)  Sets JVM settings
#   (iii) Configures ports
#
# Mandatory: the ONYX_INSTALL_PROCS_HOME environment variable to be set.
# Optional : the ONYX_INSTALL_WORKSPACE environment variable.
# The latter is an optional full path to a workspace area. If not set, defaults to a workspace
# within the install home.
#
# Pre-reqs:
#   1-acquisitions.sh has been run at some point to acquire the tomcat zip file
#   Tomcat config settings reviewed (see config/jboss directory)
#
# USAGE: {script-file-name}.sh job-name
# Where: 
#   job-name is a suitable tag to group all jobs associated with the overall workflow
# Notes:
#   The job-name is used to create a work directory for the overall workflow; eg:
#   ONYX_INSTALL_PROCS_HOME/job-name
#   This work directory must already exist.
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
echo "About to install Tomcat..."
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

TOMCAT_INSTALL_DIRECTORY_NAME=$( basename $TOMCAT_DOWNLOAD_PATH .zip )
#
# Unzip tomcat file...
print_message "" $LOG_FILE
print_message "Unzipping Tomcat..." $LOG_FILE
unzip -o $WORK_DIR/$ACQUISITIONS_DIRECTORY/$( basename $TOMCAT_DOWNLOAD_PATH .zip ) -d $ONYX_INSTALL_DIRECTORY >>$LOG_FILE 2>>$LOG_FILE
exit_if_bad $? "Failed to unzip Tomcat file to $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME" $LOG_FILE

#
# Copy tomcat catalina.sh to bin directory.
# (stopgap until we can get tomcat to run as a service 
print_message "" $LOG_FILE
print_message "Copying catalina.sh file" $LOG_FILE
cp $ONYX_INSTALL_PROCS_HOME/config/tomcat/catalina.sh $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/bin
exit_if_bad $? "Could not copy catalina.sh" $LOG_FILE

#
# Copy tomcat service script to init.d 
# Enable execution on the script
# Add appropriate run levels
#print_message "" $LOG_FILE
#print_message "Copying $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/conf/tomcat" $LOG_FILE
#sudo cp $ONYX_INSTALL_PROCS_HOME/config/tomcat/tomcat /etc/init.d
#exit_if_bad $? "Could not copy $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/conf/tomcat" $LOG_FILE
#sudo chmod u+x,g+x /etc/init.d/tomcat

#
# Enable the tomcat run scripts...
chmod u+x,g+x $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME/bin/*

#
# Create a symbolic link to tomcat...
ln -s $ONYX_INSTALL_DIRECTORY/$TOMCAT_INSTALL_DIRECTORY_NAME $ONYX_INSTALL_DIRECTORY/tomcat


#=========================================================================
# If we got this far, we must be successful...
#=========================================================================
print_message "Tomcat installation completed." $LOG_FILE
#print_message "PLEASE NOTE HOWEVER: You need to issue the following command to install Tomcat as a service:" $LOG_FILE
#sleep 2
#print_message "update-rc.d tomcat defaults"
sleep 2
print_footer $( basename $0 ) $JOB_NAME $LOG_FILE