## ADDED Requirements

### Requirement: Commit messages follow Conventional Commits format
All commit messages SHALL follow the Conventional Commits specification: `type(scope): description`. Valid types: feat, fix, chore, docs, style, refactor, test, build, ci, perf. Scope is optional but recommended (api, mobile, root).

#### Scenario: Valid commit message accepted
- **WHEN** developer commits with message `feat(api): add health check endpoint`
- **THEN** the commit is accepted by the pre-commit hook

#### Scenario: Invalid commit message rejected
- **WHEN** developer commits with message `added stuff`
- **THEN** the commit is rejected by commitlint with an error explaining the expected format

### Requirement: Husky pre-commit hook validates commit messages
The repository SHALL have a husky commit-msg hook that runs commitlint on every commit. The hook SHALL be installed automatically when running `npm install` at the repository root.

#### Scenario: Hook installs on npm install
- **WHEN** developer runs `npm install` at the repository root
- **THEN** husky git hooks are installed in `.husky/` directory

#### Scenario: Hook runs on commit
- **WHEN** developer makes a git commit
- **THEN** the commit-msg hook executes commitlint to validate the message format

### Requirement: Root package.json exists for monorepo tooling
The repository root SHALL contain a `package.json` with husky and commitlint as devDependencies. This package.json SHALL NOT define the project as an npm workspace — it is solely for monorepo-level tooling.

#### Scenario: Root package.json has correct dependencies
- **WHEN** developer inspects the root `package.json`
- **THEN** it contains `husky`, `@commitlint/cli`, and `@commitlint/config-conventional` as devDependencies

