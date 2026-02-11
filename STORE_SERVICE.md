# NorthStar Retail – Store Service

## Purpose

The Store Service represents physical or logical retail stores in the NorthStar Retail Platform. It provides store metadata used by order and inventory-related flows. It is the source of truth for “where we sell”; Book is “what we sell”; Inventory links them by (storeId, bookId).

## Responsibilities

- Manage store information (name, address, region)
- Validate store existence for orders and inventory operations
- Act as a reference service for retail operations; no direct knowledge of books or orders

## Key Domain Model

**Store**

| Field       | Type           | Description |
|------------|----------------|-------------|
| id         | Long           | PK          |
| uid        | String         | Public identifier (unique, generated on create) |
| name       | String         |             |
| address    | String         |             |
| region     | String         |             |
| creationTime | LocalDateTime |             |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/stores` | List all (paginated: `page`, `size`) |
| GET | `/v1/stores/{uuid}` | Get by UUID |
| GET | `/v1/stores/name/{name}` | List by name (paginated) |
| GET | `/v1/stores/region/{region}` | List by region (paginated) |
| POST | `/v1/stores` | Create a store |
| PUT | `/v1/stores/{id}` | Update a store |
| DELETE | `/v1/stores/{id}` | Delete a store |

## Architecture Decisions

- Independent service with clear data ownership
- No direct knowledge of books or orders; Order and Inventory hold `storeId` as a reference only
- No foreign keys from other services; deletion of a store does not cascade; orchestration or eventual cleanup is a product decision
- Pagination at repository level: `Pageable` and repository `Page<StoreEntity>`; no manual pagination in controllers
- Minimal domain: name, address, region; real system might add timezone, opening hours, etc.

## Security

- JWT-based authentication via Gateway (token relay)
- Read access allowed to internal services (Order, Inventory)

## Failure Handling

- Store validation failures (not found) → 404; validation → 400; generic → 500
- No retries needed for idempotent reads
- Gateway circuit breaker and retry apply to Store routes

## Operational Considerations

- Low write / moderate read traffic; ideal candidate for read replicas
- Stable schema, low change frequency; cache-by-id and invalidate-on-update is a natural fit
- Logging: app name and trace IDs; INFO for mutations, WARN for not-found
- Metrics: Actuator; HTTP server request metrics for latency and throughput
- Tracing: enabled for correlation with Order and other callers

## Incident Scenarios

- **Store marked inactive or deleted incorrectly** → business correction; runbook: “Store not found”, “Store update failures”
- **Store service downtime** → order creation blocked gracefully (Order returns 503/504 from Gateway); L3 scoping: Order flow failures may point to “store invalid” when Store returns 404
- **Ownership**: Store team owns store data and API
- **Postmortem**: Logs and DB support “who changed what store when” and impact on orders/inventory that reference that store

## Evolution

Possible future enhancements:

- Store hours and timezone
- Store capacity or capability flags
- Store-specific rules (e.g. fulfillment)
- Active/inactive flag (soft delete)
