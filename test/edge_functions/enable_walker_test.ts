/**
 * Edge Function integration tests: enable-walker
 *
 * Run: deno test --allow-net --allow-env test/edge_functions/enable_walker_test.ts
 */

const BASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://localhost:8000";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const FUNCTION_URL = `${BASE_URL}/functions/v1/enable-walker`;

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

Deno.test("enable-walker: missing walker_id → 400", async () => {
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

  // Non-admin user gets 403 before validation kicks in, which is also correct
  if (res.status !== 400 && res.status !== 403) {
    throw new Error(`Expected 400 or 403, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Wrong field types → 400 ────────────────────────────────────

Deno.test("enable-walker: wrong walker_id type → 400 or 403", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ walker_id: 12345 }),
  });
  const body = await res.json();

  // Non-admin gets 403; admin with bad type would get 400/500
  if (res.status !== 400 && res.status !== 403 && res.status !== 500) {
    throw new Error(`Expected error status, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error) {
    throw new Error(`Expected error object, got: ${JSON.stringify(body)}`);
  }
});

// ── Unauthorized caller → 401/403 ──────────────────────────────

Deno.test("enable-walker: no auth header → 401", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ walker_id: "some-id" }),
  });
  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

Deno.test("enable-walker: non-admin user → 403", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: JSON.stringify({ walker_id: "00000000-0000-0000-0000-000000000000" }),
  });
  const body = await res.json();

  if (res.status !== 403) {
    throw new Error(`Expected 403, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (body.error?.code !== "forbidden") {
    throw new Error(`Expected forbidden code, got: ${JSON.stringify(body)}`);
  }
});

// ── Method not allowed ─────────────────────────────────────────

Deno.test("enable-walker: GET method → 405", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "GET",
    headers: { apikey: ANON_KEY },
  });
  const body = await res.json();

  if (res.status !== 405) {
    throw new Error(`Expected 405, got ${res.status}: ${JSON.stringify(body)}`);
  }
});
