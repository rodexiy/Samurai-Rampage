# Samurai Rampage Index Studio

Site exclusivamente local para editar as tabelas Luau encontradas em:

- `src/ReplicatedStorage/Index`
- `src/ServerStorage/Index`
- `src/ServerStorage/Services/DialogService/Dialogs`

Ele roda somente em `127.0.0.1`, não envia dados para a internet e não altera nenhum código de runtime do jogo. Um arquivo do jogo só é modificado quando você abre esse arquivo, muda os campos e pressiona **Salvar no código**.

## Iniciar

No PowerShell, a partir da raiz do projeto:

```powershell
.\tools\index-studio\Start-IndexStudio.ps1
```

Ou:

```powershell
cd tools\index-studio
npm start
```

Depois abra `http://127.0.0.1:4317`.

## Recursos

- Navegação e busca por todos os arquivos dos diretórios `Index`.
- Formulários recursivos para textos, números, booleanos, tabelas, listas e expressões Luau.
- Editor visual em blocos para grupos, nodes, respostas, validações e callbacks de NPCs.
- Presets de campos, raridades coloridas e editor visual que salva `Color3.fromRGB(...)`.
- Funções e expressões como `Color3.fromRGB(...)`, `Vector3.new(...)` e callbacks são preservadas como código Luau.
- Visualização especial para drops ponderados, árvores de skill, cores e resumos de dados.
- Criação e remoção de campos e itens de listas.
- Preview do código antes de salvar.
- Backup automático em `tools/index-studio/.backups`.
- Gravação atômica e proteção contra sobrescrever mudanças recentes feitas no VS Code.
- O servidor rejeita caminhos fora dos diretórios de dados autorizados.

## Observação sobre formatação

Ao salvar, a tabela retornada é formatada de maneira padronizada com tabs. O código antes e depois da tabela — incluindo `require`, funções auxiliares e outras lógicas — permanece intacto. Blocos de função usados como valores também são mantidos como expressões Luau.
