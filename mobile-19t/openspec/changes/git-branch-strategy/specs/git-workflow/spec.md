## ADDED Requirements

### Requirement: Branch naming follows convention
All branches SHALL follow the naming convention: `main`, `feature/<description>`, `release/<version>`, `hotfix/<description>`. Feature branches SHALL be short-lived (merged within 1-3 days).

#### Scenario: Feature branch naming
- **WHEN** developer creates a branch for a new feature
- **THEN** the branch name follows the pattern `feature/<kebab-case-description>` (e.g., `feature/add-auth-login`)

#### Scenario: Release branch naming
- **WHEN** team prepares an app store submission
- **THEN** a branch is created following the pattern `release/<version>` (e.g., `release/1.0.0`)

### Requirement: Main branch is protected
The `main` branch SHALL require pull request reviews before merging. Direct pushes to `main` SHALL be blocked.

#### Scenario: Direct push to main is rejected
- **WHEN** developer attempts to push directly to `main`
- **THEN** the push is rejected by branch protection rules

#### Scenario: PR merge requires review
- **WHEN** a pull request targets `main`
- **THEN** at least 1 approving review is required before merge is allowed

### Requirement: Release tags follow semantic versioning
Releases SHALL be tagged with the format `api/vX.Y.Z` for backend and `mobile/vX.Y.Z` for frontend, following semantic versioning.

#### Scenario: Backend release tag
- **WHEN** a backend release is finalized
- **THEN** a git tag `api/v1.0.0` is created on the merge commit to `main`

