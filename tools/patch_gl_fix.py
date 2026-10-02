import pathlib

# ---------------------------------------- 1) manifest: tagged pointers off
p = pathlib.Path('tools/patch_lime_android.sh'); s = p.read_text()

old = """	# evita que o .so seja comprimido dentro do APK (abre mais rápido em aparelho fraco)
	grep -q 'android:extractNativeLibs' "$MANIFEST" || \\
		sed -i 's/android:largeHeap="true"/android:largeHeap="true" android:extractNativeLibs="true"/' "$MANIFEST"
fi"""
assert s.count(old) == 1
novo = """	# evita que o .so seja comprimido dentro do APK (abre mais rápido em aparelho fraco)
	grep -q 'android:extractNativeLibs' "$MANIFEST" || \\
		sed -i 's/android:largeHeap="true"/android:largeHeap="true" android:extractNativeLibs="true"/' "$MANIFEST"

	# TELA PRETA em Android 11/12 (API 30+): o Android passou a usar
	# "tagged pointers" no heap nativo, o que quebra a renderização de vários
	# jogos feitos com Lime/OpenFL - o jogo roda, o som toca e a tela fica
	# preta. Este atributo desliga o recurso para o nosso app (é o workaround
	# documentado pela própria OpenFL). Custo: nenhum para o jogador.
	grep -q 'allowNativeHeapPointerTagging' "$MANIFEST" || \\
		sed -i 's/android:extractNativeLibs="true"/android:extractNativeLibs="true" android:allowNativeHeapPointerTagging="false"/' "$MANIFEST"
	grep -n '<application' "$MANIFEST" | head -3
fi"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('manifest patch OK')

# ------------------------------------------------ 2) Project.xml: define
p = pathlib.Path('Project.xml'); s = p.read_text()
old = '\t<define name="MODS_ALLOWED" if="desktop || mobile" />'
assert s.count(old) == 1
novo = """\t<define name="MODS_ALLOWED" if="desktop || mobile" />

\t<!-- No mobile o OpenFL tenta economizar desenho quando "nada mudou" no palco.
\t     Em jogo isso não faz sentido (o jogo muda todo quadro) e já causou tela
\t     preta em aparelhos Android: aqui o desenho é forçado todo quadro. -->
\t<define name="openfl_always_render" if="mobile" />"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('Project.xml OK')
