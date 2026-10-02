package mobile;

import lime.system.JNI;

/**
 * Ponte para o lado Java do app (com.fnfmobile.game.FnfBoot).
 *
 * Por que isso existe: quando a tela fica preta, não adianta escrever no log
 * nem desenhar com o Flixel/OpenFL - o desenho é justamente o que não chega na
 * tela. O aviso do sistema (Toast) do Android é desenhado pelo próprio sistema
 * operacional, então ele APARECE mesmo com o OpenGL morto.
 *
 * Toda chamada aqui é opcional e à prova de erro: se a ponte não existir (por
 * exemplo numa build de desktop), não acontece nada.
 */
class MobileNative
{
	/** Função Java FnfBoot.toast(String) ligada por JNI. */
	static var toastFn:Dynamic = null;
	static var ligado:Bool = false;
	static var ultimoAviso:Float = 0;
	static var avisosDados:Int = 0;

	/** Liga a ponte (chamar uma vez no boot). */
	public static function init():Void
	{
		if (ligado) return;
		ligado = true;

		#if (android && lime_cffi)
		try
		{
			// quietFail = true: se não existir, devolve null em vez de estourar
			toastFn = JNI.createStaticMethod('com.fnfmobile.game.FnfBoot', 'toast', '(Ljava/lang/String;)V', false, true);
		}
		catch (e:Dynamic)
		{
			toastFn = null;
		}
		#end
	}

	/** A ponte está funcionando? (aparece no log do jogo) */
	public static function isAvailable():Bool
		return toastFn != null;

	/**
	 * Mostra uma mensagem na tela usando o Android (Toast).
	 *
	 * O lado Java já joga isso para a thread da interface (runOnUiThread), então
	 * pode ser chamado de dentro do laço do jogo com segurança.
	 */
	public static function toast(mensagem:String):Void
	{
		if (toastFn == null || mensagem == null) return;

		// sem spam: no máximo um aviso a cada 1,5 s (o log continua completo)
		var agora:Float = haxe.Timer.stamp();
		if (agora - ultimoAviso < 1.5) return;
		ultimoAviso = agora;
		avisosDados++;

		var texto:String = mensagem;
		if (texto.length > 220) texto = texto.substr(0, 220) + '...';

		try
		{
			Reflect.callMethod(null, toastFn, [texto]);
		}
		catch (e:Dynamic)
		{
			toastFn = null; // desiste de vez, sem travar o jogo
		}
	}

	/** Mostra a mensagem ignorando o limite de frequência (usa no erro crítico). */
	public static function toastCritico(mensagem:String):Void
	{
		ultimoAviso = 0;
		toast(mensagem);
	}

	public static function notificationsSent():Int
		return avisosDados;
}
