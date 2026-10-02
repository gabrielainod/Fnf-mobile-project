import pathlib

# ------------------------------------------------ 1) MainActivity: onPause
p = pathlib.Path('tools/patch_lime_android.sh'); s = p.read_text()

old = '''package ::APP_PACKAGE::;

import android.os.Bundle;

public class MainActivity extends org.haxe.lime.GameActivity {

	@Override protected void onCreate (Bundle state) {

		// FNF Mobile: liga o diário de bordo antes de qualquer coisa.
		// (grava o log numa pasta visível e mostra o erro da sessão anterior)
		try { com.fnfmobile.game.FnfBoot.start (this); } catch (Throwable t) { }

		super.onCreate (state);

	}

}
JAVA_EOF'''
assert s.count(old) == 1

novo = '''package ::APP_PACKAGE::;

import android.os.Bundle;

public class MainActivity extends org.haxe.lime.GameActivity {

	@Override protected void onCreate (Bundle state) {

		// FNF Mobile: liga o diário de bordo antes de qualquer coisa.
		// (grava o log numa pasta visível e mostra o erro da sessão anterior)
		try { com.fnfmobile.game.FnfBoot.start (this); } catch (Throwable t) { }

		super.onCreate (state);

	}

	// Se o jogo foi para segundo plano (ou o usuário saiu pelo botão home), a
	// sessão terminou de forma "limpa". Isso vira uma marcação em arquivo: se
	// na próxima abertura a marcação NÃO existir, é porque a sessão anterior
	// morreu no meio - e aí o diagnóstico aparece na tela automaticamente.
	@Override protected void onPause () {

		try { com.fnfmobile.game.FnfBoot.markCleanSession (); } catch (Throwable t) { }
		super.onPause ();

	}

}
JAVA_EOF'''
s = s.replace(old, novo, 1)
p.write_text(s)
print('MainActivity OK')

# ------------------------------------------------ 2) FnfBoot: marcação
p = pathlib.Path('tools/android/FnfBoot.java'); s = p.read_text()

old = """\t/** Aviso curto do sistema (nao depende do OpenGL). */"""
assert s.count(old) == 1
novo = """\t/**
\t * Marca que a sessao terminou de forma limpa (o jogo foi para segundo plano
\t * ou o jogador saiu). Se, na proxima abertura, essa marcacao nao existir, o
\t * app morreu no meio - e o diagnostico aparece sozinho na tela, com o motivo
\t * da morte lido do proprio Android.
\t */
\tpublic static void markCleanSession ()
\t{
\t\ttry
\t\t{
\t\t\tif (logDir == null) return;
\t\t\tFileOutputStream out = new FileOutputStream (new File (logDir, "sessao-limpa.txt"), false);
\t\t\tOutputStreamWriter w = new OutputStreamWriter (out, "UTF-8");
\t\t\tw.write (new SimpleDateFormat ("yyyy-MM-dd HH:mm:ss", Locale.US).format (new Date ()));
\t\t\tw.close ();
\t\t}
\t\tcatch (Throwable t) { }
\t}

\t/** A sessao anterior terminou de forma limpa? */
\tprivate static boolean lastSessionWasClean ()
\t{
\t\ttry
\t\t{
\t\t\tif (logDir == null) return true;
\t\t\tFile f = new File (logDir, "sessao-limpa.txt");
\t\t\tif (f.exists ())
\t\t\t{
\t\t\t\tf.delete ();
\t\t\t\treturn true;
\t\t\t}
\t\t\treturn false;
\t\t}
\t\tcatch (Throwable t)
\t\t{
\t\t\treturn true;
\t\t}
\t}

\t/** Aviso curto do sistema (nao depende do OpenGL). */"""
s = s.replace(old, novo, 1)

# usa a marcação no checkPreviousSession
old2 = """\t\t\tboolean ok = text.indexOf ("BOOT-OK") >= 0;
\t\t\twrite ("sessao anterior chegou ao menu: " + ok);

\t\t\tif (!ok)
\t\t\t{
\t\t\t\tpreviousSession = text;
\t\t\t\twriteFile (new File (logDir, "sessao-anterior.log"), text);
\t\t\t\twrite ("log da sessao que falhou guardado em sessao-anterior.log");
\t\t\t}"""
assert s.count(old2) == 1
novo2 = """\t\t\tboolean ok = text.indexOf ("BOOT-OK") >= 0;
\t\t\tboolean limpa = lastSessionWasClean ();
\t\t\twrite ("sessao anterior chegou ao menu: " + ok);
\t\t\twrite ("sessao anterior terminou normalmente: " + limpa);

\t\t\t// Mostra o diagnóstico quando: a sessão não chegou ao menu OU ela não
\t\t\t// terminou de forma limpa (ou seja: o app morreu no meio - foi assim
\t\t\t// que o fechamento ao abrir o Freeplay aparecia para o jogador).
\t\t\tif (!ok || !limpa)
\t\t\t{
\t\t\t\tpreviousSession = text;
\t\t\t\twriteFile (new File (logDir, "sessao-anterior.log"), text);
\t\t\t\twrite ("log da sessao que falhou guardado em sessao-anterior.log");
\t\t\t}"""
s = s.replace(old2, novo2, 1)

# o dialogo ganha o motivo da morte sempre que houver queda
old3 = """\t\t\tif (androidCrash != null && androidCrash.length () > 0)
\t\t\t{
\t\t\t\ttitle = "O app travou (erro do Android)";
\t\t\t\tbody = androidCrash;
\t\t\t\tif (gameCrash != null && gameCrash.length () > 0)
\t\t\t\t{
\t\t\t\t\tbody += "\\n--- erro dentro do jogo ---\\n" + gameCrash;
\t\t\t\t}
\t\t\t}
\t\t\telse if (gameCrash != null && gameCrash.length () > 0)
\t\t\t{
\t\t\t\ttitle = "O jogo teve um erro";
\t\t\t\tbody = gameCrash;
\t\t\t}
\t\t\telse if (previousSession != null)
\t\t\t{
\t\t\t\ttitle = "A sessao anterior nao chegou ao menu";
\t\t\t\tbody = previousSession;
\t\t\t}"""
assert s.count(old3) == 1
novo3 = """\t\t\tif (androidCrash != null && androidCrash.length () > 0)
\t\t\t{
\t\t\t\ttitle = "O app travou (erro do Android)";
\t\t\t\tbody = androidCrash;
\t\t\t\tif (gameCrash != null && gameCrash.length () > 0)
\t\t\t\t{
\t\t\t\t\tbody += "\\n--- erro dentro do jogo ---\\n" + gameCrash;
\t\t\t\t}
\t\t\t}
\t\t\telse if (gameCrash != null && gameCrash.length () > 0)
\t\t\t{
\t\t\t\ttitle = "O jogo teve um erro";
\t\t\t\tbody = gameCrash;
\t\t\t}
\t\t\telse if (previousSession != null)
\t\t\t{
\t\t\t\ttitle = "O app fechou sozinho na sessao anterior";
\t\t\t\tbody = previousSession;
\t\t\t}

\t\t\tif (title != null && body != null)
\t\t\t{
\t\t\t\t// o motivo da morte (com o trace do Android) vai sempre junto
\t\t\t\ttry { body = exitReasonReport () + "\\n" + body; } catch (Throwable t) { }
\t\t\t}"""
s = s.replace(old3, novo3, 1)
p.write_text(s)
print('FnfBoot OK; chaves', s.count('{') - s.count('}'))
