package mobile;

/**
 * Ponte entre o núcleo do Psych (que é compartilhado com PC) e o código mobile.
 *
 * O jogo base não pode depender de classes que só existem no Android, senão o
 * build de PC quebra. Esta classe existe em qualquer alvo e devolve `false`
 * quando não é mobile - assim o núcleo pode perguntar coisas do tipo
 * "as animações de fundo estão desligadas?" sem `#if` espalhado pelo código.
 */
class MobileCompat
{
	inline public static function isMobile():Bool
	{
		#if mobile
		return true;
		#else
		return false;
		#end
	}

	inline public static function isAndroid():Bool
	{
		#if android
		return true;
		#else
		return false;
		#end
	}

	/** Modo desempenho ligado (menos animações de fundo, menos efeitos). */
	inline public static function simplifyBackground():Bool
	{
		#if mobile
		return MobilePerf.skipBackgroundAnimations();
		#else
		return false;
		#end
	}

	/** Note splash (efeito de respingo) liberado? */
	inline public static function allowNoteSplash():Bool
	{
		#if mobile
		return ClientPrefs.noteSplashes && !MobilePerf.lowEnd;
		#else
		return true;
		#end
	}
}
