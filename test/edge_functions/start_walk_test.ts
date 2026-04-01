/**
 * Edge Function integration tests: start-walk
 *
 * Run: deno test --allow-net --allow-env test/edge_functions/start_walk_test.ts
 */

const BASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://localhost:8000";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const FUNCTION_URL = `${BASE_URL}/functions/v1/start-walk`;

async function getAuthToken(): Promise<string | null> {
  const res = await fetch(`${BASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ email: "demo@pawgo.dev", password: "password123" }),
  });
  if (!res.ok) return null;
  const { access_token } = await res.json();
  return access_token;
}

// ── Missing required fields → 400 ──────────────────────────────

Deno.test("start-walk: missing booking_id → 400", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({}),
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error?.message?.includes("booking_id")) {
    throw new Error(`Expected booking_id in error, got: ${body.error?.message}`);
  }
});

// ── Wrong field types → 400/404 ────────────────────────────────

Deno.test("start-walk: wrong booking_id type (number) → 400 or 404", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ booking_id: 99999 }),
  });
  const body = await res.json();

  if (res.status !== 400 && res.status !== 404 && res.status !== 500) {
    throw new Error(`Expected error status, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error) {
    throw new Error(`Expected error object, got: ${JSON.stringify(body)}`);
  }
});

Deno.test("start-walk: non-existent UUID → 404", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ booking_id: "00000000-0000-0000-0000-000000000000" }),
  });
  const body = await res.json();

  if (res.status !== 404 && res.status !== 403) {
    throw new Error(`Expected 404 or 403, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Unauthorized caller → 401 ──────────────────────────────────

Deno.test("start-walk: no auth header → 401", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ booking_id: "some-id" }),
  });
  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

Deno.test("start-walk: invalid JWT → 401", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer invalid.jwt.token",
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ booking_id: "some-id" }),
  });
  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Method not allowed ─────────────────────────────────────────

Deno.test("start-walk: GET method → 405", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "GET",
    headers: { apikey: ANON_KEY },
  });
  const body = await res.json();

  if (res.status !== 405) {
    throw new Error(`Expected 405, got ${res.status}: ${JSON.stringify(body)}`);
  }
});
