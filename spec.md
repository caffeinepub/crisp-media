# Crisp Media

## Current State
Full-stack ICP app (Motoko + React) rebuilt from scratch. The old project had two persistent unfixed bugs:
1. `useActor.ts` called `_initializeAccessControlWithSecret()` on every login, crashing the canister (IC0508 error)
2. `config.ts` uploadFile/downloadFile had no URL detection, causing Google Drive links to fail via CORS

This is a clean rebuild with both bugs fixed from the start.

## Requested Changes (Diff)

### Add
- Full Crisp Media landing site with gradient image background (from uploaded assets)
- Sticky navbar with circular Crisp Media logo
- Hero section with gold-accented slogan
- Services section (5 cards: Video Editing, Homestead Documentaries, Podcasts, Travel Vlogs, Short-Form Content)
- Portfolio section with admin-managed media (videos + Google Drive links)
- About/Process section
- Contact form using mailto: to crispmediabusinesses@gmail.com
- Footer (Founded 2020, no WhatsApp/Instagram)
- Admin panel: Internet Identity login, Claim Admin flow, media manager
- Portfolio items stored in stable memory (persist across deployments)
- Google Drive link support with proper !url! prefix storage

### Modify
- useActor.ts: NO call to _initializeAccessControlWithSecret -- permanently excluded
- config.ts: uploadFile detects URL-only blobs and stores !url!+URL bytes directly; downloadFile detects !url! prefix and returns URL without hitting storage gateway

### Remove
- Portfolio showcase box (per user preference)
- All testimonials
- WhatsApp and Instagram footer links

## Implementation Plan
1. Select authorization + blob-storage components
2. Generate Motoko backend with stable memory for portfolio items and admin state, claimAdminAccess function, no _initializeAccessControlWithSecret usage from frontend
3. Build frontend:
   - Background: gradient image `/assets/gradient-019d6192-bcff-73bc-810e-01cc9ed9883a.png` as full-page background
   - Logo: `/assets/crisp-media-logo.png` in circular frame in navbar
   - All sections as described
   - Admin panel wired to backend
   - useActor.ts: remove lines calling _initializeAccessControlWithSecret
   - config.ts: add !url! prefix detection in uploadFile and downloadFile
