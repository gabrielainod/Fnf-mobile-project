import pathlib
import re

# ------------------------------------------------------------- 1) Main.hx
p = pathlib.Path('source/Main.hx'); s = p.read_text()

old = "\t\tMobileNative.init();"
assert s.count(old) == 1
s = s.replace(old, "\t\tMobileNative.init();\n\t\tMobileGfx.init();", 1)
s = s.replace("import mobile.MobileDebugOverlay;", "import mobile.MobileDebugOverlay;\nimport mobile.MobileGfx;", 1)
p.write_text(s)
print('Main.hx OK')

# ------------------------------------- 2) batimento leva o estado do desenho
p = pathlib.Path('source/mobile/MobileDebugOverlay.hx'); s = p.read_text()

old = """			MobilePlatform.log('batimento: tela ' + estado + ' | update ' + updates + ' | desenho ' + draws);"""
assert s.count(old) == 1
novo = """			MobilePlatform.log('batimento: tela ' + estado + ' | update ' + updates + ' | desenho ' + draws);
			MobilePlatform.log('   ' + MobileGfx.report());"""
s = s.replace(old, novo, 1)

# painel: tela inteira magenta, texto grande => impossivel nao ver se o OpenFL desenha
old2 = """		var g = panel.graphics;
		g.clear();
		g.beginFill(0x101018, 0.78);
		g.drawRect(0, 0, 716, 80);
		g.endFill();
		// borda colorida: serve de sinal mesmo se a fonte nao desenhar nada
		g.lineStyle(3, 0x808080, 1);
		g.drawRect(0, 0, 716, 80);

		panel.x = 6;
		panel.y = 6;"""
assert s.count(old2) == 1
novo2 = """		var g = panel.graphics;
		g.clear();
		g.beginFill(0x101018, 0.78);
		g.drawRect(0, 0, 716, 80);
		g.endFill();
		// borda colorida: serve de sinal mesmo se a fonte nao desenhar nada
		g.lineStyle(3, 0x808080, 1);
		g.drawRect(0, 0, 716, 80);

		// TELA INTEIRA magenta (grande e chamativo de proposito): e' a prova
		// visual de que o OpenFL consegue desenhar no aparelho. Se a tela ficar
		// preta com isso ligado, o problema e' no OpenGL/tela e nao no jogo.
		try
		{
			var sw2:Float = stage.stageWidth;
			var sh2:Float = stage.stageHeight;
			if (sw2 <= 0) sw2 = 1280;
			if (sh2 <= 0) sh2 = 720;
			var fundo = new Sprite();
			fundo.mouseEnabled = false;
			fundo.name = 'fnfFundoDiagnostico';
			var gf = fundo.graphics;
			gf.beginFill(0xFF00FF, 0.92);
			gf.drawRect(0, 0, sw2, sh2);
			gf.endFill();
			stage.addChildAt(fundo, stage.getChildIndex(panel));
		}
		catch (e:Dynamic) { }

		panel.x = 0;
		panel.y = 0;"""
s = s.replace(old2, novo2, 1)

# texto maior no painel
s = s.replace("panelText.defaultTextFormat = new TextFormat('_sans', 12, 0xFFFFFF, true);",
              "panelText.defaultTextFormat = new TextFormat('_sans', 22, 0x000000, true);", 1)
s = s.replace("""		panelText.width = 700;
		panelText.height = 68;""",
              """		panelText.width = 1400;
		panelText.height = 300;""", 1)
s = s.replace("""		panelText.x = 8;
		panelText.y = 6;""",
              """		panelText.x = 24;
		panelText.y = 24;""", 1)

# texto do painel inclui o estado do desenho
old3 = """			var total:String = linha1 + '\\n' + linha2 + (linha3 != '' ? '\\n' + linha3 : '');"""
assert s.count(old3) == 1
novo3 = """			var linha4:String = '';
			try { linha4 = MobileGfx.report(); } catch (e:Dynamic) { }

			var total:String = linha1 + '\\n' + linha2 + (linha3 != '' ? '\\n' + linha3 : '') + (linha4 != '' ? '\\n' + linha4 : '');"""
s = s.replace(old3, novo3, 1)

# borda do painel: maior
s = s.replace("g.drawRect(0, 0, 716, 80);\n\t\t\t\tg.endFill();\n\t\t\t\tg.lineStyle(3, cor, 1);\n\t\t\t\tg.drawRect(0, 0, 716, 80);",
              "g.drawRect(0, 0, 716, 80);\n\t\t\t\tg.endFill();\n\t\t\t\tg.lineStyle(3, cor, 1);\n\t\t\t\tg.drawRect(0, 0, 716, 80);")
p.write_text(s)
print('MobileDebugOverlay OK')
