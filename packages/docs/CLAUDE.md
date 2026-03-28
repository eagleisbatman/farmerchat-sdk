# CLAUDE.md — packages/docs

## Purpose
Docusaurus-powered documentation site for FarmerChat SDK.
Quickstart guides, API reference, theming docs, error codes.

## Structure
- `docs/` — Markdown documentation files
  - `intro.md` — Overview, supported platforms, architecture
  - `quickstart/` — Per-platform quickstart guides
  - `configuration/` — Config options, theming, localization
  - `error-codes.md` — Error code reference

## Rules
- Documentation is versioned alongside SDK releases.
- Each platform has its own quickstart guide.
- Code samples must be tested and working.

## Commands
```bash
pnpm start   # Dev server
pnpm build   # Production build
```
