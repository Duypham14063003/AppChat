## ADDED Requirements

### Requirement: CI workflow runs on pull requests
A GitHub Actions workflow SHALL run automatically on every pull request targeting `main`. The workflow SHALL execute lint and type-check for NestJS, and analyze for Flutter.

#### Scenario: PR triggers CI
- **WHEN** developer opens a pull request targeting `main`
- **THEN** the GitHub Actions CI workflow starts automatically

#### Scenario: CI fails on lint errors
- **WHEN** the NestJS code has ESLint errors
- **THEN** the CI workflow fails and blocks the PR merge

#### Scenario: CI fails on Flutter analysis issues
- **WHEN** the Flutter code has analysis issues
- **THEN** the CI workflow fails and blocks the PR merge

### Requirement: CI workflow has separate jobs for backend and frontend
The CI workflow SHALL have at least 2 jobs: one for NestJS (install, lint, type-check, build) and one for Flutter (install, analyze, build web). Jobs SHALL run in parallel.

#### Scenario: Both jobs run in parallel
- **WHEN** CI is triggered
- **THEN** the NestJS job and Flutter job start simultaneously

### Requirement: PR template provides review checklist
The repository SHALL contain a pull request template at `.github/pull_request_template.md` with a checklist covering: description, type of change, testing, and Conventional Commits compliance.

#### Scenario: New PR shows template
- **WHEN** developer creates a new pull request on GitHub
- **THEN** the PR description is pre-filled with the template checklist

