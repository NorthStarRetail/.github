# NorthStar Retail – Inventory Service

## Purpose

The Inventory Service owns per-store, per-book stock levels for the NorthStar Retail Platform. It is the only place that links products (books) to stores in terms of quantity: (storeId, bookId, quantity). Book and Store have no direct relationship; Inventory is the join.

## Responsibilities

- Single source of truth for quantity on hand per (storeId, bookId)
- Reserve and release operations used by Order Service (reserve on order creation; release on compensation or cancellation)
- Queries by store, by book, or by (storeId, bookId); all list APIs paginated at repo level

## Key Domain Model

**Inventory**

| Field     | Type           | Description              |
|----------|----------------|--------------------------|
| id       | Long           | PK                       |
| uid      | String         | Public identifier (unique, generated on create) |
| storeId  | Long           | FK reference to Store    |
| bookId   | Long           | FK reference to Book     |
| quantity | Integer        | On hand                  |
| creationTime | LocalDateTime |                      |
| updatedAt   | LocalDateTime |                      |

Unique constraint on (storeId, bookId).

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/inventory` | Create or update stock (storeId, bookId, quantity) |
| GET | `/v1/inventory/{id}` | Get one record by ID (uid string) |
| GET | `/v1/inventory/store/{storeId}/book/{bookId}` | Get one record by store and book |
| GET | `/v1/inventory/store/{storeId}` | List by store (paginated) |
| GET | `/v1/inventory/book/{bookId}` | List by book (paginated) |
| POST | `/v1/inventory/reserve` | Reserve (body: storeId, bookId, quantity) |
| POST | `/v1/inventory/release` | Release (same body) |
| DELETE | `/v1/inventory/{id}` | Delete inventory record |

## Architecture Decisions

- Pessimistic write lock (PESSIMISTIC_WRITE) on (storeId, bookId) for reserve/release to avoid over-sale
- No negative quantity: business rule enforced; InsufficientStockException if quantity would go negative
- Reserve/release not idempotent by default; callers (Order) manage “reserve once per order” and “release once per compensation”
- Pagination at repository level: `Pageable` and `Page<InventoryEntity>`; no manual pagination in controller

## Security

- JWT-based authentication via Gateway (token relay)

## Failure Handling

- InventoryNotFoundException → 404; InsufficientStockException → 400; validation → 400; generic → 500
- No outbound sync calls; resilience is validation, locking, and clear errors
- DB deadlocks possible under high contention; timeouts and retry (Gateway or client) with backoff
- Gateway circuit breaker and retry apply to Inventory routes

## Operational Considerations

- Lock is per (storeId, bookId); contention spread across keys; scale instances horizontally
- Index on (store_id, book_id) for reserve/release and by-store/by-book queries
- Caching: quantity is critical; cache would need careful invalidation on reserve/release; often kept authoritative in DB only
- Logging: reserve/release with store, book, quantity; WARN on insufficient stock and not-found
- Metrics: Actuator; HTTP server metrics; reserve/release success and failure counts are valuable
- Tracing: enabled for correlation with Order

## Incident Scenarios

- **Insufficient stock** → 400 to client; runbook: “Insufficient stock”
- **Reserve/release failures** → runbook: “Reserve/release failures”; trace shows which (store, book)
- **Deadlocks** → runbook: “Deadlocks”; scale or backoff
- **Over-sell** → prevented by pessimistic lock; postmortem: logs and DB show which (store, book) had contention or incorrect quantity
- **Ownership**: Inventory team owns stock consistency and reserve/release semantics
- **Scoping**: 400 “Insufficient stock” or 404 “Inventory not found” clearly point to this service; Order traces show which reserve call failed
- **Postmortem**: Logs and DB show which (store, book) had contention or incorrect quantity; supports “why did this order fail?” and “did we over-sell?”

## Evolution

Future extensions:

- Idempotent reserve/release with client-supplied idempotency key
- Event-driven inventory updates (e.g. OrderConfirmed decrements, OrderCancelled restores) for eventual consistency
- Stock reservations with TTL (auto-release expired reserves)
