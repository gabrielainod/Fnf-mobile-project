#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Instala Android SDK + NDK + build-tools exigidos pelo build (NDK r21e é o que
# combina com o hxcpp/Lime usados pelo FNF mobile).
# -----------------------------------------------------------------------------
set -uo pipefail

SDK="${ANDROID_SDK:-$HOME/android-sdk}"
NDK_VERSION="${NDK_VERSION:-21.4.7075529}"
BUILD_TOOLS="30.0.3"
# compileSdk do projeto = targetSdk = 28 (armazenamento legado p/ pasta de mods)
PLATFORMS="android-28 android-30"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip"

echo "==> Android SDK em: $SDK"

# sdkmanager precisa de JDK 11+ (o build do jogo usa JDK 8)
find_jdk() {
	for candidate in "${JAVA_HOME_17_X64:-}" "${JAVA_HOME_11_X64:-}" "${JAVA_HOME_21_X64:-}"; do
		[ -n "$candidate" ] && [ -x "$candidate/bin/java" ] && { echo "$candidate"; return; }
	done
	for candidate in /usr/lib/jvm/msft-17* /usr/lib/jvm/temurin-17* /usr/lib/jvm/java-17* /usr/lib/jvm/java-11*; do
		[ -x "$candidate/bin/java" ] && { echo "$candidate"; return; }
	done
	if command -v java >/dev/null 2>&1; then
		local maj
		maj="$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')"
		[ "${maj:-0}" -ge 11 ] && { dirname "$(dirname "$(readlink -f "$(command -v java)")")"; return; }
	fi
	echo ""
}

SDK_JAVA="$(find_jdk)"
if [ -z "$SDK_JAVA" ]; then
	echo "ERRO: nenhum JDK 11+ encontrado para rodar o sdkmanager"
	exit 1
fi
echo "==> JDK para o sdkmanager: $SDK_JAVA"

if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
	mkdir -p "$SDK/cmdline-tools"
	echo "==> Baixando command-line tools"
	curl -fL --retry 3 -o /tmp/cmdline-tools.zip "$CMDLINE_TOOLS_URL" || { echo "ERRO: download do sdkmanager falhou"; exit 1; }
	unzip -q -o /tmp/cmdline-tools.zip -d "$SDK/cmdline-tools" || { echo "ERRO: unzip falhou"; exit 1; }
	rm -rf "$SDK/cmdline-tools/latest"
	mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
fi

export JAVA_HOME="$SDK_JAVA"
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
export ANDROID_SDK_ROOT="$SDK"
export ANDROID_HOME="$SDK"

echo "==> Aceitando licenças"
yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true

PACKAGES=("platform-tools" "build-tools;$BUILD_TOOLS")
for p in $PLATFORMS; do PACKAGES+=("platforms;$p"); done
if [ "${SKIP_NDK:-0}" != "1" ]; then
	PACKAGES+=("ndk;$NDK_VERSION")
else
	echo "==> SKIP_NDK=1: pulando o download do NDK (modo typecheck)"
fi
echo "==> Instalando: ${PACKAGES[*]}"
"$SDKMANAGER" --sdk_root="$SDK" "${PACKAGES[@]}" >/tmp/sdkmanager.log 2>&1 || {
	echo "ERRO: sdkmanager falhou";
	tail -30 /tmp/sdkmanager.log;
	exit 1;
}

echo "==> SDK instalado:"
ls "$SDK" | sed 's/^/    /'
ls "$SDK/ndk" 2>/dev/null | sed 's/^/    ndk: /'

# deixa os caminhos prontos para o resto do job
if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "ANDROID_SDK=$SDK"
		echo "ANDROID_SDK_ROOT=$SDK"
		echo "ANDROID_HOME=$SDK"
		echo "ANDROID_NDK_ROOT=$SDK/ndk/$NDK_VERSION"
		echo "ANDROID_NDK_DIR=$SDK/ndk/$NDK_VERSION"
	} >> "$GITHUB_ENV"
fi
