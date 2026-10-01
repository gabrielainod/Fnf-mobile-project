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
 *  - pastas graváveis (o APK é somente leitura, então "mods/" relativo não funciona)
 *  - pasta de mods acessível pelo jogador (Android/data/<pacote>/files/mods)
 *  - log em arquivo no próprio aparelho (sem precisar de ADB)
 *  - informações do aparelho usadas pelas opções de desempenho
 */
class MobilePlatform
{
	public static var isMobile(default, null):Bool = #if mobile true #else false #end;
	public static var isAndroid(default, null):Bool = #if android true #else false #end;

	/** Pasta onde os mods são lidos (absoluta no Android, relativa no PC). */
	public static var modsFolder(default, null):String = 'mods';
	/** Pasta pública opcional (ex.: /storage/emulated/0/FNF-Mobile/mods), se existir. */
	public static var publicModsFolder(default, null):String = null;
	/** Nome do pacote do aplicativo (com.fnfmobile.game). */
	public static var packageName(default, null):String = null;
	/** Pasta interna gravável do app. */
	public static var storageFolder(default, null):String = null;

	static var logPath:String = null;
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

			// Android/data/<pacote>/files — gravável SEM pedir nenhuma permissão
			var external:String = detectExternalStorage();
			var appExternal:String = external + '/Android/data/' + (packageName != null ? packageName : 'com.fnfmobile.game') + '/files';

			if (ensureDir(appExternal))
			{
				modsFolder = appExternal + '/mods';
			}
			else
			{
				modsFolder = storageFolder + '/mods';
			}
			ensureDir(modsFolder);

			// pasta pública alternativa (só é usada se já existir e for legível)
			var pub:String = external + '/FNF-Mobile/mods';
			if (dirReadable(pub)) publicModsFolder = pub;
		}
		catch (e:Dynamic)
		{
			modsFolder = 'mods';
		}

		logPath = (storageFolder != null ? storageFolder : '.') + '/fnf-mobile.log';
		log('=== FNF Mobile iniciado ===');
		log(deviceInfo());
		log('mods: ' + modsFolder);
	}

	/** Todas as pastas de mods, na ordem em que são procuradas. */
	public static function getModsFolders():Array<String>
	{
		var list:Array<String> = [];
		if (modsFolder != null && modsFolder != '') list.push(modsFolder);
		if (publicModsFolder != null) list.push(publicModsFolder);
		return list;
	}

	public static function deviceInfo():String
	{
		var info:String = 'plataforma: ' + LimeSystem.platformType + ' (' + LimeSystem.platformName + ')';
		#if android info += ' | android'; #end
		#if (cpp || neko) info += ' | cpp'; #end
		info += ' | pc: ' + LimeSystem.platformVersion;
		return info;
	}

	/** Escreve no log do aparelho (arquivo em Android/data/<pacote>/files/fnf-mobile.log). */
	public static function log(message:String):Void
	{
		#if sys
		try
		{
			var path:String = logPath;
			if (path == null) path = (storageFolder != null ? storageFolder : '.') + '/fnf-mobile.log';
			var stamp:String = Date.now().toString();
			File.saveContent(path, stamp + '  ' + message + '\n');   // saveContent sobrescreve; mantemos só as últimas
		}
		catch (e:Dynamic) {}
		#end
		try { trace('[mobile] ' + message); } catch (e:Dynamic) {}
	}

	/** Salva um log acumulado (usado no final da música/erro). */
	public static function logAppend(message:String):Void
	{
		#if sys
		try
		{
			var path:String = logPath;
			if (path == null) return;
			var file = File.append(path, false);
			file.writeString(Date.now().toString() + '  ' + message + '\n');
			file.close();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function ensureDir(path:String):Bool
	{
		#if sys
		if (path == null || path == '') return false;
		try
		{
			if (FileSystem.exists(path)) return true;
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
		if (dir == null) return null;
		var clean:String = dir;
		while (clean.length > 1 && (clean.charAt(clean.length - 1) == '/' || clean.charAt(clean.length - 1) == '\\'))
			clean = clean.substr(0, clean.length - 1);
		var parts:Array<String> = clean.split('/');
		// .../data/data/<pacote>/files => <pacote>
		if (parts.length >= 2) return parts[parts.length - 2];
		return null;
	}

	static function detectExternalStorage():String
	{
		var candidates:Array<String> = [];
		if (isAndroid)
		{
			var env:String = Sys.getEnv('EXTERNAL_STORAGE');
			if (env != null && env != '') candidates.push(env);
			candidates.push('/storage/emulated/0');
			candidates.push('/sdcard');
		}
		for (c in candidates)
		{
			if (c != null && c != '' && dirReadable(c)) return c;
		}
		return candidates.length > 0 ? candidates[0] : '/sdcard';
	}

	static function normalizePath(path:String):String
	{
		if (path == null) return null;
		var p:String = path;
		// o Lime pode devolver caminhos com "file://"
		if (p.indexOf('file://') == 0) p = p.substr(7);
		return p;
	}
}
