package mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import openfl.display.DisplayObject;
import openfl.events.TouchEvent;
import PlayState;
import StrumNote;

/**
 * CONTROLES POR HITBOX — o coração da compatibilidade mobile deste projeto.
 *
 * Como funciona: cada seta da "strumline" (as 4 setas do jogador) ganha uma
 * área de toque (hitbox) alinhada com ela, redimensionável nas opções. Tocar na
 * área acerta a seta daquele lane, exatamente como apertar o teclado — o toque é
 * injetado no mesmo caminho de código que o Psych usa para controles/gamepad,
 * então notas, sustains, animações, ratings, modcharts e scripts Lua funcionam
 * igual.
 *
 * Multi-touch de verdade: cada dedo é ligado a um lane (touchPointID) e solta a
 * nota quando sai da tela, permitindo segurar sustains e tocar jacks.
 */
class MobileControls
{
	public static var enabled(default, null):Bool = false;
	public static var active(default, null):Bool = false;

	static var playState:PlayState = null;
	static var boxes:Array<FlxRect> = [];
	static var touchLane:Map<Int, Int> = new Map();
	static var heldLanes:Array<Bool> = [false, false, false, false];
	static var listenersAdded:Bool = false;

	static var zones:FlxTypedGroup<FlxSprite> = null;
	static var zoneSprites:Array<FlxSprite> = [];
	static var wasShowingZones:Bool = false;

	static var tmpPoint:FlxPoint = new FlxPoint();
	static var tmpTouch:FlxPoint = new FlxPoint();

	public static var laneColors:Array<FlxColor> = [0xC24B99, 0x00FFFF, 0x12FA05, 0xF9393F];

	inline public static function isHeld(lane:Int):Bool
		return lane >= 0 && lane < heldLanes.length && heldLanes[lane];

	inline public static function anyHeld():Bool
		return heldLanes[0] || heldLanes[1] || heldLanes[2] || heldLanes[3];

	// ------------------------------------------------------------------ ativar

	public static function attach(ps:PlayState):Void
	{
		if (!MobilePlatform.isMobile) return;
		if (!ClientPrefs.mobileControls) return;
		if (ps == null) return;

		playState = ps;
		enabled = true;
		active = true;
		clearState();
		rebuildBoxes();
		addListeners();

		if (ClientPrefs.mobileShowHitboxes) createZones();
	}

	public static function detach():Void
	{
		releaseAll();
		active = false;
		enabled = false;
		removeListeners();
		destroyZones();
		playState = null;
		touchLane = new Map();
	}

	static function clearState():Void
	{
		touchLane = new Map();
		for (i in 0...heldLanes.length) heldLanes[i] = false;
	}

	public static function releaseAll():Void
	{
		if (playState == null) { clearState(); return; }
		for (i in 0...heldLanes.length)
		{
			if (heldLanes[i]) playState.mobileLaneRelease(i);
			heldLanes[i] = false;
		}
		touchLane = new Map();
	}

	// ------------------------------------------------------------- hitboxes

	/** Recalcula as áreas de toque conforme a posição real das setas na tela. */
	public static function rebuildBoxes():Void
	{
		if (playState == null || playState.playerStrums == null) return;

		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		var padding:Float = ClientPrefs.mobileHitboxSize;

		for (i in 0...4)
		{
			var strum:StrumNote = playState.playerStrums.members[i];
			if (strum == null)
			{
				if (boxes[i] != null) { boxes[i].put(); boxes[i] = null; }
				continue;
			}

			strum.getScreenPosition(tmpPoint, cam);
			var w:Float = strum.width * Math.abs(strum.scale.x);
			var h:Float = strum.height * Math.abs(strum.scale.y);

			if (boxes[i] == null) boxes[i] = FlxRect.get();
			boxes[i].set(tmpPoint.x - padding, tmpPoint.y - padding, w + padding * 2, h + padding * 2);
		}
	}

	static function laneAtPoint(viewX:Float, viewY:Float):Int
	{
		for (i in 0...boxes.length)
		{
			var r:FlxRect = boxes[i];
			if (r == null) continue;
			if (viewX >= r.x && viewX <= r.right && viewY >= r.y && viewY <= r.bottom) return i;
		}
		return -1;
	}

	/** Converte a posição do toque (coordenadas do stage) para o espaço da câmera do HUD. */
	static function toViewSpace(touch:TouchEvent, cam:FlxCamera):FlxPoint
	{
		var p = FlxG.game.globalToLocal(tmpFlashPoint.setTo(touch.stageX, touch.stageY));
		tmpTouch.x = (p.x - cam.x + 0.5 * cam.width * (cam.zoom - cam.initialZoom)) / cam.zoom;
		tmpTouch.y = (p.y - cam.y + 0.5 * cam.height * (cam.zoom - cam.initialZoom)) / cam.zoom;
		return tmpTouch;
	}

	static var tmpFlashPoint = new openfl.geom.Point();

	// --------------------------------------------------------------- toques

	static function addListeners():Void
	{
		if (listenersAdded) return;
		var stage = FlxG.stage;
		if (stage == null) return;
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		listenersAdded = true;
	}

	static function removeListeners():Void
	{
		if (!listenersAdded) return;
		var stage = FlxG.stage;
		if (stage == null) { listenersAdded = false; return; }
		stage.removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		stage.removeEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		stage.removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		listenersAdded = false;
	}

	static function onTouchBegin(e:TouchEvent):Void
	{
		if (!active || playState == null) return;
		if (touchLane.exists(e.touchPointID)) return;
		if (!playState.mobileCanPlay()) return;

		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		var pos = toViewSpace(e, cam);
		var lane = laneAtPoint(pos.x, pos.y);
		if (lane < 0) return;

		touchLane.set(e.touchPointID, lane);
		pressLane(lane);
	}

	static function onTouchMove(e:TouchEvent):Void
	{
		if (!active || playState == null) return;
		if (!ClientPrefs.mobileSlide) return;
		if (!touchLane.exists(e.touchPointID)) return;

		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		var pos = toViewSpace(e, cam);
		var lane = laneAtPoint(pos.x, pos.y);
		var old:Int = touchLane.get(e.touchPointID);
		if (lane < 0 || lane == old) return;

		touchLane.set(e.touchPointID, lane);
		releaseLaneIfUnused(old);
		pressLane(lane);
	}

	static function onTouchEnd(e:TouchEvent):Void
	{
		if (!touchLane.exists(e.touchPointID)) return;
		var lane:Int = touchLane.get(e.touchPointID);
		touchLane.remove(e.touchPointID);
		releaseLaneIfUnused(lane);
	}

	static function pressLane(lane:Int):Void
	{
		if (playState == null) return;
		heldLanes[lane] = true;
		playState.mobileLanePress(lane);
	}

	static function releaseLaneIfUnused(lane:Int):Void
	{
		for (v in touchLane)
		{
			if (v == lane) return;   // ainda tem dedo nesse lane
		}
		if (!heldLanes[lane]) return;
		heldLanes[lane] = false;
		if (playState != null) playState.mobileLaneRelease(lane);
	}

	// ----------------------------------------------------------- por frame

	/** Chamado a cada frame pelo PlayState. */
	public static function update():Void
	{
		if (!active || playState == null) return;

		// se a música pausou/terminou, solta tudo para não travar sustain
		if (!playState.mobileCanPlay())
		{
			if (anyHeld() || touchLane.keys().hasNext()) releaseAll();
		}

		rebuildBoxes();

		if (ClientPrefs.mobileShowHitboxes)
		{
			if (!wasShowingZones) createZones();
			updateZones();
		}
		else if (wasShowingZones)
		{
			destroyZones();
		}
	}

	// ------------------------------------------------------- visual (opcional)

	static function createZones():Void
	{
		if (playState == null || zones != null) return;
		wasShowingZones = true;
		zones = new FlxTypedGroup<FlxSprite>();
		for (i in 0...4)
		{
			var spr = new FlxSprite();
			spr.makeGraphic(2, 2, laneColors[i % laneColors.length]);
			spr.alpha = 0.16;
			spr.scrollFactor.set(0, 0);
			spr.cameras = [playState.camHUD];
			zones.add(spr);
			zoneSprites[i] = spr;
		}
		playState.add(zones);
	}

	static function updateZones():Void
	{
		if (zones == null) return;
		for (i in 0...4)
		{
			var spr = zoneSprites[i];
			var r = boxes[i];
			if (spr == null || r == null) continue;
			spr.x = r.x;
			spr.y = r.y;
			spr.scale.set(r.width / 2.0, r.height / 2.0);
			spr.updateHitbox();
			spr.alpha = heldLanes[i] ? 0.38 : 0.16;
		}
	}

	static function destroyZones():Void
	{
		if (zones == null) return;
		if (playState != null) playState.remove(zones, true);
		zones.destroy();
		zones = null;
		zoneSprites = [];
		wasShowingZones = false;
	}
}
