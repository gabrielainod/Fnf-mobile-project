package mobile;

import lime.system.System as LimeSystem;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Camada base da compatibilidade mobile deste projeto.
 *
 * Cuida do que no Psych Engine simplesmente não existia no Android:
 *  - pastas graváveis (o APK é somente leitura, então "mods/" relativo não funciona);
 *  - pasta de mods acessível pelo jogador, com teste real de escrita;
 *  - log em arquivo no próprio aparelho (sem precisar de ADB);
 *  - informações do aparelho usadas pelas opções de desempenho.
 */
class MobilePlatform
{
	public static var isMobile(default, null):Bool = #if mobile true #else false #end;
	public static var isAndroid(default, null):Bool = #if android true #else false #end;

	/** Pasta onde os mods são lidos (absoluta no Android, relativa no PC). */
	public static var modsFolder(default, null):String = 'mods';
	/** Pasta interna gravável do app (vem de applicationStorageDirectory). */
	public static var storageFolder(default, null):String = null;
	/** Nome do pacote do aplicativo. */
	public static var packageName(default, null):String = null;
	/** RAM total do aparelho em MB (0 se não deu para descobrir). */
	public static var totalRamMB(default, null):Float = 0;

	static var logPath:String = null;
	static var logFolders:Array<String> = [];
	static var logLines:Array<String> = [];
	static var stateTrail:Array<String> = [];
	static var lastState:String = null;
	static var bootOk:Bool = false;
	static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		if (!isMobile)
		{
			modsFolder = 'mods';
			return;
		}

		try
		{
			storageFolder = normalizePath(LimeSystem.applicationStorageDirectory);
			packageName = detectPackageName(storageFolder);
			ensureDir(storageFolder);

			// O log vai para TODAS as pastas em que der para escrever. Ordem de
			// prioridade (a primeira é a que o jogador vê mais fácil):
			//   1. /sdcard/FNF-Mobile              (raiz da memória interna)
			//   2. /sdcard/Android/media/<pacote>  (visível, NÃO precisa de permissão)
			//   3. pasta privada do app            (sempre funciona, invisível)
			pickLogFolders();

			try
			{
				totalRamMB = openfl.system.System.totalMemory / (1024 * 1024);
			}
			catch (e:Dynamic)
			{
				totalRamMB = 0;
			}

			modsFolder = pickModsFolder();
			ensureDir(modsFolder);
		}
		catch (e:Dynamic)
		{
			modsFolder = 'mods';
		}

		writeModsReadme();

		log('=== FNF Mobile iniciado ===');
		log(deviceInfo());
		log('RAM total: ' + Math.round(totalRamMB) + ' MB');
		log('pasta de mods: ' + modsFolder);
	}

	/**
	 * Escolhe a pasta de mods na seguinte ordem:
	 *  1. /sdcard/FNF-Mobile/mods      -> o jogador copia mods por qualquer gerenciador de arquivos
	 *  2. Android/data/<pacote>/files/mods -> sempre gravável, sem permissão nenhuma
	 *  3. /data/data/<pacote>/files/mods   -> última alternativa (só o app enxerga)
	 */
	static function pickModsFolder():String
	{
		var external:String = detectExternalStorage();

		if (external != null && external != '')
		{
			var pub:String = external + '/FNF-Mobile/mods';
			if (probeWritable(pub)) return pub;

			var appExternal:String = external + '/Android/data/' + packageName + '/files/mods';
			if (probeWritable(appExternal)) return appExternal;
		}

		var internal:String = (storageFolder != null ? storageFolder : '.') + '/mods';
		if (probeWritable(internal)) return internal;

		return 'mods';
	}

	/** Explica na própria pasta como instalar mods (o jogador não tem manual). */
	static function writeModsReadme():Void
	{
		#if sys
		try
		{
			var path:String = modsFolder + '/LEIA-ME.txt';
			if (FileSystem.exists(path)) return;
			if (!FileSystem.exists(modsFolder)) return;

			File.saveContent(path, [
				'FNF Mobile - pasta de mods',
				'',
				'Cada mod e uma pasta aqui dentro, igual ao Psych Engine no PC:',
				'',
				'  <esta pasta>/MeuMod/pack.json',
				'  <esta pasta>/MeuMod/data/bopeebo/bopeebo.json',
				'  <esta pasta>/MeuMod/images/... (PNG + XML)',
				'  <esta pasta>/MeuMod/songs/... (ogg)',
				'  <esta pasta>/MeuMod/characters/... / stages/... / weeks/...',
				'',
				'Mods globais (rodam junto com o jogo base): crie um arquivo',
				'modsList.txt nesta pasta, uma linha por mod, no formato:',
				'',
				'  MeuMod|1',
				'',
				'E onde esta esta pasta?',
				'  ' + modsFolder,
				'',
				'Para atualizar a lista, feche e abra o jogo de novo.',
			].join('\n'));
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * /sdcard/Android/media/<pacote>: pasta do app que aparece no gerenciador de
	 * arquivos e NÃO precisa de permissão (Android 10+). É por aqui que o jogador
	 * lê o log mesmo sem permissão de armazenamento.
	 */
	public static function appMediaFolder():String
	{
		var external:String = detectExternalStorage();
		if (external == null || external == '') return null;
		var pkg:String = packageName != null ? packageName : 'com.fnfmobile.game';
		return external + '/Android/media/' + pkg;
	}

	/** Pasta pública visível no gerenciador de arquivos (/sdcard/FNF-Mobile), ou null. */
	public static function publicBaseFolder():String
	{
		var external:String = detectExternalStorage();
		if (external == null || external == '') return null;
		return external + '/FNF-Mobile';
	}

	/** Cria a pasta e confirma que dá para escrever de verdade (não só existe). */
	static function probeWritable(path:String):Bool
	{
		#if sys
		if (path == null || path == '') return false;
		try
		{
			if (!FileSystem.exists(path))
			{
				FileSystem.createDirectory(path);
			}
			var probe:String = path + '/.write-test';
			File.saveContent(probe, 'ok');
			var content:String = File.getContent(probe);
			FileSystem.deleteFile(probe);
			return content == 'ok';
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	/** Nome amigável da pasta de mods para mostrar nas opções. */
	public static function modsFolderLabel():String
	{
		if (modsFolder == null) return 'mods';
		if (modsFolder.indexOf('FNF-Mobile') != -1) return '/sdcard/FNF-Mobile/mods';
		if (modsFolder.indexOf('Android/data') != -1) return 'Android/data/' + packageName + '/files/mods';
		return modsFolder;
	}

	public static function deviceInfo():String
	{
		var info:String = 'plataforma: ' + LimeSystem.platformName + ' ' + LimeSystem.platformVersion;
		#if android info += ' | android'; #end
		#if cpp info += ' | cpp'; #end
		info += ' | sistema: ' + LimeSystem.platformVersion;
		info += ' | pacote: ' + packageName;
		return info;
	}

	// ---------------------------------------------------------------- log

	/** Log do aparelho (arquivo em Android/data/<pacote>/files/fnf-mobile.log). */
	public static function log(message:String):Void
	{
		logAppend(message);
		try { trace('[mobile] ' + message); } catch (e:Dynamic) {}
	}

	public static function logAppend(message:String):Void
	{
		var line:String = Date.now().toString() + '  ' + message;
		logLines.push(line);
		while (logLines.length > 200) logLines.shift();

		// erro em tempo real aparece na tela (print = diagnostico sem PC)
		if (message.indexOf('ERRO') != -1 || message.indexOf('FATAL') != -1 || message.indexOf('CRASH') != -1)
		{
			MobileDebugOverlay.showError('FNF Mobile - algo deu errado', message);
		}

		#if sys
		var content:String = logLines.join('\n') + '\n';
		for (folder in logFolders)
		{
			try
			{
				File.saveContent(folder + '/fnf-mobile.log', content);
			}
			catch (e:Dynamic) {}
		}
		#end
	}

	/**
	 * Monta a lista de pastas onde o log será gravado (só as que aceitam
	 * escrita de verdade). É o que permite ler o log no celular sem PC.
	 */
	static function pickLogFolders():Void
	{
		var candidates:Array<String> = [];

		var pubBase:String = publicBaseFolder();
		if (pubBase != null) candidates.push(pubBase);

		var media:String = appMediaFolder();
		if (media != null) candidates.push(media);

		if (storageFolder != null) candidates.push(storageFolder);
		candidates.push('.');

		for (c in candidates)
		{
			if (c == null || c == '') continue;
			if (logFolders.indexOf(c) != -1) continue;
			if (c != '.' && !probeWritable(c)) continue;
			logFolders.push(c);
		}

		if (logFolders.length == 0) logFolders.push('.');
		logPath = logFolders[0] + '/fnf-mobile.log';
	}

	/**
	 * Últimas linhas do log, para mostrar dentro do jogo (útil quando o jogador
	 * não tem como acessar arquivo no celular). Se a memória estiver vazia,
	 * tenta ler o arquivo.
	 */
	public static function logTail(maxLines:Int = 30):String
	{
		var lines:Array<String> = logLines;
		if (lines == null || lines.length == 0)
		{
			#if sys
			try
			{
				var path:String = logPath;
				if (path == null) path = (storageFolder != null ? storageFolder : '.') + '/fnf-mobile.log';
				if (FileSystem.exists(path)) lines = File.getContent(path).split('\n');
			}
			catch (e:Dynamic) { lines = []; }
			#end
		}
		if (lines == null || lines.length == 0) return '(sem mensagens ainda)';

		var start:Int = lines.length - maxLines;
		if (start < 0) start = 0;
		var out:String = '';
		for (i in start...lines.length)
		{
			if (lines[i] != null && lines[i].length > 0) out += lines[i] + '\n';
		}
		return out;
	}

	/**
	 * Trilha de navegação: anota cada tela que o jogo cria. Se o app morrer no
	 * meio, a última linha do log diz exatamente onde ele parou.
	 */
	public static function trackState(stateName:String):Void
	{
		if (stateName == null) return;
		if (lastState == stateName) return;
		lastState = stateName;

		stateTrail.push(stateName);
		log('estado: ' + stateName);

		// se o jogo avancou de tela, o problema (se havia) passou: tira o aviso
		MobileDebugOverlay.hide();

		if (!bootOk && (stateName.indexOf('Title') != -1 || stateName.indexOf('MainMenu') != -1))
		{
			bootOk = true;
			log('BOOT-OK: menu inicial carregado');
		}
	}

	/** Já chegou ao menu principal alguma vez nesta sessão? */
	public static function isBootOk():Bool
		return bootOk;

	public static function ensureDir(path:String):Bool
	{
		#if sys
		if (path == null || path == '') return false;
		try
		{
			if (FileSystem.exists(path)) return FileSystem.isDirectory(path);
			FileSystem.createDirectory(path);
			return true;
		}
		catch (e:Dynamic) { return false; }
		#else
		return false;
		#end
	}

	static function dirReadable(path:String):Bool
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return false;
			FileSystem.readDirectory(path);
			return true;
		}
		catch (e:Dynamic) { return false; }
		#else
		return false;
		#end
	}

	static function detectPackageName(dir:String):String
	{
		if (dir == null) return 'com.fnfmobile.game';
		var clean:String = dir;
		while (clean.length > 1 && (clean.charAt(clean.length - 1) == '/' || clean.charAt(clean.length - 1) == '\\'))
			clean = clean.substr(0, clean.length - 1);
		var parts:Array<String> = clean.split('/');
		// .../data/data/<pacote>/files => <pacote>
		if (parts.length >= 2) return parts[parts.length - 2];
		return 'com.fnfmobile.game';
	}

	static function detectExternalStorage():String
	{
		var candidates:Array<String> = [];
		if (isAndroid)
		{
			var env:String = null;
			try
			{
				env = Sys.getEnv('EXTERNAL_STORAGE');
			}
			catch (e:Dynamic)
			{
				env = null;
			}
			if (env != null && env != '') candidates.push(env);
			candidates.push('/storage/emulated/0');
			candidates.push('/sdcard');
		}
		for (c in candidates)
		{
			if (c != null && c != '' && dirReadable(c)) return c;
		}
		return candidates.length > 0 ? candidates[0] : '';
	}

	static function normalizePath(path:String):String
	{
		if (path == null) return null;
		var p:String = path;
		if (p.indexOf('file://') == 0) p = p.substr(7);
		return p;
	}
}
