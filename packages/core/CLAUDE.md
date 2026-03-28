# CLAUDE.md — packages/core

## Purpose
Platform-agnostic shared logic: API client, types, SSE parser, retry logic, constants.
This package is the single source of truth for all data types used across SDKs.

## Key Files
- `src/api/client.ts` — HTTP client abstraction (platform-specific implementations inject fetch)
- `src/api/sse-parser.ts` — Parse SSE text streams into typed events
- `src/api/retry.ts` — Exponential backoff with max retries
- `src/api/endpoints.ts` — API endpoint definitions
- `src/types/config.ts` — FarmerChatConfig, ThemeConfig, CrashConfig
- `src/types/events.ts` — All SDK callback event types
- `src/types/messages.ts` — Query, Response, FollowUp, Feedback types
- `src/types/errors.ts` — FarmerChatError class + error code enum
- `src/constants/defaults.ts` — Default values for all config options
- `src/constants/error-codes.ts` — Enumerated error codes
- `src/constants/languages.json` — Bundled language fallback list (server is primary source)
- `codegen/kotlin-gen.ts` — Generates Kotlin data classes from TS types
- `codegen/swift-gen.ts` — Generates Swift structs from TS types

## Rules
- Every exported type MUST have JSDoc comments (used by codegen).
- Never import platform-specific code (no 'react-native', no 'android', no 'swift').
- All API response types must handle partial/streaming data.
- Error codes are in `constants/error-codes.ts` — add new codes there, not inline.
- Languages list is a fallback — the primary source is the server API.

## Commands
```bash
pnpm test    # Vitest
pnpm build   # tsup
pnpm codegen # Generate Kotlin + Swift types
```
