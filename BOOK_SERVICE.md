# NorthStar Retail – Book Service

## Purpose

The Book Service is responsible for managing the book (product) catalog within the NorthStar Retail Platform. It exposes APIs to create, update, retrieve, and deactivate books that can be sold across stores. It is intentionally simple to keep business logic isolated and focused on product data ownership. It has no direct relationship to Store; Inventory links products to stores by (storeId, bookId).

## Responsibilities

- Manage book metadata (title, author, ISBN, price, status)
- Expose read/write APIs for books
- Provide availability information (logical status: AVAILABLE, OUT_OF_STOCK, DISCONTINUED; stock-specific quantity lives in Inventory)
- Act as a downstream dependency for Order Service (validation only; no cross-service calls from Book)

## Key Domain Model

**Book**

| Field       | Type           | Description                          |
|------------|----------------|--------------------------------------|
| id         | Long           | PK                                   |
| uid        | String         | Public identifier (unique, generated on create) |
| title      | String         |                                      |
| author     | String         |                                      |
| isbn       | String         |                                      |
| price      | BigDecimal     |                                      |
| status     | Enum           | AVAILABLE, OUT_OF_STOCK, DISCONTINUED|
| creationTime | LocalDateTime |                              |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/books` | List all (paginated: `page`, `size`) |
| GET | `/v1/books/{uuid}` | Get by UUID |
| GET | `/v1/books/title/{title}` | List by title (paginated) |
| GET | `/v1/books/author/{author}` | List by author (paginated) |
| GET | `/v1/books/status/{status}` | List by status (paginated) |
| POST | `/v1/books` | Create a book |
| PUT | `/v1/books/{id}` | Full update |
| DELETE | `/v1/books/{id}` | Delete a book |

## Architecture Decisions

- Stateless Spring Boot application; JPA for persistence
- No cross-service calls from Book Service (pure data owner)
- Pagination at repository level: `Pageable` in controller, `Page<>` from repository; no manual offset/limit
- Idempotency: create is non-idempotent; callers should enforce idempotency keys if required

## Security

- All endpoints secured via JWT (validated at Gateway; token relay)
- Service trusts Gateway-propagated identity; can add resource-server validation if required

## Failure Handling

- Returns 404 for missing books (`BookNotFoundException`, by uid); validation → 400; invalid enum → 400; generic → 500
- No cascading failures (no synchronous outbound dependencies)
- Gateway circuit breaker and retry apply to Book routes

## Operational Considerations

- Read-heavy workload → easy horizontal scaling; Eureka and Gateway distribute load
- Cacheable endpoints (cache-aside e.g. Redis) as future optimization
- Database migration: JPA `ddl-auto: update` in demo; Flyway recommended for production
- Logging: structured logs with app name and trace IDs; INFO for mutations, WARN for not-found
- Metrics: Actuator; HTTP server request metrics for latency and throughput
- Tracing: sampling enabled for distributed trace correlation across Gateway → Book

## Incident Scenarios

- **Database unavailable** → service returns 503; alerts on DB health
- **Incorrect pricing or catalog data** → resolved via data correction, not redeploy; runbook: “Invalid book data”
- **High latency on list** → runbook: “High latency on list”; consider caching or read replicas
- **Ownership**: Book team owns catalog correctness and API contract
- **Scoping**: 404/400 from Book are clearly from this service; L3 can triage by path and status
- **Postmortem**: Logs and traces show which book IDs were accessed; DB and repo layer support root-cause analysis (e.g. slow queries by status)

## Evolution

Future extensions could include:

- Categories and taxonomy
- Promotions and pricing rules
- Localization (title/author by locale)
- Soft delete (active flag) instead of hard delete
