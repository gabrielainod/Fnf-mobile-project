import pathlib

# ------------------------- 1) protege a troca de tela dentro do FlxGame
p = pathlib.Path('tools/patch_flixel_mobile.sh'); s = p.read_text()

old = '''# registra qual tela esta sendo criada: se o app fechar aqui, a ultima linha
# do log diz exatamente em qual estado ele morreu'''
assert s.count(old) == 1
novo = '''# protege a destruicao da tela antiga: se ela jogar excecao, o processo
# inteiro morria sem deixar rastro (era uma das causas de "o app fechou")
destroy_old = "\\t\\tif (_state != null)\\n\\t\\t\\t_state.destroy();"
if text.count(destroy_old) == 1:
    destroy_new = ("\\t\\tif (_state != null)\\n"
                   "\\t\\t{\\n"
                   "\\t\\t\\ttry { _state.destroy(); } catch (e:Dynamic) { fnfMobileError(\\"state.destroy\\", e); }\\n"
                   "\\t\\t}")
    text = text.replace(destroy_old, destroy_new, 1)
else:
    print("AVISO: nao achei o destroy do estado antigo")

# e a limpeza do cache de imagens (mexe em textura: se falhar, derruba o app)
cache_old = "\\t\\tFlxG.bitmap.clearCache();"
if text.count(cache_old) == 1:
    cache_new = ("\\t\\ttry { FlxG.bitmap.clearCache(); } catch (e:Dynamic) { fnfMobileError(\\"bitmap.clearCache\\", e); }")
    text = text.replace(cache_old, cache_new, 1)
else:
    print("AVISO: nao achei o clearCache")

# registra qual tela esta sendo criada: se o app fechar aqui, a ultima linha
# do log diz exatamente em qual estado ele morreu'''
s = s.replace(old, novo, 1)
p.write_text(s)
print('patch_flixel_mobile.sh OK')

# ---------------------------------------- 2) RAM total de verdade (meminfo)
p = pathlib.Path('source/mobile/MobilePlatform.hx'); s = p.read_text()
old = """			try
			{
				totalRamMB = openfl.system.System.totalMemory / (1024 * 1024);
			}
			catch (e:Dynamic)
			{
				totalRamMB = 0;
			}"""
assert s.count(old) == 1
novo = """			try
			{
				// openfl.system.System.totalMemory é o heap do app, não a RAM do
				// aparelho; a informação certa está no /proc/meminfo.
				var memInfo:String = null;
				#if sys
				try { memInfo = sys.io.File.getContent('/proc/meminfo'); } catch (e:Dynamic) { memInfo = null; }
				#end

				if (memInfo != null)
				{
					for (linha in memInfo.split('\\n'))
					{
						if (linha.indexOf('MemTotal:') == 0)
						{
							var partes:Array<String> = ~/[ \\t]+/.split(StringTools.trim(linha));
							if (partes.length >= 2) totalRamMB = Std.parseFloat(partes[1]) / 1024;
							break;
						}
					}
				}
			}
			catch (e:Dynamic)
			{
				totalRamMB = 0;
			}

			if (totalRamMB <= 0)
			{
				try { totalRamMB = openfl.system.System.totalMemory / (1024 * 1024); } catch (e:Dynamic) { totalRamMB = 0; }
			}"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('RAM OK')
