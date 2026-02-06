# NorthStar Retail Platform

Microservices-based retail platform for demonstrating service ownership, operability, and system-level thinking.

## Overview

NorthStar Retail Platform provides a **microservices-based e-commerce solution**, offering product catalog management, order processing, inventory management, store management, authorization, and notification services within a microservices architecture. The platform is containerized with **Docker** and orchestrated using **Kubernetes**.

## Services

| Service | Port | Description |
|---------|------|-------------|
| northstar-discovery-service | 8761 | Eureka server (Service Registry) |
| northstar-gateway-service | 8181 | Spring Cloud Gateway (routing, circuit breaker, retry) |
| northstar-auth-service | 8191 | Authorization server (OAuth2, JWT, users & roles) |
| northstar-book-service | 8186 | Product catalog (books) |
| northstar-store-service | 8187 | Store master data |
| northstar-order-service | 8188 | Order orchestration (calls Book, Store, Inventory, Notification) |
| northstar-inventory-service | 8189 | Stock per store/book; reserve/release |
| northstar-notification-service | 8190 | Notification persistence (order confirmations) |

## Prerequisites

Before getting started, ensure you have the following installed:

- **Java 21** or higher
- **Maven 3.9+**
- **Docker** and **Docker Compose** (for database setup and full platform deployment)
- **PostgreSQL** (if running databases locally without Docker)
- **Redis** (for Gateway rate limiting; optional for local run)

## Getting Started

### Option 1: Quick Start with Docker Compose (Recommended)

The easiest way to get started is using Docker Compose, which sets up all databases and services automatically.

#### 1. Clone the Repository
```bash
git clone <repository-url>
cd northstar
```

#### 2. Build All Services
```bash
# Build all services (this will compile and package each service)
mvn clean install -DskipTests
```

#### 3. Start Everything with Docker Compose
```bash
# Start all services, databases, Redis, and Discovery
docker compose up -d --build
```

This will start:
- **6 PostgreSQL databases** (one per service)
- **Redis** (for rate limiting)
- **Discovery Service** (Eureka)
- **Gateway Service**
- **Auth Service**
- **All domain services** (Book, Store, Order, Inventory, Notification)

#### 4. Access the Platform
- **API Gateway**: `http://localhost:8181`
- **Swagger UI**: `http://localhost:8181/swagger-ui.html`
- **Eureka Dashboard**: `http://localhost:8761`

---

### Option 2: Running Locally (Manual Setup)

If you prefer to run services locally without Docker Compose:

#### 1. Clone the Repository
```bash
git clone <repository-url>
cd northstar
```

#### 2. Set Up Databases

**Option A: Using Docker Compose for databases only**
```bash
# Start only PostgreSQL databases and Redis
docker compose up -d postgres-auth postgres-book postgres-store postgres-order postgres-inventory postgres-notification northstar-redis
```

**Option B: Manual PostgreSQL setup**
Create the following databases:
- `northstar_auth_db`
- `northstar_book_db`
- `northstar_store_db`
- `northstar_order_db`
- `northstar_inventory_db`
- `northstar_notification_db`

#### 3. Build All Services
```bash
mvn clean install -DskipTests
```

#### 4. Start Services in Order

**Terminal 1 - Discovery Service:**
```bash
cd northstar-discovery-service
mvn spring-boot:run
```

**Terminal 2 - Gateway Service:**
```bash
cd northstar-gateway-service
mvn spring-boot:run
```

**Terminal 3 - Auth Service:**
```bash
cd northstar-auth-service
mvn spring-boot:run
```

**Terminal 4 - Book Service:**
```bash
cd northstar-book-service
mvn spring-boot:run
```

**Terminal 5 - Store Service:**
```bash
cd northstar-store-service
mvn spring-boot:run
```

**Terminal 6 - Inventory Service:**
```bash
cd northstar-inventory-service
mvn spring-boot:run
```

**Terminal 7 - Notification Service:**
```bash
cd northstar-notification-service
mvn spring-boot:run
```

**Terminal 8 - Order Service:**
```bash
cd northstar-order-service
mvn spring-boot:run
```

#### 5. Verify Services are Running

- Check Eureka Dashboard: `http://localhost:8761` - all services should be registered
- Access Swagger UI: `http://localhost:8181/swagger-ui.html`
- Test API endpoints through the Gateway at `http://localhost:8181`

## Docker Compose Details

One **docker-compose.yml** in the root directory starts the full platform: all 6 Postgres DBs, Discovery, Redis, Gateway, Auth, and all domain services (Book, Store, Order, Inventory, Notification).

**What gets started:**

| Component | Container(s) | Port(s) |
|-----------|--------------|---------|
| Discovery | northstar-discovery | 8761 |
| Redis | northstar-redis | 6379 |
| Postgres (Auth) | postgres-auth | 5433 |
| Postgres (Book) | postgres-book | 5434 |
| Postgres (Store) | postgres-store | 5435 |
| Postgres (Order) | postgres-order | 5436 |
| Postgres (Inventory) | postgres-inventory | 5437 |
| Postgres (Notification) | postgres-notification | 5438 |
| Gateway | northstar-gateway | 8181 |
| Auth | northstar-auth | 8191 |
| Book | northstar-book | 8186 |
| Store | northstar-store | 8187 |
| Order | northstar-order | 8188 |
| Inventory | northstar-inventory | 8189 |
| Notification | northstar-notification | 8190 |

**Note:** `--build` builds each service image from its Dockerfile (Java 21, JAR). Ensure each service JAR exists (`mvn package -DskipTests` in each module) or let compose build them.

**Stop all services:**
```bash
docker compose down
```

**View logs:**
```bash
docker compose logs -f [service-name]
```

## API Access

All API endpoints are accessed through the Gateway at `http://localhost:8181`.

**Swagger UI:** `http://localhost:8181/swagger-ui.html`

You can test all API endpoints from Swagger UI. For authenticated endpoints:
1. First, obtain a JWT token by calling the Auth service `/oauth2/token` endpoint
2. Click "Authorize" in Swagger UI
3. Enter your token (without "Bearer" prefix - it will be added automatically)

**Service-specific Swagger:**
- Auth Service: `http://localhost:8181/swagger-ui.html?urls.primaryName=Auth`
- Book Service: `http://localhost:8181/swagger-ui.html?urls.primaryName=Books`
- Store Service: `http://localhost:8181/swagger-ui.html?urls.primaryName=Stores`
- Order Service: `http://localhost:8181/swagger-ui.html?urls.primaryName=Orders`
- Inventory Service: `http://localhost:8181/swagger-ui.html?urls.primaryName=Inventory`
- Notification Service: `http://localhost:8181/swagger-ui.html?urls.primaryName=Notifications`

## Postman Collection

A complete Postman collection is available at `postman/NorthStar-Retail-Platform.postman_collection.json` that includes all API endpoints and a complete end-to-end flow.

### Importing the Collection

1. Open Postman
2. Click **Import** → **File**
3. Select `postman/NorthStar-Retail-Platform.postman_collection.json`
4. Import the environment file: `postman/NorthStar-Retail-Platform.postman_environment.json` (optional, for environment variables)

### Environment Variables

The collection uses the following environment variables:
- `base_url`: `http://localhost:8181` (Gateway URL)
- `admin_token`: Set automatically after admin login
- `user_token`: Set automatically after user login
- `admin_uid`, `user_uid`: Set automatically after registration
- `book_uid`, `store_uid`, `inventory_uid`, `order_uid`, `notification_uid`: Set automatically during the flow

### Complete Flow

The collection includes a **Complete Flow** under the **Flows** section that demonstrates the full platform workflow:

1. **Register Admin** - Creates an admin user (`admin@northstar.com`)
2. **Register User** - Creates a regular user (`testuser@northstar.com`)
3. **Login Admin** - Authenticates admin and saves `admin_token`
4. **Login User** - Authenticates user and saves `user_token`
5. **Create Book (Admin)** - Admin creates a book product
6. **Create Store (Admin)** - Admin creates a store
7. **Create Inventory (Admin)** - Admin adds inventory for the book at the store
8. **Create Order (User)** - User creates an order with the book
9. **Get Notifications by User** - User retrieves order confirmation notification

Each request includes **test scripts** that automatically extract values from responses and set them as environment variables for subsequent requests. This allows the entire flow to run sequentially without manual intervention.

### Running the Complete Flow

1. Ensure all services are running (via Docker Compose or locally)
2. Open the Postman collection
3. Navigate to **Flows** → **Complete Flow**
4. Click **Run** (or use Collection Runner)
5. All requests will execute in sequence, with each request using data from previous responses

### Individual Endpoints

The collection also includes individual endpoints organized by service:
- **Auth**: User registration, login, user management
- **Book**: CRUD operations for books
- **Store**: CRUD operations for stores
- **Inventory**: Inventory management, reserve/release operations
- **Order**: Order creation and management
- **Notification**: Notification retrieval

All endpoints are configured to work through the Gateway at `http://localhost:8181`.

## Kubernetes Deployment

Each service has a **k8s/** folder with Kubernetes manifests:

- **Discovery**: ConfigMap + Deployment + Service (no DB).
- **Gateway**: ConfigMap + Secret + Deployment + Service (LoadBalancer) + Redis (ConfigMap + PVC + Deployment + Service).
- **Auth, Book, Store, Order, Inventory, Notification**: ConfigMap + Deployment + Service + Postgres (ConfigMap + Secret + PVC + Deployment + Service).

Apply order: Discovery → Gateway DB + Gateway → Auth DB + Auth → then each domain service’s DB then app. See [docs/DOCKER_K8S.md](/DOCKER_K8S.md) for exact commands and image/secret notes.



## Coding Style

- Controller → Service (interface) → ServiceImpl → Repository; DTOs, Mapper (MapStruct), GlobalExceptionHandler.
- Pagination at repository level: `Pageable` in controller/service, `Page<>` in repository; no manual pagination in controller.
- Same layering and naming as the clozingtag project for consistency.

<img width="1000" height="1214" alt="Screenshot 2026-02-06 at 17 58 01" src="https://github.com/user-attachments/assets/8acbbaa7-e70f-4103-974e-377a5471ab8d" />

