import pathlib
p = pathlib.Path('tools/android/FnfBoot.java'); s = p.read_text()

old_imports = """import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;
import android.widget.ScrollView;
import android.widget.TextView;"""
novo_imports = """import android.app.Activity;
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
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;"""
assert s.count(old_imports) == 1
s = s.replace(old_imports, novo_imports, 1)

old_fields = "\tprivate static Activity activity = null;"
novo_fields = """\t/** Identificacao desta build (o CI troca este texto pelo numero do run). */
\tpublic static final String BUILD_TAG = "__FNF_BUILD_TAG__";

\t/** Depois de quanto tempo mostrar o diagnostico na tela (ms). */
\tprivate static final long DIAGNOSTIC_DELAY_MS = 15000L;

\tprivate static Activity activity = null;"""
assert s.count(old_fields) == 1
s = s.replace(old_fields, novo_fields, 1)

old_call = """\t\ttry
\t\t{
\t\t\ta.runOnUiThread (new Runnable ()
\t\t\t{
\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry { requestStorage (); } catch (Throwable t) { }
\t\t\t\t\ttry { showDialog (); } catch (Throwable t) { }
\t\t\t\t}
\t\t\t});
\t\t}
\t\tcatch (Throwable t) { }
\t}"""

novo_call = """\t\ttry
\t\t{
\t\t\ta.runOnUiThread (new Runnable ()
\t\t\t{
\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry { requestStorage (); } catch (Throwable t) { }
\t\t\t\t\ttry { showDialog (); } catch (Throwable t) { }
\t\t\t\t\ttry { toast ("FNF Mobile - diagnostico " + BUILD_TAG + " (aguarde 15s)"); } catch (Throwable t) { }
\t\t\t\t}
\t\t\t});
\t\t}
\t\tcatch (Throwable t) { }

\t\t// Depois de 15s mostra, numa janela DO ANDROID (aparece mesmo se o
\t\t// OpenGL nao desenhar nada), o resumo do log do jogo. Tem botao
\t\t// "Copiar": da' para colar o texto em qualquer conversa.
\t\ttry
\t\t{
\t\t\tnew Handler (Looper.getMainLooper ()).postDelayed (new Runnable ()
\t\t\t{
\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry { showDiagnostics (); } catch (Throwable t) { }
\t\t\t\t}
\t\t\t}, DIAGNOSTIC_DELAY_MS);
\t\t}
\t\tcatch (Throwable t) { }
\t}

\t/** Aviso curto do sistema (nao depende do OpenGL). */
\tpublic static void toast (final String message)
\t{
\t\ttry
\t\t{
\t\t\tif (activity == null) return;
\t\t\tactivity.runOnUiThread (new Runnable ()
\t\t\t{
\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry { Toast.makeText (activity, message, Toast.LENGTH_LONG).show (); } catch (Throwable t) { }
\t\t\t\t}
\t\t\t});
\t\t}
\t\tcatch (Throwable t) { }
\t}

\t// --------------------------------------------------------- diagnostico

\t/** Monta o texto com tudo o que interessa para descobrir a tela preta. */
\tprivate static String buildDiagnostics ()
\t{
\t\tStringBuilder sb = new StringBuilder ();

\t\tsb.append ("build: ").append (BUILD_TAG).append ("\\n");
\t\tsb.append ("instalado em: ").append (installTime ()).append ("\\n");
\t\tsb.append ("aparelho: ").append (Build.MANUFACTURER).append (" ").append (Build.MODEL).append ("\\n");
\t\tsb.append ("android: ").append (Build.VERSION.RELEASE).append (" (SDK ").append (Build.VERSION.SDK_INT).append (")\\n");
\t\tsb.append ("abis: ").append (joinAbis ()).append ("\\n");
\t\tsb.append ("heap max: ").append (Runtime.getRuntime ().maxMemory () / 1048576).append (" MB\\n");
\t\tsb.append ("pasta do log: ").append (logDir != null ? logDir.getAbsolutePath () : "?").append ("\\n");

\t\tif (logDir != null)
\t\t{
\t\t\tsb.append ("\\n--- fnf-mobile.log (ultimas linhas do jogo) ---\\n");
\t\t\tsb.append (orNone (readTail (new File (logDir, "fnf-mobile.log"), 5000)));
\t\t\tsb.append ("\\n--- fnf-boot.log (lado Android) ---\\n");
\t\t\tsb.append (orNone (readTail (new File (logDir, "fnf-boot.log"), 2000)));
\t\t}

\t\treturn sb.toString ();
\t}

\t/** Mostra o diagnostico numa janela nativa do Android (com botao Copiar). */
\tprivate static void showDiagnostics ()
\t{
\t\ttry
\t\t{
\t\t\tif (activity == null || logDir == null) return;

\t\t\tfinal String text = buildDiagnostics ();
\t\t\twriteFile (new File (logDir, "diagnostico.txt"), text);
\t\t\twrite ("mostrando o diagnostico na tela (build " + BUILD_TAG + ")");

\t\t\tactivity.runOnUiThread (new Runnable ()
\t\t\t{
\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry
\t\t\t\t\t{
\t\t\t\t\t\tTextView tv = new TextView (activity);
\t\t\t\t\t\ttv.setText (text);
\t\t\t\t\t\ttv.setTextSize (9f);
\t\t\t\t\t\ttv.setPadding (22, 22, 22, 22);

\t\t\t\t\t\tScrollView sv = new ScrollView (activity);
\t\t\t\t\t\tsv.addView (tv);

\t\t\t\t\t\tnew AlertDialog.Builder (activity)
\t\t\t\t\t\t\t.setTitle ("Diagnostico FNF Mobile " + BUILD_TAG)
\t\t\t\t\t\t\t.setView (sv)
\t\t\t\t\t\t\t.setPositiveButton ("Copiar", new DialogInterface.OnClickListener ()
\t\t\t\t\t\t\t{
\t\t\t\t\t\t\t\tpublic void onClick (DialogInterface dialog, int which)
\t\t\t\t\t\t\t\t{
\t\t\t\t\t\t\t\t\ttry
\t\t\t\t\t\t\t\t\t{
\t\t\t\t\t\t\t\t\t\tClipboardManager cm = (ClipboardManager) activity.getSystemService (Context.CLIPBOARD_SERVICE);
\t\t\t\t\t\t\t\t\t\tcm.setPrimaryClip (ClipData.newPlainText ("FNF Mobile", text));
\t\t\t\t\t\t\t\t\t\ttoast ("Copiado! agora e' so colar na conversa.");
\t\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t\t\tcatch (Throwable t)
\t\t\t\t\t\t\t\t\t{
\t\t\t\t\t\t\t\t\t\ttoast ("Nao consegui copiar - tire print da tela.");
\t\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t})
\t\t\t\t\t\t\t.setNegativeButton ("Fechar", null)
\t\t\t\t\t\t\t.show ();
\t\t\t\t\t}
\t\t\t\t\tcatch (Throwable t) { }
\t\t\t\t}
\t\t\t});
\t\t}
\t\tcatch (Throwable t) { }
\t}

\tprivate static String installTime ()
\t{
\t\ttry
\t\t{
\t\t\tPackageInfo info = activity.getPackageManager ().getPackageInfo (activity.getPackageName (), 0);
\t\t\treturn new SimpleDateFormat ("yyyy-MM-dd HH:mm:ss", Locale.US).format (new Date (info.lastUpdateTime));
\t\t}
\t\tcatch (Throwable t)
\t\t{
\t\t\treturn "?";
\t\t}
\t}

\tprivate static String orNone (String text)
\t{
\t\tif (text == null || text.trim ().length () == 0) return "(vazio)\\n";
\t\treturn text;
\t}"""

assert s.count(old_call) == 1
s = s.replace(old_call, novo_call, 1)
p.write_text(s)
print('FnfBoot.java OK')
