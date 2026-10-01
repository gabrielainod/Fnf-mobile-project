package mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import openfl.events.TouchEvent;

/**
 * CONTROLES POR HITBOX — o coração da compatibilidade mobile deste projeto.
 *
 * Cada uma das 4 setas do jogador ganha uma área de toque alinhada com ela
 * (a "hitbox"), que pode ser aumentada nas opções para caber o dedo. Tocar na
 * área equivale a apertar a tecla daquela seta: o toque é convertido em um
 * evento de teclado sintético por MobileKeys, ou seja, entra no jogo pelo mesmo
 * caminho que o Psych usava para teclado/gamepad. Resultado: notas, sustains
 * (segurar o dedo), ghost tapping, animação das setas, ratings, botplay,
 * modcharts e scripts Lua funcionam sem precisar mudar nada no jogo em si.
 *
 * Recursos:
 *  - multi-touch de verdade: cada dedo é preso a um lane (touchPointID), então dá
 *    para segurar uma seta e tocar as outras ao mesmo tempo;
 *  - arrastar entre setas (opcional) para quem joga deslizando o dedo;
 *  - desenho das hitboxes na tela para calibrar;
 *  - botão de pausa opcional no canto superior.
 */
class MobileControls
{
	public static var active(default, null):Bool = false;
	public static var playState(default, null):PlayState = null;

	static var boxes:Array<FlxRect> = [];
	static var laneKeys:Array<FlxKey> = [];
	static var touchLane:Map<Int, Int> = new Map();
	static var heldLanes:Array<Bool> = [false, false, false, false];
	static var listenersAdded:Bool = false;

	static var zones:FlxTypedGroup<FlxSprite> = null;
	static var zoneSprites:Array<FlxSprite> = [];
	static var showingZones:Bool = false;

	static var pauseButton:FlxSprite = null;
	static var pauseCenter:FlxSprite = null;

	static var tmpPoint:FlxPoint = new FlxPoint();
	static var tmpTouch:FlxPoint = new FlxPoint();
	static var tmpFlashPoint = new openfl.geom.Point();

	public static var laneColors:Array<FlxColor> = [0xC24B99, 0x00FFFF, 0x12FA05, 0xF9393F];

	inline public static function isHeld(lane:Int):Bool
		return lane >= 0 && lane < heldLanes.length && heldLanes[lane];

	inline public static function anyHeld():Bool
		return heldLanes[0] || heldLanes[1] || heldLanes[2] || heldLanes[3];

	// --------------------------------------------------------------- ciclo

	public static function attach(ps:PlayState):Void
	{
		if (ps == null) return;
		playState = ps;
		active = true;
		loadLaneKeys();
		clearState();
		addListeners();
		updateZones();
		updatePauseButton();
	}

	public static function detach():Void
	{
		releaseAll();
		active = false;
		removeListeners();
		destroyZones();
		destroyPauseButton();
		playState = null;
		touchLane = new Map();
	}

	/** Teclas usadas em cada lane — exatamente as mesmas binds do teclado. */
	static function loadLaneKeys():Void
	{
		var names:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];
		var defaults:Array<FlxKey> = [FlxKey.A, FlxKey.S, FlxKey.W, FlxKey.D];

		for (i in 0...4)
		{
			var key:FlxKey = null;
			try
			{
				var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(names[i]);
				if (binds != null)
				{
					for (b in binds)
					{
						var id:Int = cast b;
						if (id != 0 && id != -1) { key = b; break; }
					}
				}
			}
			catch (e:Dynamic) {}

			laneKeys[i] = key != null ? key : defaults[i];
		}
	}

	static function clearState():Void
	{
		touchLane = new Map();
		for (i in 0...heldLanes.length) heldLanes[i] = false;
	}

	public static function releaseAll():Void
	{
		for (i in 0...heldLanes.length)
		{
			if (heldLanes[i])
			{
				heldLanes[i] = false;
				MobileKeys.releaseKey(laneKeys[i]);
			}
		}
		touchLane = new Map();
	}

	inline public static function canPlay():Bool
	{
		if (playState == null) return false;
		return playState.mobileCanPlay();
	}

	// ------------------------------------------------------------- hitboxes

	static function rebuildBoxes():Void
	{
		if (playState == null || playState.playerStrums == null) return;

		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		if (cam == null) return;

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
			if (w <= 0) w = strum.width;
			if (h <= 0) h = strum.height;

			if (boxes[i] == null) boxes[i] = FlxRect.get();
			boxes[i].set(tmpPoint.x - padding, tmpPoint.y - padding, w + padding * 2, h + padding * 2);
		}
	}

	static function laneAtView(viewX:Float, viewY:Float):Int
	{
		for (i in 0...boxes.length)
		{
			var r:FlxRect = boxes[i];
			if (r == null) continue;
			if (viewX >= r.x && viewX <= r.right && viewY >= r.y && viewY <= r.bottom) return i;
		}
		return -1;
	}

	/**
	 * Converte a posição do toque (coordenadas do palco) para o espaço da câmera
	 * do HUD. Usa a mesma fórmula do FlxPointer.getScreenPosition.
	 */
	static function toViewSpace(stageX:Float, stageY:Float, cam:FlxCamera):FlxPoint
	{
		tmpFlashPoint.setTo(stageX, stageY);
		FlxG.game.globalToLocal(tmpFlashPoint);
		tmpTouch.x = (tmpFlashPoint.x - cam.x + 0.5 * cam.width * (cam.zoom - cam.initialZoom)) / cam.zoom;
		tmpTouch.y = (tmpFlashPoint.y - cam.y + 0.5 * cam.height * (cam.zoom - cam.initialZoom)) / cam.zoom;
		return tmpTouch;
	}

	/** Lane sob o ponto do palco (usado também pelo reconhecedor de gestos). */
	public static function hitboxAtScreen(stageX:Float, stageY:Float):Int
	{
		if (!active || playState == null) return -1;
		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		if (cam == null) return -1;
		var pos = toViewSpace(stageX, stageY, cam);
		return laneAtView(pos.x, pos.y);
	}

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

		// toque no botão de pausa
		if (pauseButton != null && pauseButton.visible && ClientPrefs.mobilePauseButton)
		{
			var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
			var posP = toViewSpace(e.stageX, e.stageY, cam);
			if (posP.x >= pauseButton.x && posP.x <= pauseButton.x + pauseButton.width
				&& posP.y >= pauseButton.y && posP.y <= pauseButton.y + pauseButton.height)
			{
				if (canPlay()) MobileKeys.queueTap(pauseKey());
				return;
			}
		}

		if (!canPlay()) return;

		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		var pos = toViewSpace(e.stageX, e.stageY, cam);
		var lane = laneAtView(pos.x, pos.y);
		if (lane < 0) return;

		touchLane.set(e.touchPointID, lane);
		pressLane(lane);
	}

	static function onTouchMove(e:TouchEvent):Void
	{
		if (!active || playState == null) return;
		if (!ClientPrefs.mobileSlide) return;
		if (!touchLane.exists(e.touchPointID)) return;
		if (!canPlay()) return;

		var cam:FlxCamera = playState.camHUD != null ? playState.camHUD : FlxG.camera;
		var pos = toViewSpace(e.stageX, e.stageY, cam);
		var lane = laneAtView(pos.x, pos.y);
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
		if (lane < 0 || lane > 3) return;
		heldLanes[lane] = true;
		MobileKeys.pressKey(laneKeys[lane]);
		MobilePerf.vibrate(8);
	}

	static function releaseLaneIfUnused(lane:Int):Void
	{
		if (lane < 0 || lane > 3) return;
		for (v in touchLane)
		{
			if (v == lane) return;   // ainda tem um dedo nesse lane
		}
		if (!heldLanes[lane]) return;
		heldLanes[lane] = false;
		MobileKeys.releaseKey(laneKeys[lane]);
	}

	static function pauseKey():FlxKey
	{
		try
		{
			var binds:Array<FlxKey> = ClientPrefs.keyBinds.get('pause');
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
		return FlxKey.ENTER;
	}

	// ----------------------------------------------------------- por frame

	/** Chamado a cada frame pelo PlayState. */
	public static function update():Void
	{
		if (!active || playState == null) return;

		// pausou/terminou => solta tudo para não deixar sustain presa
		if (!canPlay())
		{
			if (anyHeld() || touchLane.keys().hasNext()) releaseAll();
		}

		rebuildBoxes();
		updateZones();
		updatePauseButton();
	}

	// ------------------------------------------------------- visual (opcional)

	static function updateZones():Void
	{
		if (!active || playState == null) return;

		var want:Bool = ClientPrefs.mobileShowHitboxes;
		if (want && zones == null) createZones();
		else if (!want && zones != null) destroyZones();

		if (zones == null) return;

		for (i in 0...4)
		{
			var spr = zoneSprites[i];
			var r = boxes[i];
			if (spr == null || r == null) continue;
			spr.x = r.x;
			spr.y = r.y;
			spr.scale.set(r.width / 4.0, r.height / 4.0);
			spr.updateHitbox();
			spr.alpha = heldLanes[i] ? 0.42 : 0.18;
		}
	}

	static function createZones():Void
	{
		if (playState == null || zones != null) return;

		zones = new FlxTypedGroup<FlxSprite>();
		zoneSprites = [];

		for (i in 0...4)
		{
			var spr = new FlxSprite();
			spr.makeGraphic(4, 4, laneColors[i % laneColors.length]);
			spr.scrollFactor.set(0, 0);
			spr.alpha = 0.18;
			if (playState.camHUD != null) spr.cameras = [playState.camHUD];
			zones.add(spr);
			zoneSprites[i] = spr;
		}
		playState.add(zones);
		showingZones = true;
	}

	static function destroyZones():Void
	{
		if (zones == null) return;
		if (playState != null) playState.remove(zones, true);
		zones.destroy();
		zones = null;
		zoneSprites = [];
		showingZones = false;
	}

	// ---------------------------------------------------- botão de pausa

	static function updatePauseButton():Void
	{
		if (playState == null) return;

		var want:Bool = ClientPrefs.mobilePauseButton;
		if (!want)
		{
			destroyPauseButton();
			return;
		}

		if (pauseButton == null) createPauseButton();
		if (pauseButton == null) return;

		// o botão fica sempre do lado oposto à linha das setas, senão ele cobriria
		// a hitbox da seta da direita (em cima na descida, embaixo na subida)
		var px:Float = FlxG.width - 134;
		var py:Float = ClientPrefs.downScroll ? 24 : FlxG.height - 134;
		pauseButton.setPosition(px, py);
		if (pauseCenter != null) pauseCenter.setPosition(px + 34, py + 26);

		pauseButton.visible = canPlay();
		if (pauseCenter != null) pauseCenter.visible = pauseButton.visible;
	}

	static function createPauseButton():Void
	{
		if (playState == null) return;

		pauseButton = new FlxSprite(FlxG.width - 134, 24);
		pauseButton.makeGraphic(110, 110, 0x55000000);
		pauseButton.scrollFactor.set(0, 0);
		pauseButton.alpha = 0.85;
		if (playState.camHUD != null) pauseButton.cameras = [playState.camHUD];

		pauseCenter = new FlxSprite(pauseButton.x + 34, pauseButton.y + 26);
		pauseCenter.makeGraphic(42, 58, 0xAAFFFFFF);
		pauseCenter.scrollFactor.set(0, 0);
		pauseCenter.alpha = 0.85;
		if (playState.camHUD != null) pauseCenter.cameras = [playState.camHUD];

		playState.add(pauseButton);
		playState.add(pauseCenter);
	}

	static function destroyPauseButton():Void
	{
		if (pauseButton != null)
		{
			if (playState != null) playState.remove(pauseButton, true);
			pauseButton.destroy();
			pauseButton = null;
		}
		if (pauseCenter != null)
		{
			if (playState != null) playState.remove(pauseCenter, true);
			pauseCenter.destroy();
			pauseCenter = null;
		}
	}
}
