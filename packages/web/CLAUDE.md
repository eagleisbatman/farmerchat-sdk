# CLAUDE.md — packages/web

## Purpose
Web/JavaScript SDK for FarmerChat. Published to npm.
Embeddable chat widget for web applications.

## Architecture
- Vanilla TypeScript (no React/Vue dependency)
- Uses fetch API + EventSource for SSE
- Shadow DOM for style isolation from host page
- Consumes @digitalgreenorg/farmerchat-core types directly

## Key Components
- `FarmerChat.ts` — Public API (initialize, open, close)
- `widget/ChatWidget.ts` — Shadow DOM chat container
- `widget/FAB.ts` — Floating action button
- `api/client.ts` — fetch-based HTTP client
- `api/sse.ts` — EventSource SSE handler

## Rules
- No framework dependency (no React, Vue, Angular).
- Shadow DOM for CSS isolation.
- Must work in all modern browsers (Chrome, Firefox, Safari, Edge).
- Bundle size < 100 KB gzipped.
- No external runtime dependencies.

## Commands
```bash
pnpm build   # tsup
pnpm test    # vitest
pnpm lint    # eslint
```
