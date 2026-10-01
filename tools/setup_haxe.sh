#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Instala o Haxe (e o neko, exigido pelo haxelib oficial) e as bibliotecas
# fixadas usadas pelo build do FNF mobile. Roda no CI e localmente no Linux.
#
# Tudo que este script imprime vai para build.log quando chamado pelo CI.
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=haxe_env.sh
source "$ROOT/tools/haxe_env.sh"

HAXE_VERSION="${HAXE_VERSION:-4.2.5}"
NEKO_VERSION="${NEKO_VERSION:-2.3.0}"

echo "==> Haxe $HAXE_VERSION (home: $HAXE_HOME)"
echo "==> haxelib path: $HAXELIB_PATH"

# --- neko: o haxelib distribuído no pacote do Haxe é um binário neko --------
neko_ok() {
	if ldconfig -p 2>/dev/null | grep -q "libneko"; then return 0; fi
	[ -f /usr/lib/x86_64-linux-gnu/libneko.so.2 ] && return 0
	[ -d "$NEKO_HOME" ] && [ -n "$(ls "$NEKO_HOME"/libneko.so* 2>/dev/null)" ] && return 0
	return 1
}

if ! neko_ok; then
	echo "==> instalando neko $NEKO_VERSION (necessário para o haxelib)"
	if command -v apt-get >/dev/null 2>&1; then
		sudo apt-get update -qq >/dev/null 2>&1 || true
		sudo apt-get install -y -qq neko >/dev/null 2>&1 && echo "==> neko instalado via apt" || echo "AVISO: apt falhou, tentando release do GitHub"
	fi
	if ! neko_ok; then
		mkdir -p "$NEKO_HOME"
		URL="https://github.com/HaxeFoundation/neko/releases/download/v2-3-0/neko-$NEKO_VERSION-linux64.tar.gz"
		echo "==> baixando $URL"
		if curl -fL --retry 3 -o /tmp/neko.tar.gz "$URL"; then
			tar -xzf /tmp/neko.tar.gz -C "$NEKO_HOME" --strip-components=1
			chmod +x "$NEKO_HOME/neko" 2>/dev/null
			export PATH="$NEKO_HOME:$PATH"
			export LD_LIBRARY_PATH="$NEKO_HOME:${LD_LIBRARY_PATH:-}"
			echo "==> neko instalado em $NEKO_HOME"
		else
			echo "ERRO: não foi possível instalar o neko"
		fi
	fi
fi
echo "==> libneko: $(ldconfig -p 2>/dev/null | grep libneko | head -1 || echo "(não listado; pode estar via LD_LIBRARY_PATH)")"

# --- Haxe -------------------------------------------------------------------
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
	# alguns pacotes trazem o haxelib como bytecode neko (haxelib.n)
	[ -f "$HAXE_HOME/haxelib.n" ] && chmod +r "$HAXE_HOME/haxelib.n"
fi

echo "==> haxe --version"
haxe --version || { echo "ERRO: haxe não executa"; ls -la "$HAXE_HOME"; exit 1; }

echo "==> haxelib version"
if ! haxelib version 2>&1 | head -3; then
	echo "ERRO: haxelib não executa (provavelmente falta libneko)"
	exit 1
fi
haxelib setup "$HAXELIB_PATH" >/dev/null 2>&1 || echo "AVISO: haxelib setup retornou erro"

# persistência para os próximos passos do CI
if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "HAXE_HOME=$HAXE_HOME"
		echo "NEKO_HOME=$NEKO_HOME"
		echo "HAXELIB_PATH=$HAXELIB_PATH"
		echo "PATH=$HAXE_HOME:$NEKO_HOME:$PATH"
	} >> "$GITHUB_ENV"
fi

install_lib() {
	local name="$1"
	local ver="$2"
	echo "==> instalando $name $ver"
	haxelib --always install "$name" "$ver" 2>&1 | tail -6
	local rc=${PIPESTATUS[0]}
	if [ "$rc" -eq 0 ]; then return 0; fi
	echo "AVISO: falhou ($rc); tentando sem --always"
	haxelib install "$name" "$ver" </dev/null 2>&1 | tail -6
	rc=${PIPESTATUS[0]}
	if [ "$rc" -eq 0 ]; then return 0; fi
	echo "AVISO: versão $ver indisponível; instalando a mais recente de $name"
	haxelib --always install "$name" 2>&1 | tail -6 || true
	return 0
}

# Versões que casam com o Psych Engine 0.6.3 (openfl 9.2 / lime 8.0 / flixel 4.11)
install_lib hxcpp 4.3.2
install_lib lime 8.0.2
install_lib openfl 9.2.2 # o FlxSound do Psych 0.6.3 usa _channel.__source (removido no 9.3+)
install_lib flixel 4.11.0
install_lib flixel-addons 2.11.0
install_lib flixel-ui 2.5.0
install_lib hscript 2.5.0

echo ""
echo "==> bibliotecas instaladas (haxelib list):"
haxelib list 2>&1 | tail -20

MISSING=""
for lib in hxcpp lime openfl flixel flixel-addons flixel-ui hscript; do
	if ! haxelib path "$lib" >/dev/null 2>&1; then MISSING="$MISSING $lib"; fi
done
if [ -n "$MISSING" ]; then
	echo "ERRO: bibliotecas ausentes:$MISSING"
	exit 1
fi
echo "==> setup do Haxe concluído"
