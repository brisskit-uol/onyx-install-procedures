#!/bin/bash
#
# Default settings used by scripts within the bin directory
#
# Notes:
# (1) Onyx 1.8.1 does not sit well with JDK 1.7 (as at 9th May 2013)
#     Therefore we are running with a JDK 1.6.x
#     The issue seems to resolve around no-argument constructors, with Tomcat failing to deploy Onyx:
#     "SEVERE: Exception starting filter WicketFilter"
#     "Cannot construct org.obiba.onyx.engine.variable.export.ValueSetFilter as it does not have a no-args constructor"
# 
#-------------------------------------------------------------------

# Log file name:
export JOB_LOG_NAME=job.log

# Name of directory to hold archives of source, 
# demo data and others acquired from elsewhere
export ACQUISITIONS_DIRECTORY=acquisitions

# We need a user and password for wget to maven repo
export MVN_READONLY_USER=readonly
export MVN_READONLY_PASSWORD=readonly.....

# Download paths of installable artifacts... 

export JDK_DOWNLOAD_PATH=http://maven.brisskit.le.ac.uk/nexus/content/repositories/thirdparty/oracle/jdk/jdk/6u39-linux/jdk-6u39-linux-x64.bin
export ANT_DOWNLOAD_PATH=http://maven.brisskit.le.ac.uk/nexus/content/repositories/thirdparty/apache/ant/apache-ant/1.8.4/apache-ant-1.8.4-bin.zip
export TOMCAT_DOWNLOAD_PATH=http://maven.brisskit.le.ac.uk/nexus/content/repositories/thirdparty/apache/tomcat/apache-tomcat/6.0.35/apache-tomcat-6.0.35.zip
export ONYX_DOWNLOAD_PATH=http://maven.brisskit.le.ac.uk/nexus/content/repositories/thirdparty/onyx/brisskit-onyx-demo/1.8.1/brisskit-onyx-demo-1.8.1-apptlistfix.war
export ONYX_INTEGRATION_WS_DOWNLOAD_PATH=http://maven.brisskit.le.ac.uk/nexus/content/repositories/releases/org/brisskit/app/onyx/onyxWS/1.0-RC1/onyxWS-1.0-RC1.war
export ONYX_PROCEDURES_DOWNLOAD_PATH=http://maven.brisskit.le.ac.uk/nexus/content/repositories/releases/org/brisskit/app/onyx/onyx-admin-procedures/1.0-RC1-development/onyx-admin-procedures-1.0-RC1-development.zip

# Final install names for Onyx war and Onyx instegration service war files
# This is the simplest way of getting the url context to be,
# for example: bru2.brisskit.le.ac.uk/onyx
# A smoother technique would be to do servlet mapping in the web.xml file.
export ONYX_WAR=onyx.war
export ONYXWS_WAR=onyxWS.war

# Pdo audit directory used by the integration web service
export PDO_AUDIT_DIRECTORY=$ONYX_INSTALL_DIRECTORY/pdo-audit

# JDK and ANT expanded directory names (and version)...
export JDK=jdk1.6.0_39
export ANT=apache-ant-1.8.4
export TOMCAT=apache-tomcat-6.0.35

# Custom space for the install workspace (if required)
# If not defined, defaults to ONYX_INSTALL_PROCS_HOME/work
#export ONYX_INSTALL_WORKSPACE=?

#---------------------------------------------------------------------------------
# Java, Ant and Tomcat home directories...
#---------------------------------------------------------------------------------
export ANT_HOME=$ONYX_INSTALL_DIRECTORY/ant
export JAVA_HOME=$ONYX_INSTALL_DIRECTORY/jdk
export TOMCAT_HOME=$ONYX_INSTALL_DIRECTORY/tomcat
