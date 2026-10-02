import pathlib

p = pathlib.Path('source/Paths.hx'); s = p.read_text()

# ---------------------------------------------------------------- 1) helpers
old = "\tpublic static function returnGraphic(key:String, ?library:String) {"
assert s.count(old) == 1

helpers = '''\t#if mobile
\t/**
\t * Assets que faltaram nesta sessão (o log mostra o nome exato do arquivo).
\t *
\t * No Android, quando um asset não existe, o Psych devolvia `null` e o jogo
\t * seguia com um sprite "sem imagem". Ao desenhar isso, o código nativo do
\t * OpenFL acessa memória nula e o app FECHA na hora - sem aviso, sem erro na
\t * tela (é exatamente o que acontecia ao abrir o Freeplay e o Story Mode).
\t */
\tpublic static var missingAssets:Array<String> = [];

\tstatic var emergencyGraphic:FlxGraphic = null;

\t/** Avisa uma vez (no log) que um asset não existe. */
\tpublic static function noteMissingAsset(key:String):Void
\t{
\t\tif (key == null) key = '?';
\t\tif (missingAssets.indexOf(key) != -1) return;
\t\tmissingAssets.push(key);
\t\ttry
\t\t{
\t\t\tmobile.MobilePlatform.log('FALTA ASSET: ' + key);
\t\t}
\t\tcatch (e:Dynamic) { }
\t}

\t/**
\t * Desenho de emergência: um quadradinho magenta.
\t *
\t * Substitui qualquer imagem que faltou. Assim o jogo continua rodando (com
\t * um quadrado rosa no lugar) em vez de fechar, e o log diz qual arquivo
\t * faltou para a gente consertar de verdade.
\t */
\tpublic static function emergency():FlxGraphic
\t{
\t\tif (emergencyGraphic == null || emergencyGraphic.bitmap == null)
\t\t{
\t\t\tvar bmp:BitmapData = new BitmapData(8, 8, true, 0xFFFF00FF);
\t\t\temergencyGraphic = FlxGraphic.fromBitmapData(bmp, false, 'fnfAssetFaltando');
\t\t\temergencyGraphic.persist = true;
\t\t}
\t\treturn emergencyGraphic;
\t}

\t/** Atlas de emergência (uma moldura só, usando o quadrado magenta). */
\tpublic static function emergencyFrames():FlxAtlasFrames
\t{
\t\tvar xml:String = '<?xml version="1.0" encoding="utf-8"?><TextureAtlas imagePath="placeholder.png">'
\t\t\t+ '<SubTexture name="placeholder" x="0" y="0" width="8" height="8"/></TextureAtlas>';
\t\ttry
\t\t{
\t\t\treturn FlxAtlasFrames.fromSparrow(emergency(), xml);
\t\t}
\t\tcatch (e:Dynamic)
\t\t{
\t\t\treturn null;
\t\t}
\t}
\t#end

\tpublic static function returnGraphic(key:String, ?library:String) {'''
s = s.replace(old, helpers, 1)

# ------------------------------------- 2) returnGraphic nunca devolve null
old = """\t\ttrace('oh no its returning null NOOOO');
\t\treturn null;
\t}"""
assert s.count(old) == 1
novo = """\t\t#if mobile
\t\t// No celular nunca devolvemos null: sprite sem imagem = app fechando na
\t\t// hora de desenhar. O log diz qual arquivo faltou.
\t\tnoteMissingAsset('images/' + key + '.png');
\t\treturn emergency();
\t\t#else
\t\ttrace('oh no its returning null NOOOO');
\t\treturn null;
\t\t#end
\t}"""
s = s.replace(old, novo, 1)

# ------------------------------------------- 3) getSparrowAtlas com rede
old = """\tinline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
\t{
\t\t#if MODS_ALLOWED
\t\tvar imageLoaded:FlxGraphic = returnGraphic(key);"""
assert s.count(old) == 1
novo = """\tinline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
\t{
\t\t#if mobile
\t\t// Mesma proteção: atlas sem imagem ou sem o .xml derrubava o app.
\t\ttry
\t\t{
\t\t\tvar imagem:FlxGraphic = returnGraphic(key);
\t\t\tvar xml:String = null;

\t\t\t#if MODS_ALLOWED
\t\t\tif (FileSystem.exists(modsXml(key)))
\t\t\t\txml = File.getContent(modsXml(key));
\t\t\t#end

\t\t\tif (xml == null) xml = file('images/$key.xml', library);

\t\t\tif (imagem == null || xml == null || xml.length < 5)
\t\t\t{
\t\t\t\tnoteMissingAsset('images/$key.xml (ou .png)');
\t\t\t\treturn emergencyFrames();
\t\t\t}

\t\t\treturn FlxAtlasFrames.fromSparrow(imagem, xml);
\t\t}
\t\tcatch (e:Dynamic)
\t\t{
\t\t\tnoteMissingAsset('atlas ' + key + ': ' + Std.string(e));
\t\t\treturn emergencyFrames();
\t\t}
\t\t#else
\t\t#if MODS_ALLOWED
\t\tvar imageLoaded:FlxGraphic = returnGraphic(key);"""
s = s.replace(old, novo, 1)

# fecha o #end do ramo desktop do getSparrowAtlas
old = """\t\treturn FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)), (xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
\t\t#else
\t\treturn FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
\t\t#end
\t}"""
assert s.count(old) == 1
novo = """\t\treturn FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)), (xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
\t\t#else
\t\treturn FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
\t\t#end
\t\t#end
\t}"""
s = s.replace(old, novo, 1)

# ------------------------------------ 4) getTextFromFile nunca devolve null
old = """\t\t#end
\t\treturn Assets.getText(getPath(key, TEXT));
\t}"""
assert s.count(old) == 1
novo = """\t\t#end

\t\tvar texto:String = null;
\t\ttry
\t\t{
\t\t\ttexto = Assets.getText(getPath(key, TEXT));
\t\t}
\t\tcatch (e:Dynamic) { }

\t\t#if mobile
\t\tif (texto == null)
\t\t{
\t\t\t// arquivo de dados que não existe (lista de músicas, semana, etc.)
\t\t\t// devolvia null e o jogo fechava ao usar o valor.
\t\t\tnoteMissingAsset('texto ' + key);
\t\t\treturn '';
\t\t}
\t\t#end

\t\treturn texto;
\t}"""
s = s.replace(old, novo, 1)

p.write_text(s)
print('Paths.hx protegido OK; chaves', s.count('{') - s.count('}'), 'parens', s.count('(') - s.count(')'))
