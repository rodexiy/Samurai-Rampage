import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const chromeCandidates = [
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
];
const chrome = chromeCandidates.find(existsSync);
if (!chrome) throw new Error("Google Chrome não foi encontrado para o smoke test.");

const debugPort = 9431;
const profile = path.join(os.tmpdir(), `samurai-index-studio-smoke-${process.pid}`);
const browser = spawn(chrome, [
  "--headless=new",
  "--disable-gpu",
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${profile}`,
  "--window-size=1440,900",
  "about:blank",
], { stdio: "ignore" });

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitForDebugging() {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${debugPort}/json/version`);
      if (response.ok) return;
    } catch {}
    await sleep(100);
  }
  throw new Error("Chrome não abriu a porta de depuração.");
}

class CdpClient {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.nextId = 1;
    this.pending = new Map();
  }

  async connect() {
    await new Promise((resolve, reject) => {
      this.socket.addEventListener("open", resolve, { once: true });
      this.socket.addEventListener("error", reject, { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (!message.id) return;
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(message.error.message));
      else pending.resolve(message.result);
    });
  }

  call(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const result = await this.call("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || "Falha na avaliação da página.");
    return result.result.value;
  }

  close() { this.socket.close(); }
}

async function openPage(url) {
  const response = await fetch(`http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(url)}`, { method: "PUT" });
  const target = await response.json();
  const client = new CdpClient(target.webSocketDebuggerUrl);
  await client.connect();
  await client.call("Runtime.enable");
  await sleep(1400);
  return client;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

try {
  await waitForDebugging();

  const dialogs = await openPage("http://127.0.0.1:4317/?file=dialogs%2FGodot.luau&tab=dialog");
  const dialogState = await dialogs.evaluate(`(() => ({
    groups: document.querySelectorAll('.dialog-group-tab').length,
    nodes: document.querySelectorAll('.dialog-node-card').length,
    answers: document.querySelectorAll('.answer-block').length,
    flowRows: document.querySelectorAll('.dialog-flow-row').length,
    flowLines: document.querySelectorAll('.flow-stroke').length,
    callbackChips: document.querySelectorAll('.flow-hook-chips .callback').length,
    canScroll: document.querySelector('.workspace').scrollHeight > document.querySelector('.workspace').clientHeight,
    horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth + 2
  }))()`);
  assert(dialogState.groups === 4, `Esperados 4 grupos em Godot, recebidos ${dialogState.groups}.`);
  assert(dialogState.nodes === 3, `Esperados 3 nodes no primeiro grupo, recebidos ${dialogState.nodes}.`);
  assert(dialogState.answers >= 3, "As respostas do diálogo não foram renderizadas.");
  assert(dialogState.flowRows === 3, `Esperadas 3 rotas visuais, recebidas ${dialogState.flowRows}.`);
  assert(dialogState.flowLines === dialogState.flowRows, "Cada rota deveria possuir uma linha visível.");
  assert(dialogState.callbackChips >= 2, "Callbacks deveriam estar destacados no mapa de conexões.");
  assert(dialogState.canScroll, "A página de diálogos deveria permitir rolagem vertical.");
  assert(!dialogState.horizontalOverflow, "A página de diálogos criou overflow horizontal global.");
  const dialogMutation = await dialogs.evaluate(`(async () => {
    [...document.querySelectorAll('button')].find(button => button.textContent.includes('Grupo de diálogo')).click();
    await new Promise(resolve => setTimeout(resolve, 120));
    return {
      groups: document.querySelectorAll('.dialog-group-tab').length,
      nodes: document.querySelectorAll('.dialog-node-card').length,
      saveEnabled: !document.querySelector('#save-button').disabled
    };
  })()`);
  assert(dialogMutation.groups === 5, "Criar grupo de diálogo não adicionou um bloco.");
  assert(dialogMutation.nodes === 1, "Um grupo novo deveria começar com um node.");
  assert(dialogMutation.saveEnabled, "Criar grupo deveria habilitar o salvamento.");
  dialogs.close();

  const treeDashboard = await openPage("http://127.0.0.1:4317/");
  const categorySearchState = await treeDashboard.evaluate(`(async () => {
    const input = document.querySelector('#search');
    input.value = 'Items';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await new Promise(resolve => setTimeout(resolve, 80));
    return {
      openFolders: [...document.querySelectorAll('.tree-directory[open]')].map(folder => folder.dataset.folderPath),
      visibleFiles: [...document.querySelectorAll('.file-button')].filter(button => button.offsetParent !== null).length
    };
  })()`);
  assert(categorySearchState.openFolders.length === 1, `Buscar Items não deveria expandir todas as subpastas: ${categorySearchState.openFolders.join(', ')}.`);
  assert(categorySearchState.openFolders[0] === "replicated/Items", "A busca por Items deveria abrir somente a pasta Items.");
  treeDashboard.close();

  const nested = await openPage("http://127.0.0.1:4317/?file=replicated%2FSkillTrees%2FDefault%2FKendo.luau");
  const nestedState = await nested.evaluate(`(() => ({
    nestedTables: document.querySelectorAll('.nested-table-details').length,
    collapsedTables: [...document.querySelectorAll('.nested-table-details')].filter(node => !node.open).length,
    canScroll: document.querySelector('.workspace').scrollHeight > document.querySelector('.workspace').clientHeight,
    horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth + 2,
    colorEditors: document.querySelectorAll('.color3-editor').length
  }))()`);
  assert(nestedState.nestedTables >= 4, "Tabelas aninhadas da árvore Kendo não foram renderizadas.");
  assert(nestedState.collapsedTables >= 1, "Tabelas profundas deveriam iniciar recolhidas.");
  assert(nestedState.canScroll, "A árvore Kendo deveria permitir rolagem vertical.");
  assert(!nestedState.horizontalOverflow, "A árvore Kendo criou overflow horizontal global.");
  assert(nestedState.colorEditors === 1, "O campo Color não recebeu o editor Color3.");
  const colorMutation = await nested.evaluate(`(async () => {
    const input = document.querySelector('.native-color-input');
    input.value = '#123456';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await new Promise(resolve => setTimeout(resolve, 160));
    return {
      code: document.querySelector('.color3-code').textContent,
      previewHasColor3: document.querySelector('#code-preview').textContent.includes('Color3.fromRGB(18, 52, 86)'),
      saveEnabled: !document.querySelector('#save-button').disabled
    };
  })()`);
  assert(colorMutation.code === "Color3.fromRGB(18, 52, 86)", "O seletor de cor não converteu para Color3.fromRGB.");
  assert(colorMutation.previewHasColor3, "A cor escolhida não chegou ao código gerado.");
  assert(colorMutation.saveEnabled, "Alterar a cor deveria habilitar o salvamento.");
  nested.close();

  const rarity = await openPage("http://127.0.0.1:4317/?file=replicated%2FItems%2FEquipable%2FLegs%2FSamuraiLegplate.luau");
  const rarityState = await rarity.evaluate(`(() => ({
    rarityEditors: document.querySelectorAll('.rarity-editor').length,
    presets: document.querySelectorAll('.preset-chip').length,
    openFolders: [...document.querySelectorAll('.tree-directory[open]')].map(folder => folder.dataset.folderPath),
    saveDisabled: document.querySelector('#save-button').disabled
  }))()`);
  assert(rarityState.rarityEditors === 1, "O campo Rarity não recebeu o seletor colorido.");
  assert(rarityState.presets >= 4, "Os campos prontos de item não foram exibidos.");
  assert(rarityState.openFolders.length === 3, `Abrir um item deveria expandir só seus 3 ancestrais, não ${rarityState.openFolders.length} pastas.`);
  assert(rarityState.openFolders.every(folder => "replicated/Items/Equipable/Legs/SamuraiLegplate.luau".startsWith(folder)), "Uma pasta fora do caminho do item foi expandida.");
  assert(rarityState.saveDisabled, "Salvar deve iniciar desabilitado sem mudanças.");
  const rarityMutation = await rarity.evaluate(`(async () => {
    const select = document.querySelector('.rarity-select');
    select.value = 'Legendary';
    select.dispatchEvent(new Event('change', { bubbles: true }));
    await new Promise(resolve => setTimeout(resolve, 160));
    return {
      value: select.value,
      previewUpdated: document.querySelector('#code-preview').textContent.includes('Rarity = "Legendary"'),
      saveEnabled: !document.querySelector('#save-button').disabled
    };
  })()`);
  assert(rarityMutation.value === "Legendary", "O seletor de raridade não aceitou Legendary.");
  assert(rarityMutation.previewUpdated, "A raridade não chegou ao código gerado.");
  assert(rarityMutation.saveEnabled, "Alterar raridade deveria habilitar o salvamento.");
  rarity.close();

  console.log("Smoke test visual aprovado:");
  console.log(JSON.stringify({ dialogState, dialogMutation, categorySearchState, nestedState, colorMutation, rarityState, rarityMutation }, null, 2));
} finally {
  browser.kill();
}
