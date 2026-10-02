# Friday Night Funkin' — Mobile (Semana 1 a 3)

Port Android **de verdade** do Friday Night Funkin', feito em cima do
**Psych Engine 0.6.3** (o mesmo motor que o pessoal usa para mods). Não é um jogo
"inspirado": é o FNF/Psych original rodando no celular, com controles de toque
por **hitbox nas setas**, opções de desempenho para aparelho fraco e suporte a
mods.

---

## 1. Como instalar o APK

**Download:** https://github.com/gabrielainod/Fnf-mobile-project/releases/tag/v1.0.0-mobile
(arquivo `FNF-Mobile-1.0.0.apk`, 110 MB)

1. Abra o link acima **no celular** e baixe o APK.
2. Toque no arquivo baixado e permita "instalar apps de fontes desconhecidas"
   (o Android pede isso para qualquer APK fora da Play Store).
3. Abra o jogo. Na primeira vez ele escolhe automaticamente as opções ideais
   para o seu aparelho (veja a seção de desempenho).

Confira o arquivo baixado (opcional):

```
sha256: 630022b8ed2023f24737271b4c340996a2c156f800b2f8aa0907d7f02cde1a15
```

Requisitos: **Android 5.0+**, ~400 MB livres e **arm64 (arm64-v8a)** ou **armv7**
(o APK traz as duas ABIs compiladas, então roda em celular antigo de 32 bits).

---

### Se algo der errado (diagnóstico no próprio celular)

**Diálogo automático de queda.** Se o app fechar sozinho, na próxima vez que abrir
aparece uma janela com o motivo da morte (lido do próprio Android: erro nativo, falta
de memória, travamento…), o trace do erro e as últimas linhas do log — com botão
**Copiar**. É só colar o texto para reportar.

**Assets que faltam viram quadradinho magenta.** Em vez de fechar o app, um asset
ausente aparece como um quadrado rosa e o log escreve `FALTA ASSET: <arquivo>`.


**0. Painel de status na tela (build de diagnóstico).** Os primeiros 25 segundos
mostram um painel no canto superior esquerdo com a tela atual, quantos updates e
quantos desenhos o jogo já fez, o tamanho da janela e o estado do shader. A cor
da borda já diz muito: **verde** = está desenhando, **vermelho** = o `update`
roda mas o `desenho` fica em 0 (o desenho nunca acontece), **cinza** = ainda
começando. Se nem o painel aparecer com a tela preta, o defeito está no
OpenGL/janela (nada do OpenFL desenha). Toque na tela para fechar o painel.


**1. Tela de erro automática.** Se o app travar, na *próxima vez* que você abrir
ele mostra uma janela com o erro completo (e a última tela em que estava). É só
tirar print e mandar — não precisa de PC, cabo nem nada.

**2. Arquivos de log** (abra em qualquer gerenciador de arquivos):

```
/sdcard/FNF-Mobile/fnf-mobile.log            log do jogo (se você aceitar a permissão de armazenamento)
/sdcard/Android/media/com.fnfmobile.game/    mesma coisa, SEM precisar de permissão:
    fnf-mobile.log      log do jogo (marcadores de boot + telas visitadas)
    fnf-boot.log        log do lado Android (aparelho, versão, ABI, crashes)
    fnf-erro.txt        erro dentro do motor gráfico (com a pilha)
    ultimo-erro.txt     erro do Android (se a "tela de erro" já foi mostrada)
```

**3. Dentro do jogo:** `Options → Mobile → Ver log do jogo` mostra as últimas
mensagens na tela (print).

---

## 2. Controles

| Ação | Como fazer |
|---|---|
| Tocar as notas | Toque na **seta** (a área de toque é maior que o desenho da seta) |
| Segurar sustain | Deixe o dedo apoiado na seta |
| Sequência rápida | Vários dedos ao mesmo tempo (multi-touch) ou arrastando o dedo entre as setas |
| Pausar | Botão de pausa no canto superior direito (pode ser desligado nas opções) |
| Voltar (menus) | Botão **voltar** do Android, ou deslizar o dedo |
| Navegar nos menus | Toque = ENTER/aceitar · deslizar pra cima/baixo = setas · deslizar pros lados = mudar valor |
| Botão "voltar" do Android na música | Abre a pausa (com a pausa aberta, fecha a pausa) |

Nada foi remapeado por baixo dos panos: o toque entra no jogo pelo **mesmo
caminho do teclado** (eventos de teclado sintéticos). Por isso notas, sustains,
ghost tapping, animação das setas, ratings, botplay e modcharts continuam
funcionando exatamente como no Psych.

---

## 3. Opções exclusivas do celular

**Menu principal → Options → Mobile**

- **Controles de toque** — liga/desliga as hitboxes (dá para jogar com gamepad/teclado).
- **Área de toque das setas** — 0 a 90 px a mais de área por seta.
- **Arrastar entre setas** — permite deslizar o dedo de uma seta para outra.
- **Mostrar áreas de toque** — desenha as hitboxes para calibrar.
- **Botão de pausa na tela** — liga/desliga.
- **Limite de FPS** — 30 a 120 (30 economiza muita bateria).
- **Modo aparelho fraco** — desliga antialiasing, shaders, splashes e zooms.
- **Fundo simplificado** — tira dançarinos/luzes de fundo das Semanas 1-3.
- **Pausar ao sair do app** — pausa a música quando você troca de aplicativo.
- **Vibração** — feedback curto ao tocar as setas.
- **Ver log do jogo** — abre um painel com as últimas mensagens do app (útil
  para descobrir a causa de qualquer problema; dá para tirar print e mandar).

Na primeira execução o jogo lê a **RAM do aparelho**: até 2,9 GB ele liga o modo
aparelho fraco e 30 FPS; até 4,2 GB ele só simplifica o fundo. Dá para mudar tudo
depois, nada é forçado.

---

## 4. Mods

Os mods ficam no **armazenamento do aparelho** (o APK é somente leitura, então a
pasta `mods/` do PC não existe aqui). O jogo escolhe a primeira pasta que
funcionar, nesta ordem:

1. `/sdcard/FNF-Mobile/mods` ← **preferida**, dá para copiar mods por qualquer
   gerenciador de arquivos ou pelo PC (USB);
2. `/sdcard/Android/data/com.fnfmobile.game/files/mods` (sempre funciona, sem
   pedir permissão nenhuma);
3. pasta interna do app (só o jogo enxerga).

Na primeira execução o jogo cria a pasta, testa escrita de verdade e deixa um
`LEIA-ME.txt` explicando. O caminho exato aparece em **Options → Mobile**
(primeira linha do menu).

Formato: **o mesmo do Psych Engine 0.6.3**, uma pasta por mod:

```
mods/
  MeuMod/
    pack.json
    data/<musica>/<musica>.json     (charts / eventos)
    images/...                      (PNG + XML sparrow/packer)
    characters/...  stages/...  weeks/...  fonts/...
    songs/<musica>/Inst.ogg + Voices.ogg
```

Mods globais (que rodam junto com as músicas originais) usam `modsList.txt` na
mesma pasta:

```
MeuMod|1
OutroMod|0
```

**Suporte a Lua:** ligado também no Android. O projeto usa um fork do
`linc_luajit` com LuaJIT pré-compilado para `arm64-v8a` e `armeabi-v7a`
(`libluajit-64.a` / `libluajit-v7.a`), então os mods com `scripts/*.lua`
executam no celular igual ao Psych de PC — incluindo as callbacks como
`onCreate`, `onUpdate`, `onBeatHit`, `onStepHit`, `onKeyPress`, `onNoteHit`,
`onNoteMiss`, `setProperty`, `getProperty`, `makeLuaSprite`, `playSound`
etc. Continua valendo a regra do Psych: o script tem acesso ao que a API Lua
dele expõe (não é sandbox de segurança, é compatibilidade).

---

## 5. O que está incluído

- **Semanas 1, 2 e 3 completas** (Bopeebo → Blammed), incluindo o tutorial,
  personagens, cenários, eventos, dificuldades e músicas de menu.
- Todo o resto do Psych Engine 0.6.3: menu principal, freeplay, story mode,
  opções, notas especiais, hold notes, ratings, achievements, practice, botplay,
  editor de chart (dentro do jogo), etc.
- **Mods** (assets, charts, personagens, cenários, semanas, áudio **e scripts
  Lua**) via pasta no aparelho.
- Não incluído (fora do escopo): Semanas 4-7, vídeos (`VIDEOS_ALLOWED` —
  depende do hxCodec, que não compila para Android), Discord RPC e updater.

---

## 6. Otimizações para aparelhos fracos

- Assets carregados **sob demanda** no celular (`NO_PRELOAD_ALL`), em vez de
  despejar tudo na RAM no boot.
- Limite de FPS de verdade (`FlxG.update/drawFramerate`).
- Modo aparelho fraco desliga antialiasing, shaders, note splashes, zooms de
  câmera e efeitos de flash.
- Cenários das Semanas 1-3 sem os dançarinos/luzes de fundo.
- Liberação de texturas não usadas (`clearUnusedMemory`/`clearStoredMemory` + GC)
  ao trocar de tela.
- `largeHeap` e `extractNativeLibs` no AndroidManifest.
- Teclado virtual: zero código novo no caminho das notas, então nada de camada
  extra por nota.

---

## 7. Como este APK é construído

Tudo é construído no GitHub Actions (`.github/workflows/android.yml`), em um
runner Linux:

1. **Haxe 4.2.5** + neko + bibliotecas fixadas: `hxcpp 4.3.2`, `lime 8.0.2`,
   `openfl 9.3.2`, `flixel 4.11.0`, `flixel-addons 2.11.0`, `flixel-ui 2.5.0`.
2. **Android SDK 28/30 + build-tools 30.0.3 + NDK r21e**.
3. Assets do FNF vêm do clone do Psych Engine 0.6.3 (o repositório **não**
   guarda os assets do jogo) e são filtrados para Semanas 1-3.
4. `lime build android` (Gradle 6.7.1 + AGP 4.1.3) gera o APK, que é alinhado e
   assinado (`zipalign` + `apksigner`) e publicado na Release.

Scripts: `tools/setup_haxe.sh`, `tools/ci_android_sdk.sh`, `tools/fetch_assets.sh`,
`tools/patch_lime_android.sh`, `tools/ci_build.sh`, `tools/ci_report.sh`.
Código mobile: `source/mobile/Mobile*.hx` + integrações mínimas em
`PlayState.hx`, `Main.hx`, `Paths.hx`, `ClientPrefs.hx` e `options/OptionsState.hx`.

---

## 8. Créditos e licença

- **Friday Night Funkin'** — Funkin' Crew (ninjamuffin99, PhantomArcade, evilsk8r, Kawai Sprite).
- **Psych Engine 0.6.3** — ShadowMario e contribuidores (Apache-2.0, ver `LICENSE-PSYCH-ENGINE.txt`).
- **HaxeFlixel / OpenFL / Lime / hxcpp** — comunidades Haxe.
- Camada de compatibilidade Android, controles por hitbox e otimizações: feitas
  para este projeto (uso pessoal).

Os assets do FNF continuam sendo dos seus donos; este repositório guarda apenas
código e baixa os assets na hora do build.
