// Metro config for pnpm monorepo.
// pnpm uses symlinks for workspace packages; Metro must be told to watch the
// real package directories and to follow symlinks when resolving modules.
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '../..');

const config = getDefaultConfig(projectRoot);

// 1. Watch the entire monorepo so Metro sees changes in workspace packages.
config.watchFolders = [workspaceRoot];

// 2. Resolve modules from both the demo project and the monorepo root,
//    so workspace packages (pnpm symlinks) are found correctly.
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
];

// 3. Enable symlinks so pnpm's virtual store is traversed correctly.
config.resolver.unstable_enableSymlinks = true;

module.exports = config;
