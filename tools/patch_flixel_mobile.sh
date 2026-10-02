#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Patch no flixel (haxelib) para o FNF Mobile:
#
#   O FlxGame cria/atualiza/desenha o estado atual sem nenhum try/catch. No
#   Android, qualquer exceção que escape vira um abort do processo - o app
#   "fecha sozinho" sem deixar rastro. Este patch:
#
#     * captura a exceção em create/update/draw
#     * grava o erro (com stack) em arquivos que o jogador consegue ler no
#       celular: Android/media/<pacote>/fnf-erro.txt, /sdcard/FNF-Mobile/...
#     * mantém o jogo rodando (o loop continua) em vez de matar o processo
#
# Roda depois do haxelib install e antes do build.
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=haxe_env.sh
source "$ROOT/tools/haxe_env.sh"

FLIXEL_DIR="$(haxelib libpath flixel 2>/dev/null | head -1 | tr -d '\r')"
if [ -z "$FLIXEL_DIR" ] || [ ! -d "$FLIXEL_DIR" ]; then
	FLIXEL_DIR="$(haxelib path flixel 2>/dev/null | grep -oE '/[^ ]+' | head -1 | tr -d '\r')"
fi
if [ -z "$FLIXEL_DIR" ] || [ ! -d "$FLIXEL_DIR" ]; then
	echo "ERRO: flixel não encontrado no haxelib"
	exit 1
fi

GAME_FILE="$FLIXEL_DIR/flixel/FlxGame.hx"
if [ ! -f "$GAME_FILE" ]; then
	echo "ERRO: $GAME_FILE não existe"
	exit 1
fi

if grep -q "fnfMobileError" "$GAME_FILE"; then
	echo "==> FlxGame.hx já estava com o patch mobile"
	exit 0
fi

echo "==> Aplicando patch de captura de erros em $GAME_FILE"
python3 - "$GAME_FILE" <<'PYEOF_PATCH'
import sys

path = sys.argv[1]
text = open(path, encoding='utf-8').read()

helper = '''
	// ===================== FNF Mobile: registro de erros =====================
	/**
	 * Chamado quando algo dentro do estado joga uma exceção. Sem isso, no
	 * Android a exceção derruba o processo inteiro e o jogador não tem como
	 * saber o que aconteceu. Aqui a mensagem (com a pilha) vai para arquivos
	 * que dá para abrir no próprio celular.
	 */
	public static function fnfMobileError(where:String, e:Dynamic):Void
	{
		var msg:String = "[" + where + "] " + Std.string(e);
		#if cpp
		try
		{
			msg += "\\n" + haxe.CallStack.exceptionStack();
		}
		catch (x:Dynamic) { }
		#end

		try { trace("FNF-ERRO " + msg); } catch (x:Dynamic) { }

		// mostra na tela, por cima de tudo (via OpenFL, nao pelo Flixel: o
		// caminho do desenho pode estar quebrado justo quando da erro)
		try
		{
			var cls = Type.resolveClass("mobile.MobileDebugOverlay");
			if (cls != null)
			{
				Reflect.callMethod(cls, Reflect.field(cls, "showError"), ["FNF Mobile - erro em " + where, msg]);
			}
		}
		catch (x:Dynamic) { }

		#if sys
		var dirs:Array<String> = [];
		try { dirs.push(lime.system.System.applicationStorageDirectory + "/log"); } catch (x:Dynamic) { }
		try { dirs.push(lime.system.System.applicationStorageDirectory); } catch (x:Dynamic) { }
		dirs.push("/storage/emulated/0/Android/media/com.fnfmobile.game");
		dirs.push("/sdcard/Android/media/com.fnfmobile.game");
		dirs.push("/storage/emulated/0/FNF-Mobile");
		dirs.push("/sdcard/FNF-Mobile");

		for (d in dirs)
		{
			if (d == null || d == "") continue;
			try
			{
				if (!sys.FileSystem.exists(d)) sys.FileSystem.createDirectory(d);
				sys.io.File.saveContent(d + "/fnf-erro.txt", msg + "\\n");
			}
			catch (x:Dynamic) { }
		}
		#end
	}
	// ========================================================================
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

marker = "\tpublic function new(GameWidth:Int = 0, GameHeight:Int = 0, ?InitialState:Class<FlxState>,"
if text.count(marker) != 1:
    sys.exit("nao achei o construtor do FlxGame")

text = text.replace(marker, helper + marker, 1)

replacements = [
    ("\t\t_state.create();", "\t\ttry { _state.create(); } catch (e:Dynamic) { fnfMobileError(\"state.create\", e); }"),
    ("\t\t_state.tryUpdate(FlxG.elapsed);", "\t\ttry { _state.tryUpdate(FlxG.elapsed); } catch (e:Dynamic) { fnfMobileError(\"state.update\", e); }"),
]

for old, new in replacements:
    if text.count(old) != 1:
        sys.exit("nao achei exatamente uma ocorrencia de: " + old.strip())
    text = text.replace(old, new, 1)

# protege a destruicao da tela antiga: se ela jogar excecao, o processo
# inteiro morria sem deixar rastro (era uma das causas de "o app fechou")
destroy_old = "\t\tif (_state != null)\n\t\t\t_state.destroy();"
if text.count(destroy_old) == 1:
    destroy_new = ("\t\tif (_state != null)\n"
                   "\t\t{\n"
                   "\t\t\ttry { _state.destroy(); } catch (e:Dynamic) { fnfMobileError(\"state.destroy\", e); }\n"
                   "\t\t}")
    text = text.replace(destroy_old, destroy_new, 1)
else:
    print("AVISO: nao achei o destroy do estado antigo")

# e a limpeza do cache de imagens (mexe em textura: se falhar, derruba o app)
cache_old = "\t\tFlxG.bitmap.clearCache();"
if text.count(cache_old) == 1:
    cache_new = ("\t\ttry { FlxG.bitmap.clearCache(); } catch (e:Dynamic) { fnfMobileError(\"bitmap.clearCache\", e); }")
    text = text.replace(cache_old, cache_new, 1)
else:
    print("AVISO: nao achei o clearCache")

# registra qual tela esta sendo criada: se o app fechar aqui, a ultima linha
# do log diz exatamente em qual estado ele morreu
state_old = "\t\t// Finally assign and create the new state\n\t\t_state = _requestedState;"
if text.count(state_old) == 1:
    state_new = ("\t\t// Finally assign and create the new state\n"
                 "\t\ttry { fnfMobileLog(\"trocando de tela para \" + Type.getClassName(Type.getClass(_requestedState))); } catch (x:Dynamic) { }\n"
                 "\t\t_state = _requestedState;")
    text = text.replace(state_old, state_new, 1)
else:
    print("AVISO: nao achei a troca de estado no FlxGame (segue sem esse log)")

# desenho: draw do estado
draw_old = "\t\t_state.draw();"
if text.count(draw_old) == 1:
    text = text.replace(draw_old, "\t\ttry { _state.draw(); } catch (e:Dynamic) { fnfMobileError(\"state.draw\", e); }", 1)
else:
    print("AVISO: nao achei _state.draw() (segue sem esse try)")

open(path, 'w', encoding='utf-8').write(text)
print("patch aplicado")
PYEOF_PATCH

echo "==> Verificação:"
grep -n "fnfMobileError" "$GAME_FILE" | head -8
