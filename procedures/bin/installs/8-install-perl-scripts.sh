#!/bin/bash
#-----------------------------------------------------------------------------------------------
# Installs Perl, the perl scripts needed for ontology formation, and their prerequisites:
#
# Mandatory: the ONYX_INSTALL_PROCS_HOME environment variable to be set.
# Optional : the ONYX_INSTALL_WORKSPACE environment variable.
# The latter is an optional full path to a workspace area. If not set, defaults to a workspace
# within the install home.
#
# NOTE: NEEDS TO BE EXECUTED AS SUDO ...
#       sudo -E ./8-install-perl-scripts.sh job-name
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

echo "*************************************************"
echo "About to install some library prerequisites"
echo "*************************************************"
sleep 5
# apt-get install perl
apt-get install automake autoconf libtool
apt-get install xsltproc
apt-get install libexpat-dev
apt-get install libxml-sax-expat-perl

cp $ONYX_INSTALL_PROCS_HOME/perl/Config.pm /etc/perl/CPAN

#
# This is required for the initial Makefile.PL steps...
echo "**************************************"
echo "Installing inc::Module::Install"
echo "**************************************"
sleep 5
perl -MCPAN -e 'install "inc::Module::Install"'

#
# This is required to build pre-requisites
echo "**************************************"
echo "Installing Test::Builder"
echo "**************************************"
sleep 5
perl -MCPAN -e 'install "Test::Builder"'

echo "**************************************"
echo "About to install dagBuilder..."
echo "**************************************"
sleep 5
cd $ONYX_INSTALL_PROCS_HOME/perl/dagBuilder
perl Makefile.PL
make
make test
make install

echo "*****************************************"
echo "About to install onyxOntologyExtract..."
echo "*****************************************"
sleep 5
cd $ONYX_INSTALL_PROCS_HOME/perl/onyxOntologyExtract
perl Makefile.PL
make
make test
make install

#
# copy the scripts into the Onyx administration scripts...
ONYX_PROCEDURES_DIRECTORY_NAME=$( basename `ls -d $ONYX_INSTALL_DIRECTORY/onyx-admin-procedures*` )

cp $ONYX_INSTALL_PROCS_HOME/perl/onyxOntologyExtract/onyxOntologyExtract.pl \
   $ONYX_INSTALL_DIRECTORY/$ONYX_PROCEDURES_DIRECTORY_NAME/bin/perl

cp $ONYX_INSTALL_PROCS_HOME/perl/dagBuilder/BrisskitDAGbuilder.pl \
   $ONYX_INSTALL_DIRECTORY/$ONYX_PROCEDURES_DIRECTORY_NAME/bin/perl

# And make them executable...
chmod u+x,g+x $ONYX_INSTALL_DIRECTORY/$ONYX_PROCEDURES_DIRECTORY_NAME/bin/perl/*

#=========================================================================
# If we got this far, we must be successful...
#=========================================================================
print_message "Installation of perl scripts completed." $LOG_FILE
print_footer $( basename $0 ) $JOB_NAME $LOG_FILE









