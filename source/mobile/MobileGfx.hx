package mobile;

import lime.app.Application;
import lime.graphics.RenderContext;

/**
 * Diagnóstico da camada de desenho (não do jogo).
 *
 * A tela preta deste aparelho tem uma característica muito específica: o jogo
 * roda inteiro (menu carregado, música tocando, o Flixel "desenhando" 60x por
 * segundo), mas NADA que o OpenFL desenha aparece - nem uma caixa de texto
 * enorme. Isso significa que o problema está entre o Flixel e a tela: ou o
 * OpenGL não está mais desenhando, ou o que ele desenha não chega no display.
 *
 * Esta classe mede exatamente isso, sem depender do jogo:
 *  - quantas vezes o Lime pediu para desenhar (onRender);
 *  - se o OpenGL perdeu/recuperou o contexto;
 *  - qual é o tipo/versão do contexto de desenho;
 *  - se o renderizador do OpenFL ainda existe.
 */
class MobileGfx
{
	/** Quantas vezes o Lime mandou desenhar. Se para de subir, ninguém desenha. */
	public static var renderCount:Int = 0;
	public static var contextLost:Int = 0;
	public static var contextRestored:Int = 0;

	static var ligado:Bool = false;
	static var ultimoRenderEm:Float = 0;

	public static function init():Void
	{
		if (ligado) return;
		ligado = true;

		try
		{
			var janela:Dynamic = null;
			try { janela = Application.current.window; } catch (e:Dynamic) { }

			if (janela == null)
			{
				MobilePlatform.log('AVISO: o Lime ainda nao tem janela para medir o desenho');
				return;
			}

			// prioridade alta: o OpenFL registra o listener dele com prioridade 0
			// e pode cancelar o quadro; o nosso precisa rodar ANTES para contar.
			try
			{
				janela.onRender.add(function(ctx:RenderContext):Void
				{
					renderCount++;
					ultimoRenderEm = haxe.Timer.stamp();
				}, false, 100);
			}
			catch (e:Dynamic)
			{
				MobilePlatform.log('AVISO: nao consegui contar os quadros do Lime: ' + Std.string(e));
			}

			try
			{
				janela.onRenderContextLost.add(function():Void
				{
					contextLost++;
					MobilePlatform.log('ERRO: o OpenGL PERDEU o contexto de desenho (' + contextLost + ')');
				});
			}
			catch (e:Dynamic) { }

			try
			{
				janela.onRenderContextRestored.add(function(ctx:RenderContext):Void
				{
					contextRestored++;
					MobilePlatform.log('OpenGL recuperou o contexto de desenho (' + contextRestored + ')');
				});
			}
			catch (e:Dynamic) { }

			MobilePlatform.log('medidor de desenho ligado');
		}
		catch (e:Dynamic)
		{
			MobilePlatform.log('AVISO: medidor de desenho falhou: ' + Std.string(e));
		}
	}

	/** Tipo e versão do contexto de desenho que o Lime abriu. */
	public static function contextInfo():String
	{
		var txt:String = 'contexto: ';

		try
		{
			var janela:Dynamic = null;
			try { janela = Application.current.window; } catch (e:Dynamic) { }

			if (janela == null)
			{
				return txt + 'sem janela';
			}

			var ctx:Dynamic = null;
			try { ctx = janela.context; } catch (e:Dynamic) { }

			if (ctx == null)
			{
				return txt + 'NENHUM (o Lime nao abriu OpenGL!)';
			}

			var tipo:String = '?';
			var versao:String = '?';
			try { tipo = Std.string(ctx.type); } catch (e:Dynamic) { }
			try { versao = Std.string(ctx.version); } catch (e:Dynamic) { }

			txt += tipo + ' v' + versao;
		}
		catch (e:Dynamic)
		{
			txt += 'erro';
		}

		return txt;
	}

	/** O renderizador do OpenFL ainda existe? E o palco continua marcado para desenhar? */
	public static function rendererInfo():String
	{
		var txt:String = '';

		try
		{
			var palco:Dynamic = openfl.Lib.current.stage;

			var renderer:Dynamic = null;
			try { renderer = Reflect.field(palco, '__renderer'); } catch (e:Dynamic) { }
			txt = (renderer == null) ? 'renderizador: NULO (o OpenFL nao desenha mais)' : 'renderizador: ok';

			try
			{
				var sujo:Dynamic = Reflect.field(palco, '__renderDirty');
				txt += ' | sujo: ' + Std.string(sujo);
			}
			catch (e:Dynamic) { }
		}
		catch (e:Dynamic)
		{
			txt = 'renderizador: ?';
		}

		return txt;
	}

	/** Resumo de uma linha (vai para o log, para o painel e para o aviso do Android). */
	public static function report():String
	{
		var parado:String = '';
		if (renderCount == 0) parado = ' <== O LIME NUNCA PEDIU PARA DESENHAR';
		else if (ultimoRenderEm > 0 && (haxe.Timer.stamp() - ultimoRenderEm) > 2) parado = ' <== O DESENHO PAROU';

		return 'quadros do Lime: ' + renderCount + parado
			+ ' | contexto perdido: ' + contextLost + ' (recuperado ' + contextRestored + ')'
			+ ' | ' + contextInfo() + ' | ' + rendererInfo();
	}
}
