#!/bin/bash
#--------------------------------------------------------------------------------------------------------------
# Source this at the start of any shell session.
# (There should be no need to do this as sudo or root)
# Use "source ./set.sh" or ". ./set.sh" at the command line or within a composition script.
# Remember, if you execute any script as sudo, then you must inherit the environment variables; eg:
# > sudo -E ./1-acquisitions.sh job-20130214
#
# NOTES.
# (1) Edit setting for ONYX_INSTALL_DIRECTORY.
# (2) Edit setting for INSTALL_PACKAGE_NAME in order to pick up the correct version of the install procedures.
# (3) Edit setting for ADMIN_PACKAGE_NAME in order to pick up the correct version of the admin procedures.
#--------------------------------------------------------------------------------------------------------------
export ONYX_INSTALL_DIRECTORY=/var/local/brisskit/onyx
INSTALL_PACKAGE_NAME=onyx-1.8.1-install-procedures-1.0-RC1-development
ADMIN_PACKAGE_NAME=onyx-admin-procedures-1.0-RC1-development
export ONYX_INSTALL_PROCS_HOME=${ONYX_INSTALL_DIRECTORY}/${INSTALL_PACKAGE_NAME}
export ONYX_ADMIN_PROCS_HOME=${ONYX_INSTALL_DIRECTORY}/${ADMIN_PACKAGE_NAME}
