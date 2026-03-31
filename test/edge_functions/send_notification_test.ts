/**
 * Edge Function integration tests: send-notification
 *
 * Run: deno test --allow-net --allow-env test/edge_functions/send_notification_test.ts
 *
 * Note: send-notification uses service-role-level auth (called internally by other
 * Edge Functions). Tests verify input validation and auth checks.
 */

const BASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://localhost:8000";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";
const FUNCTION_URL = `${BASE_URL}/functions/v1/send-notification`;

// ── Missing required fields → 400 ──────────────────────────────

Deno.test("send-notification: missing all fields → 400", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({}),
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error?.message) {
    throw new Error(`Expected error.message, got: ${JSON.stringify(body)}`);
  }
});

Deno.test("send-notification: missing user_id → 400", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      type: "booking_confirmed",
      title: "Test",
      body: "Test notification",
    }),
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

Deno.test("send-notification: missing type → 400", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      user_id: "some-user-id",
      title: "Test",
      body: "Test notification",
    }),
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Wrong field types → 400 ────────────────────────────────────

Deno.test("send-notification: invalid notification type → 400", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      user_id: "some-user-id",
      type: "invalid_type",
      title: "Test",
      body: "Test notification",
    }),
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error?.message?.includes("type")) {
    throw new Error(`Expected type validation error, got: ${body.error?.message}`);
  }
});

// ── Unauthorized caller → 401 ──────────────────────────────────

Deno.test("send-notification: no auth header → 401", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({
      user_id: "some-id",
      type: "booking_confirmed",
      title: "Test",
      body: "Test",
    }),
  });
  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Method not allowed ─────────────────────────────────────────

Deno.test("send-notification: GET method → 405", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "GET",
    headers: { apikey: ANON_KEY },
  });
  const body = await res.json();

  if (res.status !== 405) {
    throw new Error(`Expected 405, got ${res.status}: ${JSON.stringify(body)}`);
  }
});
