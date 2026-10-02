import pathlib

p = pathlib.Path('tools/patch_flixel_mobile.sh'); s = p.read_text()

# 1) helper de log ao lado do fnfMobileError
old_helper_marker = """	// ========================================================================

'''
"""
assert s.count(old_helper_marker) == 1
novo_helper = """	// ========================================================================
	/**
	 * Escreve uma linha no log do jogo (o mesmo arquivo que o MobilePlatform
	 * mantem). Usado para registrar as trocas de tela: e' assim que se descobre
	 * qual tela estava sendo criada quando o app fechou sozinho.
	 */
	public static function fnfMobileLog(msg:String):Void
	{
		try
		{
			var cls = Type.resolveClass("mobile.MobilePlatform");
			if (cls != null)
			{
				var fn = Reflect.field(cls, "log");
				if (fn != null) Reflect.callMethod(cls, fn, [msg]);
			}
		}
		catch (x:Dynamic) { }
	}
	// ========================================================================
'''
"""
s = s.replace(old_helper_marker, novo_helper, 1)

# 2) loga a tela que esta sendo criada (antes do create do estado)
old_rep = """for old, new in replacements:
    if text.count(old) != 1:
        sys.exit("nao achei exatamente uma ocorrencia de: " + old.strip())
    text = text.replace(old, new, 1)"""
assert s.count(old_rep) == 1
novo_rep = """for old, new in replacements:
    if text.count(old) != 1:
        sys.exit("nao achei exatamente uma ocorrencia de: " + old.strip())
    text = text.replace(old, new, 1)

# registra qual tela esta sendo criada: se o app fechar aqui, a ultima linha
# do log diz exatamente em qual estado ele morreu
state_old = "\\t\\t// Finally assign and create the new state\\n\\t\\t_state = _requestedState;"
if text.count(state_old) == 1:
    state_new = ("\\t\\t// Finally assign and create the new state\\n"
                 "\\t\\ttry { fnfMobileLog(\\"trocando de tela para \\" + Type.getClassName(Type.getClass(_requestedState))); } catch (x:Dynamic) { }\\n"
                 "\\t\\t_state = _requestedState;")
    text = text.replace(state_old, state_new, 1)
else:
    print("AVISO: nao achei a troca de estado no FlxGame (segue sem esse log)")"""
s = s.replace(old_rep, novo_rep, 1)
p.write_text(s)
print('patch_flixel_mobile.sh OK')
