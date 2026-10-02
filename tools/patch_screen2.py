import pathlib

# ------------------------------------------- MobilePlatform: avisos na tela
p = pathlib.Path('source/mobile/MobilePlatform.hx'); s = p.read_text()

old = """\t\t// erro em tempo real aparece na tela (print = diagnostico sem PC)
\t\tif (message.indexOf('ERRO') != -1 || message.indexOf('FATAL') != -1 || message.indexOf('CRASH') != -1)
\t\t{
\t\t\tMobileDebugOverlay.showError('FNF Mobile - algo deu errado', message);
\t\t}
"""
assert s.count(old) == 1
novo = """\t\t// erro em tempo real aparece na tela (print = diagnostico sem PC)
\t\tif (message.indexOf('ERRO') != -1 || message.indexOf('FATAL') != -1 || message.indexOf('CRASH') != -1)
\t\t{
\t\t\tMobileDebugOverlay.showError('FNF Mobile - algo deu errado', message);
\t\t}

\t\t// E TAMBEM como aviso do proprio Android (Toast): esse aviso e' desenhado
\t\t// pelo sistema operacional, entao aparece mesmo quando o OpenGL nao
\t\t// desenha nada - que e' exatamente o caso da tela preta.
\t\tMobileNative.toast(message);
"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('MobilePlatform OK')

# ------------------------------------- MobileDebugOverlay: batimento no log
p = pathlib.Path('source/mobile/MobileDebugOverlay.hx'); s = p.read_text()

old = """		if (frame % 10 != 0) return; // nao mexe no texto todo frame (custo no celular)
		refreshPanel();"""
assert s.count(old) == 1
novo = """		// batimento: de 3 em 3 segundos grava no log (e na tela) um resumo do
		// estado, para o ultimo registro antes de um defeito dizer tudo.
		if (frame % 180 == 0)
		{
			var estado:String = '?';
			try { estado = MobilePlatform.currentStateName(); } catch (e:Dynamic) { }
			MobilePlatform.log('batimento: tela ' + estado + ' | update ' + updates + ' | desenho ' + draws);
		}

		if (frame % 10 != 0) return; // nao mexe no texto todo frame (custo no celular)
		refreshPanel();"""
s = s.replace(old, novo, 1)
p.write_text(s)
print('MobileDebugOverlay OK')
