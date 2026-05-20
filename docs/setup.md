# 🚀 Configuração do Ambiente de Desenvolvimento

Este guia explica como clonar o repositório e preparar o ambiente para trabalhar com o projeto **SHURA**, garantindo que a estrutura de validação de código esteja ativa.

---

## 📥 Clonando o Repositório

1. Abra o terminal
2. Navegue até a pasta onde deseja salvar o projeto
3. Execute:

```bash
git clone https://github.com/rodexiy/SHURA.git
cd SHURA
```
## 🧩 Instalando as Dependências
O projeto utiliza ferramentas baseadas em **Node.js** para validação de commits.

### 1. Instale o [Node.js](https://nodejs.org/) (se ainda não tiver)

Após Instalar, verifique:

```
node -v
npm -v
```

### 2. Instale as dependências do projeto
Dentro da pasta do projeto:
```
npm install
```

### 🛡️ Ativando os Hooks Locais (Husky)
Depois que o npm install for concluído, o Husky será ativado automaticamente através do comando:

```
npm run setup:husky
```
Isso garante que o hook de commit (`.husky/commit-msg`) funcione, validando suas mensagens com o padrão Conventional Commits.

### ✅ Teste de Commit
Tente fazer um commit com mensagem incorreta:
```
git commit -m "update"
```

Você verá um erro como:
```
⛔ Commit message does not match Conventional Commits format
```

Agora teste com uma mensagem correta:
```
git commit -m "feat(ui): adiciona botão de pausa no menu"
```

### 🔁 Atualizando Dependências (se necessário)
Caso novas dependências sejam adicionadas futuramente, basta rodar novamente:
`npm install`

### 📌 Observação
A pasta `node_modules/` não é versionada. Tudo que você precisa está no `package.json`, então sempre use `npm install` após clonar o projeto.