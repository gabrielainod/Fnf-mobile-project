package mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import openfl.display.Sprite;
import openfl.events.TouchEvent;

typedef MobileTapRect =
{
	x:Float,
	y:Float,
	w:Float,
	h:Float,
	cb:Void->Void
};

/**
 * Camada de toque para os menus do jogo.
 *
 * Os menus do Psych são feitos para teclado (setas + Enter). Sem isso aqui, um
 * celular não teria como escolher música, mudar opção ou sair de uma tela.
 * Cada estado registra retângulos tocáveis (normalmente em cima dos próprios
 * itens do menu) e este helper transforma os toques em ações.
 */
class MobileUI
{
	public static var enabled:Bool = #if mobile true #else false #end;

	static var rects:Array<MobileTapRect> = [];
	static var pending:Map<Int, MobileTapRect> = new Map();
	static var dragging:Map<Int, Bool> = new Map();
	static var listenersAdded:Bool = false;

	static var acceptQueued:Bool = false;
	static var scrollQueued:Int = 0;

	static var backSprite:FlxSprite = null;
	static var backCallback:Void->Void = null;
	static var backState:FlxState = null;

	static var tmpPoint:FlxPoint = new FlxPoint();
	static var tmpFlashPoint = new openfl.geom.Point();

	// --------------------------------------------------------- registro

	/** Limpa os registros do estado anterior. Chamar no create() de cada estado. */
	public static function reset():Void
	{
		rects = [];
		pending = new Map();
		dragging = new Map();
		acceptQueued = false;
		scrollQueued = 0;
		backSprite = null;
		backCallback = null;
		backState = null;
		addListeners();
	}

	public static function add(x:Float, y:Float, w:Float, h:Float, cb:Void->Void):Void
	{
		if (!enabled) return;
		rects.push({x: x, y: y, w: w, h: h, cb: cb});
	}

	/** Registra o próprio sprite como área de toque (com uma folga de pixels). */
	public static function addSprite(spr:FlxSprite, cb:Void->Void, expand:Float = 14):Void
	{
		if (spr == null) return;
		var cam:FlxCamera = FlxG.camera;
		spr.getScreenPosition(tmpPoint, cam);
		var w:Float = spr.width * Math.abs(spr.scale.x);
		var h:Float = spr.height * Math.abs(spr.scale.y);
		add(tmpPoint.x - expand, tmpPoint.y - expand, w + expand * 2, h + expand * 2, cb);
	}

	/** Botão de voltar desenhado no canto (equivalente à tecla ESC). */
	public static function addBackButton(state:FlxState, cb:Void->Void):Void
	{
		if (!enabled || state == null) return;
		backState = state;
		backCallback = cb;

		var btn = new FlxSprite(20, 20);
		btn.makeGraphic(160, 60, FlxColor.BLACK);
		btn.alpha = 0.45;
		btn.scrollFactor.set(0, 0);
		state.add(btn);
		backSprite = btn;

		add(20, 20, 160, 60, function() {
			if (backCallback != null) backCallback();
		});
	}

	public static function queueAccept():Void acceptQueued = true;
	public static function queueScroll(dir:Int):Void scrollQueued += dir;

	/** true uma única vez quando o jogador tocou num item (equivale ao Enter). */
	public static function acceptPressed():Bool
	{
		if (!enabled) return false;
		if (acceptQueued) { acceptQueued = false; return true; }
		return false;
	}

	/** -1 / 0 / 1: rolagem pedida por arrasto (equivale às setas ↑/↓). */
	public static function scrollDelta():Int
	{
		if (!enabled) return 0;
		var d:Int = scrollQueued;
		scrollQueued = 0;
		return d;
	}

	// ------------------------------------------------------------ toques

	static function addListeners():Void
	{
		if (!enabled || listenersAdded) return;
		var stage = FlxG.stage;
		if (stage == null) return;
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onBegin);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onMove);
		stage.addEventListener(TouchEvent.TOUCH_END, onEnd);
		listenersAdded = true;
	}

	public static function removeListeners():Void
	{
		if (!listenersAdded) return;
		var stage = FlxG.stage;
		if (stage == null) { listenersAdded = false; return; }
		stage.removeEventListener(TouchEvent.TOUCH_BEGIN, onBegin);
		stage.removeEventListener(TouchEvent.TOUCH_MOVE, onMove);
		stage.removeEventListener(TouchEvent.TOUCH_END, onEnd);
		listenersAdded = false;
	}

	static function toViewSpace(e:TouchEvent, cam:FlxCamera):FlxPoint
	{
		var p = FlxG.game.globalToLocal(tmpFlashPoint.setTo(e.stageX, e.stageY));
		tmpPoint.x = (p.x - cam.x + 0.5 * cam.width * (cam.zoom - cam.initialZoom)) / cam.zoom;
		tmpPoint.y = (p.y - cam.y + 0.5 * cam.height * (cam.zoom - cam.initialZoom)) / cam.zoom;
		return tmpPoint;
	}

	static function rectAt(x:Float, y:Float):MobileTapRect
	{
		var i:Int = rects.length - 1;
		while (i >= 0)
		{
			var r = rects[i];
			if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) return r;
			i--;
		}
		return null;
	}

	static function onBegin(e:TouchEvent):Void
	{
		if (!enabled) return;
		var cam:FlxCamera = FlxG.camera;
		var pos = toViewSpace(e, cam);
		var r = rectAt(pos.x, pos.y);
		if (r == null) return;
		pending.set(e.touchPointID, r);
		dragging.set(e.touchPointID, false);
	}

	static function onMove(e:TouchEvent):Void
	{
		if (!enabled) return;
		if (!pending.exists(e.touchPointID)) return;
		dragging.set(e.touchPointID, true);   // arrastou => não é toque simples
	}

	static function onEnd(e:TouchEvent):Void
	{
		if (!enabled) return;
		var r = pending.get(e.touchPointID);
		pending.remove(e.touchPointID);
		var wasDrag:Bool = dragging.get(e.touchPointID) == true;
		dragging.remove(e.touchPointID);

		if (r == null || wasDrag) return;

		var cam:FlxCamera = FlxG.camera;
		var pos = toViewSpace(e, cam);
		// só dispara se o dedo soltou dentro do mesmo retângulo
		if (pos.x >= r.x && pos.x <= r.x + r.w && pos.y >= r.y && pos.y <= r.y + r.h)
		{
			r.cb();
		}
	}
}
