#!/usr/bin/env bash
# Sincroniza o histórico local com o remoto e commita o estado atual da árvore.
# (o snapshot do sandbox às vezes restaura um .git mais antigo; este script
#  recoloca o HEAD no topo do branch e commita o que estiver na árvore)
# Uso: tools/sync_push.sh "mensagem do commit"
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="arena/01a0f99d-fnf-mobile-project"

if ! git fetch -q --force origin "refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"; then
  echo "ERRO: git fetch falhou (sem isso, o push seria rejeitado)"
  exit 1
fi
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/$BRANCH")"
echo "local:  $LOCAL"
echo "remoto: $REMOTE"
if [ "$LOCAL" != "$REMOTE" ]; then
  if ! git merge-base --is-ancestor "$REMOTE" HEAD 2>/dev/null; then
    echo "==> recolocando o HEAD no topo do remoto (arvore preservada)"
    git reset --mixed "origin/$BRANCH" >/dev/null
  fi
fi
git add -A
git -c user.email=agent@arena.ai -c user.name=agent commit -q -m "$1" || echo "(nada para commitar)"
git push -q origin HEAD:refs/heads/$BRANCH && echo "PUSH_OK $(git rev-parse --short HEAD)"
