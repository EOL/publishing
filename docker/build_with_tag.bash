#!/usr/bin/env bash
set -euo pipefail

readenv # your existing alias/function

IMAGE_BASE="ghcr.io/eol/publishing"
GIT_SHA="$(git rev-parse --short=12 HEAD)"

case "${RAILS_ENV:?RAILS_ENV is required}" in
  staging)
    TAG="staging-${GIT_SHA}"
    ;;
  production)
    TAG="production-${GIT_SHA}"
    ;;
  *)
    echo "Refusing to build: unsupported RAILS_ENV=${RAILS_ENV}" >&2
    exit 1
    ;;
esac

IMAGE="${IMAGE_BASE}:${TAG}"

docker build \
  --target app \
  --secret id=rails_master_key,env=RAILS_MASTER_KEY \
  --secret id=traitbank_url,env=TRAITBANK_URL \
  --secret id=neo4j_user,env=NEO4J_USER \
  --secret id=neo4j_password,env=NEO4J_PASSWORD \
  --build-arg rails_env="$RAILS_ENV" \
  --build-arg neo4j_driver_url="$NEO4J_DRIVER_URL" \
  --build-arg eol_github_email="$EOL_GITHUB_EMAIL" \
  --build-arg eol_github_user="$EOL_GITHUB_USER" \
  -t "$IMAGE" \
  ..

echo "Built $IMAGE"
echo "Now checking for security breaches:"

docker history --no-trunc "$IMAGE" | grep -Ei 'master|traitbank|password|scout|neo4j' || true
docker run --rm "$IMAGE" env | grep -Ei 'RAILS_MASTER|TRAITBANK|PASSWORD|SCOUT' && {
  echo "Secret-looking runtime env vars appeared in image output; refusing to push." >&2
  exit 1
} || true

docker push "$IMAGE"

DIGEST="$(docker buildx imagetools inspect "$IMAGE" \
  --format '{{json .Manifest.Digest}}' | tr -d '"')"

IMAGE_DIGEST="${IMAGE_BASE}@${DIGEST}"

echo
echo "Pushed tag:"
echo "  $IMAGE"
echo
echo "Deployable digest reference:"
echo "  $IMAGE_DIGEST"