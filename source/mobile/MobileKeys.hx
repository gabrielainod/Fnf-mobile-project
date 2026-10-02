package mobile;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

/**
 * Teclado virtual do FNF Mobile.
 *
 * O Psych Engine (assim como o Flixel) trata teclado como fonte de verdade da
 * jogabilidade e dos menus: `FlxG.keys`, os listeners de `onKeyPress` do
 * PlayState e os `controls` de cada menu escutam eventos de teclado no stage.
 * Em vez de reescrever cada menu, este projeto injeta eventos de teclado
 * sintéticos a partir dos toques na tela - ou seja, o celular "digita" para o
 * jogo. Com isso tudo que já existia continua funcionando igual:
 * notas, sustains, ghosts taps, menus, sliders, scripts Lua e mods.
 *
 * Duas formas de disparo:
 *  - pressKey/releaseKey: imediato, usado nos acertos (latência mínima);
 *  - queueTap/queueMoves: agendado, disparado no meio do frame pelo plugin
 *    (depois de `FlxG.keys.update()` e antes do `update()` do estado), que é
 *    o único momento em que `justPressed` vale para os menus.
 */
class MobileKeys
{
	public static var enabled(default, null):Bool = #if mobile true #else false #end;

	/** Fila de teclas agendadas (um passo por frame, para justPressed valer). */
	static var queue:Array<KeyStep> = [];
	static var plugin:MobileKeysPlugin = null;
	static var lastError:String = null;

	public static function init():Void
	{
		if (!enabled || plugin != null) return;
		if (FlxG.plugins == null) return;

		plugin = new MobileKeysPlugin();
		plugin.active = true;
		FlxG.plugins.add(plugin);

		// ao trocar de tela, joga fora toques pendentes: senão um toque feito no
		// menu anterior acertaria um item do menu novo
		FlxG.signals.preStateSwitch.add(clearQueue);
	}

	/** Quantos passos ainda estão na fila (usado para não afogar o menu). */
	inline public static function pending():Int
		return queue.length;

	public static function clearQueue():Void
	{
		queue = [];
	}

	// ------------------------------------------------- disparo imediato

	/** Pressiona uma tecla agora (mesmo caminho de um teclado de verdade). */
	public static function pressKey(key:FlxKey):Void
	{
		dispatch(key, true);
	}

	/** Solta uma tecla agora. */
	public static function releaseKey(key:FlxKey):Void
	{
		dispatch(key, false);
	}

	/** Clique completo: solta no próximo frame (senão o Flixel perde o justPressed). */
	public static function tapKey(key:FlxKey):Void
	{
		pressKey(key);
		queuePush(key, false);
	}

	// ------------------------------------------------- disparo agendado

	public static function queuePress(key:FlxKey):Void
	{
		queuePush(key, true);
	}

	public static function queueRelease(key:FlxKey):Void
	{
		queuePush(key, false);
	}

	/** Pressiona e solta em frames seguidos (equivale a um toque de tecla). */
	public static function queueTap(key:FlxKey):Void
	{
		queuePush(key, true);
		queuePush(key, false);
	}

	/** Repete a mesma tecla N vezes (ex.: descer 3 itens no menu). */
	public static function queueMoves(key:FlxKey, times:Int):Void
	{
		if (times <= 0) return;
		for (i in 0...times) queueTap(key);
	}

	static function queuePush(key:Null<FlxKey>, press:Bool):Void
	{
		if (!enabled) return;
		if (key == null) return;
		if (queue.length > 40) return;   // trava de segurança
		queue.push({key: key, press: press});
	}

	// ------------------------------------------------------------ interno

	/** Chamado pelo plugin dentro do frame: aplica UM passo da fila. */
	public static function tick():Void
	{
		if (!enabled || queue.length == 0) return;

		var step:KeyStep = queue.shift();
		dispatch(step.key, step.press);
	}

	static function dispatch(key:FlxKey, press:Bool):Void
	{
		if (!enabled) return;

		var stage = FlxG.stage;
		if (stage == null) return;

		var keyCode:Int = cast key;
		if (keyCode == 0 || keyCode == -1) return;

		try
		{
			var type:String = press ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP;
			// assinatura: (type, bubbles, cancelable, charCode, keyCode)
			stage.dispatchEvent(new KeyboardEvent(type, true, true, -1, keyCode));
		}
		catch (e:Dynamic)
		{
			var msg:String = Std.string(e);
			if (lastError != msg)
			{
				lastError = msg;
				MobilePlatform.logAppend('erro ao despachar tecla ' + keyCode + ': ' + msg);
			}
		}
	}
}

private typedef KeyStep =
{
	key:FlxKey,
	press:Bool
};

/**
 * Plugin do Flixel: roda entre o `FlxG.keys.update()` e o `update()` do estado,
 * que é exatamente a janela em que um `justPressed` recém despachado é válido
 * para os menus.
 */
private class MobileKeysPlugin extends FlxBasic
{
	public function new()
	{
		super();
	}

	override public function update(elapsed:Float):Void
	{
		MobileKeys.tick();

		// anota em que tela o jogo está (diagnóstico de travamento no boot)
		try
		{
			var state = FlxG.state;
			if (state != null)
			{
				MobilePlatform.trackState(Type.getClassName(Type.getClass(state)));
			}
		}
		catch (e:Dynamic) {}
	}
}
