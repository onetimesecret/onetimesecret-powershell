# Releasing

How the `OnetimeSecret` module gets from `main` to the PowerShell Gallery,
and the one-time setup a maintainer needs before the first release.

## Names

- **`OnetimeSecret`** is the module name on the PowerShell Gallery and the
  name people `Import-Module`. Module names are PascalCase by convention and
  must be unique on the Gallery.
- **`Ots`** is the noun prefix on every cmdlet (`New-OtsSecret`,
  `Get-OtsReceipt`), following the `Verb-PrefixNoun` convention that keeps
  cmdlets from colliding with other modules.
- **`onetimesecret-powershell`** is the repository name, matching the rest of
  the SDK family (`onetimesecret-ruby`, …). Repository and package names do not
  need to match.

## One-time setup

### 1. PowerShell Gallery account and API key

The Gallery authenticates publishes with an API key; it does not offer OIDC
trusted publishing the way RubyGems and PyPI do, so a key has to live in
GitHub as a secret.

1. Sign in at <https://www.powershellgallery.com> with the Microsoft account
   that will own the package. Use a shared organisation account, not a
   personal one, so ownership survives staff changes.
2. Go to **API Keys → Create** and create a key with:
   - **Key name**: `onetimesecret-powershell release`
   - **Expires in**: 365 days (the maximum). Put the expiry in the team
     calendar; a lapsed key is the most common reason a release fails.
   - **Scope**: *Push new packages and package versions*.
   - **Glob pattern**: `OnetimeSecret` (exact name, so the key cannot publish
     anything else).
3. Copy the key once; the Gallery will not show it again.

### 2. GitHub environment and secret

The release workflow publishes from a GitHub environment named
`powershellgallery.com` so the key is only exposed to tagged releases.

1. **Settings → Environments → New environment**: `powershellgallery.com`.
2. **Deployment branches and tags**: *Selected branches and tags* → add the
   tag rule `v*`.
3. Optionally add **Required reviewers** for a human gate before publish.
4. Under the environment's **Secrets**, add `PSGALLERY_API_KEY` with the key
   from step 1.

Referencing an environment from a workflow creates it unprotected, so do
this before the first tag, not after.

### 3. Optional: integration tests in CI

The guest-endpoint integration tests run on `main` and on the daily schedule
when a repository **variable** (not secret) `ONETIME_BASE_URL` is set, e.g.
`https://eu.onetimesecret.com`. They only use anonymous endpoints and burn or
reveal everything they create.

### 4. Local tooling

```powershell
./build.ps1 -Bootstrap     # installs InvokeBuild, Pester 5, PSScriptAnalyzer, platyPS
./build.ps1                # Analyze + Test
./build.ps1 -Task ?        # list tasks
```

## Versioning

Semantic versioning. The module stays at `0.x` until the cmdlet surface has
settled; within `0.x`, a minor bump may change parameters or output shapes
and the changelog says so.

The version lives in exactly one place:
`src/OnetimeSecret/OnetimeSecret.psd1` → `ModuleVersion`, plus
`PrivateData.PSData.Prerelease` for a preview label. The release workflow
refuses to publish if the tag does not match both.

Prerelease labels follow the Gallery's rules: alphanumerics only, no dots or
hyphens (`preview1`, `rc2`). A prerelease is only installed when the user
passes `-AllowPrerelease`, which makes it the right vehicle for trying a
breaking change with early adopters.

## Cutting a release

1. Make sure `main` is green in CI on all four matrix legs (PowerShell 7 on
   Linux/macOS/Windows and Windows PowerShell 5.1).
2. Set `ModuleVersion` (and `Prerelease`, or clear it) in
   `src/OnetimeSecret/OnetimeSecret.psd1`.
3. Move the `## [Unreleased]` notes in `CHANGELOG.md` into a new
   `## [X.Y.Z] - YYYY-MM-DD` section (for a prerelease, `## [X.Y.Z-label]`).
   The workflow fails without a matching section.
4. If cmdlet help changed, regenerate the reference docs and commit them:

   ```powershell
   ./build.ps1 -Task Docs
   ```

5. Commit:

   ```sh
   git commit -am "Release 0.2.0"
   git push origin main
   ```

6. Tag and push the tag:

   ```sh
   git tag -a v0.2.0 -m "OnetimeSecret 0.2.0"
   git push origin v0.2.0
   ```

The tag runs `.github/workflows/release.yml`, which:

- checks the tag against the manifest and the changelog,
- runs PSScriptAnalyzer and the Pester suite,
- builds the single-file module into `output/OnetimeSecret/<version>/`,
- publishes it to the Gallery with `Publish-Module`,
- creates a GitHub Release with the changelog section as notes and the
  packaged zip attached (marked *pre-release* when the tag has a label).

Verify:

```powershell
Find-Module OnetimeSecret -AllVersions -AllowPrerelease
Install-Module OnetimeSecret -RequiredVersion 0.2.0 -Scope CurrentUser
Get-Command -Module OnetimeSecret
```

The Gallery indexes a new version within a few minutes; `Find-Module` may lag
briefly behind the web page.

## If a release goes wrong

- **Publish failed, nothing on the Gallery**: fix the problem, delete the tag
  locally and remotely (`git tag -d v0.2.0; git push origin :refs/tags/v0.2.0`),
  and tag again. Nothing has been consumed.
- **Published but broken**: the Gallery never lets a version be re-published,
  so ship a fix as `0.2.1`. Then **unlist** the bad version on the Gallery
  (package page → *Manage* → uncheck *Listed*). Unlisting hides it from
  `Find-Module` while still serving it to anyone who pinned it. Do not expect
  to delete it.
- **Key expired or rotated**: create a new key (step 1), update the
  `PSGALLERY_API_KEY` secret, re-run the failed *publish* job from the
  Actions tab. The *verify* job's results are reused.

## Publishing by hand

Only when the workflow is unavailable. Same checks, from a clean checkout of
the tag:

```powershell
$env:PSGALLERY_API_KEY = '<key>'
./build.ps1 -Task Analyze, Test, Publish
```

`Publish` refuses to run if the version already exists on the Gallery.
