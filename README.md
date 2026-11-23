# Samurai-Rampage

## Progressão por atributo

Os seis atributos sobem individualmente de 0 a 10. XP, níveis e pontos são calculados e salvos no servidor por `StatService`; a UI recebe as atualizações por Knit. Não existe mais nível geral.

O balanceamento fica em [`StatProgression.luau`](src/ReplicatedStorage/StatProgression.luau):

```luau
MaxLevel = 10,
PointsPerLevel = 1, -- Pontos exclusivos da árvore do atributo treinado.
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

Strength, Resistance, Vitality, Agility e Dexterity têm skill trees próprias. Cada nível concede `PointsPerLevel` somente à árvore correspondente, até 10 pontos por atributo na configuração atual. Spirit continua fora dessas árvores e não concede pontos nelas. Os saldos são derivados dos níveis menos os talentos comprados e replicados em `StrengthSkillPoints`, `ResistanceSkillPoints`, `VitalitySkillPoints`, `AgilitySkillPoints` e `DexteritySkillPoints`.

Os saves com nível geral ainda passam pela migração de XP para os seis atributos, com os originais em `LegacyProgression`. A migração das árvores arquiva os nós, o saldo compartilhado e os créditos antigos em `LegacySkillTree`, remove os talentos antigos e libera os pontos derivados dos níveis para redistribuição. Créditos antigos não são atribuídos arbitrariamente a uma árvore. Inventário, missões, equipamentos e habilidades permanentes são preservados.

## Skill trees de atributos

As definições e os valores dos talentos ficam em [`SkillTreeConfig.luau`](src/ReplicatedStorage/SkillTreeConfig.luau). Cada compra custa 2 pontos do atributo, sem requisito adicional de nível. As cinco árvores têm estruturas próprias: Força forma um gancho com bifurcação, Destreza separa finta e resposta ao parry, Agilidade segue uma escada, Resistência divide dois ramos que convergem, e Vitalidade abre três ramos de recuperação. Uma progressão completa custa 10 pontos. Preferências exclusivas existem nas quatro primeiras árvores; Vitalidade permite adquirir seus cinco talentos.

Nenhum talento depende de consumíveis, inventário ou equipamento específico. Vitalidade oferece recuperação em repouso, resistência a queimaduras, cura por execução, Second Wind e Recovery Reserve. Os dois últimos exigem um intervalo sem dano após um golpe em combate e juntos recuperam no máximo 15% da vida máxima por golpe. Talentos retirados são arquivados em `RetiredSkillNodes`, com seus pontos devolvidos; compras ainda válidas são preservadas.

`SkillTreeProgression` calcula os saldos e valida pontos, nós anteriores, duplicatas e exclusividade. `SkillTreeService` mantém os desbloqueios no servidor; `TalentService` aplica efeitos de combate. A interface mostra o saldo do atributo selecionado e explica por que um talento está bloqueado.

Os aumentos repetidos de dano, vida e stamina foram retirados das árvores. Up Slash, Barrage e Floating Passage pertencem ao conjunto inicial da espada, recebido gratuitamente e preservado por resets. A proficiência, os treinadores e os caminhos adicionais de combate ficam separados desta implementação de skill trees.

A finta usa **X** durante a preparação de um ataque básico corpo a corpo, após comprar o talento. A versão mobile tem botão próprio. Bandagens têm aplicação interrompível de 2 segundos e curam 15 de vida, independentemente das árvores. Os rótulos `FightingStyle` e `SwordStyle` no menu `Meditate` são atualizados por `CombatStyleController`.

`SwordStyle` é o caminho da espada e começa em `Beginner`. Espada não é um `FightingStyle`. O campo `FightingStyle` representa um estilo aprendido com treinador, como punhos, rifle ou arco, e começa vazio. As duas seleções coexistem; equipar uma arma não substitui o estilo aprendido exibido no menu.

`ResetSpecificSkillTree(Player, "Strength")` devolve somente os pontos de Força; `ResetSkillTree(Player)` devolve os pontos das cinco árvores. Nenhum dos dois remove as técnicas iniciais da espada ou as habilidades permanentes de `OtherSkills`.

O HUD antigo de nível foi substituído por `Hud.MainMenuShortcut`, mantendo o botão de abrir o inventário. Requisitos baseados no nível geral foram removidos dos duelos e do PvP. A dificuldade numérica dos NPCs de duelo permanece separada da progressão do jogador.

## Testes de progressão

Com Python e a CLI oficial do Luau instalados:

```powershell
python tests/run_stat_progression.py "caminho/para/luau.exe"
python tests/run_talents.py "caminho/para/luau.exe"
python tests/run_block_lifecycle.py "caminho/para/luau.exe"
```

Os testes executam os módulos reais com serviços e instâncias simulados, sem acessar saves. Cobrem curvas de XP, limites, pontos separados, escolhas exclusivas, migração, resets, treinamento, fintas, bandagens, recuperação natural e por execução, convergência de ramos e bloqueio com replicação atrasada. A integração visual e de rede deve ser conferida também no Play do Studio.
