import pathlib

# ------------------------------------------------- 1) tab do build no Java
p = pathlib.Path('tools/patch_lime_android.sh'); s = p.read_text()

old = """\tcp -f "$BOOT_SRC" "$JAVA_DIR/FnfBoot.java"
\tls -la "$JAVA_DIR/FnfBoot.java\""""
assert s.count(old) == 1
novo = """\tcp -f "$BOOT_SRC" "$JAVA_DIR/FnfBoot.java"

\t# marca qual build esta instalada (aparece no aviso/dialogo do diagnostico,
\t# para nao existir duvida se o APK novo foi mesmo instalado)
\tBUILD_TAG="${GITHUB_RUN_NUMBER:-local}-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 'x')"
\tsed -i "s/__FNF_BUILD_TAG__/$BUILD_TAG/" "$JAVA_DIR/FnfBoot.java"
\tgrep -n "BUILD_TAG = " "$JAVA_DIR/FnfBoot.java" | sed 's/^/    /'

\tls -la "$JAVA_DIR/FnfBoot.java\""""
s = s.replace(old, novo, 1)
p.write_text(s)
print('patch_lime_android.sh OK')

# ------------------------------------- 2) erro tambem no aviso do sistema
p = pathlib.Path('source/mobile/MobileDebugOverlay.hx'); s = p.read_text()
old = """			text.defaultTextFormat = new TextFormat('_sans', 15, 0xFFFFFF);
			text.text = body;"""
assert s.count(old) == 1
novo = """			// aviso do sistema tambem (aparece mesmo com o OpenGL morto)
			MobileNative.toastCritico(title + ' | ' + details);

			text.defaultTextFormat = new TextFormat('_sans', 15, 0xFFFFFF);
			text.text = body;"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('MobileDebugOverlay OK')
