# FoodBridge

FoodBridge helps donors, community organizations, and volunteer couriers coordinate surplus-food pickups and track redistribution impact.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — API service used by FoodBridge
- `pnpm --filter @workspace/foodbridge run typecheck` — check FoodBridge TypeScript
- `pnpm run typecheck` — check all workspace packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from OpenAPI
- Apply `artifacts/foodbridge/supabase/migrations/20261006_foodbridge_init.sql` to the Supabase project before live use.
- See `artifacts/foodbridge/README.md` for required app environment and role setup.

## Stack

- pnpm workspace, TypeScript, React, Vite, Wouter, Tailwind CSS
- Shared API: Express 5, OpenAPI, Orval-generated client and Zod validation
- Product auth, database, Realtime, and uploads: Supabase
- AI analysis: Google Gemini called from the server; `GEMINI_API_KEY` must never be exposed in client variables.
- Maps: OpenStreetMap

## Where things live

- `artifacts/foodbridge` — FoodBridge frontend, Supabase migrations, seed data, and setup docs
- `artifacts/api-server` — validated server endpoints for AI and donation matching
- `lib/api-spec/openapi.yaml` — source of truth for API routes and generated hooks
- `lib/api-client-react` and `lib/api-zod` — generated API clients and validation schemas

## Architecture decisions

- Supabase is used for user auth, persistence, Realtime, and file storage as explicitly requested. Database access is protected by RLS; the browser only receives the Supabase publishable key.
- Role-sensitive pickup and claim transitions use database functions so concurrent users cannot claim the same donation or volunteer task.
- Gemini calls stay on the API server; user text and donation details submitted for AI analysis are sent to Google for processing.
- When Supabase is not configured, the frontend may show an explicitly labeled local demo experience; demo totals are not real-world impact.
- Public registration supports donor, NGO, and volunteer roles only. ADMIN must be assigned manually by a trusted operator.

## Product

FoodBridge supports donation posting, nearby organization matching, volunteer pickup coordination, role-based dashboards, impact reporting, community feedback, and AI-assisted summaries.

## User preferences

- Keep branding, UI, copy, data structure, and user flows original; use the referenced product only as broad inspiration.
- Do not present demo statistics as real impact.

## Gotchas

- The Gemini key is a server secret named `GEMINI_API_KEY`; never add a `VITE_` prefix to it.
- `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` are client-side configuration, not service-role credentials.
- Do not expose or use a Supabase service-role key in the browser.
