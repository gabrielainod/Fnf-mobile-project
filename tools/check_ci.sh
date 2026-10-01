#!/usr/bin/env bash
# Espera o run mais recente terminar e imprime o resultado + erros do relatório.
# Uso: tools/check_ci.sh [--no-wait]
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPO="$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')"

if [ "${1:-}" != "--no-wait" ]; then
  SHA="$(git rev-parse HEAD)"
  rid=""
  for _ in $(seq 1 20); do
    rid=$(gh run list --limit 10 --json databaseId,headSha -q ".[] | select(.headSha==\"$SHA\") | .databaseId" 2>/dev/null | head -1)
    [ -n "$rid" ] && break
    sleep 5
  done
  [ -z "$rid" ] && { echo "nenhum run encontrado para $SHA"; exit 1; }
  echo "==> aguardando o run $rid terminar"
  for i in $(seq 1 90); do
    st=$(gh api "repos/$REPO/actions/runs/$rid" -q .status 2>/dev/null || echo "?")
    echo "   [$i] $st"
    [ "$st" = "completed" ] && break
    sleep 20
  done
  gh api "repos/$REPO/actions/runs/$rid" -q '.status + "/" + (.conclusion // "-") + " → " + .html_url' 2>/dev/null
fi
gh run list --limit 3 | cat

rm -rf /tmp/cirCI
git clone -q --depth 1 --branch ci-report "$(git remote get-url origin)" /tmp/cirCI 2>/dev/null || { echo "SEM RELATORIO (branch ci-report não publicado)"; exit 1; }
echo "=================== RESUMO ==================="
head -14 /tmp/cirCI/reports/last-build.txt
echo "=================== ERROS ===================="
sed -n '/-- erros encontrados no log --/,/-- contexto/p' /tmp/cirCI/reports/last-build.txt | head -40
echo "=================== PRIMEIRO ERRO NO LOG ==========="
python3 - "$@" <<'PY'
import sys
lines = open('/tmp/cirCI/reports/last-build.log', encoding='utf-8', errors='replace').read().split('\n')
start = 0
for i,l in enumerate(lines):
    if 'STEP: typecheck' in l: start = i
out = [l for l in lines[start:] if l.strip() and 'MB /' not in l and 'KB /' not in l]
print('\n'.join(out[:45]))
PY
