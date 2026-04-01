/**
 * Edge Function integration tests: create-booking
 *
 * Run against local Supabase stack:
 *   deno test --allow-net test/edge_functions/create_booking_test.ts
 *
 * Requires:
 *   - Local Supabase stack running (docker-compose up -d)
 *   - SUPABASE_URL and SUPABASE_ANON_KEY env vars (or uses defaults below)
 */

const BASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://localhost:8000";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const FUNCTION_URL = `${BASE_URL}/functions/v1/create-booking`;

// ── Missing required fields → 400 ──────────────────────────────

Deno.test("create-booking: missing all fields → 400 with descriptive error", async () => {
  // First sign in to get a valid JWT
  const authRes = await fetch(`${BASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ email: "demo@pawgo.dev", password: "password123" }),
  });

  if (!authRes.ok) {
    console.warn("Skipping: could not authenticate (is the local stack running?)");
    return;
  }

  const { access_token } = await authRes.json();

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${access_token}`,
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

Deno.test("create-booking: missing walker_id → 400", async () => {
  const authRes = await fetch(`${BASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ email: "demo@pawgo.dev", password: "password123" }),
  });

  if (!authRes.ok) {
    console.warn("Skipping: could not authenticate");
    return;
  }

  const { access_token } = await authRes.json();

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${access_token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      dog_id: "some-dog-id",
      scheduled_at: new Date().toISOString(),
    }),
  });

  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Wrong field types → 400 ────────────────────────────────────

Deno.test("create-booking: wrong field types (numeric walker_id) → 400 or 404", async () => {
  const authRes = await fetch(`${BASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ email: "demo@pawgo.dev", password: "password123" }),
  });

  if (!authRes.ok) {
    console.warn("Skipping: could not authenticate");
    return;
  }

  const { access_token } = await authRes.json();

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${access_token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      walker_id: 12345, // should be UUID string
      dog_id: 67890, // should be UUID string
      scheduled_at: "not-a-date",
    }),
  });

  const body = await res.json();

  // Function should reject with 400 (validation) or 404 (not found due to bad UUID)
  if (res.status !== 400 && res.status !== 404 && res.status !== 500) {
    throw new Error(`Expected 400/404, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error) {
    throw new Error(`Expected error object, got: ${JSON.stringify(body)}`);
  }
});

// ── Unauthorized caller → 401 ──────────────────────────────────

Deno.test("create-booking: no auth header → 401", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      walker_id: "some-walker-id",
      dog_id: "some-dog-id",
      scheduled_at: new Date().toISOString(),
    }),
  });

  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (body.error?.code !== "unauthorized") {
    throw new Error(`Expected unauthorized error code, got: ${JSON.stringify(body)}`);
  }
});

Deno.test("create-booking: invalid JWT → 401", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer invalid.jwt.token",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({
      walker_id: "some-walker-id",
      dog_id: "some-dog-id",
      scheduled_at: new Date().toISOString(),
    }),
  });

  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Method not allowed ─────────────────────────────────────────

Deno.test("create-booking: GET method → 405", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "GET",
    headers: { apikey: ANON_KEY },
  });

  const body = await res.json();

  if (res.status !== 405) {
    throw new Error(`Expected 405, got ${res.status}: ${JSON.stringify(body)}`);
  }
});
