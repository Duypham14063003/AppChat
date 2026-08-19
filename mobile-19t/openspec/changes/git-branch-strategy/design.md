## Context

The Nineteen Tech Internal App monorepo will contain both NestJS (backend) and Flutter (frontend) code. With multiple developers contributing, the team needs a consistent Git workflow, commit conventions, and automated CI checks before feature development begins.

Key constraints:
- Small team (< 5 devs)
- Monorepo with 2 apps (NestJS + Flutter) — different languages, different build tools
- GitHub as repo host (decided in explore session)
- Mobile app requires app store submissions (release branches needed)
- No existing CI/CD or commit conventions

## Goals / Non-Goals

**Goals:**
- Clear branching model that the whole team follows
- Automated commit message validation (Conventional Commits)
- CI pipeline that catches lint/type errors before merge
- PR template that ensures consistent review process

**Non-Goals:**
- CD (Continuous Deployment) — deferred until hosting decision (D3) is made
- App store build/release automation — deferred to later phase
- Docker image building in CI — deferred until production compose exists
- Code coverage enforcement — deferred until test suites exist

## Decisions

### D1: Modified GitHub Flow (not Git Flow, not Trunk-based)
**Choice**: `main` (protected) + short-lived `feature/*` + `release/*` for app store + `hotfix/*`
**Rationale**: Git Flow is overkill for < 5 devs (too many long-lived branches). Pure trunk-based is too aggressive for mobile apps that need app store review cycles. Modified GitHub Flow is the sweet spot.
**Alternatives**: Git Flow — rejected (overhead). Trunk-based — rejected (mobile release needs).

### D2: Conventional Commits with commitlint + husky
**Choice**: Enforce `type(scope): description` format via git hooks
**Rationale**: Enables automated changelog generation later. Consistent history. Low overhead once set up.
**Types**: feat, fix, chore, docs, style, refactor, test, build, ci, perf
**Scopes**: api, mobile, root (optional)
**Alternatives**: No enforcement — leads to inconsistent history. Squash-only merges — loses granular history.

### D3: Root package.json for monorepo tooling
**Choice**: Create `package.json` at repo root for husky, commitlint, and shared scripts
**Rationale**: Husky hooks must be at the git root. commitlint config lives at root. This is standard monorepo practice. Does NOT make this an npm workspace — just a convenience package.json.
**Alternatives**: Put husky in `apps/api/package.json` — doesn't work, husky needs to be at git root.

### D4: GitHub Actions for CI
**Choice**: Single workflow file triggered on PRs to `main`
**Rationale**: GitHub is the repo host. Actions are free for public repos, generous free tier for private. Native integration.
**Jobs**: (1) NestJS: install → lint → type-check → build, (2) Flutter: install → analyze → build (web, for speed)
**Alternatives**: GitLab CI — not applicable since GitHub is chosen.

### D5: Tag format for releases
**Choice**: `api/v1.0.0` and `mobile/v1.0.0` — separate version tracks
**Rationale**: Backend and mobile release independently. Semantic versioning for both. Prefix distinguishes which app.
**Alternatives**: Single version for both — forces coupled releases, bad for monorepo.

## Risks / Trade-offs

- **[Husky requires npm install at root]** → Developers must run `npm install` at repo root after cloning. Document in README.
- **[CI runs both NestJS and Flutter on every PR]** → Acceptable for small team. Can optimize with path filters later if CI time becomes an issue.
- **[No CD yet]** → Intentional. Deployment automation depends on hosting decision (D3 in KICKOFF). Manual deploy is fine for MVP.
- **[commitlint may frustrate initially]** → Provide cheat sheet in PR template. Team adapts quickly.

