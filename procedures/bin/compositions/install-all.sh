#!/bin/bash
#-----------------------------------------------------------------------------------------------
# Installs the whole of Onyx and its prerequisites:
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
#   The job-name is used to create a work directory for the overall workflow; eg:
#   ONYX_INSTALL_PROCS_HOME/job-name
#   This work directory must already exist.
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

$ONYX_INSTALL_PROCS_HOME/bin/installs/1a-prerequisites.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/1b-acquisitions.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/2-install-ant.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/3-install-jdk.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/4-install-tomcat.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/5-install-onyx.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/6-install-onyx-iws.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/7-install-onyx-procedures.sh $JOB_NAME
$ONYX_INSTALL_PROCS_HOME/bin/installs/8-install-perl-scripts.sh $JOB_NAME

