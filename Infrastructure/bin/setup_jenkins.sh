#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi -n $GUID-jenkins

oc new-build  -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n f9ff-jenkins

#Setting up jenkins pipelines on Openshift 
echo "Creating and configuring Build Configs for 3 pipelines"
oc new-build ${REPO} --name="mlbparks-pipeline" --strategy=pipeline --context-dir="MLBParks" -n $GUID-jenkins
oc set env bc/mlbparks-pipeline CLUSTER=${CLUSTER} GUID=${GUID} -n $GUID-jenkins

oc new-build ${REPO} --name="nationalparks-pipeline" --strategy=pipeline --context-dir="Nationalparks" -n $GUID-jenkins
oc set env bc/nationalparks-pipeline CLUSTER=${CLUSTER} GUID=${GUID} -n $GUID-jenkins

oc new-build ${REPO} --name="parksmap-pipeline" --strategy=pipeline --context-dir="ParksMap" -n $GUID-jenkins
oc set env bc/parksmap-pipeline CLUSTER=${CLUSTER} GUID=${GUID} -n $GUID-jenkins

#Delete the empty build created by default
sleep 10
oc delete build/mlbparks-pipeline-1 -n $GUID-jenkins
oc delete build/nationalparks-pipeline-1 -n $GUID-jenkins
oc delete build/parksmap-pipeline-1 -n $GUID-jenkins
