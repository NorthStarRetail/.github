# NorthStar Retail – Notification Service

## Purpose

The Notification Service handles persistence and (when implemented) delivery of notifications triggered by order flow—e.g. order confirmation. It is decoupled from core business logic so that notification failures do not cause order creation to fail. Order calls it fire-and-forget after creating an order.

## Responsibilities

- Persist notification records (subject, body, recipient, userId, etc.)
- User-scoped list: users can list their own notifications via GET `/v1/notifications/user/{userId}` (paginated)
- Consume order-related create requests from Order Service (sync HTTP today; event-driven in evolution)
- Log notification delivery outcomes; actual sending (SMTP, provider) can be plugged in
- Extensibility: template, channel (email/SMS), and provider can be added without changing the core API

## Key Domain Model

**Notification**

| Field   | Type           | Description |
|--------|----------------|-------------|
| id     | Long           | PK          |
| uid    | String         | Public identifier (unique, generated on create) |
| userId | Long           |             |
| name   | String         |             |
| email  | String         |             |
| subject| String         |             |
| body   | String         |             |
| createdAt | LocalDateTime |          |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/notifications` | Create notification (internal; used by Order) |
| GET | `/v1/notifications/{id}` | Get by ID (uid string) |
| GET | `/v1/notifications` | List all (paginated: `page`, `size`) |
| GET | `/v1/notifications/user/{userId}` | List notifications for a user (paginated) |
| DELETE | `/v1/notifications/{id}` | Delete |

## Architecture Decisions

- Fire-and-forget from Order: Order calls create and does not block on success; notification failure is logged and does not roll back the order
- No synchronous dependencies from Notification (leaf service)
- In demo, entity is stored only; production would integrate mail/SMS provider and possibly async queue (e.g. Kafka) for durability and retries
- Pagination at repository level
- POST marked `@Hidden` in Swagger so external clients are guided to use Order for “send order confirmation”; internal use remains supported

## Security

- JWT via Gateway (token relay); no external exposure; internal service-to-service and user-scoped read

## Failure Handling

- Notification creation failure → Order logs and continues; does not affect order flow
- Retry on transient failures via Gateway or Order’s WebClient
- GlobalExceptionHandler: not found → 404; generic → 500
- Gateway circuit breaker and retry apply to Notification routes

## Operational Considerations

- Scales independently; high volume could use partitioning by date or queue-based async workers
- Logging: create and delete with IDs; WARN on not-found
- Metrics: Actuator; HTTP server metrics; “notifications_created” and “delivery_failed” (when delivery is implemented) are useful
- Tracing: enabled for correlation with Order
- Monitoring: 5xx, latency; runbooks for “notification not sent”, “delivery provider down”

## Incident Scenarios

- **Notification failure** → retry; does not fail order; runbook: “Notification not received”, “Create endpoint failing”
- **Message backlog** (when event-driven) → scale consumers
- **Duplicate messages** (when event-driven) → idempotent handling
- **Ownership**: Notification team owns delivery and templates
- **Scoping**: 404/500 from Notification are clearly this service; Order logs indicate “notification failed” without failing the order
- **Postmortem**: Stored records show what was requested and when; supports “was the notification created?” and “why didn’t the user receive it?” (e.g. provider failure, wrong address)

## Evolution

- Multi-channel notifications (email, SMS, push)
- User preferences (opt-in/opt-out, channel)
- Real delivery providers (SMTP, SendGrid, etc.)
- Event-driven consumption (e.g. OrderCreated from Kafka) instead of sync HTTP from Order
- Dead-letter queue for poison messages
