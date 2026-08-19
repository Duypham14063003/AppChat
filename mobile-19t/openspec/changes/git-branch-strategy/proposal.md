## Why

With the monorepo structure (Task 0.1), NestJS scaffold (Task 0.2), and Flutter scaffold (Task 0.3) in place, the team needs a consistent Git workflow before feature development begins. Without branch conventions, commit standards, and CI checks, a small team can quickly accumulate merge conflicts, inconsistent commit history, and broken builds. This is Task 0.4 in the project roadmap.

## What Changes

- Establish Modified GitHub Flow branching strategy: `main` (protected) + `feature/*` + `release/*` + `hotfix/*`
- Set up Conventional Commits enforcement via commitlint + husky at the monorepo root
- Create root `package.json` for husky/commitlint (monorepo-level tooling, not app-level)
- Create GitHub Actions CI workflow that runs on PRs: lint + type-check for NestJS, analyze for Flutter
- Create PR template with checklist
- Create branch protection rules documentation for `main`

## Capabilities

### New Capabilities
- `git-workflow`: Branch naming conventions, merge strategy, and release tagging process
- `commit-enforcement`: Conventional Commits validation via commitlint + husky pre-commit hooks
- `ci-pipeline`: GitHub Actions workflow for automated lint, type-check, and build verification on pull requests

### Modified Capabilities
<!-- No existing capabilities to modify -->

## Impact

- **Repository root**: New `package.json` (for husky/commitlint), `.husky/` directory, `commitlint.config.js`
- **`.github/`**: New `workflows/ci.yml`, `pull_request_template.md`
- **Developer workflow**: All commits must follow Conventional Commits format; PRs trigger CI checks
- **Dependencies**: commitlint, husky, @commitlint/config-conventional (devDependencies at root)
- **Subsequent tasks**: Establishes the development workflow for all future feature branches

