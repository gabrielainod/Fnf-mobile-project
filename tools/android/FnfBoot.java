package com.fnfmobile.game;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.DialogInterface;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.graphics.Rect;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Diario de bordo do FNF Mobile no lado Java.
 *
 * Por que isso existe: no Android, se o jogo morre durante a abertura, o
 * jogador nao tem como descobrir o motivo (o Android guarda o erro no logcat,
 * que so aparece com cabo/PC). Este arquivo resolve dois problemas:
 *
 *  1. escolhe uma pasta de log que da para abrir no proprio celular
 *     (Android/media/<pacote>, que nao precisa de permissao nenhuma) e tambem
 *     tenta /sdcard/FNF-Mobile (que precisa de permissao);
 *  2. instala um "salva-vidas": se o app travar, o erro completo (com a pilha)
 *     e gravado em ultimo-erro.txt e, na proxima abertura, o jogo mostra uma
 *     telinha com o texto - basta tirar print e mandar.
 *
 * O pacote precisa ser este (com.fnfmobile.game) porque este arquivo e copiado
 * para app/src/main/java/com/fnfmobile/game/FnfBoot.java.
 */
public class FnfBoot
{
	/** Identificacao desta build (o CI troca este texto pelo numero do run). */
	public static final String BUILD_TAG = "__FNF_BUILD_TAG__";

	/** Depois de quanto tempo mostrar o diagnostico na tela (ms). */
	private static final long DIAGNOSTIC_DELAY_MS = 15000L;

	private static Activity activity = null;
	private static File logDir = null;
	private static File logFile = null;
	private static File crashFile = null;
	private static String previousSession = null;
	private static boolean started = false;

	/** Chamado pelo MainActivity antes de tudo (antes do super.onCreate). */
	public static void start (Activity a)
	{
		if (started) return;
		started = true;
		activity = a;

		try
		{
			logDir = pickDir (a);
			if (logDir != null)
			{
				logFile = new File (logDir, "fnf-boot.log");
				crashFile = new File (logDir, "ultimo-erro.txt");
			}
		}
		catch (Throwable t) { }

		write ("=== FNF Mobile (lado Android) ===");
		write ("pacote: " + a.getPackageName ());
		write ("android: " + Build.VERSION.RELEASE + " (SDK " + Build.VERSION.SDK_INT + ")");
		write ("aparelho: " + Build.MANUFACTURER + " " + Build.MODEL);
		write ("abis: " + joinAbis ());
		write ("heap max: " + (Runtime.getRuntime ().maxMemory () / 1048576) + " MB");
		write ("pasta do log: " + (logDir != null ? logDir.getAbsolutePath () : "?"));

		checkPreviousSession ();
		installCrashHandler ();

		// grava no log do boot como a sessao anterior terminou (aparece no print
		// do aviso do sistema, sem precisar abrir o dialogo)
		try { write (exitReasonReport ()); } catch (Throwable t) { }

		try
		{
			a.runOnUiThread (new Runnable ()
			{
				public void run ()
				{
					try { requestStorage (); } catch (Throwable t) { }
					try { showDialog (); } catch (Throwable t) { }
					try { toast ("FNF Mobile - diagnostico " + BUILD_TAG + " (aguarde 15s)"); } catch (Throwable t) { }
				}
			});
		}
		catch (Throwable t) { }

		// Depois de 15s mostra, numa janela DO ANDROID (aparece mesmo se o
		// OpenGL nao desenhar nada), o resumo do log do jogo. Tem botao
		// "Copiar": da' para colar o texto em qualquer conversa.
		try
		{
			new Handler (Looper.getMainLooper ()).postDelayed (new Runnable ()
			{
				public void run ()
				{
					try { showDiagnostics (); } catch (Throwable t) { }
				}
			}, DIAGNOSTIC_DELAY_MS);
		}
		catch (Throwable t) { }

		startHeartbeat ();

		// Aos 6 segundos inspeciona a superficie de video do Android: e' ela que
		// recebe o que o OpenGL desenha. Se ela estiver invalida/zerada, a tela
		// fica preta mesmo com o jogo rodando.
		try
		{
			new Handler (Looper.getMainLooper ()).postDelayed (new Runnable ()
			{
				public void run ()
				{
					try { write (surfaceReport ()); } catch (Throwable t) { }
				}
			}, 6000L);
		}
		catch (Throwable t) { }
	}

	/**
	 * Motivo pelo qual a sessao anterior morreu, lido do proprio Android
	 * (ApplicationExitInfo, disponivel a partir do Android 11/API 30).
	 *
	 * Isso responde de uma vez a pergunta que importa: o app foi fechado por
	 * erro no codigo (SIGSEGV), por falta de memoria (OOM), por travamento (ANR)
	 * ou foi o usuario que fechou. Quando o Android tem o "trace" do erro, ele
	 * vem junto - com o nome da funcao onde o app morreu.
	 */
	public static String exitReasonReport ()
	{
		StringBuilder sb = new StringBuilder ();

		try
		{
			if (Build.VERSION.SDK_INT < 30)
			{
				return "motivo da morte: (Android antigo, essa informacao nao existe)\n";
			}

			Object am = activity.getSystemService (Context.ACTIVITY_SERVICE);
			if (am == null)
			{
				return "motivo da morte: (sem ActivityManager)\n";
			}

			// Chamada por reflexao de proposito: o projeto e' compilado com o SDK
			// 28 (por causa do armazenamento dos mods), mas no aparelho - Android
			// 11 ou mais novo - a funcao existe e devolve o motivo real da morte.
			java.lang.reflect.Method metodo = am.getClass ().getMethod ("getHistoricalProcessExitInfos");
			Object resultado = metodo.invoke (am);

			if (!(resultado instanceof java.util.List))
			{
				return "motivo da morte: (o Android nao devolveu historico)\n";
			}

			java.util.List<?> itens = (java.util.List<?>) resultado;
			sb.append ("--- como as sessoes anteriores terminaram ---\n");

			int mostrados = 0;
			for (Object info : itens)
			{
				if (info == null || mostrados >= 3) break;
				mostrados++;

				int motivo = intField (info, "getReason");
				int detalhe = intField (info, "getSubReason");
				long quando = longField (info, "getTimestamp");
				String descricao = strField (info, "getDescription");

				sb.append ("sessao ").append (mostrados).append (": ").append (reasonName (motivo))
					.append (" / detalhe ").append (detalhe);
				if (quando > 0)
				{
					sb.append (" em ").append (new SimpleDateFormat ("HH:mm:ss", Locale.US).format (new Date (quando)));
				}
				sb.append ("\n");

				if (descricao != null && descricao.length () > 0)
				{
					sb.append ("   descricao: ").append (descricao).append ("\n");
				}

				// o "trace" costuma trazer a funcao exata onde o app morreu
				try
				{
					java.lang.reflect.Method tm = info.getClass ().getMethod ("getTraceInputStream");
					Object in = tm.invoke (info);
					if (in instanceof java.io.InputStream)
					{
						java.io.BufferedReader br = new java.io.BufferedReader (new java.io.InputStreamReader ((java.io.InputStream) in, "UTF-8"));
						StringBuilder trace = new StringBuilder ();
						String linha;
						while ((linha = br.readLine ()) != null)
						{
							trace.append (linha).append ("\n");
						}
						br.close ();
						String t = trace.toString ();
						if (t.length () > 3000) t = t.substring (0, 3000) + "\n...(cortado)\n";
						sb.append ("   trace:\n").append (t);
					}
				}
				catch (Throwable t) { }
			}
		}
		catch (Throwable t)
		{
			sb.append ("motivo da morte: (falhou ao ler: ").append (t.toString ()).append (")\n");
		}

		return sb.toString ();
	}

	private static int intField (Object obj, String metodo)
	{
		try
		{
			Object v = obj.getClass ().getMethod (metodo).invoke (obj);
			return (v instanceof Integer) ? ((Integer) v).intValue () : 0;
		}
		catch (Throwable t)
		{
			return 0;
		}
	}

	private static long longField (Object obj, String metodo)
	{
		try
		{
			Object v = obj.getClass ().getMethod (metodo).invoke (obj);
			return (v instanceof Long) ? ((Long) v).longValue () : 0L;
		}
		catch (Throwable t)
		{
			return 0L;
		}
	}

	private static String strField (Object obj, String metodo)
	{
		try
		{
			Object v = obj.getClass ().getMethod (metodo).invoke (obj);
			return (v != null) ? v.toString () : null;
		}
		catch (Throwable t)
		{
			return null;
		}
	}

	/** Nome do motivo (numeros fixos da API do Android 11+). */
	private static String reasonName (int reason)
	{
		switch (reason)
		{
			case 0: return "motivo desconhecido";
			case 1: return "o app se fechou sozinho";
			case 2: return "MORTO POR SINAL do sistema";
			case 3: return "SEM MEMORIA - o Android matou (OOM)";
			case 4: return "ERRO no codigo Java";
			case 5: return "ERRO no codigo nativo (SIGSEGV/abort)";
			case 6: return "TRAVOU e o Android matou (ANR)";
			case 7: return "falha ao iniciar";
			case 8: return "mudanca de permissao";
			case 9: return "uso excessivo de recurso";
			case 10: return "fechado pelo usuario";
			case 11: return "parado pelo sistema/usuario";
			case 12: return "dependencia caiu";
			case 13: return "outro motivo";
			case 14: return "congelado pelo sistema";
			case 15: return "mudanca de estado do pacote";
			case 16: return "app foi atualizado";
			default: return "motivo " + reason;
		}
	}

	/** Resumo do estado da superficie de video (o que o OpenGL usa para aparecer). */
	public static String surfaceReport ()
	{
		StringBuilder sb = new StringBuilder ();

		sb.append ("=== superficie de video (6s) ===\n");

		try
		{
			android.view.WindowManager wm = (android.view.WindowManager) activity.getSystemService (Context.WINDOW_SERVICE);
			android.util.DisplayMetrics dm = new android.util.DisplayMetrics ();
			wm.getDefaultDisplay ().getMetrics (dm);
			sb.append ("tela: ").append (dm.widthPixels).append ("x").append (dm.heightPixels)
				.append (" densidade ").append (dm.densityDpi).append ("dpi refresh ")
				.append (wm.getDefaultDisplay ().getRefreshRate ()).append ("Hz\n");
		}
		catch (Throwable t) { }

		try
		{
			sb.append ("flags da janela: 0x").append (Integer.toHexString (activity.getWindow ().getAttributes ().flags)).append ("\n");
		}
		catch (Throwable t) { }

		try
		{
			View decor = activity.getWindow ().getDecorView ();
			sb.append ("decor: ").append (decor.getWidth ()).append ("x").append (decor.getHeight ())
				.append (" visivel=").append (decor.getVisibility ()).append (" naTela=").append (decor.isShown ()).append ("\n");
		}
		catch (Throwable t) { }

		try
		{
			View conteudo = activity.findViewById (android.R.id.content);
			if (conteudo != null)
			{
				sb.append ("arvore de views (ate 3 niveis):\n");
				descreverView (conteudo, sb, 0, 3);
			}
		}
		catch (Throwable t) { }

		return sb.toString () + "================================\n";
	}

	private static void describir (StringBuilder sb, int nivel)
	{
		for (int i = 0; i < nivel; i++) sb.append ("   ");
	}

	private static void descreverView (View v, StringBuilder sb, int nivel, int maxNivel)
	{
		try
		{
			describir (sb, nivel);
			sb.append (v.getClass ().getName ())
				.append (" ").append (v.getWidth ()).append ("x").append (v.getHeight ())
				.append (" vis=").append (v.getVisibility ())
				.append (" naTela=").append (v.isShown ());

			if (v instanceof SurfaceView)
			{
				SurfaceView sv = (SurfaceView) v;
				SurfaceHolder h = sv.getHolder ();
				Surface sup = (h != null) ? h.getSurface () : null;
				sb.append (" SUPERFICIE=");
				if (sup == null) sb.append ("nula");
				else if (!sup.isValid ()) sb.append ("INVALIDA");
				else sb.append ("ok");
				try
				{
					Rect r = new Rect ();
					sv.getGlobalVisibleRect (r);
					sb.append (" areaVisivel=").append (r.width ()).append ("x").append (r.height ());
				}
				catch (Throwable t) { }
			}

			sb.append ("\n");

			if (v instanceof ViewGroup && nivel < maxNivel)
			{
				ViewGroup g = (ViewGroup) v;
				for (int i = 0; i < g.getChildCount (); i++)
				{
					descreverView (g.getChildAt (i), sb, nivel + 1, maxNivel);
				}
			}
		}
		catch (Throwable t) { }
	}

	/**
	 * Repete, num aviso do sistema (Toast), as ultimas linhas do log do jogo.
	 *
	 * Serve para o caso em que o OpenGL nao desenha NADA: o jogo continua
	 * rodando e gravando o log, e o aviso do sistema (desenhado pelo proprio
	 * Android) mostra na tela o que esta acontecendo, sem precisar de PC.
	 */
	private static void startHeartbeat ()
	{
		try
		{
			final Handler handler = new Handler (Looper.getMainLooper ());
			handler.postDelayed (new Runnable ()
			{
				int count = 0;

				public void run ()
				{
					try
					{
						if (count >= 15) return;
						count++;

						String tail = (logDir != null) ? readTail (new File (logDir, "fnf-mobile.log"), 300) : null;
						if (tail != null)
						{
							String[] lines = tail.split ("\n");
							String last = "";
							int achou = 0;
							for (int i = lines.length - 1; i >= 0 && achou < 3; i--)
							{
								String l = lines[i].trim ();
								if (l.length () == 0) continue;
								last = l + "\n" + last;
								achou++;
							}
							toast (last.length () > 240 ? last.substring (0, 240) : last);
						}

						handler.postDelayed (this, 4000L);
					}
					catch (Throwable t) { }
				}
			}, 3000L);
		}
		catch (Throwable t) { }
	}

	/**
	 * Marca que a sessao terminou de forma limpa (o jogo foi para segundo plano
	 * ou o jogador saiu). Se, na proxima abertura, essa marcacao nao existir, o
	 * app morreu no meio - e o diagnostico aparece sozinho na tela, com o motivo
	 * da morte lido do proprio Android.
	 */
	public static void markCleanSession ()
	{
		try
		{
			if (logDir == null) return;
			FileOutputStream out = new FileOutputStream (new File (logDir, "sessao-limpa.txt"), false);
			OutputStreamWriter w = new OutputStreamWriter (out, "UTF-8");
			w.write (new SimpleDateFormat ("yyyy-MM-dd HH:mm:ss", Locale.US).format (new Date ()));
			w.close ();
		}
		catch (Throwable t) { }
	}

	/** A sessao anterior terminou de forma limpa? */
	private static boolean lastSessionWasClean ()
	{
		try
		{
			if (logDir == null) return true;
			File f = new File (logDir, "sessao-limpa.txt");
			if (f.exists ())
			{
				f.delete ();
				return true;
			}
			return false;
		}
		catch (Throwable t)
		{
			return true;
		}
	}

	/** Aviso curto do sistema (nao depende do OpenGL). */
	public static void toast (final String message)
	{
		try
		{
			if (activity == null) return;
			activity.runOnUiThread (new Runnable ()
			{
				public void run ()
				{
					try { Toast.makeText (activity, message, Toast.LENGTH_LONG).show (); } catch (Throwable t) { }
				}
			});
		}
		catch (Throwable t) { }
	}

	// --------------------------------------------------------- diagnostico

	/** Monta o texto com tudo o que interessa para descobrir a tela preta. */
	private static String buildDiagnostics ()
	{
		StringBuilder sb = new StringBuilder ();

		sb.append ("build: ").append (BUILD_TAG).append ("\n");
		sb.append ("instalado em: ").append (installTime ()).append ("\n");
		sb.append ("aparelho: ").append (Build.MANUFACTURER).append (" ").append (Build.MODEL).append ("\n");
		sb.append ("android: ").append (Build.VERSION.RELEASE).append (" (SDK ").append (Build.VERSION.SDK_INT).append (")\n");
		sb.append ("abis: ").append (joinAbis ()).append ("\n");
		sb.append ("heap max: ").append (Runtime.getRuntime ().maxMemory () / 1048576).append (" MB\n");
		sb.append ("pasta do log: ").append (logDir != null ? logDir.getAbsolutePath () : "?").append ("\n");
		try { sb.append ("\n").append (surfaceReport ()); } catch (Throwable t) { }
		try { sb.append ("\n").append (exitReasonReport ()); } catch (Throwable t) { }

		if (logDir != null)
		{
			sb.append ("\n--- fnf-mobile.log (ultimas linhas do jogo) ---\n");
			sb.append (orNone (readTail (new File (logDir, "fnf-mobile.log"), 5000)));
			sb.append ("\n--- fnf-boot.log (lado Android) ---\n");
			sb.append (orNone (readTail (new File (logDir, "fnf-boot.log"), 2000)));
		}

		return sb.toString ();
	}

	/** Mostra o diagnostico numa janela nativa do Android (com botao Copiar). */
	private static void showDiagnostics ()
	{
		try
		{
			if (activity == null || logDir == null) return;

			final String text = buildDiagnostics ();
			writeFile (new File (logDir, "diagnostico.txt"), text);
			write ("mostrando o diagnostico na tela (build " + BUILD_TAG + ")");

			activity.runOnUiThread (new Runnable ()
			{
				public void run ()
				{
					try
					{
						TextView tv = new TextView (activity);
						tv.setText (text);
						tv.setTextSize (9f);
						tv.setPadding (22, 22, 22, 22);

						ScrollView sv = new ScrollView (activity);
						sv.addView (tv);

						new AlertDialog.Builder (activity)
							.setTitle ("Diagnostico FNF Mobile " + BUILD_TAG)
							.setView (sv)
							.setPositiveButton ("Copiar", new DialogInterface.OnClickListener ()
							{
								public void onClick (DialogInterface dialog, int which)
								{
									try
									{
										ClipboardManager cm = (ClipboardManager) activity.getSystemService (Context.CLIPBOARD_SERVICE);
										cm.setPrimaryClip (ClipData.newPlainText ("FNF Mobile", text));
										toast ("Copiado! agora e' so colar na conversa.");
									}
									catch (Throwable t)
									{
										toast ("Nao consegui copiar - tire print da tela.");
									}
								}
							})
							.setNegativeButton ("Fechar", null)
							.show ();
					}
					catch (Throwable t) { }
				}
			});
		}
		catch (Throwable t) { }
	}

	private static String installTime ()
	{
		try
		{
			PackageInfo info = activity.getPackageManager ().getPackageInfo (activity.getPackageName (), 0);
			return new SimpleDateFormat ("yyyy-MM-dd HH:mm:ss", Locale.US).format (new Date (info.lastUpdateTime));
		}
		catch (Throwable t)
		{
			return "?";
		}
	}

	private static String orNone (String text)
	{
		if (text == null || text.trim ().length () == 0) return "(vazio)\n";
		return text;
	}

	/** Acrescenta uma linha no log (usado tambem pelo lado Haxe, via JNI). */
	public static void write (String message)
	{
		if (logFile == null) return;
		try
		{
			String stamp = new SimpleDateFormat ("HH:mm:ss", Locale.US).format (new Date ());
			FileOutputStream out = new FileOutputStream (logFile, true);
			OutputStreamWriter w = new OutputStreamWriter (out, "UTF-8");
			w.write (stamp + "  " + message + "\n");
			w.close ();
		}
		catch (Throwable t) { }
	}

	// ------------------------------------------------------------- pastas

	/**
	 * Ordem de preferencia:
	 *  1. Android/media/<pacote>  -> visivel no gerenciador de arquivos, sem permissao
	 *  2. /sdcard/FNF-Mobile      -> visivel na raiz da memoria interna (precisa de permissao)
	 *  3. pasta privada do app    -> sempre funciona, mas so o app ve
	 */
	private static File pickDir (Activity a)
	{
		try
		{
			File[] dirs = a.getExternalMediaDirs ();
			if (dirs != null && dirs.length > 0 && dirs[0] != null)
			{
				File d = dirs[0];
				if (d.exists () || d.mkdirs ())
				{
					if (canWrite (d)) return d;
				}
			}
		}
		catch (Throwable t) { }

		try
		{
			File d = new File (Environment.getExternalStorageDirectory (), "FNF-Mobile");
			if (d.exists () || d.mkdirs ())
			{
				if (canWrite (d)) return d;
			}
		}
		catch (Throwable t) { }

		try
		{
			File d = new File (a.getFilesDir (), "log");
			if (d.exists () || d.mkdirs ()) return d;
		}
		catch (Throwable t) { }

		return null;
	}

	private static boolean canWrite (File dir)
	{
		try
		{
			File probe = new File (dir, "escrita.teste");
			FileOutputStream out = new FileOutputStream (probe);
			out.write (1);
			out.close ();
			probe.delete ();
			return true;
		}
		catch (Throwable t)
		{
			return false;
		}
	}

	// -------------------------------------------------------------- erro

	private static void installCrashHandler ()
	{
		try
		{
			final Thread.UncaughtExceptionHandler previous = Thread.getDefaultUncaughtExceptionHandler ();
			Thread.setDefaultUncaughtExceptionHandler (new Thread.UncaughtExceptionHandler ()
			{
				public void uncaughtException (Thread t, Throwable e)
				{
					try
					{
						write ("CRASH na thread " + t.getName ());
						write (stack (e));
						writeFile (crashFile, "thread: " + t.getName () + "\n" + stack (e));
					}
					catch (Throwable x) { }

					if (previous != null) previous.uncaughtException (t, e);
				}
			});
		}
		catch (Throwable t) { }
	}

	/** Guarda o log da sessao anterior quando ela nao chegou ao menu. */
	private static void checkPreviousSession ()
	{
		try
		{
			if (logDir == null) return;

			String text = readTail (new File (logDir, "fnf-mobile.log"), 4000);
			if (text == null)
			{
				write ("sessao anterior: ainda nao existe log do jogo");
				return;
			}

			boolean ok = text.indexOf ("BOOT-OK") >= 0;
			boolean limpa = lastSessionWasClean ();
			write ("sessao anterior chegou ao menu: " + ok);
			write ("sessao anterior terminou normalmente: " + limpa);

			// Mostra o diagnóstico quando: a sessão não chegou ao menu OU ela não
			// terminou de forma limpa (ou seja: o app morreu no meio - foi assim
			// que o fechamento ao abrir o Freeplay aparecia para o jogador).
			if (!ok || !limpa)
			{
				previousSession = text;
				writeFile (new File (logDir, "sessao-anterior.log"), text);
				write ("log da sessao que falhou guardado em sessao-anterior.log");
			}
		}
		catch (Throwable t) { }
	}

	/** Mostra na tela o erro da sessao anterior (se houver). */
	private static void showDialog ()
	{
		try
		{
			if (activity == null || logDir == null) return;

			String title = null;
			String body = null;

			String androidCrash = readTail (crashFile, 2500);
			String gameCrash = readTail (new File (logDir, "fnf-erro.txt"), 2500);

			if (androidCrash != null && androidCrash.length () > 0)
			{
				title = "O app travou (erro do Android)";
				body = androidCrash;
				if (gameCrash != null && gameCrash.length () > 0)
				{
					body += "\n--- erro dentro do jogo ---\n" + gameCrash;
				}
			}
			else if (gameCrash != null && gameCrash.length () > 0)
			{
				title = "O jogo teve um erro";
				body = gameCrash;
			}
			else if (previousSession != null)
			{
				title = "O app fechou sozinho na sessao anterior";
				body = previousSession;
			}

			if (title != null && body != null)
			{
				// o motivo da morte (com o trace do Android) vai sempre junto
				try { body = exitReasonReport () + "\n" + body; } catch (Throwable t) { }
			}

			if (title == null || body == null) return;

			// mostra uma vez so, para nao ficar aparecendo toda vez
			try { if (crashFile != null) crashFile.delete (); } catch (Throwable t) { }
			try { new File (logDir, "fnf-erro.txt").delete (); } catch (Throwable t) { }
			previousSession = null;

			write ("mostrando diagnostico na tela");

			TextView tv = new TextView (activity);
			tv.setText (body);
			tv.setTextSize (10f);
			tv.setPadding (24, 24, 24, 24);

			ScrollView sv = new ScrollView (activity);
			sv.addView (tv);

			AlertDialog.Builder builder = new AlertDialog.Builder (activity);
			builder.setTitle (title + " — tire print e mande");
			builder.setView (sv);
			builder.setPositiveButton ("Fechar", new DialogInterface.OnClickListener ()
			{
				public void onClick (DialogInterface dialog, int which) { }
			});
			builder.show ();
		}
		catch (Throwable t) { }
	}

	// -------------------------------------------------------- permissao

	private static void requestStorage ()
	{
		try
		{
			if (activity == null) return;

			if (Build.VERSION.SDK_INT >= 23 && Build.VERSION.SDK_INT <= 29)
			{
				if (activity.checkSelfPermission ("android.permission.WRITE_EXTERNAL_STORAGE") != PackageManager.PERMISSION_GRANTED)
				{
					write ("pedindo permissao de armazenamento (para usar /sdcard/FNF-Mobile)");
					activity.requestPermissions (new String[] { "android.permission.WRITE_EXTERNAL_STORAGE", "android.permission.READ_EXTERNAL_STORAGE" }, 1001);
				}
				else
				{
					write ("permissao de armazenamento ja concedida");
				}
			}
			else
			{
				write ("android " + Build.VERSION.SDK_INT + ": pasta publica via Android/media (sem permissao)");
			}
		}
		catch (Throwable t) { }
	}

	// ------------------------------------------------------------ apoio

	private static String joinAbis ()
	{
		try
		{
			String out = "";
			for (int i = 0; i < Build.SUPPORTED_ABIS.length; i++)
			{
				if (i > 0) out += ",";
				out += Build.SUPPORTED_ABIS[i];
			}
			return out;
		}
		catch (Throwable t)
		{
			return "?";
		}
	}

	private static String stack (Throwable e)
	{
		try
		{
			java.io.StringWriter sw = new java.io.StringWriter ();
			java.io.PrintWriter pw = new java.io.PrintWriter (sw);
			e.printStackTrace (pw);
			pw.close ();
			return sw.toString ();
		}
		catch (Throwable t)
		{
			return String.valueOf (e);
		}
	}

	private static void writeFile (File f, String text)
	{
		try
		{
			if (f == null) return;
			FileOutputStream out = new FileOutputStream (f, false);
			OutputStreamWriter w = new OutputStreamWriter (out, "UTF-8");
			w.write (text);
			w.close ();
		}
		catch (Throwable t) { }
	}

	private static String readTail (File f, int maxChars)
	{
		try
		{
			if (f == null || !f.exists ()) return null;

			BufferedReader r = new BufferedReader (new InputStreamReader (new FileInputStream (f), "UTF-8"));
			StringBuilder sb = new StringBuilder ();
			String line;
			while ((line = r.readLine ()) != null)
			{
				sb.append (line).append ("\n");
				if (sb.length () > maxChars * 2)
				{
					sb.delete (0, sb.length () - maxChars);
				}
			}
			r.close ();
			return sb.toString ();
		}
		catch (Throwable t)
		{
			return null;
		}
	}
}
