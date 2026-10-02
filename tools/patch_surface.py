import pathlib

p = pathlib.Path('tools/android/FnfBoot.java'); s = p.read_text()

# --- imports novos para inspecionar a superficie de video ---
old_i = """import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;"""
assert s.count(old_i) == 1
novo_i = """import android.graphics.Rect;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;"""
s = s.replace(old_i, novo_i, 1)

# --- agenda a inspecao da superficie (6s) junto do heartbeat ---
old_h = "\t\tstartHeartbeat ();\n\t}"
assert s.count(old_h) == 1
novo_h = """\t\tstartHeartbeat ();

\t\t// Aos 6 segundos inspeciona a superficie de video do Android: e' ela que
\t\t// recebe o que o OpenGL desenha. Se ela estiver invalida/zerada, a tela
\t\t// fica preta mesmo com o jogo rodando.
\t\ttry
\t\t{
\t\t\tnew Handler (Looper.getMainLooper ()).postDelayed (new Runnable ()
\t\t\t{
\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry { write (surfaceReport ()); } catch (Throwable t) { }
\t\t\t\t}
\t\t\t}, 6000L);
\t\t}
\t\tcatch (Throwable t) { }
\t}

\t/** Resumo do estado da superficie de video (o que o OpenGL usa para aparecer). */
\tpublic static String surfaceReport ()
\t{
\t\tStringBuilder sb = new StringBuilder ();

\t\tsb.append ("=== superficie de video (6s) ===\\n");

\t\ttry
\t\t{
\t\t\tandroid.view.WindowManager wm = (android.view.WindowManager) activity.getSystemService (Context.WINDOW_SERVICE);
\t\t\tandroid.util.DisplayMetrics dm = new android.util.DisplayMetrics ();
\t\t\twm.getDefaultDisplay ().getMetrics (dm);
\t\t\tsb.append ("tela: ").append (dm.widthPixels).append ("x").append (dm.heightPixels)
\t\t\t\t.append (" densidade ").append (dm.densityDpi).append ("dpi refresh ")
\t\t\t\t.append (wm.getDefaultDisplay ().getRefreshRate ()).append ("Hz\\n");
\t\t}
\t\tcatch (Throwable t) { }

\t\ttry
\t\t{
\t\t\tsb.append ("flags da janela: 0x").append (Integer.toHexString (activity.getWindow ().getAttributes ().flags)).append ("\\n");
\t\t}
\t\tcatch (Throwable t) { }

\t\ttry
\t\t{
\t\t\tView decor = activity.getWindow ().getDecorView ();
\t\t\tsb.append ("decor: ").append (decor.getWidth ()).append ("x").append (decor.getHeight ())
\t\t\t\t.append (" visivel=").append (decor.getVisibility ()).append (" naTela=").append (decor.isShown ()).append ("\\n");
\t\t}
\t\tcatch (Throwable t) { }

\t\ttry
\t\t{
\t\t\tView conteudo = activity.findViewById (android.R.id.content);
\t\t\tif (conteudo != null)
\t\t\t{
\t\t\t\tsb.append ("arvore de views (ate 3 niveis):\\n");
\t\t\t\tdescreverView (conteudo, sb, 0, 3);
\t\t\t}
\t\t}
\t\tcatch (Throwable t) { }

\t\treturn sb.toString () + "================================\\n";
\t}

\tprivate static void describir (StringBuilder sb, int nivel)
\t{
\t\tfor (int i = 0; i < nivel; i++) sb.append ("   ");
\t}

\tprivate static void descreverView (View v, StringBuilder sb, int nivel, int maxNivel)
\t{
\t\ttry
\t\t{
\t\t\tdescribir (sb, nivel);
\t\t\tsb.append (v.getClass ().getName ())
\t\t\t\t.append (" ").append (v.getWidth ()).append ("x").append (v.getHeight ())
\t\t\t\t.append (" vis=").append (v.getVisibility ())
\t\t\t\t.append (" naTela=").append (v.isShown ());

\t\t\tif (v instanceof SurfaceView)
\t\t\t{
\t\t\t\tSurfaceView sv = (SurfaceView) v;
\t\t\t\tSurfaceHolder h = sv.getHolder ();
\t\t\t\tSurface sup = (h != null) ? h.getSurface () : null;
\t\t\t\tsb.append (" SUPERFICIE=");
\t\t\t\tif (sup == null) sb.append ("nula");
\t\t\t\telse if (!sup.isValid ()) sb.append ("INVALIDA");
\t\t\t\telse sb.append ("ok");
\t\t\t\ttry
\t\t\t\t{
\t\t\t\t\tRect r = new Rect ();
\t\t\t\t\tsv.getGlobalVisibleRect (r);
\t\t\t\t\tsb.append (" areaVisivel=").append (r.width ()).append ("x").append (r.height ());
\t\t\t\t}
\t\t\t\tcatch (Throwable t) { }
\t\t\t}

\t\t\tsb.append ("\\n");

\t\t\tif (v instanceof ViewGroup && nivel < maxNivel)
\t\t\t{
\t\t\t\tViewGroup g = (ViewGroup) v;
\t\t\t\tfor (int i = 0; i < g.getChildCount (); i++)
\t\t\t\t{
\t\t\t\t\tdescreverView (g.getChildAt (i), sb, nivel + 1, maxNivel);
\t\t\t\t}
\t\t\t}
\t\t}
\t\tcatch (Throwable t) { }
\t}"""
s = s.replace(old_h, novo_h, 1)

# --- o dialogo de diagnostico passa a incluir o estado da superficie ---
old_d = """\t\tsb.append ("pasta do log: ").append (logDir != null ? logDir.getAbsolutePath () : "?").append ("\\n");"""
assert s.count(old_d) == 1
novo_d = """\t\tsb.append ("pasta do log: ").append (logDir != null ? logDir.getAbsolutePath () : "?").append ("\\n");
\t\ttry { sb.append ("\\n").append (surfaceReport ()); } catch (Throwable t) { }"""
s = s.replace(old_d, novo_d, 1)
p.write_text(s)
print('FnfBoot surfaceReport OK; chaves', s.count('{') - s.count('}'))
