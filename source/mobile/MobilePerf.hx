package mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import openfl.system.System as FlashSystem;
import Paths;

/**
 * Otimizações reais para aparelhos fracos ("batatas").
 *
 * Nada aqui é enfeite: cada função economiza RAM, GPU ou bateria.
 *  - limite de FPS/desenho aplicado de verdade no FlxG
 *  - desligar shaders/antialiasing/splashes/zoom de câmera em modo desempenho
 *  - soltar texturas não usadas depois de cada música (evita reiniciar por OOM)
 *  - evitar atualizações de fundo animado em fases com dançarinos
 */
class MobilePerf
{
	/** Modo desempenho: ligado por padrão em modo low-end nas opções. */
	public static var lowEnd(get, never):Bool;
	static function get_lowEnd():Bool return ClientPrefs.lowEndMode && MobilePlatform.isMobile;

	/** Aplica as preferências de desempenho no motor (chamar no boot e ao mudar opções). */
	public static function applyPreferences():Void
	{
		var cap:Int = ClientPrefs.mobileFPS;
		if (cap <= 0) cap = 60;
		if (cap > 240) cap = 240;

		FlxG.updateFramerate = cap;
		FlxG.drawFramerate = cap;

		if (lowEnd)
		{
			// aparelho fraco: sem antialiasing, sem shaders, menos efeitos
			// (o Psych consulta esses campos ao criar cada sprite/nota)
			ClientPrefs.globalAntialiasing = false;
			ClientPrefs.shaders = false;
			ClientPrefs.noteSplashes = false;
			ClientPrefs.camZooms = false;
			ClientPrefs.scoreZoom = false;
			ClientPrefs.flashing = false;
			ClientPrefs.comboStacking = false;
		}

		// obs: FlxG.autoPause é ligado no MobileApp.init (economiza bateria quando o
		// app vai para segundo plano). A opção mobileAutoPause controla a pausa da
		// música/menu ao voltar.
	}

	/** Solta texturas/sons que não estão em uso (chamado ao trocar de estado). */
	public static function collectMemory(aggressive:Bool = false):Void
	{
		try
		{
			Paths.clearUnusedMemory();
			if (aggressive || lowEnd)
			{
				Paths.clearStoredMemory();
				#if cpp
				FlashSystem.gc();
				#end
			}
		}
		catch (e:Dynamic) {}
	}

	/** Fases 1-3 têm dançarinos e luzes no fundo; em modo desempenho eles saem de cena. */
	public static function skipBackgroundAnimations():Bool
	{
		if (!MobilePlatform.isMobile) return false;
		if (lowEnd) return true;                        // aparelho fraco: sempre simplifica
		return ClientPrefs.mobileSimplifyBackground;    // escolha do jogador
	}

	/** NoteSplash é um dos efeitos mais caros por nota acertada. */
	public static function allowNoteSplash():Bool
	{
		return ClientPrefs.noteSplashes && !lowEnd;
	}

	/** Vibração curta (haptics) usada nos acertos/erros. Sem permissão extra no Android. */
	public static function vibrate(durationMs:Int):Void
	{
		if (!MobilePlatform.isMobile || !ClientPrefs.mobileVibration) return;
		try
		{
			// Lime 8: vibração via Haptic (precisa da permissão VIBRATE, que já está no
			// AndroidManifest gerado pelo Project.xml)
			lime.ui.Haptic.vibrate(0, durationMs);
		}
		catch (e:Dynamic) {}
	}
}
