#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Ambiente comum do Haxe para os outros scripts (fonte este arquivo).
# Define PATH do Haxe/neko, HAXELIB_PATH e LD_LIBRARY_PATH quando necessário.
# -----------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export HAXE_HOME="${HAXE_HOME:-$HOME/haxe}"
export NEKO_HOME="${NEKO_HOME:-$HOME/neko}"
export HAXELIB_PATH="${HAXELIB_PATH:-$ROOT/.haxelib}"

export PATH="$HAXE_HOME:$NEKO_HOME:$PATH"
if [ -d "$NEKO_HOME" ]; then
	export LD_LIBRARY_PATH="$NEKO_HOME:${LD_LIBRARY_PATH:-}"
fi
