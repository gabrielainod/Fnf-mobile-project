package mobile;

import flixel.FlxG;
import openfl.Lib;
import openfl.events.Event;

/**
 * Ciclo de vida do aplicativo no Android (trocar de app, apagar a tela, voltar).
 *
 * O Psych não tinha nenhum tratamento para isso: se o jogador saísse do app no
 * meio da música, o jogo continuava rodando/consumindo bateria e voltava
 * dessincronizado. Aqui o jogo pede a pausa (o PlayState abre o menu de pausa)
 * assim que o app volta para a frente, e o Lime também é configurado para pausar
 * o loop enquanto o app está em segundo plano.
 */
class MobileApp
{
	public static var backgrounded(default, null):Bool = false;

	static var added:Bool = false;

	public static function init():Void
	{
		#if mobile
		if (added) return;

		try
		{
			// O Flixel pausa o loop de jogo quando a janela perde o foco.
			FlxG.autoPause = true;

			var stage = Lib.current.stage;
			if (stage != null)
			{
				stage.addEventListener(Event.DEACTIVATE, onDeactivate);
				stage.addEventListener(Event.ACTIVATE, onActivate);
				added = true;
			}

			var app = lime.app.Application.current;
			if (app != null && app.window != null)
			{
				// eventos de ciclo de vida do Lime (o Window do Lime 8 não tem onHide)
				app.window.onDeactivate.add(onHide);
				app.window.onActivate.add(onShow);
			}

			MobilePlatform.log('ciclo de vida do app registrado');
		}
		catch (e:Dynamic)
		{
			MobilePlatform.log('falha no ciclo de vida: ' + Std.string(e));
		}
		#end
	}

	#if mobile
	static function onDeactivate(e:Event):Void onHide();

	static function onHide():Void
	{
		if (backgrounded) return;
		backgrounded = true;

		// não dá para abrir o menu de pausa com o app em segundo plano, então a
		// música é parada na hora e a pausa abre quando o jogador voltar.
		if (ClientPrefs.mobileAutoPause)
		{
			try
			{
				if (FlxG.sound != null && FlxG.sound.music != null && FlxG.sound.music.playing)
					FlxG.sound.music.pause();
			}
			catch (e:Dynamic) {}
		}
	}

	static function onActivate(e:Event):Void
	{
		backgrounded = false;
	}

	static function onShow():Void
	{
		if (!backgrounded) return;
		backgrounded = false;
		requestPause();
	}

	/** Pede ao PlayState que abra a pausa (se estiver no meio de uma música). */
	public static function requestPause():Void
	{
		if (!ClientPrefs.mobileAutoPause) return;

		var ps = MobileControls.playState;
		if (ps == null) return;
		if (!ps.startedCountdown || ps.paused || ps.isDead || ps.endingSong) return;

		ps.mobileRequestPause();
	}
	#end
}
