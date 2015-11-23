#!/bin/bash
#
# Basic environment variables for Onyx
#
#-------------------------------------------------------------------
if [ -z $ONYX_INSTALL_DEFAULTS_DEFINED ]
then
	export ONYX_INSTALL_DEFAULTS_DEFINED=true	
	source $ONYX_INSTALL_PROCS_HOME/config/defaults.sh	
fi


