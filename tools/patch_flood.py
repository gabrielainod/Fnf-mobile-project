import pathlib

p = pathlib.Path('source/mobile/MobileDebugOverlay.hx'); s = p.read_text()

# 1) guarda o fundo magenta numa variavel para poder apagar depois
old = """	static var panelCreatedAt:Float = 0;"""
assert s.count(old) == 1
s = s.replace(old, """	static var panelCreatedAt:Float = 0;
	static var fundoMagenta:Sprite = null;""", 1)

old = """			var fundo = new Sprite();
			fundo.mouseEnabled = false;
			fundo.name = 'fnfFundoDiagnostico';
			var gf = fundo.graphics;
			gf.beginFill(0xFF00FF, 0.92);
			gf.drawRect(0, 0, sw2, sh2);
			gf.endFill();
			stage.addChildAt(fundo, stage.getChildIndex(panel));"""
assert s.count(old) == 1
novo = """			if (fundoMagenta == null)
			{
				fundoMagenta = new Sprite();
				fundoMagenta.mouseEnabled = false;
				fundoMagenta.name = 'fnfFundoDiagnostico';
				var gf = fundoMagenta.graphics;
				gf.beginFill(0xFF00FF, 0.92);
				gf.drawRect(0, 0, sw2, sh2);
				gf.endFill();
				stage.addChildAt(fundoMagenta, stage.getChildIndex(panel));
			}"""
s = s.replace(old, novo, 1)

# 2) o fundo some junto com o painel (nao fica atrapalhando o jogo)
old = """	static function closePanel():Void
	{
		try
		{
			if (panel != null) panel.visible = false;
			panelClosed = true;
		}
		catch (e:Dynamic) { }
	}"""
assert s.count(old) == 1
novo = """	static function closePanel():Void
	{
		try
		{
			if (panel != null) panel.visible = false;
			panelClosed = true;
		}
		catch (e:Dynamic) { }

		// o fundo magenta e' so' para o teste: sai de cena junto com o painel
		try
		{
			if (fundoMagenta != null && fundoMagenta.parent != null)
			{
				fundoMagenta.parent.removeChild(fundoMagenta);
			}
			fundoMagenta = null;
		}
		catch (e:Dynamic) { }
	}"""
s = s.replace(old, novo, 1)

# 3) tempo do painel: 12s (era 25s) e fechar tambem quando a tela mudar
s = s.replace("if (panelCreatedAt > 0 && (haxe.Timer.stamp() - panelCreatedAt) > 25)",
              "if (panelCreatedAt > 0 && (haxe.Timer.stamp() - panelCreatedAt) > 12)", 1)
p.write_text(s)
print('flood com auto-destruicao OK')
