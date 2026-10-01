#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Instala o Haxe e as bibliotecas (versões fixadas) usadas pelo build do FNF mobile.
# Roda no CI e também dá para rodar na sua máquina (Linux/macOS).
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HAXE_VERSION="${HAXE_VERSION:-4.2.5}"
HAXE_HOME="${HAXE_HOME:-$HOME/haxe}"
export HAXELIB_PATH="${HAXELIB_PATH:-$ROOT/.haxelib}"

echo "==> Instalando Haxe $HAXE_VERSION"
if [ ! -x "$HAXE_HOME/haxe" ]; then
	mkdir -p "$HAXE_HOME"
	URL="https://github.com/HaxeFoundation/haxe/releases/download/$HAXE_VERSION/haxe-$HAXE_VERSION-linux64.tar.gz"
	curl -fL --retry 3 -o /tmp/haxe-download.tar.gz "$URL" || { echo "ERRO: download do Haxe falhou"; exit 1; }
	tar -xzf /tmp/haxe-download.tar.gz -C "$HAXE_HOME" --strip-components=1 || { echo "ERRO: extração do Haxe falhou"; exit 1; }
fi
export PATH="$HAXE_HOME:$PATH"

haxe --version || { echo "ERRO: haxe não executa"; exit 1; }
haxelib setup "$HAXELIB_PATH" >/dev/null 2>&1 || true
echo "==> haxelib: $HAXELIB_PATH"

# Nome, versão (fixada) — versões que casam com o Psych Engine 0.6.3
LIBS="hxcpp:4.3.2 lime:8.0.2 openfl:9.3.2 flixel:4.11.0 flixel-addons:2.11.0 flixel-ui:2.5.0 hscript:2.5.0"

for entry in $LIBS; do
	name="${entry%%:*}"
	ver="${entry##*:}"
	echo "==> haxelib: $name $ver"
	if haxelib path "$name" >/dev/null 2>&1; then
		# já existe alguma versão instalada: confere se é a pedida
		if ! haxelib path "$name" 2>/dev/null | grep -q "$ver"; then
			haxelib install "$name" "$ver" --quiet || echo "AVISO: falha ao instalar $name $ver (seguindo)"
		fi
	else
		haxelib install "$name" "$ver" --quiet || {
			echo "AVISO: versão $ver de $name indisponível, instalando a mais recente"
			haxelib install "$name" --quiet || { echo "ERRO: falha instalando $name"; exit 1; }
		}
	fi
done

echo "==> Bibliotecas instaladas:"
haxelib list | sed 's/^/    /'
