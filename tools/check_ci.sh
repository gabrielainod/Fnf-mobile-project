#!/usr/bin/env bash
# Espera o run mais recente terminar e imprime o resultado + erros do relatório.
# Uso: tools/check_ci.sh [--no-wait]
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${1:-}" != "--no-wait" ]; then
  rid=$(gh run list --limit 1 --json databaseId,status -q '.[0].databaseId')
  echo "==> aguardando o run $rid terminar (gh run watch)"
  gh run watch "$rid" --interval 15 >/dev/null 2>&1 || true
  gh run view "$rid" --json status,conclusion -q '"run \(.status)/\(.conclusion)"' 2>/dev/null || true
fi
gh run list --limit 3 | cat

rm -rf /tmp/cirCI
git clone -q --depth 1 --branch ci-report https://github.com/gabrielainod/Fnf-mobile-project /tmp/cirCI 2>/dev/null || { echo "SEM RELATORIO (branch ci-report não publicado)"; exit 1; }
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
