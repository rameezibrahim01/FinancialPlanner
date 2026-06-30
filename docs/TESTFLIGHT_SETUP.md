# TestFlight automation — setup checklist

Goal: merge a PR to `main` (from any device, including the phone) → a GitHub
Actions macOS runner builds, signs, and uploads to TestFlight. **No Mac
required** at any point.

The repo files are already in place:

- `Gemfile` — fastlane dependency
- `fastlane/Appfile`, `fastlane/Matchfile`, `fastlane/Fastfile` — build + sign + upload
- `.github/workflows/testflight.yml` — triggers on push to `main` + manual run

Everything Apple-specific is read from **GitHub Actions secrets**, so nothing
private lives in the repo. Below is what's left — all doable from a browser.

---

## ✅ Already done (in this repo)
- Bundle ID set to `com.presight.financialplanner` (`project.yml` + project).
- `ITSAppUsesNonExemptEncryption = false` (skips the export-compliance prompt).
- Fastlane lanes: `beta` (build + upload) and `certificates` (one-time signing).
- Workflow wired to `push: branches: [main]` + `workflow_dispatch`.
- `.gitignore` blocks `*.p8`, `*.p12`, `*.mobileprovision`, `.env`, etc.

## ⏳ Blocked on the Apple Developer account
Do these once the paid account ($99/yr) is active.

### 1. App identity (developer.apple.com / App Store Connect)
- [ ] Register App ID `com.presight.financialplanner`.
- [ ] Create the app record in App Store Connect.

### 2. App Store Connect API key (App Store Connect → Users and Access → Integrations)
- [ ] Create a key with the **App Manager** role.
- [ ] Save **Key ID**, **Issuer ID**, download the **`.p8`**.

### 3. Team IDs (developer.apple.com → Membership)
- [ ] Note the **Team ID** (10 chars). (App Store Connect team id only if it differs.)

### 4. Certificates repo (GitHub)
- [ ] Create a **private** repo, e.g. `ios-certificates`.
- [ ] Create a token/credential CI can use to read it.

### 5. GitHub secrets (this repo → Settings → Secrets and variables → Actions)
| Secret | Value |
|---|---|
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | API Issuer ID |
| `ASC_KEY_P8` | Full contents of the `.p8` file |
| `TEAM_ID` | Apple Developer Team ID |
| `ITC_TEAM_ID` | App Store Connect team id (optional; same as TEAM_ID if unsure) |
| `MATCH_GIT_URL` | URL of the private certificates repo |
| `MATCH_PASSWORD` | A passphrase you choose (encrypts the match repo) |
| `MATCH_GIT_AUTH` | `base64("username:token")` for the certs repo |

### 6. One-time signing setup (no Mac)
- [ ] Run the workflow manually (**Actions → TestFlight → Run workflow**) with
      lane = `certificates`. This generates the distribution cert + profile in
      the cloud and stores them in the certs repo.

### 7. First build
- [ ] Run the workflow manually with lane = `beta` (or just merge to `main`).
- [ ] Wait a few minutes → the build appears in **TestFlight** → install it via
      the TestFlight app on your iPhone.

---

## How it runs after setup
- Merge any PR to `main` → `testflight.yml` fires → `fastlane beta`:
  regenerate project → fetch signing (match) → bump build number →
  archive (Release) → upload to TestFlight.
- The build number auto-increments from the latest TestFlight build, so no CI
  commit-back and no version collisions.

## Notes / TODO when wiring the real account
- Confirm `runs-on: macos-15` and `xcode-version: latest-stable` match the
  Xcode/iOS version you want to build against.
- The Fastfile uses manual signing via match (`match AppStore <bundle id>`
  profile). If you switch to Xcode-managed signing, adjust `build_app`.
- Consider Apple's free 25 Xcode-Cloud hours as an alternative if GitHub macOS
  minutes get expensive.
