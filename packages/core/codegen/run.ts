/**
 * Codegen entry point.
 * Generates Kotlin data classes and Swift structs from TypeScript types.
 *
 * Source types:
 *   - src/types/config.ts    -> Config.kt, Config.swift
 *   - src/types/events.ts    -> Events.kt, Events.swift
 *   - src/types/messages.ts  -> Messages.kt, Messages.swift
 *   - src/types/errors.ts    -> Errors.kt, Errors.swift
 *   - src/markdown/types.ts  -> MarkdownNode.kt, MarkdownNode.swift
 *
 * Usage:
 *   pnpm codegen            (via package.json script)
 *   npx tsx codegen/run.ts  (direct)
 */
import { generateKotlin } from './kotlin-gen';
import { generateSwift } from './swift-gen';

async function main() {
  const start = Date.now();
  console.log('Running type codegen...\n');

  console.log('[Kotlin]');
  await generateKotlin();
  console.log('  Done: MarkdownNode.kt, Messages.kt, Config.kt, Events.kt, Errors.kt\n');

  console.log('[Swift]');
  await generateSwift();
  console.log('  Done: MarkdownNode.swift, Messages.swift, Config.swift, Events.swift, Errors.swift\n');

  const elapsed = Date.now() - start;
  console.log(`Codegen complete in ${elapsed}ms.`);
}

main().catch((err) => {
  console.error('Codegen failed:', err);
  process.exit(1);
});
