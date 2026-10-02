package;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import mobile.MobileApp;
import mobile.MobileBack;
import mobile.MobileGestures;
import mobile.MobileKeys;
import mobile.MobilePerf;
import mobile.MobileDebugOverlay;
import mobile.MobilePlatform;

//crash handler stuff
#if CRASH_HANDLER
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import Discord.DiscordClient;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}
	
		ClientPrefs.loadDefaultKeys();

		#if mobile
		// ------------------------------------------------------------------
		// FNF Mobile: inicialização da camada de compatibilidade Android.
		// (pastas graváveis, opções que dependem do aparelho, teclado virtual,
		//  gestos de menu e ciclo de vida do app)
		// ------------------------------------------------------------------
		MobilePlatform.init();
		MobilePlatform.log('boot: setupGame inicio');

		// O save precisa estar ligado ANTES de ler/escrever FlxG.save.data:
		// o Psych só chama FlxG.save.bind() lá dentro do TitleState, e escrever
		// em FlxG.save.data antes disso derruba o app no Android.
		var saveOk:Bool = false;
		try
		{
			saveOk = FlxG.save.bind('funkin', 'ninjamuffin99');
		}
		catch (e:Dynamic)
		{
			MobilePlatform.log('AVISO: nao consegui abrir o save: ' + Std.string(e));
		}
		MobilePlatform.log('save ligado: ' + saveOk);

		if (saveOk && FlxG.save.data != null)
		{
			try
			{
				ClientPrefs.loadPrefs();
				ClientPrefs.applyMobileDefaults();
			}
			catch (e:Dynamic)
			{
				MobilePlatform.log('ERRO ao carregar preferencias: ' + Std.string(e));
			}
		}

		MobilePlatform.log('boot: criando FlxGame');
		try
		{
			addChild(new FlxGame(gameWidth, gameHeight, initialState, zoom, framerate, framerate, skipSplash, startFullscreen));
			MobilePlatform.log('boot: FlxGame criado');
		}
		catch (e:Dynamic)
		{
			// se o motor falhar aqui, o log diz o motivo em vez de o app sumir
			MobilePlatform.log('ERRO FATAL ao criar o FlxGame: ' + Std.string(e));
			#if cpp
			try { MobilePlatform.log(Std.string(haxe.CallStack.exceptionStack())); } catch (x:Dynamic) {}
			#end
			MobilePlatform.log('(o processo provavelmente vai encerrar agora)');
			throw e;
		}

		// marcadores: provam que o laco de jogo (update/draw) esta rodando.
		// Se o app fica preto e o log nao tem 'primeiro draw', o problema e no
		// laco/renderizacao, nao numa tela especifica.
		try
		{
			var firstUpdate:Bool = false;
			var firstDraw:Bool = false;
			FlxG.signals.postUpdate.add(function()
			{
				MobileDebugOverlay.noteUpdate();
				MobileDebugOverlay.tick();
				if (firstUpdate) return;
				firstUpdate = true;
				MobilePlatform.log('primeiro update OK - ' + MobilePlatform.windowInfo());
			});
			FlxG.signals.postDraw.add(function()
			{
				MobileDebugOverlay.noteDraw();
				if (firstDraw) return;
				firstDraw = true;
				MobilePlatform.log('primeiro draw OK (a tela esta desenhando) - ' + MobilePlatform.windowInfo());
			});
		}
		catch (e:Dynamic) { }

		// tudo daqui pra baixo é opcional: se algo falhar, o jogo tem que abrir
		try
		{
			MobilePerf.applyPreferences();
			MobileKeys.init();
			MobileGestures.init();
			MobileApp.init();
			MobileBack.init();
			MobilePlatform.log('camada mobile inicializada');
		}
		catch (e:Dynamic)
		{
			MobilePlatform.log('ERRO na camada mobile: ' + Std.string(e));
		}
		#else
		addChild(new FlxGame(gameWidth, gameHeight, initialState, zoom, framerate, framerate, skipSplash, startFullscreen));
		#end

		#if !mobile
		fpsVar = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.showFPS;
		}
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		DiscordClient.shutdown();
		Sys.exit(1);
	}
	#end
}
