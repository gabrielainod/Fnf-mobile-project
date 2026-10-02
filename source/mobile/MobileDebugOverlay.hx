package mobile;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

/**
 * Mostra um erro DIRETO NA TELA, por cima de tudo.
 *
 * Por que não usar FlxText: quando o problema é no desenho ou na criação do
 * estado, o caminho do Flixel pode estar quebrado justamente quando o erro
 * acontece. Aqui o texto é desenhado pelo próprio OpenFL (um TextField comum
 * no palco), então continua aparecendo mesmo com o Flixel travado.
 *
 * Serve para o jogador conseguir reportar o problema sem PC: aparece a
 * mensagem, o estado atual e as últimas linhas do log - é só tirar print.
 */
class MobileDebugOverlay
{
	static var box:Sprite = null;
	static var text:TextField = null;
	static var visibleNow:Bool = false;

	/** Mostra (ou atualiza) a caixa de erro. Nunca derruba o jogo. */
	public static function showError(title:String, details:String):Void
	{
		try
		{
			var stage = (Lib.current != null) ? Lib.current.stage : null;
			if (stage == null) return;

			if (box == null)
			{
				box = new Sprite();
				box.mouseEnabled = false;

				text = new TextField();
				text.multiline = true;
				text.wordWrap = true;
				text.selectable = false;
				text.mouseEnabled = false;
				text.autoSize = TextFieldAutoSize.NONE;
				text.defaultTextFormat = new TextFormat('_sans', 15, 0xFFFFFF);
				text.textColor = 0xFFFFFF;
				box.addChild(text);

				stage.addChild(box);
			}

			var sw:Float = stage.stageWidth;
			var sh:Float = stage.stageHeight;
			if (sw <= 0) sw = 1280;
			if (sh <= 0) sh = 720;

			var body:String = title + '\n\n' + details;
			try
			{
				body += '\n\n--- últimas mensagens ---\n' + MobilePlatform.logTail(14);
			}
			catch (e:Dynamic) { }

			text.defaultTextFormat = new TextFormat('_sans', 15, 0xFFFFFF);
			text.text = body;
			text.x = 18;
			text.y = 18;
			text.width = sw - 36;
			text.height = sh - 36;

			var g = box.graphics;
			g.clear();
			g.beginFill(0x000000, 0.93);
			g.drawRect(0, 0, sw, sh);
			g.endFill();

			box.x = 0;
			box.y = 0;
			box.visible = true;
			visibleNow = true;

			// garante que a caixa fica por cima de tudo o que já está no palco
			if (box.parent == stage) stage.setChildIndex(box, stage.numChildren - 1);
		}
		catch (e:Dynamic)
		{
			// se nem isso deu certo, não há mais nada a fazer
		}
	}

	/** Esconde a caixa (chamado quando o jogo consegue avançar de tela). */
	public static function hide():Void
	{
		try
		{
			if (box != null) box.visible = false;
			visibleNow = false;
		}
		catch (e:Dynamic) { }
	}

	public static function isVisible():Bool
		return visibleNow;
}
