# Minikube Deployment Plan — Go Microservices

This is your step-by-step plan to deploy all services from `docker-compose.yml` into Minikube (local Kubernetes).
We go one step at a time. Do not skip steps.

---

## What We Are Deploying

| Service | What it does | Needs |
|---|---|---|
| `broker-service` | Main entry point, routes requests | Nothing |
| `authentication-service` | Checks user login | Postgres DB |
| `logger-service` | Saves logs | MongoDB |
| `mailer-service` | Sends emails | Mailhog |
| `listener-service` | Listens to RabbitMQ events | RabbitMQ |
| `postgres` | Database for auth | Nothing |
| `mongo` | Database for logs | Nothing |
| `rabbitmq` | Message queue | Nothing |
| `mailhog` | Fake email server (for dev) | Nothing |

---

## Folder Structure We Will Create

```
go-micro/
└── k8s/                          ← NEW folder, create this
    ├── namespace.yaml             ← our isolated space inside Kubernetes
    ├── secrets.yaml               ← passwords (postgres, mongo)
    ├── postgres/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── mongo/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── rabbitmq/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── mailhog/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── broker-service/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── authentication-service/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── logger-service/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── mailer-service/
    │   ├── deployment.yaml
    │   └── service.yaml
    └── listener-service/
        └── deployment.yaml
```

---

## Phase 1 — Setup (Do This Once)

### Step 1.1 — Start Minikube
```bash
minikube start --driver=docker
```
Check it works:
```bash
minikube status
kubectl get nodes
```
Expected output from `kubectl get nodes`:
```
NAME       STATUS   ROLES           AGE
minikube   Ready    control-plane   1m
```

### Step 1.2 — Point Docker to Minikube's engine
This is important. It means when you build Docker images,
they go straight into Minikube — no need to push to Docker Hub.
```bash
eval $(minikube docker-env)
```
> ⚠️ You must run this in EVERY new terminal session before building images.

### Step 1.3 — Create the k8s folder
```bash
mkdir -p k8s/{postgres,mongo,rabbitmq,mailhog,broker-service,authentication-service,logger-service,mailer-service,listener-service}
```

---

## Phase 2 — Create namespace and secrets

### Step 2.1 — namespace.yaml
A namespace is just a folder inside Kubernetes to keep your stuff separate.

Create `k8s/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: go-micro
```
Apply it:
```bash
kubectl apply -f k8s/namespace.yaml
```

### Step 2.2 — secrets.yaml
Passwords must NOT be hardcoded. Kubernetes has a "Secret" object for this.
Passwords are base64-encoded (not real encryption, just encoding).

To encode a password:
```bash
echo -n "password" | base64     # outputs: cGFzc3dvcmQ=
echo -n "admin"    | base64     # outputs: YWRtaW4=
echo -n "postgres" | base64     # outputs: cG9zdGdyZXM=
```

Create `k8s/secrets.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: go-micro
type: Opaque
data:
  POSTGRES_USER: cG9zdGdyZXM=        # postgres
  POSTGRES_PASSWORD: cGFzc3dvcmQ=    # password
  MONGO_ROOT_USERNAME: YWRtaW4=      # admin
  MONGO_ROOT_PASSWORD: cGFzc3dvcmQ=  # password
```
Apply it:
```bash
kubectl apply -f k8s/secrets.yaml
```

---

## Phase 3 — Deploy Infrastructure (Databases + Queue)

Deploy these FIRST because your app services depend on them.

### Step 3.1 — Postgres

**`k8s/postgres/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:14.0
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              value: users
```

**`k8s/postgres/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: go-micro
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

Apply:
```bash
kubectl apply -f k8s/postgres/
```

### Step 3.2 — MongoDB

**`k8s/mongo/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
        - name: mongo
          image: mongo:4.2.16-bionic
          ports:
            - containerPort: 27017
          env:
            - name: MONGO_INITDB_DATABASE
              value: logs
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: MONGO_ROOT_USERNAME
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: MONGO_ROOT_PASSWORD
```

**`k8s/mongo/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo
  namespace: go-micro
spec:
  selector:
    app: mongo
  ports:
    - port: 27017
      targetPort: 27017
```

Apply:
```bash
kubectl apply -f k8s/mongo/
```

### Step 3.3 — RabbitMQ

**`k8s/rabbitmq/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
        - name: rabbitmq
          image: rabbitmq:3.9-alpine
          ports:
            - containerPort: 5672
```

**`k8s/rabbitmq/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: go-micro
spec:
  selector:
    app: rabbitmq
  ports:
    - port: 5672
      targetPort: 5672
```

Apply:
```bash
kubectl apply -f k8s/rabbitmq/
```

### Step 3.4 — Mailhog (fake email server)

**`k8s/mailhog/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailhog
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mailhog
  template:
    metadata:
      labels:
        app: mailhog
    spec:
      containers:
        - name: mailhog
          image: mailhog/mailhog:latest
          ports:
            - containerPort: 1025   # SMTP
            - containerPort: 8025   # Web UI
```

**`k8s/mailhog/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mailhog
  namespace: go-micro
spec:
  selector:
    app: mailhog
  ports:
    - name: smtp
      port: 1025
      targetPort: 1025
    - name: webui
      port: 8025
      targetPort: 8025
```

Apply:
```bash
kubectl apply -f k8s/mailhog/
```

Check all infrastructure is running before moving on:
```bash
kubectl get pods -n go-micro
```
All pods should show `Running` before you continue.

---

## Phase 4 — Build Your App Images

Run this FIRST (points Docker at Minikube):
```bash
eval $(minikube docker-env)
```

Then build all service images:
```bash
# Broker
docker build -f broker-service/broker-service.dockerfile -t broker-service:latest ./broker-service

# Authentication
docker build -f authentication-service/authentication-service.dockerfile -t authentication-service:latest ./authentication-service

# Logger
docker build -f logger-service/logger-service.dockerfile -t logger-service:latest ./logger-service

# Mailer
docker build -f mail-service/mail-service.dockerfile -t mailer-service:latest ./mail-service

# Listener
docker build -f listener-service/listener-service.dockerfile -t listener-service:latest ./listener-service
```

Verify images are in Minikube:
```bash
docker images | grep -E "broker|auth|logger|mailer|listener"
```

---

## Phase 5 — Deploy Your App Services

### Step 5.1 — Broker Service

**`k8s/broker-service/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broker-service
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broker-service
  template:
    metadata:
      labels:
        app: broker-service
    spec:
      containers:
        - name: broker-service
          image: broker-service:latest
          imagePullPolicy: Never    # use local image, not Docker Hub
          ports:
            - containerPort: 80
```

**`k8s/broker-service/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: broker-service
  namespace: go-micro
spec:
  selector:
    app: broker-service
  type: NodePort          # makes it reachable from your browser
  ports:
    - port: 8088
      targetPort: 80
      nodePort: 30088     # fixed port on your laptop
```

Apply:
```bash
kubectl apply -f k8s/broker-service/
```

Test it immediately:
```bash
minikube service broker-service -n go-micro --url
```
Open that URL in your browser.

### Step 5.2 — Authentication Service

**`k8s/authentication-service/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: authentication-service
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: authentication-service
  template:
    metadata:
      labels:
        app: authentication-service
    spec:
      containers:
        - name: authentication-service
          image: authentication-service:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 80
          env:
            - name: DSN
              value: "host=postgres port=5432 user=postgres password=password dbname=users sslmode=disable timezone=UTC connect_timeout=5"
```

**`k8s/authentication-service/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: authentication-service
  namespace: go-micro
spec:
  selector:
    app: authentication-service
  ports:
    - port: 80
      targetPort: 80
```

Apply:
```bash
kubectl apply -f k8s/authentication-service/
```

### Step 5.3 — Logger Service

**`k8s/logger-service/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logger-service
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logger-service
  template:
    metadata:
      labels:
        app: logger-service
    spec:
      containers:
        - name: logger-service
          image: logger-service:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 80
            - containerPort: 5001   # gRPC port
```

**`k8s/logger-service/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: logger-service
  namespace: go-micro
spec:
  selector:
    app: logger-service
  ports:
    - name: http
      port: 80
      targetPort: 80
    - name: grpc
      port: 5001
      targetPort: 5001
```

Apply:
```bash
kubectl apply -f k8s/logger-service/
```

### Step 5.4 — Mailer Service

**`k8s/mailer-service/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailer-service
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mailer-service
  template:
    metadata:
      labels:
        app: mailer-service
    spec:
      containers:
        - name: mailer-service
          image: mailer-service:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 80
          env:
            - name: MAIL_DOMAIN
              value: localhost
            - name: MAIL_HOST
              value: mailhog
            - name: MAIL_PORT
              value: "1025"
            - name: MAIL_ENCRYPTION
              value: none
            - name: MAIL_USERNAME
              value: ""
            - name: MAIL_PASSWORD
              value: ""
            - name: FROM_NAME
              value: "John Smith"
            - name: FROM_ADDRESS
              value: john.smith@example.com
```

**`k8s/mailer-service/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mailer-service
  namespace: go-micro
spec:
  selector:
    app: mailer-service
  ports:
    - port: 80
      targetPort: 80
```

Apply:
```bash
kubectl apply -f k8s/mailer-service/
```

### Step 5.5 — Listener Service

**`k8s/listener-service/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: listener-service
  namespace: go-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: listener-service
  template:
    metadata:
      labels:
        app: listener-service
    spec:
      containers:
        - name: listener-service
          image: listener-service:latest
          imagePullPolicy: Never
```

Apply:
```bash
kubectl apply -f k8s/listener-service/
```

---

## Phase 6 — Verify Everything is Running

```bash
# See all pods
kubectl get pods -n go-micro

# See all services
kubectl get services -n go-micro

# If a pod is NOT running, check why:
kubectl describe pod <pod-name> -n go-micro

# See logs from a pod:
kubectl logs <pod-name> -n go-micro
```

All pods should show:
```
NAME                                  READY   STATUS    RESTARTS
broker-service-xxx                    1/1     Running   0
authentication-service-xxx            1/1     Running   0
logger-service-xxx                    1/1     Running   0
mailer-service-xxx                    1/1     Running   0
listener-service-xxx                  1/1     Running   0
postgres-xxx                          1/1     Running   0
mongo-xxx                             1/1     Running   0
rabbitmq-xxx                          1/1     Running   0
mailhog-xxx                           1/1     Running   0
```

---

## Phase 7 — Access Your App

```bash
# Get the URL for broker-service
minikube service broker-service -n go-micro --url

# Get the URL for mailhog web UI
minikube service mailhog -n go-micro --url
```

---

## Useful Commands Cheat Sheet

```bash
# See what's running
kubectl get pods -n go-micro
kubectl get services -n go-micro
kubectl get deployments -n go-micro

# Debug a broken pod
kubectl describe pod <name> -n go-micro
kubectl logs <name> -n go-micro

# Restart a deployment (after rebuilding image)
kubectl rollout restart deployment/<name> -n go-micro

# Delete everything and start over
kubectl delete namespace go-micro

# Stop minikube (saves state)
minikube stop

# Start again later
minikube start
```

---

## Order Summary (Do Not Skip)

```
Phase 1 → Start Minikube + point Docker to it
Phase 2 → Create namespace + secrets
Phase 3 → Deploy postgres, mongo, rabbitmq, mailhog
           ↳ Wait for all pods to be Running before continuing
Phase 4 → Build all your app images
Phase 5 → Deploy broker, auth, logger, mailer, listener
Phase 6 → Verify all pods are Running
Phase 7 → Open in browser
```

---

> When you're ready to start, go to Phase 1 and run the commands one by one.
> Come back here to check the next step each time.
