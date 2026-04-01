# Edge Function Integration Tests

These tests validate input validation and error handling for Supabase Edge Functions.

## Prerequisites

- Local Supabase stack running: `docker-compose up -d` (in Pawgo-api/)
- Deno installed: `brew install deno`
- Demo user seeded: `demo@pawgo.dev` / `password123`

## Running Tests

```bash
# All Edge Function tests
deno test --allow-net --allow-env test/edge_functions/

# Individual function
deno test --allow-net --allow-env test/edge_functions/create_booking_test.ts
deno test --allow-net --allow-env test/edge_functions/confirm_payment_test.ts
deno test --allow-net --allow-env test/edge_functions/start_walk_test.ts
deno test --allow-net --allow-env test/edge_functions/end_walk_test.ts
deno test --allow-net --allow-env test/edge_functions/enable_walker_test.ts
deno test --allow-net --allow-env test/edge_functions/upload_walk_media_test.ts
deno test --allow-net --allow-env test/edge_functions/send_notification_test.ts
```

## Environment Variables (optional)

Tests default to local Supabase, but can be overridden:

```bash
SUPABASE_URL=http://localhost:8000
SUPABASE_ANON_KEY=<your-anon-key>
```

## Test Strategy

Each test file validates:
1. **Missing required fields** → HTTP 400 with descriptive error message
2. **Wrong field types** → HTTP 400 (or 404 when bad UUID fails lookup)
3. **Unauthorized caller** → HTTP 401/403
4. **Method not allowed** → HTTP 405

Tests gracefully skip when the local stack is not running.
