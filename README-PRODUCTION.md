# Noura Production Integrity Build

Key fixes: durable vendor slugs, `/store/:slug` Vercel rewrites, vendor→restaurant synchronization, real admin Supabase reads/RPCs, storage policies for vendor/user images, vendor PWA, and storefront canonical URLs.

## Deploy
1. Upload this folder to the Noura repo root.
2. Run `auto_trigger.sql` in Supabase SQL Editor.
3. Deploy `vercel.json` with the HTML files.
4. Ensure the Supabase project URL/anon key remain the same as the existing app.
5. Create at least one Supabase admin account and set its `profiles.role` to `admin` or `super_admin`.
6. Test a fresh vendor registration, then open `/store/<slug>`, refresh, and test the logo/cover upload.

The clean storefront route is now resolved by Vercel to `store.html?v=<slug>`. Subdomain URLs such as `noura.nourafood.vercel.app` require a separately configured wildcard/custom domain; the package does not pretend that Vercel provides that automatically.

## AUTH FIX — 15 AUG 2026

The consumer authentication flow was hardened so a successful Supabase login is not rejected just because profile hydration has a transient RLS/database problem. Supabase sessions are restored on refresh/OAuth return, and the profile is upserted during onboarding.

### Google sign-in requirement
Google OAuth is handled by Supabase Auth. The frontend does not need a Google client secret.

In Supabase:
1. Authentication → Providers → Google → enable it and enter the Google OAuth client ID/secret.
2. Google Cloud OAuth redirect URI must be the Supabase callback:
   `https://qkuznrnxclppvorpomcr.supabase.co/auth/v1/callback`
3. Supabase Authentication → URL Configuration → add:
   `https://nourafood.vercel.app/`
4. Redeploy the root files so `index.html` and the updated SQL are live.

Run the updated `auto_trigger.sql` once in the Supabase SQL Editor. It adds a real UNIQUE constraint for `vendors.auth_user_id`, removes recursive profile-admin RLS checks, and allows authenticated users to create/upsert their own profile row.

## PWA / ROUTING INTEGRITY PASS — 2026-08-15

This build keeps the consumer and vendor PWAs separate and fixes the clean URL routing.

- Consumer PWA: `/` → `manifest.json` + `/sw.js`
- Vendor PWA: `/vendor` → `manifest-vendor.json` + `/sw-vendor.js`
- Vendor service worker is scoped to `/vendor` and no longer claims the whole origin.
- Consumer service worker no longer hijacks `/vendor`, `/admin`, `/landing`, or dynamic `/store/:slug` routes.
- Dynamic storefronts use `/store/:slug` and resolve the slug from the browser path/query.
- `/admin` → `admin.html`
- `/landing` → `landing.html`
- Internal index navigation uses the clean routes instead of nonexistent `noura-*.html` filenames.
- Manifest, favicon and Apple touch-icon references use root-safe paths.
- Icon files are valid PNGs with the declared dimensions.
- `vercel.json` supplies the service-worker and manifest MIME/cache headers.

### Deployment

Deploy every file in this ZIP at the project root. Do not put the files inside an `icons/`, `public/`, or other folder unless the deployment setup is intentionally changed to match.

After deployment, clear the old service worker once on a device/browser that previously opened Noura so the new `noura-consumer-shell-v4` / `noura-vendor-shell-v4` workers can take control.
