#!/usr/bin/env bash
set -euo pipefail

OUT="apps/openwebui/overlays/production/sealed-secret.yaml"
KEY="$(openssl rand -hex 32)"

kubectl create secret generic openwebui-secret \
  --namespace openwebui \
  --from-literal=WEBUI_SECRET_KEY="${KEY}" \
  --dry-run=client -o yaml \
| kubeseal \
  --cert pub-cert.pem \
  --format yaml \
> "${OUT}"

echo "SealedSecret geschrieben nach ${OUT} - jetzt committen."