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
