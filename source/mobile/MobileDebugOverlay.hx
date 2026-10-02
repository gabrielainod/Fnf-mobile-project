package mobile;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

/**
 * Desenha informacao DIRETO NA TELA, por cima de tudo, usando o OpenFL puro.
 *
 * Dois elementos independentes:
 *
 * 1. PAINEL DE STATUS (canto superior esquerdo, sempre visivel no inicio):
 *    mostra a tela atual, quantos updates e quantos draws o Flixel ja fez e o
 *    estado do shader. Serve para separar dois problemas que parecem iguais:
 *       - se o texto aparece mas o jogo nao: o OpenGL esta bom, o defeito esta
 *         dentro do Flixel (alguma tela desenhando errado);
 *       - se nem o texto aparece: o problema e no proprio OpenGL/janela.
 *
 * 2. CAIXA DE ERRO (tela inteira): aparece quando o jogo captura uma excecao.
 *
 * Por que nao usar FlxText: quando o defeito e no desenho, o caminho do Flixel
 * pode estar quebrado justamente na hora do erro. Aqui o texto e um TextField
 * comum no palco do OpenFL, entao continua aparecendo mesmo com o Flixel morto.
 *
 * Nunca lanca excecao: se qualquer coisa falhar aqui, o jogo segue normal.
 */
class MobileDebugOverlay
{
	static var box:Sprite = null;
	static var text:TextField = null;
	static var visibleNow:Bool = false;

	static var panel:Sprite = null;
	static var panelText:TextField = null;
	static var panelCreatedAt:Float = 0;
	static var panelClosed:Bool = false;
	static var extraInfo:String = '';
	static var lastRendered:String = null;
	static var lastBorder:Int = -1;
	static var frame:Int = 0;

	/** Quantos updates o laco do Flixel ja rodou (contador de diagnostico). */
	public static var updates:Int = 0;
	/** Quantos draws o Flixel ja completou. Se fica em 0, a tela nao desenha. */
	public static var draws:Int = 0;

	// ------------------------------------------------------------------ status

	/** Chamado a cada update do jogo. */
	public static function noteUpdate():Void
	{
		updates++;
	}

	/** Chamado a cada draw concluido do jogo. */
	public static function noteDraw():Void
	{
		draws++;
	}

	/** Texto extra no painel (ex.: "shader desligado"). */
	public static function setStatus(info:String):Void
	{
		extraInfo = (info == null) ? '' : info;
		lastRendered = null;
		if (panelClosed) reopenPanel();
	}

	/** Atualiza o painel; chamar uma vez por frame (barato: so redesenha se mudou). */
	public static function tick():Void
	{
		if (panelClosed) return;

		frame++;

		// tira o painel da frente depois de um tempo, pra nao atrapalhar o jogo
		if (panelCreatedAt > 0 && (haxe.Timer.stamp() - panelCreatedAt) > 25)
		{
			closePanel();
			return;
		}

		// batimento: de 3 em 3 segundos grava no log (e na tela) um resumo do
		// estado, para o ultimo registro antes de um defeito dizer tudo.
		if (frame % 180 == 0)
		{
			var estado:String = '?';
			try { estado = MobilePlatform.currentStateName(); } catch (e:Dynamic) { }
			MobilePlatform.log('batimento: tela ' + estado + ' | update ' + updates + ' | desenho ' + draws);
			MobilePlatform.log('   ' + MobileGfx.report());
		}

		if (frame % 10 != 0) return; // nao mexe no texto todo frame (custo no celular)
		refreshPanel();
	}

	static function buildPanel():Void
	{
		var stage = (Lib.current != null) ? Lib.current.stage : null;
		if (stage == null) return;

		panel = new Sprite();
		panel.mouseEnabled = false;

		panelText = new TextField();
		panelText.multiline = true;
		panelText.selectable = false;
		panelText.mouseEnabled = false;
		panelText.autoSize = TextFieldAutoSize.NONE;
		panelText.defaultTextFormat = new TextFormat('_sans', 22, 0x000000, true);
		panelText.width = 1400;
		panelText.height = 300;
		panelText.x = 24;
		panelText.y = 24;
		panel.addChild(panelText);

		var g = panel.graphics;
		g.clear();
		g.beginFill(0x101018, 0.78);
		g.drawRect(0, 0, 716, 80);
		g.endFill();
		// borda colorida: serve de sinal mesmo se a fonte nao desenhar nada
		g.lineStyle(3, 0x808080, 1);
		g.drawRect(0, 0, 716, 80);

		// TELA INTEIRA magenta (grande e chamativo de proposito): e' a prova
		// visual de que o OpenFL consegue desenhar no aparelho. Se a tela ficar
		// preta com isso ligado, o problema e' no OpenGL/tela e nao no jogo.
		try
		{
			var sw2:Float = stage.stageWidth;
			var sh2:Float = stage.stageHeight;
			if (sw2 <= 0) sw2 = 1280;
			if (sh2 <= 0) sh2 = 720;
			var fundo = new Sprite();
			fundo.mouseEnabled = false;
			fundo.name = 'fnfFundoDiagnostico';
			var gf = fundo.graphics;
			gf.beginFill(0xFF00FF, 0.92);
			gf.drawRect(0, 0, sw2, sh2);
			gf.endFill();
			stage.addChildAt(fundo, stage.getChildIndex(panel));
		}
		catch (e:Dynamic) { }

		panel.x = 0;
		panel.y = 0;
		stage.addChild(panel);
		if (panel.parent == stage) stage.setChildIndex(panel, stage.numChildren - 1);

		panelCreatedAt = haxe.Timer.stamp();

		// o jogador pode tocar na tela pra fechar o painel
		try
		{
			stage.addEventListener(MouseEvent.CLICK, function(_) closePanel());
			stage.addEventListener(TouchEvent.TOUCH_BEGIN, function(_) closePanel());
		}
		catch (e:Dynamic) { }
	}

	static function reopenPanel():Void
	{
		try
		{
			if (panel == null)
			{
				buildPanel();
			}
			else
			{
				panel.visible = true;
				if (panel.parent != Lib.current.stage) Lib.current.stage.addChild(panel);
				panelCreatedAt = haxe.Timer.stamp();
			}
			panelClosed = false;
			lastRendered = null;
			refreshPanel();
		}
		catch (e:Dynamic) { }
	}

	static function closePanel():Void
	{
		try
		{
			if (panel != null) panel.visible = false;
			panelClosed = true;
		}
		catch (e:Dynamic) { }
	}

	static function refreshPanel():Void
	{
		try
		{
			if (panel == null) buildPanel();
			if (panel == null) return;
			if (panel.parent == null && Lib.current != null) Lib.current.stage.addChild(panel);

			var estado:String = 'iniciando';
			try
			{
				estado = MobilePlatform.currentStateName();
			}
			catch (e:Dynamic) { }

			var linha1:String = 'FNF-Mobile (diagnostico)  |  tela: ' + estado;
			var linha2:String = 'update: ' + updates + '   desenho: ' + draws;
			if (draws == 0 && updates > 60) linha2 += '   <== A TELA NAO ESTA DESENHANDO';
			if (extraInfo != '') linha2 += '   | ' + extraInfo;

			var linha3:String = '';
			try
			{
				linha3 = 'janela: ' + Std.int(Lib.current.stage.stageWidth) + 'x' + Std.int(Lib.current.stage.stageHeight);
				linha3 += '   |   objetos no palco: ' + Lib.current.stage.numChildren;
				linha3 += '   |   flixel visivel: ' + (FlxG.game != null ? Std.string(FlxG.game.visible) : '?');
			}
			catch (e:Dynamic) { }

			var linha4:String = '';
			try { linha4 = MobileGfx.report(); } catch (e:Dynamic) { }

			var total:String = linha1 + '\n' + linha2 + (linha3 != '' ? '\n' + linha3 : '') + (linha4 != '' ? '\n' + linha4 : '');

			// borda: cinza = normal, vermelha = tela sem desenho, verde = shader ok
			try
			{
				var cor:Int = 0x808080;
				if (draws == 0 && updates > 60) cor = 0xFF3030;
				else if (extraInfo == '' && draws > 0 && updates > 60) cor = 0x30FF60;
				if (cor != lastBorder)
				{
					lastBorder = cor;
					var g = panel.graphics;
					g.clear();
					g.beginFill(0x101018, 0.78);
					g.drawRect(0, 0, 716, 80);
					g.endFill();
					g.lineStyle(3, cor, 1);
					g.drawRect(0, 0, 716, 80);
				}
			}
			catch (e:Dynamic) { }
			if (total != lastRendered)
			{
				lastRendered = total;
				panelText.text = total;
			}

			// garante que fica por cima do jogo
			if (Lib.current != null && panel.parent == Lib.current.stage)
				Lib.current.stage.setChildIndex(panel, Lib.current.stage.numChildren - 1);
		}
		catch (e:Dynamic) { }
	}

	public static function isPanelVisible():Bool
		return panel != null && panel.visible;

	// ------------------------------------------------------------------- erro

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

			// aviso do sistema tambem (aparece mesmo com o OpenGL morto)
			MobileNative.toastCritico(title + ' | ' + details);

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
