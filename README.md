# Samurai-Rampage

## Progressão por atributo

Os seis atributos sobem individualmente de 0 a 10. XP, níveis e pontos são calculados e salvos no servidor por `StatService`; a UI recebe as atualizações por Knit. Não existe mais nível geral.

O balanceamento fica em [`StatProgression.luau`](src/ReplicatedStorage/StatProgression.luau):

```luau
MaxLevel = 10,
PointsPerLevel = 1, -- Pontos compartilhados entre todas as skill trees.
XPRequired = { 250, 450, 800, 1250, 1850, 2550, 3450, 4600, 6000, 7600 },
```

`XPRequired[1]` é o custo de 0 → 1, `[2]` de 1 → 2, etc. São custos por nível, não XP acumulado. O XP excedente passa para o próximo nível; no máximo, o XP fica em zero e a UI mostra `MAX`. Para aumentar o limite em updates, aumente `MaxLevel` e acrescente os custos correspondentes.

Use `StatXPRequired.Strength = { ... }` para uma curva exclusiva de um atributo. `Training` controla o XP das ações, `RewardWeights` divide recompensas entre atributos, `Rewards` controla a escala e o limite por recompensa, e `Bonuses` define os ganhos por nível.

A curva soma **28.800 XP por atributo**, com uma meta de aproximadamente **8 horas de treino focado do 0 ao 10** nos seguintes ritmos de referência:

| Atributo | Ritmo de referência | XP ganho |
| --- | --- | --- |
| Strength | 30 acertos por minuto | 2 por acerto |
| Resistance | 15 bloqueios por minuto | 4 por bloqueio |
| Vitality | 150 de dano recebido por minuto, incluindo recuperação | 0,4 por ponto de dano |
| Agility | Corrida contínua a partir de 24 studs/s, com os bônus de velocidade dos níveis | 0,037 por stud |
| Dexterity | 7,5 parries por minuto | 8 por parry |
| Spirit | Meditação contínua válida | 1 por segundo |

São estimativas de balanceamento, não um bloqueio por tempo: jogadores mais eficientes podem subir mais rápido. Pausas aumentam o tempo; recompensas, rolagens, esquivas e habilidades podem reduzi-lo. Atributos treinados juntos avançam simultaneamente, portanto as oito horas de cada um não precisam ser somadas.

Recompensas antigas de missões, mobs e duelos passam por `Rewards.Multiplier = 0.1` e, após a divisão pelos pesos, concedem no máximo `Rewards.MaxXPPerStat = 120` para cada atributo por recompensa. Esse limite vale por recompensa, sem limite por hora. Uma entrega de caixa agora rende 50 XP para Agility e 50 para Resistance; um duelo de dificuldade 70 rende 120 para Strength e 120 para Dexterity. Dinheiro e itens não são afetados.

| Atributo | Como treinar |
| --- | --- |
| Strength | Acertar ataques corpo a corpo, recompensas de combate e coleta |
| Resistance | Bloquear ataques, recompensas de coleta e entregas |
| Vitality | Receber dano real em combate, tarefas de cura |
| Agility | Correr com deslocamento, rolar, esquivar, explorar e entregar |
| Dexterity | Defletir ataques, recompensas de combate |
| Spirit | Meditar perto de rugs (ou com MeditateAnywhere), usar habilidades de artefato |

Sparring com outros jogadores também concede XP. Correr parado não concede XP de corrida. Meditação e seus requisitos são validados no servidor.

Para novas atividades, chame **somente no servidor**:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local StatService = Knit.GetService("StatService")

StatService:GiveXP(Player, "Strength", 25)
StatService:GiveRewardXP(Player, 100, "Combat")
```

Cada nível concede `PointsPerLevel` ao saldo compartilhado das skill trees. Resets recalculam esse saldo pelos níveis dos atributos.

Os saves antigos são migrados uma única vez: o XP total do sistema antigo é dividido igualmente entre os seis atributos. Os valores originais ficam em `LegacyProgression`. Skills já desbloqueadas e pontos disponíveis são preservados com créditos de migração; não se apagam inventário, missões ou equipamentos. Os novos níveis ficam em `Stats[Nome] = { Level, XP }`.

O HUD antigo de nível foi substituído por `Hud.MainMenuShortcut`, mantendo o botão de abrir o inventário. Requisitos baseados no nível geral foram removidos dos duelos e do PvP. A dificuldade numérica dos NPCs de duelo permanece separada da progressão do jogador.

## Testes de progressão

Com Python e a CLI oficial do Luau instalados:

```powershell
python tests/run_stat_progression.py "caminho/para/luau.exe"
```

Os testes executam os módulos reais com serviços e instâncias simulados, sem acessar saves. Cobrem curvas de XP, limite, pontos compartilhados, migração, treinamento e bônus de combate. A integração visual e de rede deve ser conferida também no Play do Studio.
