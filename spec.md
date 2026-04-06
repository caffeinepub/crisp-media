# Crisp Media

## Current State
The site is fully functional with a Motoko backend and React frontend. The backend stores portfolio items and admin access control state in non-stable variables (`var portfolioItems` and `let accessControlState`), which means all data is wiped on every canister upgrade/deployment.

## Requested Changes (Diff)

### Add
- `stable var stablePortfolioItems`, `stable var stableAdminAssigned`, `stable var stableAdminPrincipals` to persist data across upgrades
- `preupgrade` system hook to save mutable state to stable vars before upgrades
- `postupgrade` system hook to restore mutable state from stable vars after upgrades

### Modify
- `accessControlState` initialization: now directly reads from stable vars so admin assignment survives upgrades
- `portfolioItems` initialization: now reads from `stablePortfolioItems` so portfolio items survive upgrades

### Remove
- Nothing removed from the frontend or API surface

## Implementation Plan
1. Rewrite `src/backend/main.mo` to use stable storage for portfolio items and admin state
2. No frontend changes required -- the API surface is unchanged
3. Deploy
