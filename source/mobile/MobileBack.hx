package mobile;

import flixel.FlxG;

/**
 * Botão "voltar" do Android.
 *
 * No Android, o Lime fecha/minimiza o app quando o botão voltar é solto
 * (NativeApplication.hx: a menos que o evento `window.onKeyUp` seja cancelado).
 * Aqui esse evento é capturado e convertido numa ação do jogo:
 *  - dentro da música -> abre a pausa (ou fecha a pausa, se já estiver pausada);
 *  - nos menus        -> volta uma tela (mesmo efeito do ESC);
 *  - na tela inicial  -> deixa o Android minimizar o app (comportamento normal).
 */
class MobileBack
{
	static var added:Bool = false;
	static var window:lime.ui.Window = null;

	public static function init():Void
	{
		#if mobile
		if (added) return;

		try
		{
			var app = lime.app.Application.current;
			if (app == null) return;
			window = app.window;
			if (window == null) return;

			window.onKeyUp.add(onWindowKeyUp);
			added = true;
			MobilePlatform.log('botão voltar registrado no Lime');
		}
		catch (e:Dynamic)
		{
			MobilePlatform.log('não foi possível registrar o botão voltar: ' + Std.string(e));
		}
		#end
	}

	#if mobile
	static function onWindowKeyUp(code:lime.ui.KeyCode, modifier:lime.ui.KeyModifier):Void
	{
		if (code != lime.ui.KeyCode.APP_CONTROL_BACK) return;

		if (handleBack() && window != null)
		{
			// cancela o comportamento padrão (fechar o app)
			try { window.onKeyUp.cancel(); } catch (e:Dynamic) {}
		}
	}
	#end

	/** Executa a ação de "voltar" do estado atual. Retorna false para deixar o Android agir. */
	public static function handleBack():Bool
	{
		var state = FlxG.state;
		if (state == null) return false;

		#if mobile
		if (Std.isOfType(state, TitleState))
		{
			// tela inicial: deixa o Android minimizar o jogo
			return false;
		}

		var ps:PlayState = MobileControls.playState;
		if (ps != null && Std.isOfType(state, PlayState))
		{
			if (ps.paused || (state.subState != null))
			{
				// pausa aberta -> ESC fecha/resume
				MobileKeys.queueTap(MobileGestures.backKey());
			}
			else
			{
				// música rolando -> abre a pausa
				MobileKeys.queueTap(MobileGestures.pauseKey());
			}
			return true;
		}
		#end

		// menus: mesmo efeito do ESC
		MobileKeys.queueTap(MobileGestures.backKey());
		return true;
	}
}
