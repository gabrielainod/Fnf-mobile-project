package mobile;

#if mobile
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import options.BaseOptionsMenu;
import options.Option;
import Paths;

/**
 * Menu "Mobile" dentro de Options.
 *
 * É o mesmo sistema de opções do Psych (BaseOptionsMenu), então tudo funciona
 * igual ao resto do jogo: setas pra navegar, Enter/Toque pra mudar, ESC/voltar
 * pra sair. Cada opção grava direto em ClientPrefs (com save automático).
 */
class MobileOptions extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Mobile';
		rpcTitle = 'Mobile Settings';

		// ------------------------------------------------ controles de toque
		addOption(new Option('Controles de toque',
			'Liga as hitboxes de toque nas setas. Desligue para jogar com teclado ou gamepad.',
			'mobileControls', 'bool', true));

		var hitbox = new Option('Área de toque das setas',
			'Quantos pixels a mais de área cada seta ganha. Aumente se estiver errando toque fino.',
			'mobileHitboxSize', 'int', 30);
		hitbox.minValue = 0;
		hitbox.maxValue = 90;
		hitbox.changeValue = 10;
		hitbox.displayFormat = '%v px';
		addOption(hitbox);

		addOption(new Option('Arrastar entre setas',
			'Permite deslizar o dedo de uma seta para outra sem soltar (útil em sequências rápidas).',
			'mobileSlide', 'bool', true));

		addOption(new Option('Mostrar áreas de toque',
			'Desenha as hitboxes na cor de cada seta, para conferir se estão do tamanho certo.',
			'mobileShowHitboxes', 'bool', false));

		addOption(new Option('Botão de pausa na tela',
			'Mostra um botão de pausa no canto durante a música.',
			'mobilePauseButton', 'bool', true));

		// ----------------------------------------------------- desempenho
		var fps = new Option('Limite de FPS',
			'30 FPS economiza muita bateria em aparelho fraco; 60 FPS deixa o jogo mais fluido.',
			'mobileFPS', 'int', 60);
		fps.minValue = 30;
		fps.maxValue = 120;
		fps.changeValue = 30;
		fps.displayFormat = '%v FPS';
		fps.onChange = function() { MobilePerf.applyPreferences(); };
		addOption(fps);

		var lowEnd = new Option('Modo aparelho fraco',
			'Desliga antialiasing, shaders, splashes e zooms de câmera. Recomendado em celular antigo.',
			'lowEndMode', 'bool', false);
		lowEnd.onChange = function() { MobilePerf.applyPreferences(); };
		addOption(lowEnd);

		var simplify = new Option('Fundo simplificado',
			'Reduz animações dos cenários das Semanas 1 a 3 (dançarinos, luzes, trem).',
			'mobileSimplifyBackground', 'bool', true);
		simplify.onChange = function() { MobilePerf.applyPreferences(); };
		addOption(simplify);

		addOption(new Option('Pausar ao sair do app',
			'Pausa a música quando você troca de aplicativo ou apaga a tela.',
			'mobileAutoPause', 'bool', true));

		addOption(new Option('Vibração',
			'Vibra de leve no toque das setas (usa o vibrador do aparelho).',
			'mobileVibration', 'bool', true));

		super();

		// ------------------------------------------------- pasta de mods
		var info:FlxText = new FlxText(75, 92, FlxG.width - 150, '', 16);
		info.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		info.text = 'Mods: ' + MobilePlatform.modsFolder;
		info.alpha = 0.75;
		info.borderSize = 1.6;
		add(info);
	}
}
#end
