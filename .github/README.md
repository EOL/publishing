# CI/CD — publishing → eol-talos

Shared workflow: [`.github/workflows/build.yml`](workflows/build.yml).
One pipeline for both environments; branch selects Environment, Rails build
env, and which kubecfg overlay gets the digest pin.

| Git branch   | GitHub Environment | `RAILS_ENV` (image build) | Digest pin (EOL/kubecfg)           | Namespace    |
|--------------|--------------------|---------------------------|------------------------------------|--------------|
| `main`       | `staging`          | `staging`                 | `publishing/overlays/staging`      | `eol-staging`|
| `production` | `production`       | `production`              | `publishing/overlays/prod`         | `eol-prod`   |

**What CI does:** gitleaks → Docker build → Trivy (report-only) → push
`ghcr.io/eol/publishing:nonroot-<sha>` → print digest for kustomize.

**What CI does not do:** `kubectl apply`, Ingress/TLS (those live in
**talos-config**), or writing cluster Secrets. Runtime secrets are SOPS files
in kubecfg, applied separately (`sops --decrypt … \| kubectl apply -f -`).

## Digest pin (staging and prod)

After a green build, open the job Summary, copy the `digest:` block into the
matching overlay’s `kustomization.yaml`, commit in **EOL/kubecfg**, then:

```sh
kubectl apply -k publishing/overlays/staging   # or .../prod
```

Same digest-pin workflow for both; only the overlay path / namespace changes.
Do not add Ingress/TLS apply steps here.

## Secrets and Environment setup

### GitHub Environments (repo: `EOL/publishing`)

Create / keep Environments named exactly:

- `staging`
- `production` — enable **Required reviewers** (Settings → Environments →
  `production` → Protection rules). Staging may stay unprotected for
  day-to-day pushes to `main`.

### Environment secrets (build-time only)

Set these on **each** Environment (`staging` and `production`). They decrypt
Rails credentials during `assets:precompile` in the Docker build. They are
**not** a substitute for kubecfg SOPS runtime secrets.

| Name               | Scope                         | Purpose                                      |
|--------------------|-------------------------------|----------------------------------------------|
| `RAILS_MASTER_KEY` | Environment `staging`         | Decrypt staging Rails credentials at build   |
| `NEO4J_PASSWORD`   | Environment `staging`         | Satisfy Neo4j boot during assets precompile  |
| `RAILS_MASTER_KEY` | Environment `production`      | Decrypt **production** credentials at build  |
| `NEO4J_PASSWORD`   | Environment `production`      | Same, for production-keyed builds            |

Use the production master key that matches the production credentials blob;
do not reuse staging values.

### Do **not** put these in Actions

Cluster / runtime values stay in kubecfg (SOPS → `kubectl apply`):

- `RAILS_MASTER_KEY` (as a Kubernetes Secret key in `publishing-secrets`)
- `NEO4J_*` / Neo4j auth (`neo4j-secrets`)
- `MYSQL_*` / MySQL root or app DB secrets (`mysql-secrets`)

GitHub Actions only needs the two Environment secrets above so the image can
build. Topology and live DB passwords never belong in the workflow file.

### Repo-level secrets / vars

None required for this path. Image push uses the built-in `GITHUB_TOKEN`
(`packages: write`). No `vars.*` are used.

### GHCR

Package: `ghcr.io/eol/publishing`. Ensure the workflow can write packages
(see header comments in `build.yml`).

## Manual dispatch

`workflow_dispatch` on a non-`production` ref uses the **staging** Environment
and overlay (same ternary as pushes). Dispatch from `production` to build
with the production Environment (subject to Required reviewers).
