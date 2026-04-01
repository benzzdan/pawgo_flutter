# Security Audit — Supabase Keys in Flutter Client

**Date:** 2026-03-30
**Scope:** `pawgo_flutter/` — full codebase search for embedded Supabase service role keys

## Summary

**PASS** — No Supabase service role key is present in the Flutter client codebase.

## Methodology

1. Searched entire `pawgo_flutter/` for `service_role`, `serviceRole`, `SERVICE_ROLE`, and `service.role`
2. Reviewed `lib/config/env.dart` (the only Supabase configuration file)
3. Verified no `.env` files exist in `pawgo_flutter/`
4. Searched for other secret-like patterns (`secret`, `private_key`, `api_key`)

## Findings

### env.dart — Only Anon Key Present

`lib/config/env.dart` contains two fields per environment:

| Field              | Local Value                          | Production Value         |
|--------------------|--------------------------------------|--------------------------|
| `supabaseUrl`      | `http://localhost:8000`              | Placeholder              |
| `supabaseAnonKey`  | Local demo JWT (anon role)           | Placeholder              |

No `serviceRoleKey` field exists in the `Env` class.

### No .env Files

No `.env`, `.env.local`, or `.env.production` files exist in the Flutter project directory. Configuration is handled entirely through `lib/config/env.dart`.

### Minor Note

`lib/screens/sign_in_screen.dart` has a hardcoded default password (`password123`) in the `TextEditingController`. This is a dev convenience for the local environment and does not constitute a secret leak, but should be removed before production release.

## GitHub Actions / CI

The Supabase service role key should only exist in:
- The backend repo (`Pawgo-api`) environment variables
- GitHub Actions secrets for the backend CI/CD pipeline

Manual verification of GitHub Actions secrets is recommended to confirm the service role key is not exposed in Flutter CI workflows.
