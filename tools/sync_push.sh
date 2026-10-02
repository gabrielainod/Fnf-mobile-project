#!/usr/bin/env bash
# Sincroniza o histórico local com o remoto e commita o estado atual da árvore.
# (o snapshot do sandbox às vezes restaura um .git mais antigo; este script
#  recoloca o HEAD no topo do branch e commita o que estiver na árvore)
# Uso: tools/sync_push.sh "mensagem do commit"
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="arena/01a0f99d-fnf-mobile-project"

git fetch -q origin "$BRANCH" || true
if ! git merge-base --is-ancestor HEAD "origin/$BRANCH" 2>/dev/null; then
  git reset --mixed "origin/$BRANCH" >/dev/null
fi
git add -A
git -c user.email=agent@arena.ai -c user.name=agent commit -q -m "$1" || echo "(nada para commitar)"
git push -q origin HEAD:refs/heads/$BRANCH && echo "PUSH_OK $(git rev-parse --short HEAD)"
