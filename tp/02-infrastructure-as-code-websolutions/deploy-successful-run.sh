#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage : bash deploy-successful-run.sh <numero-du-run-github>"
  exit 2
fi

run_id="$1"
repo="JulienGrade/correction-iac-maalsi26-lille"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tp="$root/tp/02-infrastructure-as-code-websolutions"
infra="$tp/infra"
release_vars="$infra/release.auto.tfvars"
workdir="$(mktemp -d)"
applied=0
had_release=0

if [[ -f "$release_vars" ]]; then
  cp "$release_vars" "$workdir/previous-release.tfvars"
  had_release=1
fi

cleanup() {
  if [[ "$applied" -eq 0 ]]; then
    if [[ "$had_release" -eq 1 ]]; then
      cp "$workdir/previous-release.tfvars" "$release_vars"
    else
      rm -f "$release_vars"
    fi
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

echo "Attente de la CI : run $run_id"
gh run watch "$run_id" -R "$repo" --exit-status --compact

conclusion="$(gh run view "$run_id" -R "$repo" --json conclusion --jq '.conclusion')"
workflow="$(gh run view "$run_id" -R "$repo" --json workflowName --jq '.workflowName')"
sha="$(gh run view "$run_id" -R "$repo" --json headSha --jq '.headSha')"

if [[ "$conclusion" != "success" ||
      "$workflow" != "WebSolutions - Tests et image" ||
      ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Run non conforme : aucun déploiement."
  exit 1
fi

echo "Téléchargement de l'image du commit $sha"
gh run download "$run_id" -R "$repo" \
  -n "websolutions-image-$sha" -D "$workdir"
gzip -t "$workdir/websolutions-image.tar.gz"

gzip -dc "$workdir/websolutions-image.tar.gz" |
  docker --context websolutions-vm image load

image_id="$(docker --context websolutions-vm image inspect \
  --format '{{.Id}}' "websolutions-api:$sha")"

cat > "$release_vars" <<EOF
api_image_id = "$image_id"
app_version  = "$sha"
EOF

plan="$workdir/websolutions.tfplan"
tofu -chdir="$infra" plan -out="$plan"

plan_details="$(tofu -chdir="$infra" show -no-color "$plan")"
printf '%s\n' "$plan_details"

resources="$(printf '%s\n' "$plan_details" | grep '^  # ' || true)"
if [[ "$resources" != "  # docker_container.api must be replaced" ]]; then
  echo "Le plan ne remplace pas uniquement l'API : déploiement arrêté."
  exit 1
fi

tofu -chdir="$infra" apply "$plan"
applied=1

ansible-playbook -i "$tp/ansible/inventory.ini" \
  "$tp/ansible/configure.yml" -K

health="$(curl -fsS --retry 10 --retry-delay 2 \
  "http://192.168.56.20:8081/health")"
printf '%s\n' "$health"

if [[ "$health" != *'"status":"ok"'* ||
      "$health" != *'"database":"ok"'* ||
      "$health" != *"\"version\":\"$sha\""* ]]; then
  echo "La route de santé ne confirme pas la version $sha."
  exit 1
fi

echo "Livraison vérifiée : $sha"