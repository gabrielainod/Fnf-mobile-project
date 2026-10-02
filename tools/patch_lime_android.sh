#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Ajustes no template Android do Lime 8.0.2 para que ele compile nos dias de hoje
# e para o FNF mobile:
#   * troca jcenter() (desligado) por mavenCentral()
#   * habilita largeHeap (aparelhos fracos têm pouca RAM e o FNF usa bastante)
#   * registra SDK/NDK/JDK no Lime ("lime setup android")
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=haxe_env.sh
source "$ROOT/tools/haxe_env.sh"

ANDROID_SDK="${ANDROID_SDK:-$HOME/android-sdk}"
NDK_VERSION="${NDK_VERSION:-21.4.7075529}"
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_SDK/ndk/$NDK_VERSION}"

LIME_DIR="$(haxelib libpath lime 2>/dev/null | head -1 | tr -d '\r')"
if [ -z "$LIME_DIR" ] || [ ! -d "$LIME_DIR" ]; then
	# fallback: "haxelib path lime" imprime "-cp /caminho/"
	LIME_DIR="$(haxelib path lime 2>/dev/null | grep -oE '/[^ ]+' | head -1 | tr -d '\r')"
fi
if [ -z "$LIME_DIR" ] || [ ! -d "$LIME_DIR" ]; then
	echo "ERRO: lime não encontrado no haxelib (haxelib libpath falhou)"
	echo "haxelib list:"; haxelib list 2>&1 | head -10
	exit 1
fi
echo "==> Lime: $LIME_DIR"

TPL="$LIME_DIR/templates/android/template"
if [ ! -d "$TPL" ]; then
	echo "ERRO: template android do lime não encontrado em $TPL"
	exit 1
fi

echo "==> Trocando jcenter() por mavenCentral() (jcenter foi desativado)"
find "$TPL" -name "*.gradle" -print0 | while IFS= read -r -d '' f; do
	sed -i 's/jcenter()/mavenCentral()/g' "$f"
done

APP_GRADLE="$TPL/app/build.gradle"
if [ -f "$APP_GRADLE" ]; then
	echo "==> Desligando o lintVital do release (o AGP 4.1.3 quebra no JDK 8)"
	if ! grep -q "checkReleaseBuilds" "$APP_GRADLE"; then
		python3 - "$APP_GRADLE" <<'PYEOF_GRADLE'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
marker = "android {\n"
index = text.find(marker)
if index < 0:
    sys.exit("nao achei o bloco android { em " + path)
index += len(marker)
patch = "\tlintOptions {\n\t\tcheckReleaseBuilds false\n\t\tabortOnError false\n\t}\n\n"
open(path, 'w', encoding='utf-8').write(text[:index] + patch + text[index:])
print("lintOptions adicionado")
PYEOF_GRADLE
	fi
	grep -n "checkReleaseBuilds\|abortOnError" "$APP_GRADLE" | sed 's/^/    /'
fi

# ---------------------------------------------------- diário de bordo (Java)
# O jogo precisa se reportar sozinho: no Android o jogador não tem logcat.
# A classe FnfBoot grava o log numa pasta visível (Android/media/<pacote>), pede
# a permissão de armazenamento e mostra na tela o erro da sessão anterior.
JAVA_DIR="$TPL/app/src/main/java/com/fnfmobile/game"
MAIN_ACTIVITY="$LIME_DIR/templates/android/MainActivity.java"
BOOT_SRC="$ROOT/tools/android/FnfBoot.java"

if [ -f "$BOOT_SRC" ]; then
	echo "==> Instalando o diário de bordo Java (FnfBoot)"
	mkdir -p "$JAVA_DIR"
	cp -f "$BOOT_SRC" "$JAVA_DIR/FnfBoot.java"

	# marca qual build esta instalada (aparece no aviso/dialogo do diagnostico,
	# para nao existir duvida se o APK novo foi mesmo instalado)
	BUILD_TAG="${GITHUB_RUN_NUMBER:-local}-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 'x')"
	sed -i "s/__FNF_BUILD_TAG__/$BUILD_TAG/" "$JAVA_DIR/FnfBoot.java"
	grep -n "BUILD_TAG = " "$JAVA_DIR/FnfBoot.java" | sed 's/^/    /'

	ls -la "$JAVA_DIR/FnfBoot.java"

	if [ -f "$MAIN_ACTIVITY" ]; then
		if grep -q "FnfBoot" "$MAIN_ACTIVITY"; then
			echo "    MainActivity já estava ajustada"
		else
			echo "    Ajustando o MainActivity para chamar o FnfBoot"
			cp -f "$MAIN_ACTIVITY" "$MAIN_ACTIVITY.orig"
			cat > "$MAIN_ACTIVITY" <<'JAVA_EOF'
package ::APP_PACKAGE::;

import android.os.Bundle;

public class MainActivity extends org.haxe.lime.GameActivity {

	@Override protected void onCreate (Bundle state) {

		// FNF Mobile: liga o diário de bordo antes de qualquer coisa.
		// (grava o log numa pasta visível e mostra o erro da sessão anterior)
		try { com.fnfmobile.game.FnfBoot.start (this); } catch (Throwable t) { }

		super.onCreate (state);

	}

	// Se o jogo foi para segundo plano (ou o usuário saiu pelo botão home), a
	// sessão terminou de forma "limpa". Isso vira uma marcação em arquivo: se
	// na próxima abertura a marcação NÃO existir, é porque a sessão anterior
	// morreu no meio - e aí o diagnóstico aparece na tela automaticamente.
	@Override protected void onPause () {

		try { com.fnfmobile.game.FnfBoot.markCleanSession (); } catch (Throwable t) { }
		super.onPause ();

	}

}
JAVA_EOF
			grep -n "FnfBoot" "$MAIN_ACTIVITY" | sed 's/^/    /'
		fi
	else
		echo "    AVISO: $MAIN_ACTIVITY não existe"
	fi
else
	echo "    AVISO: $BOOT_SRC não existe (sem diário de bordo Java)"
fi

MANIFEST="$TPL/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
	echo "==> Ajustando AndroidManifest (largeHeap + extractNativeLibs)"
	grep -q 'android:largeHeap' "$MANIFEST" || \
		sed -i 's/android:hardwareAccelerated="true"/android:hardwareAccelerated="true" android:largeHeap="true"/' "$MANIFEST"
	# evita que o .so seja comprimido dentro do APK (abre mais rápido em aparelho fraco)
	grep -q 'android:extractNativeLibs' "$MANIFEST" || \
		sed -i 's/android:largeHeap="true"/android:largeHeap="true" android:extractNativeLibs="true"/' "$MANIFEST"

	# TELA PRETA em Android 11/12 (API 30+): o Android passou a usar
	# "tagged pointers" no heap nativo, o que quebra a renderização de vários
	# jogos feitos com Lime/OpenFL - o jogo roda, o som toca e a tela fica
	# preta. Este atributo desliga o recurso para o nosso app (é o workaround
	# documentado pela própria OpenFL). Custo: nenhum para o jogador.
	grep -q 'allowNativeHeapPointerTagging' "$MANIFEST" || \
		sed -i 's/android:extractNativeLibs="true"/android:extractNativeLibs="true" android:allowNativeHeapPointerTagging="false"/' "$MANIFEST"
	grep -n '<application' "$MANIFEST" | head -3
fi

echo "==> Registrando SDK/NDK/JDK no Lime"
export ANDROID_SDK ANDROID_SDK_ROOT="$ANDROID_SDK" ANDROID_NDK_ROOT
export ANDROID_NDK_DIR="$ANDROID_NDK_ROOT"
printf '%s\n%s\n%s\n' "$ANDROID_SDK" "$ANDROID_NDK_ROOT" "${JAVA_HOME:-}" | \
	haxelib run lime setup android 2>&1 | sed 's/^/    /' || true

echo "==> Verificação do template:"
grep -rn "mavenCentral()" "$TPL"/*.gradle "$TPL"/app/*.gradle 2>/dev/null | sed 's/^/    /' | head -5
grep -n "largeHeap" "$MANIFEST" 2>/dev/null | sed 's/^/    /'
