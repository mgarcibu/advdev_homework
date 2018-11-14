GUID=$1

oc project $GUID-parks-dev

oc policy add-role-to-user edit system:serviceaccount:f9ff-jenkins:jenkins -n f9ff-parks-dev

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


oc new-build --binary=true --name="mlb-parks-dev" --image-stream=redhat-openjdk18-openshift:1.2 -n f9ff-parks-dev
oc new-build --binary=true --name="national-parks-dev" --image-stream=redhat-openjdk18-openshift:1.2 -n f9ff-parks-dev
oc new-build --binary=true --name="parksmap-dev" --image-stream=redhat-openjdk18-openshift:1.2 -n f9ff-parks-dev

oc new-app f9ff-parks-dev/mlb-parks-dev --name=mlb-parks-dev --allow-missing-imagestream-tags=true -n f9ff-parks-dev
oc new-app f9ff-parks-dev/national-parks-dev --name=national-parks-dev --allow-missing-imagestream-tags=true -n f9ff-parks-dev
oc new-app f9ff-parks-dev/parksmap-dev --name=parksmap-dev --allow-missing-imagestream-tags=true -n f9ff-parks-dev

oc set triggers dc mlb-parks-dev --remove-all -n f9ff-parks-dev
oc set triggers dc national-parks-dev --remove-all -n f9ff-parks-dev
oc set triggers dc parksmap-dev --remove-all -n f9ff-parks-dev

oc expose dc mlb-parks-dev --port 8080 -n f9ff-parks-dev
oc expose dc national-parks-dev --port 8080 -n f9ff-parks-dev
oc expose dc parksmap-dev --port 8080 -n f9ff-parks-dev

oc expose svc mlb-parks-dev -n f9ff-parks-dev
oc expose svc national-parks-dev -n f9ff-parks-dev
oc expose svc parksmap-dev -n f9ff-parks-dev

oc create configmap mlb-parks-config --from-literal="mlb-parks.properties=Placeholder" -n f9ff-parks-dev
oc create configmap national-parks-config --from-literal="national-parks.properties=Placeholder" -n f9ff-parks-dev
oc create configmap parksmap-config --from-literal="parksmap.properties=Placeholder" -n f9ff-parks-dev
