# NorthStar Retail – Order Service

## Purpose

The Order Service orchestrates the retail order lifecycle for the NorthStar Retail Platform. It is the core business service and coordinates between Book, Store, Inventory, and Notification. It owns the order aggregate (header + line items) and maintains order state.

## Responsibilities

- Create and manage orders (validate store and books, reserve inventory, persist order, notify)
- Maintain order state transitions (e.g. PENDING → CONFIRMED → SHIPPED)
- Serve as system-of-record for orders
- Compensate on failure: release reserved inventory before rethrowing

## Key Domain Model

**Order**

| Field     | Type     | Description                    |
|----------|----------|--------------------------------|
| id       | Long     | PK (internal, auto)            |
| uid      | String   | Public identifier (unique, set on create) |
| userId   | Long     | From JWT; not in request body  |
| storeId  | Long     | FK reference to Store          |
| status   | Enum     | PENDING, CONFIRMED, SHIPPED, etc. |
| createdAt| LocalDateTime |                         |
| lineItems| One-to-many | OrderLineItem[]            |

**OrderLineItem**

| Field   | Type    | Description        |
|--------|---------|--------------------|
| id     | Long    | PK                 |
| orderId| Long    | FK                 |
| bookId | Long    | FK reference       |
| quantity | Integer |                 |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/orders` | Create order (body: storeId, lineItems[]). Requires auth; userId and user name/email from JWT. |
| GET | `/v1/orders/{uuid}` | Get by UUID |
| GET | `/v1/orders/user/{userId}` | List orders for a user (paginated) |
| GET | `/v1/orders/store/{storeId}` | List by store (paginated) |
| GET | `/v1/orders/status/{status}` | List by status (paginated) |
| PATCH | `/v1/orders/{id}/status?status=` | Update order status |

## State Machine

Valid transitions only; invalid transitions return 400.

- **PENDING** → CONFIRMED, CANCELLED
- **CONFIRMED** → SHIPPED
- **SHIPPED** → (terminal)
- **CANCELLED** → (terminal)

Same status (e.g. PENDING → PENDING) is allowed (no-op). On transition to **CANCELLED**, the service releases reserved inventory for all line items before updating the order status; if any release fails, the status is not updated and the client receives an error.

## Architecture Decisions

- Synchronous validation against Store and Book; synchronous reserve/release against Inventory
- Fire-and-forget call to Notification (failure logged only; does not fail the order)
- Reserve-then-persist: reserve inventory first; on any failure after reserve, release all reserved items then rethrow
- No distributed transaction (2PC); accept “reserve committed, order save failed” as transient; ops reconcile stale reserves
- Pagination at repository level: `Pageable` and repository `Page<>`; no manual pagination in controller

## Security

- POST `/v1/orders` requires valid JWT; Order Service is OAuth2 resource server; user id, name, username extracted from token for order and notification

## Failure Handling

- Downstream 404 (Book or Store) → order not created; no reserve
- Insufficient stock (Inventory 400) → propagated to client; no partial reserve (all-or-nothing per order)
- Release on failure: on exception after any reserve, iterate reserved items and call Inventory release; then rethrow
- Notification failure → wrapped in try/catch; logged only
- Gateway circuit breaker and retry reduce cascading failures from downstream

## Operational Considerations

- Critical path → higher SLA; WebClient and Gateway timeouts to avoid long blocking
- Structured logging for order ID, store, user, downstream calls; WARN on notification failure and on release during compensation
- Metrics: Actuator; HTTP server metrics; custom “order_created”, “order_creation_failed”, “inventory_release_called” would help in production
- Tracing: end-to-end from Gateway → Order → Book/Store/Inventory/Notification for incident analysis
- Idempotent order creation: idempotency keys recommended for production

## Incident Scenarios

- **Duplicate orders** → idempotency key (future); runbook: “Order creation failing”
- **Partial failure (reserve then order save fails)** → reserves released; runbook: “Stale reserves”
- **Notification not sent** → non-blocking; runbook: “Notification not sent”
- **Downstream timeout** → trace shows which service; L3 hands off to correct team
- **Ownership**: Order team owns the flow and compensation logic
- **Scoping**: Trace and logs show which service failed (Book vs Store vs Inventory vs DB); L3 can hand off to the right team
- **Postmortem**: Order ID and line items are in DB; trace shows exact downstream calls and status codes; supports “why did this order fail?” and “did we release correctly?”

## Evolution

Future additions:

- Idempotency keys for order creation
- Payments integration
- Order splitting or partial fulfillment
- Returns and refunds
- Domain events (e.g. OrderCreated) for Notification and analytics
