GUID=$1

oc project $GUID-nexus

oc new-app sonatype/nexus3:latest
