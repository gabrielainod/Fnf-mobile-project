import pathlib

# ------------------------------------------------------------------ 1) Main.hx
p = pathlib.Path('source/Main.hx'); s = p.read_text()

old_size = """\tprivate function setupGame():Void
\t{
\t\tvar stageWidth:Int = Lib.current.stage.stageWidth;
\t\tvar stageHeight:Int = Lib.current.stage.stageHeight;

\t\tif (zoom == -1)
\t\t{
\t\t\tvar ratioX:Float = stageWidth / gameWidth;
\t\t\tvar ratioY:Float = stageHeight / gameHeight;
\t\t\tzoom = Math.min(ratioX, ratioY);
\t\t\tgameWidth = Math.ceil(stageWidth / zoom);
\t\t\tgameHeight = Math.ceil(stageHeight / zoom);
\t\t}
\t"""
assert s.count(old_size) == 1, s.count(old_size)

new_size = """\tprivate function setupGame():Void
\t{
\t\tvar stageWidth:Int = Lib.current.stage.stageWidth;
\t\tvar stageHeight:Int = Lib.current.stage.stageHeight;

\t\t#if mobile
\t\t// ---------------------------------------------------------------
\t\t// TELA PRETA: aqui é onde ela nasce ou não.
\t\t//
\t\t// O zoom é calculado dividindo o tamanho da janela pelo tamanho do jogo.
\t\t// Se a janela chega sem tamanho (0x0) - o que acontece em alguns
\t\t// aparelhos por causa do modo tela cheia -, o zoom vira 0, o jogo fica
\t\t// com uma área de desenho 0x0 e o resultado é exatamente o pior tipo de
\t\t// defeito: o app roda, a música toca, e a tela fica preta.
\t\t//
\t\t// Então aqui a gente espera a janela ter tamanho de verdade antes de
\t\t// criar o jogo, e o tamanho medido vai para o log.
\t\t// ---------------------------------------------------------------
\t\tMobilePlatform.log('janela na hora de criar o jogo: ' + stageWidth + 'x' + stageHeight);

\t\tif (stageWidth < 64 || stageHeight < 64)
\t\t{
\t\t\twindowTries++;

\t\t\tif (windowTries == 1)
\t\t\t{
\t\t\t\tMobilePlatform.log('AVISO: a janela ainda nao tem tamanho (' + stageWidth + 'x' + stageHeight + ')');
\t\t\t\tMobileNative.toast('FNF: janela sem tamanho (' + stageWidth + 'x' + stageHeight + '). Esperando...');
\t\t\t}

\t\t\tif (windowTries <= 900) // ~15 segundos
\t\t\t{
\t\t\t\t// tenta de novo no próximo quadro
\t\t\t\tremoveEventListener(Event.ENTER_FRAME, tentaDeNovo);
\t\t\t\taddEventListener(Event.ENTER_FRAME, tentaDeNovo);
\t\t\t\treturn;
\t\t\t}

\t\t\t// desistiu de esperar: usa o tamanho padrao para o jogo existir e
\t\t\t// registrar o tamanho real no log
\t\t\tMobilePlatform.log('AVISO: a janela nunca informou tamanho; usando 1280x720 como padrao');
\t\t\tMobileNative.toastCritico('FNF: tela do aparelho nao informou tamanho. Usando 1280x720.');
\t\t\tstageWidth = 1280;
\t\t\tstageHeight = 720;
\t\t}

\t\tremoveEventListener(Event.ENTER_FRAME, tentaDeNovo);
\t\t#end

\t\tif (zoom == -1)
\t\t{
\t\t\tvar ratioX:Float = stageWidth / gameWidth;
\t\t\tvar ratioY:Float = stageHeight / gameHeight;
\t\t\tzoom = Math.min(ratioX, ratioY);
\t\t\tgameWidth = Math.ceil(stageWidth / zoom);
\t\t\tgameHeight = Math.ceil(stageHeight / zoom);
\t\t}

\t\t#if mobile
\t\tMobilePlatform.log('configuracao de tela: janela ' + stageWidth + 'x' + stageHeight + ' | jogo ' + gameWidth + 'x' + gameHeight
\t\t\t+ ' | zoom ' + zoom);
\t\t#end
\t"""
s = s.replace(old_size, new_size, 1)

# campos e função de espera
old_fields = """\tvar startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
\tpublic static var fpsVar:FPS;"""
assert s.count(old_fields) == 1
new_fields = """\tvar startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
\tpublic static var fpsVar:FPS;

\t#if mobile
\t/** Quantos quadros já esperamos a janela informar um tamanho. */
\tvar windowTries:Int = 0;

\t/** Reagenda a criação do jogo até a janela ter tamanho (ver setupGame). */
\tfunction tentaDeNovo(_:Event):Void
\t{
\t\tif (stage == null) return;
\t\tif (stage.stageWidth >= 64 && stage.stageHeight >= 64)
\t\t{
\t\t\tremoveEventListener(Event.ENTER_FRAME, tentaDeNovo);
\t\t\tsetupGame();
\t\t}
\t\telse
\t\t{
\t\t\tsetupGame(); // continua contando as tentativas
\t\t}
\t}
\t#end"""
s = s.replace(old_fields, new_fields, 1)

# liga a ponte nativa no boot
old_boot = "\t\tMobilePlatform.log('boot: setupGame inicio');"
assert s.count(old_boot) == 1
s = s.replace(old_boot, old_boot + "\n\t\tMobileNative.init();\n\t\tMobilePlatform.log('aviso na tela (toast): ' + MobileNative.isAvailable());", 1)

# import
s = s.replace("import mobile.MobileDebugOverlay;", "import mobile.MobileDebugOverlay;\nimport mobile.MobileNative;", 1)
p.write_text(s)
print('Main.hx OK')

# --------------------------------------------------- 2) MobilePlatform: toasts
p = pathlib.Path('source/mobile/MobilePlatform.hx'); s = p.read_text()

old_append = """	public static function logAppend(message:String):Void"""
if s.count(old_append) != 1:
    raise SystemExit('nao achei logAppend')

# descobre o corpo do logAppend para inserir o toast no fim
inicio = s.index('	public static function logAppend(message:String):Void')
fim = s.index('\n\tpublic static function ', inicio + 10)
trecho = s[inicio:fim]
print('--- logAppend atual ---')
print(trecho)
p.write_text(s)
