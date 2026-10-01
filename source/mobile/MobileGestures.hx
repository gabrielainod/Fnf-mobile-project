package mobile;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import openfl.events.TouchEvent;

/**
 * Camada de toque para os MENUS (o jogo inteiro foi feito para teclado).
 *
 * Regra simples e universal, sem precisar reescrever cada tela:
 *  - toque curto  -> equivale a ENTER  (aceita / seleciona);
 *  - deslizar pra cima/baixo  -> equivale as setas (muda a seleção);
 *  - deslizar pros lados -> equivale a esquerda/direita (muda valores/sliders);
 *  - botão "voltar" do Android -> equivale a ESC (MobileBack).
 *
 * Como as teclas entram pelo teclado virtual (MobileKeys), qualquer menu do Psych
 * - inclusive submenus, sliders e telas de mod - fica navegável no celular sem
 * alteração no código original dele.
 */
class MobileGestures
{
	public static var enabled:Bool = #if mobile true #else false #end;

	/** Pixels de arrasto necessários para trocar uma opção na lista. */
	public static var stepPx:Float = 42;

	static var touches:Map<Int, TouchTrack> = new Map();
	static var listenersAdded:Bool = false;

	public static function init():Void
	{
		if (!enabled || listenersAdded) return;
		var stage = FlxG.stage;
		if (stage == null) return;

		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onBegin);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onMove);
		stage.addEventListener(TouchEvent.TOUCH_END, onEnd);
		listenersAdded = true;
	}

	// ------------------------------------------------------------- teclas

	inline public static function acceptKey():FlxKey
		return firstBind('accept', FlxKey.SPACE);

	inline public static function backKey():FlxKey
		return firstBind('back', FlxKey.ESCAPE);

	inline public static function pauseKey():FlxKey
		return firstBind('pause', FlxKey.ENTER);

	public static function firstBind(name:String, fallback:FlxKey):FlxKey
	{
		try
		{
			var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(name);
			if (binds != null)
			{
				for (b in binds)
				{
					var id:Int = cast b;
					if (id != 0 && id != -1) return b;
				}
			}
		}
		catch (e:Dynamic) {}
		return fallback;
	}

	// ---------------------------------------------------- quando não vale

	/**
	 * Durante a música tocando (sem menu aberto) o toque serve só para as setas:
	 * nada de converter toque em tecla de menu no meio do jogo.
	 */
	static function allowMenuInput():Bool
	{
		if (!enabled) return false;

		#if mobile
		var ps:PlayState = MobileControls.playState;
		if (ps != null)
		{
			var subStateOpened:Bool = (FlxG.state != null && FlxG.state.subState != null);
			if (!subStateOpened && ps.mobileCanPlay())
				return false;   // música rolando: toque é só das setas
		}
		#end
		return true;
	}

	static function track(e:TouchEvent):TouchTrack
	{
		var t:TouchTrack = touches.get(e.touchPointID);
		if (t == null)
		{
			t = {startX: e.stageX, startY: e.stageY, lastStepY: e.stageY, lastStepX: e.stageX, moved: false};
			touches.set(e.touchPointID, t);
		}
		return t;
	}

	// --------------------------------------------------------------- toques

	static function onBegin(e:TouchEvent):Void
	{
		if (!enabled) return;

		// se o dedo caiu numa hitbox de seta, quem cuida é o MobileControls
		if (MobileControls.hitboxAtScreen(e.stageX, e.stageY) >= 0)
		{
			touches.remove(e.touchPointID);
			return;
		}

		track(e);
	}

	static function onMove(e:TouchEvent):Void
	{
		if (!enabled) return;
		var t:TouchTrack = touches.get(e.touchPointID);
		if (t == null) return;
		if (!allowMenuInput()) return;

		var dx:Float = e.stageX - t.lastStepX;
		var dy:Float = e.stageY - t.lastStepY;

		if (Math.abs(e.stageX - t.startX) > 18 || Math.abs(e.stageY - t.startY) > 18) t.moved = true;

		// não afoga a fila de teclas
		if (MobileKeys.pending() > 3) return;

		if (Math.abs(dy) >= Math.abs(dx) && Math.abs(dy) >= stepPx)
		{
			MobileKeys.queueTap(dy > 0 ? firstBind('ui_down', FlxKey.DOWN) : firstBind('ui_up', FlxKey.UP));
			t.lastStepY = e.stageY;
		}
		else if (Math.abs(dx) >= stepPx)
		{
			MobileKeys.queueTap(dx > 0 ? firstBind('ui_right', FlxKey.RIGHT) : firstBind('ui_left', FlxKey.LEFT));
			t.lastStepX = e.stageX;
		}
	}

	static function onEnd(e:TouchEvent):Void
	{
		var t:TouchTrack = touches.get(e.touchPointID);
		touches.remove(e.touchPointID);
		if (t == null) return;
		if (!allowMenuInput()) return;

		if (!t.moved)
		{
			// toque curto = ENTER
			MobileKeys.queueTap(acceptKey());
		}
	}

	/** Chamado quando troca de tela, para não deixar toque "preso". */
	public static function clear():Void
	{
		touches = new Map();
	}
}

private typedef TouchTrack =
{
	startX:Float,
	startY:Float,
	lastStepX:Float,
	lastStepY:Float,
	moved:Bool
};
