#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

oc project $GUID-parks-dev

oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-parks-dev

echo 'kind: StatefulSet
apiVersion: apps/v1
metadata:
  name: "mongodb"
spec:
  serviceName: "mongodb-internal"
  replicas: 1
  selector:
    matchLabels:
      name: mongodb
  template:
    metadata:
      labels:
        name: "mongodb"
    spec:
      containers:
        - name: mongo-container
          image: "registry.access.redhat.com/rhscl/mongodb-34-rhel7:latest"
          ports:
            - containerPort: 27017
          args:
            - "run-mongod-replication"
          volumeMounts:
            - name: mongo-data
              mountPath: "/var/lib/mongodb/data"
          env:
            - name: MONGODB_DATABASE
              value: "mongodb"
            - name: MONGODB_USER
              value: "mongodb_user"
            - name: MONGODB_PASSWORD
              value: "mongodb_password"
            - name: MONGODB_ADMIN_PASSWORD
              value: "mongodb_admin_password"
            - name: MONGODB_REPLICA_NAME
              value: "rs0"
            - name: MONGODB_KEYFILE_VALUE
              value: "12345678901234567890"
            - name: MONGODB_SERVICE_NAME
              value: "mongodb-internal"
          readinessProbe:
            exec:
              command:
                - stat
                - /tmp/initialized
  volumeClaimTemplates:
    - metadata:
        name: mongo-data
        labels:
          name: "mongodb"
      spec:
        accessModes: [ ReadWriteOnce ]
        resources:
          requests:
            storage: "4Gi"' | oc create -f -

oc new-build --binary=true --name=mlbparks jboss-eap70-openshift:1.7 -n $GUID-parks-dev
oc new-build --binary=true --name=nationalparks redhat-openjdk18-openshift:1.2 -n $GUID-parks-dev
oc new-build --binary=true --name=parksmap redhat-openjdk18-openshift:1.2 -n $GUID-parks-dev

oc new-app $GUID-parks-dev/mlbparks:0.0-0 --allow-missing-imagestream-tags=true --name=mlbparks -l type=parksmap-backend --allow-missing-imagestream-tags=true -n $GUID-parks-dev
oc new-app $GUID-parks-dev/nationalparks:0.0-0 --allow-missing-imagestream-tags=true --name=nationalparks -l type=parksmap-backend --allow-missing-imagestream-tags=true -n $GUID-parks-dev
oc new-app $GUID-parks-dev/parksmap:0.0-0 --allow-missing-imagestream-tags=true --name=parksmap -l type=parksmap-frontend --allow-missing-imagestream-tags=true -n $GUID-parks-dev

oc set triggers dc mlbparks --remove-all -n $GUID-parks-dev
oc set triggers dc nationalparks --remove-all -n $GUID-parks-dev
oc set triggers dc parksmap --remove-all -n $GUID-parks-dev

oc expose dc mlbparks --port 8080 -n $GUID-parks-dev
oc expose dc nationalparks --port 8080 -n $GUID-parks-dev
oc expose dc parksmap --port 8080 -n $GUID-parks-dev
oc expose svc/parksmap -n ${GUID}-parks-dev

oc set probe dc/mlbparks --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev
oc set probe dc/mlbparks --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev
oc set probe dc/nationalparks --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev
oc set probe dc/nationalparks --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev
oc set probe dc/parksmap --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev
oc set probe dc/parksmap --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc create configmap parksdb-config -n ${GUID}-parks-dev \
       --from-literal=DB_HOST=mongodb \
       --from-literal=DB_PORT=27017 \
       --from-literal=DB_USERNAME=mongodb_user \
       --from-literal=DB_PASSWORD=mongodb_password \
       --from-literal=DB_NAME=mongodb-internal
oc create configmap mlbparks-config --from-literal=APPNAME="MLB Parks (Dev)" -n $GUID-parks-dev
oc create configmap nationalparks-config --from-literal=APPNAME="National Parks (Dev)" -n $GUID-parks-dev
oc create configmap parksmap-config --from-literal=APPNAME="ParksMap (Dev)" -n $GUID-parks-dev

oc set env dc/mlbparks --from=configmap/parksdb-config -n ${GUID}-parks-dev
oc set env dc/mlbparks --from=configmap/mlbparks-config -n ${GUID}-parks-dev
oc set env dc/nationalparks --from=configmap/parksdb-config -n ${GUID}-parks-dev
oc set env dc/nationalparks --from=configmap/nationalparks-config -n ${GUID}-parks-dev
oc set env dc/parksmap --from=configmap/parksdb-config -n ${GUID}-parks-dev
oc set env dc/parksmap --from=configmap/parksmap-config -n ${GUID}-parks-dev

oc set deployment-hook dc/mlbparks --post -- curl -s http://mlbparks:8080/ws/data/load/ -n ${GUID}-parks-dev
oc set deployment-hook dc/nationalparks --post -- curl -s http://nationalparks:8080/ws/data/load/ -n ${GUID}-parks-dev
