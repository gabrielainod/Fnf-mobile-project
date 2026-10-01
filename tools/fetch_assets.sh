#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Baixa os assets do Friday Night Funkin' (base: Psych Engine 0.6.3) e mantém
# SOMENTE o que o build mobile precisa: Semanas 1-3 (+ tutorial), menu e fontes.
#
# Os assets NÃO ficam no repositório (são da Funkin' Crew / Psych Engine).
# Este script é rodado automaticamente pelo CI antes do build.
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PSYCH_VERSION="${PSYCH_VERSION:-0.6.3}"
SRC="${PSYCH_SRC:-/tmp/fnf-psych-base}"

# Semanas 1-3 (+ o tutorial, que é a primeira parada do modo história do FNF)
SONGS_KEEP="tutorial bopeebo fresh dad-battle spookeez south monster pico philly-nice blammed"
WEEKS_KEEP="tutorial week1 week2 week3"

echo "==> Assets do FNF (Psych Engine $PSYCH_VERSION)"

if [ ! -d "$SRC/assets" ]; then
	echo "==> Clonando base do FNF em $SRC (isso demora um pouco)..."
	rm -rf "$SRC"
	git clone --depth 1 --branch "$PSYCH_VERSION" \
		https://github.com/ShadowMario/FNF-PsychEngine "$SRC" || {
		echo "ERRO: falha ao clonar a base do FNF"; exit 1;
	}
fi

DEST="$ROOT/assets"
rm -rf "$DEST"
mkdir -p "$DEST"

# --- músicas das semanas 1-3 (somente .ogg, que é o formato usado no Android)
for s in $SONGS_KEEP; do
	mkdir -p "$DEST/songs/$s"
	cp -f "$SRC/assets/songs/$s/"*.ogg "$DEST/songs/$s/" 2>/dev/null
	cp -f "$SRC/assets/songs/$s/"*.json "$DEST/songs/$s/" 2>/dev/null
done

# --- bibliotecas compartilhadas (personagens, UI, sons, músicas de menu)
cp -a "$SRC/assets/shared" "$DEST/shared"
cp -a "$SRC/assets/week2" "$DEST/week2"
cp -a "$SRC/assets/week3" "$DEST/week3"
cp -a "$SRC/assets/fonts" "$DEST/fonts"

# --- preload (personagens, stages, dados das músicas, imagens, músicas de menu)
cp -a "$SRC/assets/preload" "$DEST/preload"

# --- limpeza: mp3 só é removido quando existe o .ogg equivalente
find "$DEST" -name "*.mp3" -print0 | while IFS= read -r -d '' f; do
	if [ -f "${f%.mp3}.ogg" ]; then rm -f "$f"; fi
done

# --- dados de músicas: manter só as das semanas 1-3
if [ -d "$DEST/preload/data" ]; then
	cd "$DEST/preload/data"
	for d in */; do
		d="${d%/}"
		case " $SONGS_KEEP " in
			*" $d "*) ;;
			*) rm -rf "$d" ;;
		esac
	done
fi

# --- semanas: manter apenas tutorial + 1-3
if [ -d "$DEST/preload/weeks" ]; then
	cd "$DEST/preload/weeks"
	rm -f week4.json week5.json week6.json week7.json
	printf '%s\n' $WEEKS_KEEP > weekList.txt
fi

cd "$ROOT"

TOTAL="$(du -sh "$DEST" 2>/dev/null | cut -f1)"
COUNT="$(find "$DEST" -type f | wc -l)"
echo "==> Assets prontos: $COUNT arquivos, $TOTAL em $DEST"
echo "==> Músicas incluídas: $SONGS_KEEP"
