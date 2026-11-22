# Lindoso 3D

Jogo 3D estilo Ludo feito em **Godot 4.x** com **GDScript**.

## Regras
- Tabuleiro 3D em cruz com 52 casas, 4 cores (Vermelho, Verde, Amarelo, Azul), 4 peões cada.
- Modo **1 jogador vs 3 bots** ou **2 a 4 jogadores locais** (celular passado entre os jogadores).
- É preciso tirar **6** para sair da base. Tirar **6** joga de novo.
- Cair numa casa com peão inimigo manda ele de volta para a base (casas douradas são seguras).
- Para entrar no centro é preciso o número exato. Vence quem levar os 4 peões ao centro.

## Estrutura
- `scenes/main.tscn` – cena principal (só o `game_manager.gd`; o resto é montado por código)
- `scripts/game_manager.gd` – regras, turnos, vitória, tabuleiro e UI
- `scripts/player.gd` – peões e movimento
- `scripts/dice.gd` – dado 3D animado
- `scripts/bot.gd` – IA dos bots
- `assets/`, `models/` – reservadas para modelos .glb e texturas futuras

## Rodar
Abra a pasta no Godot 4.3+ e aperte F5. Para Android: Projeto > Exportar > Android
(configure o JDK e o Android SDK em Editor > Configurações do Editor > Exportar).
Tela vertical (720x1280), câmera a 45 graus, botões grandes para toque.
