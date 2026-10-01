#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Instala o Haxe e as bibliotecas (versões fixadas) usadas pelo build do FNF mobile.
# Roda no CI e também dá para rodar na sua máquina (Linux/macOS).
#
# Tudo que este script imprime vai para build.log quando chamado pelo CI.
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HAXE_VERSION="${HAXE_VERSION:-4.2.5}"
HAXE_HOME="${HAXE_HOME:-$HOME/haxe}"
export HAXELIB_PATH="${HAXELIB_PATH:-$ROOT/.haxelib}"

echo "==> Haxe $HAXE_VERSION (home: $HAXE_HOME)"
echo "==> haxelib path: $HAXELIB_PATH"

if [ ! -x "$HAXE_HOME/haxe" ]; then
	mkdir -p "$HAXE_HOME"
	URL="https://github.com/HaxeFoundation/haxe/releases/download/$HAXE_VERSION/haxe-$HAXE_VERSION-linux64.tar.gz"
	echo "==> baixando $URL"
	if ! curl -fL --retry 3 -o /tmp/haxe-download.tar.gz "$URL"; then
		echo "ERRO: download do Haxe falhou"
		exit 1
	fi
	ls -la /tmp/haxe-download.tar.gz
	if ! tar -xzf /tmp/haxe-download.tar.gz -C "$HAXE_HOME" --strip-components=1; then
		echo "ERRO: extração do Haxe falhou"
		exit 1
	fi
	chmod +x "$HAXE_HOME/haxe" "$HAXE_HOME/haxelib" 2>/dev/null
fi

export PATH="$HAXE_HOME:$PATH"

echo "==> haxe --version"
haxe --version || { echo "ERRO: haxe não executa"; ls -la "$HAXE_HOME"; exit 1; }
echo "==> haxelib version"
haxelib version 2>&1 | head -3 || true
haxelib setup "$HAXELIB_PATH" >/dev/null 2>&1 || echo "AVISO: haxelib setup retornou erro"

install_lib() {
	local name="$1"
	local ver="$2"
	echo "==> instalando $name $ver"
	if haxelib --always install "$name" "$ver" 2>&1 | tail -5; then
		return 0
	fi
	echo "AVISO: falhou com --always; tentando sem flag"
	if haxelib install "$name" "$ver" 2>&1 | tail -5; then
		return 0
	fi
	echo "AVISO: versão $ver indisponível; instalando a mais recente de $name"
	haxelib --always install "$name" 2>&1 | tail -5 || true
}

# Versões que casam com o Psych Engine 0.6.3 (mesma geração: openfl 9.3 / flixel 4.11)
install_lib hxcpp 4.3.2
install_lib lime 8.0.2
install_lib openfl 9.3.2
install_lib flixel 4.11.0
install_lib flixel-addons 2.11.0
install_lib flixel-ui 2.5.0
install_lib hscript 2.5.0

echo ""
echo "==> bibliotecas instaladas (haxelib list):"
haxelib list 2>&1

echo ""
echo "==> caminhos resolvidos:"
for lib in hxcpp lime openfl flixel flixel-addons flixel-ui hscript; do
	printf '    %-16s %s\n' "$lib" "$(haxelib path "$lib" 2>&1 | head -2 | tr '\n' ' ')"
done

# Falha se alguma biblioteca essencial não resolveu
MISSING=""
for lib in hxcpp lime openfl flixel flixel-addons flixel-ui hscript; do
	if ! haxelib path "$lib" >/dev/null 2>&1; then
		MISSING="$MISSING $lib"
	fi
done
if [ -n "$MISSING" ]; then
	echo "ERRO: bibliotecas ausentes:$MISSING"
	exit 1
fi
echo "==> setup do Haxe concluído"
