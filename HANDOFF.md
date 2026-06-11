# Publishing — non-root / slim image hardening: handoff

## What this is

The publishing app was converted to run as non-root on a slim image, and a
batch of build/boot bugs and CI gaps were fixed along the way. This describes
what changed and how to reproduce the deploy. The fixes live on the
`nonroot-k8s` branch of the publishing fork; the deploy config is the
`publishing-test` directory in this tarball (uncommitted — do with it as you
like).

A live-credential leak was found and remediated during this work (see
Background); the credentials gate it created is now resolved.

## Current state

- Slim image is built, deployed to `eol-dev`, and verified running: pod 1/1,
  uid 1000, no shell tooling in the runtime, clean logs (no env dump), assets
  rendering, Neo4j-backed pages working.
- On-node image size dropped from ~776 MB (fat) to ~187 MB (slim).
- Credentials gate: **resolved** — the rotated credentials blob now carries the
  `staging:` schema the app reads at boot, so images build and boot clean.

## The fixes (publishing fork, branch `nonroot-k8s`)

Run as non-root: rails UID 1000 for the cluster's restricted Pod Security
Admission. This forced a Dockerfile stage-ordering fix — the USER switch must
follow all root-level RUN steps.

Slim image: cut over from the legacy fat build to a slim multi-stage base.

Asset pipeline (this was several linked edits, all needed together):
- `config/webpacker.yml` `source_path` pointed at a nonexistent `app/webpacker`;
  real sources live at `app/javascript`. The slim build produced an empty
  manifest until this was corrected.
- `config/webpack/*.js` — the customized config the app actually uses was
  gitignored and absent from the tree; committed it from the production image.
- uglifier needs a JS runtime (execjs/Node) and was instantiating at boot. The
  slim runtime has no Node. Gated it behind `ASSETS_PRECOMPILE=true` in
  `config/environments/production.rb` and set `require: false` in the Gemfile so
  it loads only during `assets:precompile` in the build image, never in the
  running pod.

Gemfile.lock: the checked-in lock was a Rails 8 lock in a 6.1.7.7 app, causing
nondeterministic resolution. Replaced it with the resolution proven in the
production image.

CI workflow (`.github/workflows/build.yml`, new this branch): base images
pinned by digest, all actions SHA-pinned, Trivy + gitleaks scanning added.
gitleaks is scoped to pushed commits and skips blobs over 10MB to avoid OOMing
the runner. Build order is build → scan → push, and the pushed digest is
emitted for kustomize.

All actions were moved to the Node 24 generation to clear GitHub's Node 20
deprecation (Node 20 default-flips June 16 2026, removed from runners Sept 16
2026): checkout pinned to v5.0.1 (both jobs), setup-buildx to v4.1.0, login to
v4.2.0, build-push to v7.2.0 (both the build and push steps). Each new SHA was
verified to declare `runs.using: node24` before pinning. Note build-push v6→v7
is a major bump and came through the pipeline clean (build, scan, and push all
succeeded). Actions are pinned by commit SHA with a trailing `# vX.Y.Z` comment;
the SHA is authoritative, the comment is for humans — re-verify a SHA against
the tags API (`curl -s https://api.github.com/repos/<owner>/<repo>/tags`) rather
than trusting the comment. A Renovate config with the
`helpers:pinGitHubActionDigestsToSemver` preset would keep SHA pins and version
comments in sync automatically and is worth adding to prevent drift.

Topology removed from build: real internal Neo4j addresses were replaced with
resolvable `127.0.0.1` placeholder ARG defaults, so the image carries no
infrastructure detail.

Entrypoint file fix: removed a bare `set` that dumped the environment to logs.

## How to reproduce the deploy

The deploy is by immutable digest, not mutable tag.

1. Resolve the digest of the image you intend to deploy:
   ```
   skopeo inspect --format '{{.Digest}}' docker://<your-image-ref>
   ```
2. In `overlays/dev/kustomization.yaml`, set the image by digest (not tag):
   ```yaml
   images:
     - name: ghcr.io/eol/publishing
       newName: <your-registry>/publishing
       digest: sha256:<digest-from-step-1>
   ```
3. Dry-run render and confirm the image line uses `@sha256:` (with an `@`, not a
   `:` — a colon means the digest landed in the tag field and the pull will
   fail):
   ```
   kubectl kustomize overlays/dev | grep 'image:'
   ```
4. Apply and watch the rollout:
   ```
   kubectl apply -k overlays/dev
   kubectl -n eol-dev rollout status deployment/publishing-web --timeout=5m
   ```
5. Verify:
   ```
   kubectl -n eol-dev get pods                                  # 1/1 Running
   kubectl -n eol-dev exec deploy/publishing-web -- id          # uid=1000
   kubectl -n eol-dev exec deploy/publishing-web -- which vim ssh node   # empty
   kubectl -n eol-dev logs deploy/publishing-web | head -50     # no env dump
   ```
   Then in a browser: confirm CSS/JS render (asset provenance changed — a
   200-OK but unstyled page is the failure mode) and load a Neo4j-backed page
   (first real seabolt connection from the slim image).

   Rollback if needed: `kubectl -n eol-dev rollout undo deployment/publishing-web`.

### Note on `ASSETS_PRECOMPILE`

That env var must exist only in the Dockerfile's precompile step. If it leaks
into the running Deployment's env (the kustomize patch or configmap), the pod
will try to load uglifier at boot and crash the same way the original did.
Worth a grep before deploying.  I have it in the Dockerfile now.

## Background: the credential leak

A public Docker Hub image, `encoflife/eol_seabolt_rails:2024.05.09.01`,
contained a full app checkout including `.git` history and a staged
`docker/.env` with live credentials (master key, Neo4j password, secret_key_base,
JWT secret, DB password, and several API keys). All were rotated. Assume the
image was scraped; the tag should be pulled from Docker Hub. The rotation is
what created — and the restored `staging:` schema is what closed — the
credentials boot gate.

## Still open (not done in this work)

- Offline secret-history audit of the publishing repo (trufflehog + full
  gitleaks JSON). 34+ historical findings are known to exist in deep history
  (older API keys, a staging env file, CI config); the verified-live count is
  not yet established. These live in the repo's full history, not in the
  `nonroot-k8s` commits.
- Rails 6.1.7.7 → 6.1.7.10 (the EOL branch's final security patches).
- NetworkPolicy: memcached / Elasticsearch / Redis are unauthenticated, so
  network position is effectively a credential. Also a least-privilege Neo4j
  user (currently the superuser).
- Pull the legacy `encoflife/...` tag from Docker Hub once the slim image is
  established as the source of truth.
- Base image is pinned to Debian 11 (bullseye), which drives most of the OS-level
  CVE count in the Trivy scan. The pin is a documented hard constraint, not an
  oversight: the app uses an EOL fork of neo4j-ruby-driver
  (`github.com/EOL/neo4j-ruby-driver`, branch 1.7, locked at 1.7.5.*), which
  FFI-loads the seabolt C library at boot, and `eol_seabolt_rails.slim.Dockerfile`
  notes "seabolt fails to build on Debian 12" (bookworm dropped OpenSSL 1.1, which
  seabolt links against). So bullseye is load-bearing for seabolt today.
  Lifting it means getting off the seabolt/FFI path. Upstream neo4j-ruby-driver
  added a pure-Ruby Bolt implementation in its later (4.4.x) line that has no
  seabolt dependency, so the migration path exists — but this app is on a forked,
  pinned 1.7, so moving to a current driver is an application-level change to
  evaluate (reconcile the fork's changes, confirm Neo4j server version
  compatibility, and check whether TLS — neo4j+s — is required, which the older
  seabolt path handled differently). Jeremy to evaluate; this is the root lever
  for both the bullseye pin and the OS-CVE surface.

## Vulnerability scan (Trivy, currently report-only)

Trivy runs but does not fail the build (`exit-code: 0`) — it reports, it doesn't
gate. Latest run showed two scans:
- OS packages: ~565 findings (mostly HIGH). Largely a function of the bullseye
  base (see above) — many have no fixed version available in oldstable, and the
  kernel-header CVEs (`linux-libc-dev`) are not exploitable from inside the
  container since it runs no kernel of its own. The fixable subset clears by
  updating packages / a newer base, which is gated on the seabolt/bullseye issue.
- App dependencies (gems): ~22 findings (17 HIGH, 5 CRITICAL). These are the
  actionable set and are mostly addressed by the Rails 6.1.7.7 upgrade. Note one
  CRITICAL (activestorage CVE-2026-33195) lists fix versions in the 7.2/8.0/8.1
  ranges and may not have a 6.1.x backport — verify against the 6.1 branch before
  assuming 6.1.7.10 closes it; if not, it argues for the 7.x migration.

Recommended order: clear the fixable app CVEs (Rails upgrade), then flip Trivy to
`exit-code: '1'` so the gate has teeth. Flipping it before then would block every
build on the unfixable OS findings.
