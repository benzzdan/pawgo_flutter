/**
 * Edge Function integration tests: upload-walk-media
 *
 * Run: deno test --allow-net --allow-env test/edge_functions/upload_walk_media_test.ts
 */

const BASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://localhost:8000";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const FUNCTION_URL = `${BASE_URL}/functions/v1/upload-walk-media`;

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

Deno.test("upload-walk-media: missing file and booking_id → 400", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  // Send empty form data
  const formData = new FormData();
  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: formData,
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error?.message) {
    throw new Error(`Expected error.message, got: ${JSON.stringify(body)}`);
  }
});

Deno.test("upload-walk-media: missing file (only booking_id) → 400", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const formData = new FormData();
  formData.append("booking_id", "some-booking-id");

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: formData,
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Wrong field types → 400 ────────────────────────────────────

Deno.test("upload-walk-media: unsupported file type → 400", async () => {
  const token = await getAuthToken();
  if (!token) { console.warn("Skipping: no auth"); return; }

  const formData = new FormData();
  formData.append("booking_id", "00000000-0000-0000-0000-000000000000");
  formData.append(
    "file",
    new File(["malicious content"], "test.exe", { type: "application/x-msdownload" })
  );

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
    },
    body: formData,
  });
  const body = await res.json();

  if (res.status !== 400) {
    throw new Error(`Expected 400, got ${res.status}: ${JSON.stringify(body)}`);
  }
  if (!body.error?.message?.includes("type")) {
    throw new Error(`Expected file type error, got: ${body.error?.message}`);
  }
});

// ── Unauthorized caller → 401 ──────────────────────────────────

Deno.test("upload-walk-media: no auth header → 401", async () => {
  const formData = new FormData();
  formData.append("booking_id", "some-id");

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: { apikey: ANON_KEY },
    body: formData,
  });
  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

Deno.test("upload-walk-media: invalid JWT → 401", async () => {
  const formData = new FormData();
  formData.append("booking_id", "some-id");

  const res = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      Authorization: "Bearer invalid.jwt.token",
      apikey: ANON_KEY,
    },
    body: formData,
  });
  const body = await res.json();

  if (res.status !== 401) {
    throw new Error(`Expected 401, got ${res.status}: ${JSON.stringify(body)}`);
  }
});

// ── Method not allowed ─────────────────────────────────────────

Deno.test("upload-walk-media: GET method → 405", async () => {
  const res = await fetch(FUNCTION_URL, {
    method: "GET",
    headers: { apikey: ANON_KEY },
  });
  const body = await res.json();

  if (res.status !== 405) {
    throw new Error(`Expected 405, got ${res.status}: ${JSON.stringify(body)}`);
  }
});
