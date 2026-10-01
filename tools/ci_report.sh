#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Publica o resultado do build:
#   1. cria/atualiza o GitHub Release com o APK (link fixo para instalar)
#   2. commita relatório + log + keystore no branch "ci-report"
#      (assim o build se reporta mesmo quando o log do Actions não é legível)
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG="$ROOT/build.log"
STATUS_FILE="$ROOT/.ci-status"
STATUS="$(cat "$STATUS_FILE" 2>/dev/null || echo 'FAIL:desconhecido')"
APK="$(cat "$ROOT/.apk-final" 2>/dev/null || echo '')"
REPORT="$ROOT/report.txt"
RELEASE_TAG="${RELEASE_TAG:-v1.0.0-mobile}"

RUN_NUMBER="${GITHUB_RUN_NUMBER:-local}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-local}/actions/runs/${GITHUB_RUN_ID:-0}"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
COMMIT_MSG="$(git log -1 --pretty=%s 2>/dev/null || echo '?')"

# ------------------------------------------------------------------ relatório
{
	echo "FNF Mobile — relatório de build"
	echo "================================"
	echo "status    : $STATUS"
	echo "run       : #$RUN_NUMBER"
	echo "run url   : $RUN_URL"
	echo "commit    : $COMMIT — $COMMIT_MSG"
	echo "data      : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
	echo ""
	if [ -n "$APK" ] && [ -f "$APK" ]; then
		echo "APK       : $(basename "$APK")"
		echo "tamanho   : $(du -h "$APK" | cut -f1) ($(stat -c%s "$APK") bytes)"
		echo "sha256    : $(sha256sum "$APK" | cut -d' ' -f1)"
		echo ""
		echo "-- libs nativas no APK --"
		unzip -l "$APK" | grep -E "lib/(arm64-v8a|armeabi-v7a)/" || true
		echo ""
		echo "-- verificação de assinatura --"
		BT="$ANDROID_SDK/build-tools/30.0.3"
		[ -x "$BT/apksigner" ] && "$BT/apksigner" verify --print-certs "$APK" 2>&1 | head -10 || true
	else
		echo "APK       : (nenhum APK gerado)"
	fi
	echo ""
	echo "-- marcos do log --"
	grep -E "^########## (STEP|OK|FALHOU)" "$LOG" 2>/dev/null || true
	echo ""
	echo "-- erros encontrados no log --"
	grep -n -i -E "error|error:|fatal|exception|failed|não encontrado|no such file" "$LOG" 2>/dev/null | head -60 || echo "(nenhum)"
	echo ""
	echo "-- contexto dos primeiros erros --"
	grep -n -i -B6 -A18 -m2 -E "^[^#]*error|ERROR:|exception|fatal" "$LOG" 2>/dev/null || echo "(nada)"
	echo ""
	echo "-- últimas 200 linhas do log --"
	tail -200 "$LOG" 2>/dev/null
} > "$REPORT" 2>&1

echo "==> Relatório:"
head -40 "$REPORT"

# --------------------------------------------------------------------- release
if [ -n "$APK" ] && [ -f "$APK" ] && [ -n "${GH_TOKEN:-}" ]; then
	echo "==> Publicando release $RELEASE_TAG"
	if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
		gh release upload "$RELEASE_TAG" "$APK" --clobber && echo "APK anexado à release existente"
	else
		gh release create "$RELEASE_TAG" "$APK" \
			--title "FNF Mobile — Semanas 1-3 (APK)" \
			--notes "APK do Friday Night Funkin' com compatibilidade mobile feita sob medida (controles por hitbox, otimizações para aparelhos fracos e suporte a mods).

Build #$RUN_NUMBER — commit $COMMIT
Status: $STATUS

Instalação: baixe o APK no celular e abra (pode ser preciso permitir 'instalar de fontes desconhecidas').
Mods: coloque as pastas de mod dentro de 'Android/data/com.fnfmobile.game/files/mods' no aparelho.
" && echo "release criada"
	fi
fi

# --------------------------------------------- relatório + keystore em um branch
if [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
	REMOTE="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
	WORK="/tmp/ci-report-repo"
	rm -rf "$WORK"
	if git clone -q --depth 1 --branch ci-report "$REMOTE" "$WORK" 2>/dev/null; then
		echo "branch ci-report existente"
	else
		mkdir -p "$WORK"
		git -C "$WORK" init -q
		git -C "$WORK" remote add origin "$REMOTE"
	fi
	mkdir -p "$WORK/reports" "$WORK/signing"
	cp "$REPORT" "$WORK/reports/last-build.txt"
	tail -c 400000 "$LOG" > "$WORK/reports/last-build.log" 2>/dev/null || true
	[ -f "$ROOT/signing/fnf-mobile.keystore" ] && cp "$ROOT/signing/fnf-mobile.keystore" "$WORK/signing/"
	{
		echo "# Relatórios de build (automático)"
		echo ""
		echo "Última atualização: $(date -u '+%Y-%m-%d %H:%M UTC')"
		echo "Status: $STATUS"
		echo "Run: $RUN_URL"
		echo ""
		echo "Arquivos:"
		echo "- reports/last-build.txt — resumo do último build"
		echo "- reports/last-build.log — log completo (truncado em 400 KB)"
		echo "- signing/fnf-mobile.keystore — keystore usado para assinar (senha: fnfmobile)"
	} > "$WORK/README.md"

	git -C "$WORK" config user.email "ci@fnfmobile.local"
	git -C "$WORK" config user.name "FNF Mobile CI"
	git -C "$WORK" add -A
	git -C "$WORK" commit -q -m "ci: build #$RUN_NUMBER — $STATUS" || echo "nada para commitar"
	git -C "$WORK" push -q -f origin HEAD:ci-report && echo "relatório publicado no branch ci-report" || echo "AVISO: falha ao publicar relatório"
fi

echo ""
echo "==> Resultado: $STATUS"
if [ "${STATUS#OK}" = "$STATUS" ]; then
	exit 1
fi
exit 0
