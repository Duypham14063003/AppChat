## 1. Root Package Setup

- [ ] 1.1 Create root `package.json` with project name, private: true, and prepare script for husky
- [ ] 1.2 Install devDependencies at root: husky, @commitlint/cli, @commitlint/config-conventional
- [ ] 1.3 Create `commitlint.config.js` extending @commitlint/config-conventional with custom scopes (api, mobile, root)

## 2. Husky Hooks

- [ ] 2.1 Initialize husky: `npx husky init`
- [ ] 2.2 Create `.husky/commit-msg` hook that runs `npx --no -- commitlint --edit $1`
- [ ] 2.3 Verify hook works: test with invalid commit message (should reject) and valid message (should accept)

## 3. GitHub Actions CI

- [ ] 3.1 Create `.github/workflows/ci.yml` with trigger on pull_request to main
- [ ] 3.2 Add NestJS job: checkout → setup Node 20 → npm ci in apps/api → lint → type-check → build
- [ ] 3.3 Add Flutter job: checkout → setup Flutter → flutter pub get in apps/mobile → analyze → build web
- [ ] 3.4 Configure jobs to run in parallel

## 4. PR Template & Branch Docs

- [ ] 4.1 Create `.github/pull_request_template.md` with description, type of change, checklist, and Conventional Commits reference
- [ ] 4.2 Document branch strategy and commit conventions in root README.md (append to existing README)

