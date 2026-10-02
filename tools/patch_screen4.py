import pathlib

# --------------------------------------------------------------- 1) Main.hx
p = pathlib.Path('source/Main.hx'); s = p.read_text()

old = """\t\tif (stageWidth < 64 || stageHeight < 64)
\t\t{
\t\t\twindowTries++;

\t\t\tif (windowTries == 1)
\t\t\t{
\t\t\t\tMobilePlatform.log('AVISO: a janela ainda nao tem tamanho (' + stageWidth + 'x' + stageHeight + ')');
\t\t\t\tMobileNative.toast('FNF: janela sem tamanho (' + stageWidth + 'x' + stageHeight + '). Esperando...');
\t\t\t}
"""
assert s.count(old) == 1
novo = """\t\tif (stageWidth < 64 || stageHeight < 64)
\t\t{
\t\t\twindowTries++;

\t\t\tif (windowTries == 1)
\t\t\t{
\t\t\t\tMobilePlatform.log('AVISO: a janela ainda nao tem tamanho (' + stageWidth + 'x' + stageHeight + ')');
\t\t\t\tMobileNative.toast('FNF: janela sem tamanho (' + stageWidth + 'x' + stageHeight + '). Esperando...');
\t\t\t}

\t\t\t// Uma vez so: mostra o que o sistema diz sobre a tela e tenta
\t\t\t// redimensionar a janela pelo tamanho real do aparelho. E' o
\t\t\t// conserto da tela preta quando a janela nasce sem tamanho.
\t\t\tif (windowTries == 30)
\t\t\t{
\t\t\t\ttentaArrumarJanela();
\t\t\t}
"""
s = s.replace(old, novo, 1)

# funcao nova
old2 = """\t#if mobile
\t/** Quantos quadros já esperamos a janela informar um tamanho. */
\tvar windowTries:Int = 0;"""
assert s.count(old2) == 1
novo2 = """\t#if mobile
\t/** Quantos quadros já esperamos a janela informar um tamanho. */
\tvar windowTries:Int = 0;

\t/**
\t * A janela nasceu sem tamanho (é a causa clássica da tela preta: o jogo
\t * roda, a música toca, e nada é desenhado porque a área de desenho é 0x0).
\t *
\t * Aqui a gente pergunta ao sistema o tamanho real da tela do aparelho e
\t * manda a janela se redimensionar para ele. Tudo vai para o log.
\t */
\tfunction tentaArrumarJanela():Void
\t{
\t\ttry
\t\t{
\t\t\tvar janela:Dynamic = null;
\t\t\ttry { janela = Lib.application.window; } catch (e:Dynamic) { }

\t\t\tif (janela == null)
\t\t\t{
\t\t\t\tMobilePlatform.log('AVISO: nao consegui acessar a janela do sistema');
\t\t\t\treturn;
\t\t\t}

\t\t\tvar larguraReal:Int = 0;
\t\t\tvar alturaReal:Int = 0;
\t\t\ttry
\t\t\t{
\t\t\t\tvar modo:Dynamic = janela.display.currentMode;
\t\t\t\tif (modo != null)
\t\t\t\t{
\t\t\t\t\tlarguraReal = modo.width;
\t\t\t\t\talturaReal = modo.height;
\t\t\t\t}
\t\t\t}
\t\t\tcatch (e:Dynamic) { }

\t\t\tMobilePlatform.log('tela do aparelho: ' + larguraReal + 'x' + alturaReal
\t\t\t\t+ ' | janela: ' + janela.width + 'x' + janela.height
\t\t\t\t+ ' | tela cheia: ' + janela.fullscreen);

\t\t\tif (larguraReal >= 64 && alturaReal >= 64)
\t\t\t{
\t\t\t\tMobilePlatform.log('tentando redimensionar a janela para ' + larguraReal + 'x' + alturaReal);
\t\t\t\tjanela.resize(larguraReal, alturaReal);
\t\t\t\tMobileNative.toastCritico('FNF: janela sem tamanho; redimensionando para ' + larguraReal + 'x' + alturaReal);
\t\t\t}
\t\t\telse
\t\t\t{
\t\t\t\tMobileNative.toastCritico('FNF: a janela ficou sem tamanho (' + Std.int(stage.stageWidth) + 'x' + Std.int(stage.stageHeight) + ')');
\t\t\t}
\t\t}
\t\tcatch (e:Dynamic)
\t\t{
\t\t\tMobilePlatform.log('AVISO: falhou ao tentar arrumar a janela: ' + Std.string(e));
\t\t}
\t}

\t/** Reagenda a criação do jogo até a janela ter tamanho (ver setupGame). */"""
s = s.replace(old2, novo2, 1)
p.write_text(s)
print('Main.hx (plano B) OK')
