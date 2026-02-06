# NorthStar Retail – Docker & Kubernetes

## Docker

### Build images

From each service directory (after `mvn package -DskipTests`):

```bash
cd northstar-discovery-service && mvn package -DskipTests && docker build -t northstar-discovery-service:latest .
cd northstar-gateway-service && mvn package -DskipTests && docker build -t northstar-gateway-service:latest .
cd northstar-auth-service    && mvn package -DskipTests && docker build -t northstar-auth-service:latest .
cd northstar-book-service    && mvn package -DskipTests && docker build -t northstar-book-service:latest .
cd northstar-store-service   && mvn package -DskipTests && docker build -t northstar-store-service:latest .
cd northstar-order-service   && mvn package -DskipTests && docker build -t northstar-order-service:latest .
cd northstar-inventory-service   && mvn package -DskipTests && docker build -t northstar-inventory-service:latest .
cd northstar-notification-service && mvn package -DskipTests && docker build -t northstar-notification-service:latest .
```

Or from repo root, build all and run with root `docker-compose.yml`:

```bash
# Build all JARs first
for d in northstar-*-service; do (cd $d && mvn package -q -DskipTests); done

# Start infrastructure + apps
docker compose up -d
```

Gateway will be on `http://localhost:8181`; Discovery on `http://localhost:8761`.

### Per-service docker-compose

Each service that needs a DB has a `docker-compose.yml` for local dev:

- **northstar-auth-service**: Postgres (port 5432)
- **northstar-gateway-service**: Redis (6379)
- **northstar-book-service**: Postgres (5433)
- **northstar-store-service**: Postgres (5434)
- **northstar-order-service**: Postgres (5435)
- **northstar-inventory-service**: Postgres (5436)
- **northstar-notification-service**: Postgres (5437)

Example: run DB then app for auth:

```bash
cd northstar-auth-service && docker compose up -d postgres
# set DB_HOST=localhost, DB_PORT=5432 and run the app
```

---

## Kubernetes

### Apply order

1. **Discovery** (no DB): other services need its ConfigMap.
2. **Gateway Redis**: gateway needs Redis for rate limiting.
3. **Auth + Auth DB**
4. **Book + Book DB**, **Store + Store DB**, **Order + Order DB**, **Inventory + Inventory DB**, **Notification + Notification DB**

Commands (from repo root, after building and pushing images or using `imagePullPolicy: IfNotPresent` with local images):

```bash
# 1. Discovery (creates northstar-discovery-service-configmap used by others)
kubectl apply -f northstar-discovery-service/k8s/northstar-discovery-service-deployment.yaml

# 2. Gateway Redis then Gateway
kubectl apply -f northstar-gateway-service/k8s/northstar-gateway-service-db-deployment.yaml
kubectl apply -f northstar-gateway-service/k8s/northstar-gateway-service-deployment.yaml

# 3. Auth DB then Auth
kubectl apply -f northstar-auth-service/k8s/northstar-auth-service-db-deployment.yaml
kubectl apply -f northstar-auth-service/k8s/northstar-auth-service-deployment.yaml

# 4. Domain services (each: db then app)
kubectl apply -f northstar-book-service/k8s/northstar-book-service-db-deployment.yaml
kubectl apply -f northstar-book-service/k8s/northstar-book-service-deployment.yaml
kubectl apply -f northstar-store-service/k8s/northstar-store-service-db-deployment.yaml
kubectl apply -f northstar-store-service/k8s/northstar-store-service-deployment.yaml
kubectl apply -f northstar-order-service/k8s/northstar-order-service-db-deployment.yaml
kubectl apply -f northstar-order-service/k8s/northstar-order-service-deployment.yaml
kubectl apply -f northstar-inventory-service/k8s/northstar-inventory-service-db-deployment.yaml
kubectl apply -f northstar-inventory-service/k8s/northstar-inventory-service-deployment.yaml
kubectl apply -f northstar-notification-service/k8s/northstar-notification-service-db-deployment.yaml
kubectl apply -f northstar-notification-service/k8s/northstar-notification-service-deployment.yaml
```

### Images

K8s manifests use `image: northstar-<service>:latest` and `imagePullPolicy: IfNotPresent`. For a real cluster:

1. Build and push to a registry (e.g. `ghcr.io/org/northstar-discovery-service:tag`).
2. Replace `image` and set `imagePullPolicy: Always` (or omit for default), and add `imagePullSecrets` if the registry is private.

### Secrets

DB credentials are in Secrets (base64). Defaults: user `postgres`, password `root`. Change for non-dev:

```bash
echo -n 'postgres' | base64   # db-user
echo -n 'yourpassword' | base64  # db-pass
```

Update the Secret YAML and re-apply.

### Gateway access

Gateway Service is `type: LoadBalancer`. Use the external IP/hostname from `kubectl get svc northstar-gateway-service-svc` to reach the API (e.g. `http://<EXTERNAL-IP>:8181`). For an ingress, add an Ingress resource pointing to `northstar-gateway-service-svc:8181`.

### Storage

PVCs use the cluster’s default StorageClass. If none is set, create a StorageClass or bind PVCs to a specific provisioner. No PV is defined so the provisioner will create one.
