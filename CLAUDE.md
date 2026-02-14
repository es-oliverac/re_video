# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Revideo Architecture

Revideo is a monorepo managed with Lerna, consisting of 13 packages that work together to provide a programmatic video editing framework forked from Motion Canvas.

### Core Packages

- **@revideo/core**: Foundation package containing animation engine logic including:
  - `app/` - Application lifecycle and management
  - `scenes/` - Scene management and execution
  - `flow/` - Control flow (yield-based animations, threads, tasks)
  - `tweening/` - Tweening and value interpolation
  - `transitions/` - Scene transitions
  - `signals/` - Reactive signals
  - `events/` - Event system
  - `media/` - Media handling
  - `decorators/` - Decorators for metadata

- **@revideo/2d**: 2D renderer with components like `<Img>`, `<Video>`, `<Audio>`. Structure:
  - `src/lib/` - Library components and utilities
  - `src/editor/` - Editor-specific code
  - Has two build outputs: `lib/` (library) and `editor/` (editor bundle)

- **@revideo/renderer**: Headless rendering service. Split into:
  - `client/` - Browser-side rendering code
  - `server/` - Server-side rendering code using Puppeteer
  - Uses FFmpeg for video export

- **@revideo/ffmpeg**: FFmpeg wrappers and utilities for video processing

### Development Tools

- **@revideo/vite-plugin**: Vite plugin handling backend functionality through HTTP middleware. Key insight: Revideo doesn't have a traditional backend server - all server functionality is implemented as Vite plugins (see `vite-plugin/src/partials/` for various plugins like `ffmpegExporter.ts`, `metaHandler.ts`)

- **@revideo/cli**: Command-line interface (`revideo` command) for running render servers

- **@revideo/create**: Project scaffolding (`npm init @revideo`)

### User-Facing Packages

- **@revideo/ui**: Visual editor built with Preact
- **@revideo/player**: Web component player
- **@revideo/player-react**: React wrapper for the player
- **@revideo/template**: Example project used for development and testing
- **@revideo/examples**: Documentation examples
- **@revideo/e2e**: End-to-end tests
- **@revideo/telemetry**: Anonymous usage tracking via PostHog (disable with `DISABLE_TELEMETRY=true`)

## Development Commands

### Building
```bash
# Build all packages
npx lerna run build

# Build specific package
npm run core:build      # or 2d:build, renderer:build, etc.

# Build with fresh logs (skip cache)
npx lerna run build --skip-nx-cache
```

### Development
```bash
# Work on the template project (recommended for testing changes)
npm run template:dev      # Start dev server
npm run template:render   # Render video

# Watch-mode build for specific packages
npm run core:dev          # Watch core
npm run 2d:dev            # Watch 2d
npm run renderer:build     # Build renderer (no watch)
```

### Testing
```bash
npm run core:test          # Unit tests for core
npm run 2d:test            # Unit tests for 2d
npm run e2e:test           # End-to-end tests
```

### Linting & Formatting
```bash
npm run eslint             # Check linting
npm run eslint:fix        # Fix linting issues
npm run prettier          # Check formatting
npm run prettier:fix      # Fix formatting issues
```

## Key Implementation Details

### Vite Plugin Architecture
All server-side functionality is implemented as Vite plugins in `packages/vite-plugin/src/partials/`:
- `ffmpegExporter.ts` - Websocket communication for video export
- `metaHandler.ts` - Read/write `.meta` files
- `versionPlugin.ts` - Version checking
- No traditional Express/Fastify backend - everything is Vite middleware

### Scene System
Scenes are generator functions using `yield` for animation sequencing:
```tsx
export default makeScene2D('scene', function* (view) {
  const ref = createRef<Img>();
  view.add(<Img ref={ref} src="..." />);
  yield* all(ref().scale(2, 1));
});
```

### Lerna Configuration
- Version: `0.10.4` (in lerna.json)
- Uses `useNx: true` for Nx-based caching
- Conventional commits required (e.g., `feat:`, `fix(core):`, `chore:`)
- CI runs `.github/workflows/verify.yml`

### TypeScript Configurations
- Root: TypeScript 5.2.2
- ESLint with TSDoc enforcement required
- Naming convention enforced: camelCase for variables/functions, PascalCase for types
- Type imports must be separate: `import type { ... }`

## Code Style

Run `npm run prettier:fix` before committing. The project enforces:
- TSDoc comments on all public APIs
- Consistent type imports
- No leading/trailing underscores (except unused parameters: `_parameter`)
- Getter/setter pairs with getter before setter

## Testing Your Changes

Use `packages/template` as your test project:
1. Make changes to packages
2. Run `npx lerna run build` from root
3. Run `npm run template:dev` or `npm run template:render` to test

## CI/CD Requirements

For PRs to pass verification:
1. `npx lerna run build` - must succeed
2. `npx prettier --write .` - formatting correct
3. Conventional commits - proper commit message format
