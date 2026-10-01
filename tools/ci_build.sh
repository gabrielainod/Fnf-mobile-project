#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Build do APK (FNF Mobile). Faz typecheck rápido, compila (hxcpp/NDK), assina e
# verifica o APK. TODO o log vai para ./build.log, que o CI publica no branch
# "ci-report" — é assim que o build se reporta.
#
# Variáveis:
#   TYPECHECK_ONLY=1 -> só compila o Haxe (sem C++/gradle), para iterar rápido
#   QUICK=1          -> build completo, mas só arm64-v8a
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG="$ROOT/build.log"
STATUS_FILE="$ROOT/.ci-status"
[ -f "$STATUS_FILE" ] || echo "PENDING" > "$STATUS_FILE"

TYPECHECK_ONLY="${TYPECHECK_ONLY:-0}"
QUICK="${QUICK:-0}"
ABIS="${ABIS:-both}"
if [ "$QUICK" = "1" ]; then ABIS="arm64"; fi

# shellcheck source=haxe_env.sh
source "$ROOT/tools/haxe_env.sh"
export ANDROID_SDK="${ANDROID_SDK:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export ANDROID_HOME="$ANDROID_SDK"
NDK_VERSION="${NDK_VERSION:-21.4.7075529}"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_SDK/ndk/$NDK_VERSION}"
export ANDROID_NDK_DIR="$ANDROID_NDK_ROOT"

BUILD_TOOLS="$ANDROID_SDK/build-tools/30.0.3"
APK_NAME="FNF-Mobile-1.0.0.apk"
KS_DIR="$ROOT/signing"
KS="$KS_DIR/fnf-mobile.keystore"
KS_PASS="${KS_PASS:-fnfmobile}"
KS_ALIAS="fnfmobile"

log() { echo "$*" | tee -a "$LOG"; }

run_step() {
	local name="$1"; shift
	log ""
	log "########## STEP: $name ##########"
	local t0 dt rc
	t0=$(date +%s)
	"$@" >>"$LOG" 2>&1
	rc=$?
	dt=$(( $(date +%s) - t0 ))
	if [ "$rc" -eq 0 ]; then
		log "########## OK: $name (${dt}s) ##########"
		return 0
	fi
	log "########## FALHOU: $name (exit $rc, ${dt}s) ##########"
	echo "FAIL:$name" > "$STATUS_FILE"
	return 1
}

dump_env() {
	echo "commit: $(git rev-parse --short HEAD 2>/dev/null)"
	echo "haxe: $(haxe --version 2>&1)"
	echo "haxelib path: $HAXELIB_PATH"
	haxelib list 2>&1
	echo "java: $(java -version 2>&1 | head -2 | tr '\n' ' ')"
	echo "JAVA_HOME: ${JAVA_HOME:-<vazio>}"
	echo "ANDROID_SDK: $ANDROID_SDK"
	echo "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
	echo "build-tools: $(ls "$ANDROID_SDK/build-tools" 2>&1 | tr '\n' ' ')"
	echo "platforms: $(ls "$ANDROID_SDK/platforms" 2>&1 | tr '\n' ' ')"
	echo "ndk: $(ls "$ANDROID_SDK/ndk" 2>&1 | tr '\n' ' ')"
	echo "g++: $(g++ --version 2>&1 | head -1)"
	echo "cpu: $(nproc) cores"
	df -h / | tail -1
	echo "assets: $(find assets -type f 2>/dev/null | wc -l) arquivos"
}

configure_abis() {
	echo "ABIs solicitadas: $ABIS"
	if [ "$ABIS" = "arm64" ]; then
		sed -i 's|<architecture name="armv7" />|<architecture name="armv7" exclude="armv7" />|' Project.xml
		echo "armv7 removida (build rápido)"
	fi
	grep -n "<architecture" Project.xml
}

fetch_keystore() {
	mkdir -p "$KS_DIR"
	if [ -f "$KS" ]; then
		echo "keystore já existe no workspace"
		return 0
	fi
	if git fetch -q origin ci-report 2>/dev/null; then
		if git show origin/ci-report:signing/fnf-mobile.keystore > "$KS" 2>/dev/null && [ -s "$KS" ]; then
			echo "keystore recuperado do branch ci-report (assinatura estável entre builds)"
			return 0
		fi
	fi
	rm -f "$KS"
	echo "gerando keystore novo"
	keytool -genkeypair -keystore "$KS" -alias "$KS_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
		-storepass "$KS_PASS" -keypass "$KS_PASS" \
		-dname "CN=FNF Mobile, OU=Personal, O=Personal, C=BR" >/dev/null 2>&1 || {
		echo "ERRO: keytool falhou"; return 1; }
	keytool -list -keystore "$KS" -storepass "$KS_PASS" 2>&1 | tail -3
}

typecheck() {
	cp Project.xml /tmp/Project.xml.orig
	sed -i 's|</project>|\t<haxeflag name="--no-output" />\n</project>|' Project.xml
	grep -n "no-output" Project.xml
	haxelib run lime build android
	local rc=$?
	cp /tmp/Project.xml.orig Project.xml
	return $rc
}

build_apk() {
	# -release: código otimizado (importante em aparelho fraco). O APK sai
	# sem assinatura e é assinado por nós no passo seguinte.
	haxelib run lime build android -release
}

find_apk() {
	# procura em todo o export (o Lime 8 usa export/release/android, mas o layout
	# já mudou entre versões); pega o APK mais recente
	APK_SRC="$(find export -name "*.apk" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
	if [ -z "$APK_SRC" ] || [ ! -f "$APK_SRC" ]; then
		echo "ERRO: nenhum APK gerado em export/release/android"
		find export -name "*.apk" 2>/dev/null | head
		return 1
	fi
	echo "APK bruto: $APK_SRC"
	echo "$APK_SRC" > "$ROOT/.apk-src"
}

package_apk() {
	local src out
	src="$(cat "$ROOT/.apk-src")"
	mkdir -p "$ROOT/dist"
	out="$ROOT/dist/$APK_NAME"

	"$BUILD_TOOLS/zipalign" -f -p 4 "$src" /tmp/aligned.apk || { echo "ERRO: zipalign falhou"; return 1; }

	"$BUILD_TOOLS/apksigner" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" \
		--ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
		--v1-signing-enabled true --v2-signing-enabled true \
		--out "$out" /tmp/aligned.apk || { echo "ERRO: apksigner falhou"; return 1; }

	"$BUILD_TOOLS/apksigner" verify --verbose --print-certs "$out" || { echo "ERRO: verificação falhou"; return 1; }

	echo ""
	echo "==> APK final: $out"
	ls -la "$out"
	echo "sha256: $(sha256sum "$out" | cut -d' ' -f1)"
	echo ""
	echo "==> Conteúdo (resumo):"
	unzip -l "$out" | tail -3
	echo "assets no APK: $(unzip -l "$out" | grep -c 'assets/')"
	echo "libs nativas:"
	unzip -l "$out" | grep -E "lib/(arm64-v8a|armeabi-v7a)/" || echo "    (nenhuma!)"
	echo ""
	echo "==> Assets empacotados (topo):"
	unzip -l "$out" | awk '{print $4}' | grep -E "^assets/" | cut -d/ -f1-3 | sort -u | head -40

	echo "$out" > "$ROOT/.apk-final"
}

main() {
	run_step dump_env dump_env || exit 1
	run_step configure_abis configure_abis || exit 1

	if [ "$TYPECHECK_ONLY" = "1" ]; then
		run_step typecheck typecheck || exit 1
		echo "OK:typecheck" > "$STATUS_FILE"
		log "########## TYPECHECK OK ##########"
		exit 0
	fi

	run_step keystore fetch_keystore || exit 1
	run_step typecheck typecheck || exit 1
	run_step build_nativo build_apk || exit 1
	run_step localizar_apk find_apk || exit 1
	run_step assinar_e_verificar package_apk || exit 1

	echo "OK:$(basename "$(cat "$ROOT/.apk-final" 2>/dev/null)")" > "$STATUS_FILE"
	log ""
	log "########## BUILD COMPLETO ##########"
	log "status: $(cat "$STATUS_FILE")"
	return 0
}

main
