# FoodBridge

**Rescue surplus food. Connect communities. Reduce waste.**

FoodBridge coordinates surplus-food donations from restaurants, stores, households, college kitchens, and events with NGOs, food banks, community organizations, and volunteers.

## What it includes

- Donor, NGO, volunteer, and administrator experiences
- Donation status tracking and transactional claim/pickup functions
- Nearby organization matching and OpenStreetMap location views
- Supabase Auth, PostgreSQL, Realtime, RLS, and Storage
- Gemini-assisted donation prioritization, feedback summaries, and waste insights
- Impact and waste analytics, notifications, and clearly labeled demonstration records

## Architecture

- React, TypeScript, Vite, Tailwind CSS, Wouter, generated API hooks, Recharts, and Leaflet
- Express API service for Zod-validated AI and organization-matching endpoints
- Supabase provides authentication, the product database, Realtime subscriptions, and image/document storage
- The service-role key is not used in the browser. Database permissions are enforced by RLS and narrowly scoped SQL functions.

## Configure Supabase

1. Create a Supabase project.
2. In Replit, set the non-secret environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` from the Supabase project API settings. The publishable key is intended for browser use; do not use a service-role key.
3. Apply `supabase/migrations/20261006_foodbridge_init.sql` using the Supabase SQL editor or the Supabase CLI:

   ```sh
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

4. Optional: run `supabase/seed.sql` in the SQL editor for clearly marked synthetic records. It creates 20 demo donations, 10 organizations, 15 volunteer profiles, 30 feedback entries, 30 waste logs, and 20 pickup tasks. It does not create real users or demo passwords.
5. For live authentication, enable email/password in Supabase Auth. Google sign-in works only after configuring the Google provider in Supabase.
6. The migration creates the `avatars`, `food-images`, and private `organization-documents` Storage buckets and their upload policies.

The app supports a local demo when Supabase is not configured. Demo data and changes remain in that browser and are not shared with other users.

## Roles and demo accounts

Public sign-up supports **DONOR**, **NGO**, and **VOLUNTEER** only. Create accounts through the app, then use the role-specific dashboard. NGOs must be verified before they can claim a live donation. Volunteers must set up an available volunteer profile before accepting a pickup.

To create an administrator:

1. Sign up with a normal account.
2. Confirm the email and locate that user in Supabase Auth.
3. In the SQL editor, grant administrator access to that specific account:

   ```sql
   update public.profiles
   set role = 'ADMIN'
   where id = 'REPLACE_WITH_TRUSTED_AUTH_USER_UUID';
   ```

Never grant ADMIN from the public sign-up form. For an NGO account, verify the organization's details before changing its `verified` value in the Supabase dashboard.

## Gemini setup

`GEMINI_API_KEY` is read only by the Express API service. Set it in Replit Secrets; do not use a `VITE_` environment variable or commit it. AI endpoints validate inputs, limit requests, return structured JSON, and show a safe unavailable message when AI is not configured. AI food guidance is informational and is not a food-safety determination.

Donation details, feedback text, and aggregate waste metrics sent to the AI analysis actions are transmitted to Google Gemini for processing. Avoid entering personal or sensitive information into free-text fields.

## Local development

Install workspace dependencies with `pnpm install`. Run the configured FoodBridge web and API services from the Replit workflows. The API routes are under `/api`.

Regenerate API hooks after changing the OpenAPI contract:

```sh
pnpm --filter @workspace/api-spec run codegen
```

Type-check the app and shared packages:

```sh
pnpm --filter @workspace/foodbridge run typecheck
pnpm --filter @workspace/api-server run typecheck
pnpm run typecheck
```

## Test the main flows

1. Explore the explicitly marked demo, then sign up as a donor and post a donation.
2. Sign in as an NGO with a verified organization and claim an available live donation.
3. Sign in as a volunteer with availability enabled, accept its pickup, and advance the pickup status through delivery.
4. Confirm donation/pickup updates and notifications refresh in open sessions.
5. Submit feedback and request a feedback summary.
6. Use an administrator account to review the real feedback, donations, waste logs, and analytics.

## Deployment

Configure the Supabase URL and publishable key in the target environment, keep `GEMINI_API_KEY` in Replit Secrets, apply the SQL migration to the target Supabase project, and publish the FoodBridge web artifact with the API service available at `/api`. Test sign-in, RLS, storage, and role transitions against the target Supabase project before inviting real users.

## Future improvements

- Automated organization-verification workflow and document review
- Turn-by-turn directions and delivery proofs
- Audited admin actions, richer operational reporting, and production monitoring
