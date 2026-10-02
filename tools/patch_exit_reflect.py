import pathlib

p = pathlib.Path('tools/android/FnfBoot.java'); s = p.read_text()

# 1) remove o import do Android 11 (nao existe no compileSdk 28)
s = s.replace("import android.app.ApplicationExitInfo;\n", "", 1)

# 2) troca o bloco inteiro do motivo da morte por uma versao com reflexao
start = s.index("\tpublic static String exitReasonReport ()")
end = s.index("\t/** Resumo do estado da superficie de video")
bloco_novo = '''\tpublic static String exitReasonReport ()
\t{
\t\tStringBuilder sb = new StringBuilder ();

\t\ttry
\t\t{
\t\t\tif (Build.VERSION.SDK_INT < 30)
\t\t\t{
\t\t\t\treturn "motivo da morte: (Android antigo, essa informacao nao existe)\\n";
\t\t\t}

\t\t\tObject am = activity.getSystemService (Context.ACTIVITY_SERVICE);
\t\t\tif (am == null)
\t\t\t{
\t\t\t\treturn "motivo da morte: (sem ActivityManager)\\n";
\t\t\t}

\t\t\t// Chamada por reflexao de proposito: o projeto e' compilado com o SDK
\t\t\t// 28 (por causa do armazenamento dos mods), mas no aparelho - Android
\t\t\t// 11 ou mais novo - a funcao existe e devolve o motivo real da morte.
\t\t\tjava.lang.reflect.Method metodo = am.getClass ().getMethod ("getHistoricalProcessExitInfos");
\t\t\tObject resultado = metodo.invoke (am);

\t\t\tif (!(resultado instanceof java.util.List))
\t\t\t{
\t\t\t\treturn "motivo da morte: (o Android nao devolveu historico)\\n";
\t\t\t}

\t\t\tjava.util.List<?> itens = (java.util.List<?>) resultado;
\t\t\tsb.append ("--- como as sessoes anteriores terminaram ---\\n");

\t\t\tint mostrados = 0;
\t\t\tfor (Object info : itens)
\t\t\t{
\t\t\t\tif (info == null || mostrados >= 3) break;
\t\t\t\tmostrados++;

\t\t\t\tint motivo = intField (info, "getReason");
\t\t\t\tint detalhe = intField (info, "getSubReason");
\t\t\t\tlong quando = longField (info, "getTimestamp");
\t\t\t\tString descricao = strField (info, "getDescription");

\t\t\t\tsb.append ("sessao ").append (mostrados).append (": ").append (reasonName (motivo))
\t\t\t\t\t.append (" / detalhe ").append (detalhe);
\t\t\t\tif (quando > 0)
\t\t\t\t{
\t\t\t\t\tsb.append (" em ").append (new SimpleDateFormat ("HH:mm:ss", Locale.US).format (new Date (quando)));
\t\t\t\t}
\t\t\t\tsb.append ("\\n");

\t\t\t\tif (descricao != null && descricao.length () > 0)
\t\t\t\t{
\t\t\t\t\tsb.append ("   descricao: ").append (descricao).append ("\\n");
\t\t\t\t}

\t\t\t\t// o "trace" costuma trazer a funcao exata onde o app morreu
\t\t\t\ttry
\t\t\t\t{
\t\t\t\t\tjava.lang.reflect.Method tm = info.getClass ().getMethod ("getTraceInputStream");
\t\t\t\t\tObject in = tm.invoke (info);
\t\t\t\t\tif (in instanceof java.io.InputStream)
\t\t\t\t\t{
\t\t\t\t\t\tjava.io.BufferedReader br = new java.io.BufferedReader (new java.io.InputStreamReader ((java.io.InputStream) in, "UTF-8"));
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

\tprivate static int intField (Object obj, String metodo)
\t{
\t\ttry
\t\t{
\t\t\tObject v = obj.getClass ().getMethod (metodo).invoke (obj);
\t\t\treturn (v instanceof Integer) ? ((Integer) v).intValue () : 0;
\t\t}
\t\tcatch (Throwable t)
\t\t{
\t\t\treturn 0;
\t\t}
\t}

\tprivate static long longField (Object obj, String metodo)
\t{
\t\ttry
\t\t{
\t\t\tObject v = obj.getClass ().getMethod (metodo).invoke (obj);
\t\t\treturn (v instanceof Long) ? ((Long) v).longValue () : 0L;
\t\t}
\t\tcatch (Throwable t)
\t\t{
\t\t\treturn 0L;
\t\t}
\t}

\tprivate static String strField (Object obj, String metodo)
\t{
\t\ttry
\t\t{
\t\t\tObject v = obj.getClass ().getMethod (metodo).invoke (obj);
\t\t\treturn (v != null) ? v.toString () : null;
\t\t}
\t\tcatch (Throwable t)
\t\t{
\t\t\treturn null;
\t\t}
\t}

\t/** Nome do motivo (numeros fixos da API do Android 11+). */
\tprivate static String reasonName (int reason)
\t{
\t\tswitch (reason)
\t\t{
\t\t\tcase 0: return "motivo desconhecido";
\t\t\tcase 1: return "o app se fechou sozinho";
\t\t\tcase 2: return "MORTO POR SINAL do sistema";
\t\t\tcase 3: return "SEM MEMORIA - o Android matou (OOM)";
\t\t\tcase 4: return "ERRO no codigo Java";
\t\t\tcase 5: return "ERRO no codigo nativo (SIGSEGV/abort)";
\t\t\tcase 6: return "TRAVOU e o Android matou (ANR)";
\t\t\tcase 7: return "falha ao iniciar";
\t\t\tcase 8: return "mudanca de permissao";
\t\t\tcase 9: return "uso excessivo de recurso";
\t\t\tcase 10: return "fechado pelo usuario";
\t\t\tcase 11: return "parado pelo sistema/usuario";
\t\t\tcase 12: return "dependencia caiu";
\t\t\tcase 13: return "outro motivo";
\t\t\tcase 14: return "congelado pelo sistema";
\t\t\tcase 15: return "mudanca de estado do pacote";
\t\t\tcase 16: return "app foi atualizado";
\t\t\tdefault: return "motivo " + reason;
\t\t}
\t}

'''
s = s[:start] + bloco_novo + s[end:]

# 3) tira a funcao antiga subReasonName, que nao e' mais usada
ini = s.find("\tprivate static String subReasonName (int sub)")
if ini != -1:
    fim = s.index("\n\t}", ini) + len("\n\t}\n")
    s = s[:ini] + s[fim:]

p.write_text(s)
print('reflexao OK; chaves', s.count('{') - s.count('}'), 'parens', s.count('(') - s.count(')'))
print('subReasonName restante:', s.count('subReasonName'))
print('ApplicationExitInfo restante:', s.count('ApplicationExitInfo'))
