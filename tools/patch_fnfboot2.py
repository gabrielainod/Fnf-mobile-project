import pathlib
p = pathlib.Path('tools/android/FnfBoot.java'); s = p.read_text()

# agenda o "batimento" junto com o diagnostico de 15s
old = """\t\ttry
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
\t}"""
assert s.count(old) == 1
novo = """\t\ttry
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

\t\tstartHeartbeat ();
\t}

\t/**
\t * Repete, num aviso do sistema (Toast), as ultimas linhas do log do jogo.
\t *
\t * Serve para o caso em que o OpenGL nao desenha NADA: o jogo continua
\t * rodando e gravando o log, e o aviso do sistema (desenhado pelo proprio
\t * Android) mostra na tela o que esta acontecendo, sem precisar de PC.
\t */
\tprivate static void startHeartbeat ()
\t{
\t\ttry
\t\t{
\t\t\tfinal Handler handler = new Handler (Looper.getMainLooper ());
\t\t\thandler.postDelayed (new Runnable ()
\t\t\t{
\t\t\t\tint count = 0;

\t\t\t\tpublic void run ()
\t\t\t\t{
\t\t\t\t\ttry
\t\t\t\t\t{
\t\t\t\t\t\tif (count >= 15) return;
\t\t\t\t\t\tcount++;

\t\t\t\t\t\tString tail = (logDir != null) ? readTail (new File (logDir, "fnf-mobile.log"), 300) : null;
\t\t\t\t\t\tif (tail != null)
\t\t\t\t\t\t{
\t\t\t\t\t\t\tString[] lines = tail.split ("\\n");
\t\t\t\t\t\t\tString last = "";
\t\t\t\t\t\t\tint achou = 0;
\t\t\t\t\t\t\tfor (int i = lines.length - 1; i >= 0 && achou < 3; i--)
\t\t\t\t\t\t\t{
\t\t\t\t\t\t\t\tString l = lines[i].trim ();
\t\t\t\t\t\t\t\tif (l.length () == 0) continue;
\t\t\t\t\t\t\t\tlast = l + "\\n" + last;
\t\t\t\t\t\t\t\tachou++;
\t\t\t\t\t\t\t}
\t\t\t\t\t\t\ttoast (last.length () > 240 ? last.substring (0, 240) : last);
\t\t\t\t\t\t}

\t\t\t\t\t\thandler.postDelayed (this, 4000L);
\t\t\t\t\t}
\t\t\t\t\tcatch (Throwable t) { }
\t\t\t\t}
\t\t\t}, 3000L);
\t\t}
\t\tcatch (Throwable t) { }
\t}"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('heartbeat OK, chaves', s.count('{') - s.count('}'))
