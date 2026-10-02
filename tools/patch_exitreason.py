import pathlib

p = pathlib.Path('tools/android/FnfBoot.java'); s = p.read_text()

# --------------------------------------------------------------- imports
old_i = "import android.app.Activity;\nimport android.app.AlertDialog;"
assert s.count(old_i) == 1
novo_i = """import android.app.Activity;
import android.app.ActivityManager;
import android.app.AlertDialog;
import android.app.ApplicationExitInfo;"""
s = s.replace(old_i, novo_i, 1)

# ------------------------------------------ leitura do motivo da morte
old = """\t/** Resumo do estado da superficie de video (o que o OpenGL usa para aparecer). */"""
assert s.count(old) == 1
novo = """\t/**
\t * Motivo pelo qual a sessao anterior morreu, lido do proprio Android
\t * (ApplicationExitInfo, disponivel a partir do Android 11/API 30).
\t *
\t * Isso responde de uma vez a pergunta que importa: o app foi fechado por
\t * erro no codigo (SIGSEGV), por falta de memoria (OOM), por travamento (ANR)
\t * ou foi o usuario que fechou. Quando o Android tem o "trace" do erro, ele
\t * vem junto - com o nome da funcao onde o app morreu.
\t */
\tpublic static String exitReasonReport ()
\t{
\t\tStringBuilder sb = new StringBuilder ();

\t\ttry
\t\t{
\t\t\tif (Build.VERSION.SDK_INT < 30)
\t\t\t{
\t\t\t\treturn "motivo da morte: (Android antigo, essa informacao nao existe)\\n";
\t\t\t}

\t\t\tActivityManager am = (ActivityManager) activity.getSystemService (Context.ACTIVITY_SERVICE);
\t\t\tjava.util.List<ApplicationExitInfo> lista = am.getHistoricalProcessExitInfos ();

\t\t\tif (lista == null || lista.size () == 0)
\t\t\t{
\t\t\t\treturn "motivo da morte: (o Android nao tem historico)\\n";
\t\t\t}

\t\t\tsb.append ("--- como as sessoes anteriores terminaram ---\\n");
\t\t\tint mostrados = 0;
\t\t\tfor (ApplicationExitInfo info : lista)
\t\t\t{
\t\t\t\tif (mostrados >= 3) break;
\t\t\t\tif (info == null) continue;
\t\t\t\tmostrados++;

\t\t\t\tsb.append ("sessao ").append (mostrados).append (": ")
\t\t\t\t\t.append (reasonName (info.getReason ()))
\t\t\t\t\t.append (" / ").append (subReasonName (info.getSubReason ()))
\t\t\t\t\t.append (info.getTimestamp () > 0 ? (" em " + new SimpleDateFormat ("HH:mm:ss", Locale.US).format (new Date (info.getTimestamp ()))) : "")
\t\t\t\t\t.append ("\\n");

\t\t\t\tString desc = info.getDescription ();
\t\t\t\tif (desc != null && desc.length () > 0)
\t\t\t\t{
\t\t\t\t\tsb.append ("   descricao: ").append (desc).append ("\\n");
\t\t\t\t}

\t\t\t\t// o "trace" e' o ouro: costuma trazer a funcao exata do erro
\t\t\t\ttry
\t\t\t\t{
\t\t\t\t\tjava.io.InputStream in = info.getTraceInputStream ();
\t\t\t\t\tif (in != null)
\t\t\t\t\t{
\t\t\t\t\t\tjava.io.BufferedReader br = new java.io.BufferedReader (new java.io.InputStreamReader (in, "UTF-8"));
\t\t\t\t\t\tStringBuilder trace = new StringBuilder ();
\t\t\t\t\t\tString linha;
\t\t\t\t\t\twhile ((linha = br.readLine ()) != null)
\t\t\t\t\t\t{
\t\t\t\t\t\t\ttrace.append (linha).append ("\\n");
\t\t\t\t\t\t}
\t\t\t\t\t\tbr.close ();
\t\t\t\t\t\tString t = trace.toString ();
\t\t\t\t\t\tif (t.length () > 3000) t = t.substring (0, 3000) + "\\n...(cortado)\\n";
\t\t\t\t\t\tsb.append ("   trace:\\n").append (t);
\t\t\t\t\t}
\t\t\t\t}
\t\t\t\tcatch (Throwable t) { }
\t\t\t}
\t\t}
\t\tcatch (Throwable t)
\t\t{
\t\t\tsb.append ("motivo da morte: (falhou ao ler: ").append (t.toString ()).append (")\\n");
\t\t}

\t\treturn sb.toString ();
\t}

\tprivate static String reasonName (int reason)
\t{
\t\tswitch (reason)
\t\t{
\t\t\tcase ApplicationExitInfo.REASON_CRASH: return "ERRO no codigo Java (REASON_CRASH)";
\t\t\tcase ApplicationExitInfo.REASON_CRASH_NATIVE: return "ERRO no codigo nativo - SIGSEGV/abort (REASON_CRASH_NATIVE)";
\t\t\tcase ApplicationExitInfo.REASON_ANR: return "TRAVOU e o Android matou (REASON_ANR)";
\t\t\tcase ApplicationExitInfo.REASON_LOW_MEMORY: return "SEM MEMORIA - o Android matou (REASON_LOW_MEMORY)";
\t\t\tcase ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE: return "USO EXCESSIVO de recurso (REASON_EXCESSIVE_RESOURCE_USAGE)";
\t\t\tcase ApplicationExitInfo.REASON_SIGNALED: return "MORTO por sinal (REASON_SIGNALED)";
\t\t\tcase ApplicationExitInfo.REASON_EXIT_SELF: return "o app se fechou sozinho (REASON_EXIT_SELF)";
\t\t\tcase ApplicationExitInfo.REASON_USER_REQUESTED: return "fechado pelo usuario";
\t\t\tcase ApplicationExitInfo.REASON_USER_STOPPED: return "parado pelo sistema/usuario";
\t\t\tcase ApplicationExitInfo.REASON_INITIALIZATION_FAILURE: return "falha ao iniciar (REASON_INITIALIZATION_FAILURE)";
\t\t\tcase ApplicationExitInfo.REASON_DEPENDENCY_DIED: return "dependencia caiu (REASON_DEPENDENCY_DIED)";
\t\t\tcase ApplicationExitInfo.REASON_OTHER: return "outro motivo (REASON_OTHER)";
\t\t\tcase 14: return "congelado pelo sistema (REASON_FREEZER)";
\t\t\tcase 15: return "mudanca de estado do pacote (REASON_PACKAGE_STATE_CHANGE)";
\t\t\tcase 16: return "app atualizado (REASON_PACKAGE_UPDATED)";
\t\t\tdefault: return "motivo " + reason;
\t\t}
\t}

\tprivate static String subReasonName (int sub)
\t{
\t\tswitch (sub)
\t\t{
\t\t\tcase 0: return "sem detalhe";
\t\t\tcase ApplicationExitInfo.SUBREASON_UNKNOWN + 0: return "sem detalhe";
\t\t\tcase ApplicationExitInfo.SUBREASON_CRASH_NATIVE: return "crash nativo";
\t\t\tcase ApplicationExitInfo.SUBREASON_ANR: return "travamento (ANR)";
\t\t\tcase ApplicationExitInfo.SUBREASON_INITIALIZATION_FAILURE: return "falha de inicializacao";
\t\t\tcase ApplicationExitInfo.SUBREASON_LOW_MEMORY: return "memoria baixa";
\t\t\tcase ApplicationExitInfo.SUBREASON_EXCESSIVE_CPU: return "CPU demais";
\t\t\tcase ApplicationExitInfo.SUBREASON_EXCESSIVE_MEMORY: return "memoria demais";
\t\t\tcase ApplicationExitInfo.SUBREASON_OTHER: return "outro";
\t\t\tdefault: return "detalhe " + sub;
\t\t}
\t}

\t/** Resumo do estado da superficie de video (o que o OpenGL usa para aparecer). */"""
s = s.replace(old, novo, 1)

# ------------------- coloca no diagnostico e no log de boot
old2 = """\t\ttry { sb.append ("\\n").append (surfaceReport ()); } catch (Throwable t) { }"""
assert s.count(old2) == 1
novo2 = """\t\ttry { sb.append ("\\n").append (surfaceReport ()); } catch (Throwable t) { }
\t\ttry { sb.append ("\\n").append (exitReasonReport ()); } catch (Throwable t) { }"""
s = s.replace(old2, novo2, 1)

# e tambem no log de boot (para o print rapido)
old3 = """\t\tcheckPreviousSession ();
\t\tinstallCrashHandler ();"""
assert s.count(old3) == 1
novo3 = """\t\tcheckPreviousSession ();
\t\tinstallCrashHandler ();

\t\t// grava no log do boot como a sessao anterior terminou (aparece no print
\t\t// do aviso do sistema, sem precisar abrir o dialogo)
\t\ttry { write (exitReasonReport ()); } catch (Throwable t) { }"""
s = s.replace(old3, novo3, 1)
p.write_text(s)
print('exitReasonReport OK; chaves', s.count('{') - s.count('}'))
