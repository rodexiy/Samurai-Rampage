const state = {
  token: "",
  tree: [],
  files: [],
  current: null,
  ast: null,
  originalAst: null,
  dirty: false,
  activeTab: "form",
  search: "",
  dialogGroup: null,
  expandedFolders: new Set(),
};

const elements = {
  tree: document.querySelector("#file-tree"),
  search: document.querySelector("#search"),
  dashboard: document.querySelector("#dashboard"),
  editor: document.querySelector("#editor-screen"),
  stats: document.querySelector("#stats-grid"),
  categories: document.querySelector("#category-grid"),
  count: document.querySelector("#file-count"),
  repoRoot: document.querySelector("#repo-root"),
  filePath: document.querySelector("#file-path"),
  fileTitle: document.querySelector("#file-title"),
  fileMeta: document.querySelector("#file-meta"),
  fileDetails: document.querySelector("#file-details"),
  analysis: document.querySelector("#analysis-panel"),
  form: document.querySelector("#form-root"),
  visual: document.querySelector("#visual-root"),
  dialog: document.querySelector("#dialog-root"),
  dialogTab: document.querySelector("#dialog-tab-button"),
  code: document.querySelector("#code-preview"),
  save: document.querySelector("#save-button"),
  reset: document.querySelector("#reset-button"),
  dirty: document.querySelector("#dirty-indicator"),
  toast: document.querySelector("#toast-region"),
  confirmDialog: document.querySelector("#confirm-dialog"),
};

const RARITIES = [
  { value: "Common", label: "Comum", color: "#a8b0ba" },
  { value: "Uncommon", label: "Incomum", color: "#59cb78" },
  { value: "Rare", label: "Raro", color: "#5d9dff" },
  { value: "Epic", label: "Épico", color: "#b66cff" },
  { value: "Legendary", label: "Lendário", color: "#ffb547" },
  { value: "Mythic", label: "Mítico", color: "#ff6177" },
];

const FIELD_PRESETS = [
  { key: "DisplayName", label: "Nome visível", node: () => ({ type: "string", value: "" }), scopes: ["Items"] },
  { key: "Description", label: "Descrição", node: () => ({ type: "string", value: "" }), scopes: ["Items", "SkillTrees"] },
  { key: "Rarity", label: "Raridade", node: () => ({ type: "string", value: "Common" }), scopes: ["Items"] },
  { key: "MaxStack", label: "Stack máximo", node: () => ({ type: "number", value: 1 }), scopes: ["Items"] },
  { key: "MetalArmor", label: "Armadura metálica", node: () => ({ type: "boolean", value: false }), scopes: ["Items"] },
  { key: "HideHair", label: "Esconder cabelo", node: () => ({ type: "boolean", value: false }), scopes: ["Items"] },
  { key: "Color", label: "Cor Color3", node: () => ({ type: "raw", code: "Color3.fromRGB(255, 255, 255)" }), scopes: ["SkillTrees", "Races", "Stances"] },
  { key: "Weight", label: "Peso / chance", node: () => ({ type: "number", value: 0 }), scopes: ["Mobs", "Items"] },
  { key: "Priority", label: "Prioridade", node: () => ({ type: "number", value: 0 }), scopes: ["Quests"] },
];

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function create(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

function flattenTree(roots) {
  const files = [];
  function visit(rootId, nodes, folders = []) {
    for (const node of nodes) {
      if (node.type === "directory") visit(rootId, node.children, [...folders, node.name]);
      else files.push({ ...node, rootId, folders, apiPath: `${rootId}/${node.path}` });
    }
  }
  roots.forEach((root) => visit(root.id, root.children));
  return files;
}

function countNodes(nodes) {
  return nodes.reduce((total, node) => total + (node.type === "file" ? 1 : countNodes(node.children)), 0);
}

function categoryMap() {
  const categories = new Map();
  for (const file of state.files) {
    const category = file.folders[0] || "Raiz";
    const key = `${file.rootId}:${category}`;
    if (!categories.has(key)) categories.set(key, { rootId: file.rootId, name: category, count: 0 });
    categories.get(key).count += 1;
  }
  return [...categories.values()].sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
}

function renderDashboard() {
  const categories = categoryMap();
  const replicated = state.files.filter((file) => file.rootId === "replicated").length;
  const server = state.files.filter((file) => file.rootId === "server").length;
  const dialogs = state.files.filter((file) => file.rootId === "dialogs").length;
  const itemCount = state.files.filter((file) => file.folders[0] === "Items").length;
  const cards = [
    ["{}", state.files.length, "Arquivos de dados"],
    ["刀", itemCount, "Itens e skills"],
    ["R", replicated, "Dados replicados"],
    ["S", server + dialogs, "Servidor e diálogos"],
  ];
  elements.stats.replaceChildren(...cards.map(([icon, value, label]) => {
    const card = create("article", "stat-card");
    card.append(create("span", "stat-icon", icon), create("strong", "", String(value)), create("span", "", label));
    return card;
  }));
  elements.count.textContent = `${state.files.length} arquivos`;
  elements.categories.replaceChildren(...categories.map((category) => {
    const button = create("button", "category-card");
    button.type = "button";
    const copy = create("div");
    copy.append(create("strong", "", category.name), create("span", "", category.rootId === "server" ? "ServerStorage" : "ReplicatedStorage"));
    button.append(copy, create("b", "", String(category.count)));
    button.addEventListener("click", () => {
      elements.search.value = category.name;
      state.search = category.name.toLowerCase();
      renderFileTree();
      elements.search.focus();
    });
    return button;
  }));
}

function filteredNodes(nodes, query) {
  if (!query) return nodes;
  const result = [];
  for (const node of nodes) {
    if (node.type === "file") {
      if (node.name.toLowerCase().includes(query)) result.push(node);
    } else {
      const children = filteredNodes(node.children, query);
      const directoryMatches = node.name.toLowerCase().includes(query);
      if (children.length || directoryMatches) {
        result.push({
          ...node,
          children: children.length ? children : node.children,
          searchOpen: children.length > 0 || directoryMatches,
        });
      }
    }
  }
  return result;
}

function renderTreeNodes(root, nodes, parent, depth = 0, folders = []) {
  for (const node of nodes) {
    if (node.type === "directory") {
      const folderPath = [...folders, node.name];
      const folderKey = `${root.id}/${folderPath.join("/")}`;
      const containsCurrent = state.current?.path === folderKey || state.current?.path.startsWith(`${folderKey}/`);
      const details = create("details", "tree-directory");
      details.open = containsCurrent
        || state.expandedFolders.has(folderKey)
        || !!node.searchOpen
        || (!state.current && !state.search && depth < 1);
      details.dataset.folderPath = folderKey;
      const summary = create("summary", "", node.name);
      summary.addEventListener("click", () => {
        if (details.open) state.expandedFolders.delete(folderKey);
        else state.expandedFolders.add(folderKey);
      });
      details.append(summary);
      const children = create("div", "tree-children");
      renderTreeNodes(root, node.children, children, depth + 1, folderPath);
      details.append(children);
      parent.append(details);
    } else {
      const apiPath = `${root.id}/${node.path}`;
      const button = create("button", `file-button${state.current?.path === apiPath ? " active" : ""}`);
      button.type = "button";
      button.title = node.path;
      button.append(create("span", "", node.name));
      button.addEventListener("click", () => openFile(apiPath));
      parent.append(button);
    }
  }
}

function renderFileTree() {
  elements.tree.replaceChildren();
  let visible = 0;
  for (const root of state.tree) {
    const nodes = filteredNodes(root.children, state.search);
    visible += countNodes(nodes);
    if (!nodes.length) continue;
    const container = create("section", "tree-root");
    const title = create("div", "tree-root-title");
    title.append(create("span", "", root.label), create("span", "", String(countNodes(nodes))));
    container.append(title);
    renderTreeNodes(root, nodes, container);
    elements.tree.append(container);
  }
  if (!visible) elements.tree.append(create("div", "tree-empty", "Nenhum arquivo encontrado."));
}

async function api(url, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (options.body) headers["Content-Type"] = "application/json";
  if (state.token && options.method && options.method !== "GET") headers["X-Index-Studio-Token"] = state.token;
  const response = await fetch(url, { ...options, headers });
  const payload = await response.json().catch(() => ({ error: "Resposta inválida do servidor." }));
  if (!response.ok) {
    const error = new Error(payload.error || `Erro HTTP ${response.status}`);
    error.details = payload.details;
    error.status = response.status;
    throw error;
  }
  return payload;
}

function toast(title, message = "", type = "success") {
  const node = create("div", `toast${type === "error" ? " error" : ""}`);
  node.append(create("strong", "", title));
  if (message) node.append(document.createTextNode(message));
  elements.toast.append(node);
  window.setTimeout(() => node.remove(), 5200);
}

function namedEntry(table, name) {
  return table?.type === "table"
    ? table.entries.find((entry) => entry.key?.kind === "named" && entry.key.value === name)
    : undefined;
}

function removeNamedEntry(table, name) {
  if (table?.type !== "table") return;
  const index = table.entries.findIndex((entry) => entry.key?.kind === "named" && entry.key.value === name);
  if (index >= 0) table.entries.splice(index, 1);
}

function setNamedEntry(table, name, value) {
  let entry = namedEntry(table, name);
  if (!entry) {
    entry = { key: { kind: "named", value: name }, value };
    table.entries.push(entry);
  } else {
    entry.value = value;
  }
  return entry;
}

function parseColor3(code) {
  const rgb = String(code || "").match(/Color3\.fromRGB\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)/);
  if (rgb) return [1, 2, 3].map((index) => Math.max(0, Math.min(255, Math.round(Number(rgb[index])))));
  const unit = String(code || "").match(/Color3\.new\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)/);
  if (unit) return [1, 2, 3].map((index) => Math.max(0, Math.min(255, Math.round(Number(unit[index]) * 255))));
  return null;
}

function rgbToHex([red, green, blue]) {
  return `#${[red, green, blue].map((value) => value.toString(16).padStart(2, "0")).join("")}`;
}

function hexToRgb(hex) {
  const clean = hex.replace("#", "");
  return [0, 2, 4].map((index) => Number.parseInt(clean.slice(index, index + 2), 16));
}

function rgbToHsv([red, green, blue]) {
  const r = red / 255;
  const g = green / 255;
  const b = blue / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  let hue = 0;
  if (delta) {
    if (max === r) hue = ((g - b) / delta) % 6;
    else if (max === g) hue = (b - r) / delta + 2;
    else hue = (r - g) / delta + 4;
    hue /= 6;
    if (hue < 0) hue += 1;
  }
  return [hue, max === 0 ? 0 : delta / max, max];
}

function hsvToRgb([hue, saturation, value]) {
  const index = Math.floor(hue * 6);
  const fraction = hue * 6 - index;
  const p = value * (1 - saturation);
  const q = value * (1 - fraction * saturation);
  const t = value * (1 - (1 - fraction) * saturation);
  const options = [[value, t, p], [q, value, p], [p, value, t], [p, q, value], [t, p, value], [value, p, q]];
  return options[index % 6].map((channel) => Math.round(channel * 255));
}

function isColorField(entry) {
  return entry?.key?.kind === "named"
    && /colou?r/i.test(entry.key.value)
    && entry.value?.type === "raw"
    && !!parseColor3(entry.value.code);
}

function scalarLabel(node) {
  if (!node) return "—";
  if (node.type === "string" || node.type === "number") return String(node.value);
  if (node.type === "boolean") return node.value ? "Sim" : "Não";
  if (node.type === "nil") return "nil";
  if (node.type === "raw") return node.code;
  return `${node.entries?.length || 0} campos`;
}

function itemTitle() {
  const name = namedEntry(state.ast, "DisplayName")?.value || namedEntry(state.ast, "Name")?.value;
  if (name?.type === "string") return name.value;
  return state.current?.path.split("/").at(-1).replace(/\.luau$/, "") || "Arquivo";
}

async function confirmDiscard() {
  if (!state.dirty) return true;
  return new Promise((resolve) => {
    const onClose = () => {
      elements.confirmDialog.removeEventListener("close", onClose);
      resolve(elements.confirmDialog.returnValue === "confirm");
    };
    elements.confirmDialog.addEventListener("close", onClose);
    elements.confirmDialog.showModal();
  });
}

async function openFile(apiPath) {
  if (state.current?.path === apiPath) return;
  if (!(await confirmDiscard())) return;
  try {
    const data = await api(`/api/file?path=${encodeURIComponent(apiPath)}`);
    state.current = data;
    state.ast = data.editable ? clone(data.ast) : null;
    state.originalAst = data.editable ? clone(data.ast) : null;
    state.dirty = false;
    state.dialogGroup = data.path.startsWith("dialogs/")
      ? state.ast?.entries.find((entry) => entry.key?.kind === "named" && entry.value?.type === "table")?.key.value || null
      : null;
    state.activeTab = data.path.startsWith("dialogs/") ? "dialog" : "form";
    elements.dashboard.classList.add("hidden");
    elements.editor.classList.remove("hidden");
    history.replaceState(null, "", `?file=${encodeURIComponent(apiPath)}`);
    renderFileTree();
    renderEditor();
  } catch (error) {
    toast("Não foi possível abrir o arquivo", error.message, "error");
  }
}

function markDirty() {
  state.dirty = true;
  elements.dirty.textContent = "Alterações não salvas";
  elements.dirty.classList.add("dirty");
  elements.save.disabled = false;
  elements.reset.disabled = false;
  refreshDerivedViews();
}

function markClean() {
  state.dirty = false;
  elements.dirty.textContent = "Sem alterações";
  elements.dirty.classList.remove("dirty");
  elements.save.disabled = true;
  elements.reset.disabled = true;
}

function defaultNode(type) {
  const defaults = {
    string: { type: "string", value: "" },
    number: { type: "number", value: 0 },
    boolean: { type: "boolean", value: false },
    nil: { type: "nil" },
    raw: { type: "raw", code: "Enum.Exemplo.Valor" },
    table: { type: "table", entries: [] },
  };
  return clone(defaults[type] || defaults.string);
}

function typeSelect(node, onChange) {
  const select = create("select", "select");
  for (const [value, label] of [
    ["string", "Texto"], ["number", "Número"], ["boolean", "Booleano"],
    ["table", "Tabela"], ["raw", "Código Luau"], ["nil", "nil"],
  ]) {
    const option = create("option", "", label);
    option.value = value;
    option.selected = node.type === value;
    select.append(option);
  }
  select.addEventListener("change", () => onChange(select.value));
  return select;
}

let derivedTimer;
function refreshDerivedViews() {
  window.clearTimeout(derivedTimer);
  derivedTimer = window.setTimeout(() => {
    renderCodePreview();
    renderVisuals();
    elements.fileTitle.textContent = itemTitle();
  }, 80);
}

function renderRarityEditor(node, container, onMutate) {
  const shell = create("div", "rarity-editor");
  const dot = create("span", "rarity-dot");
  const select = create("select", "select rarity-select");
  RARITIES.forEach((rarity) => {
    const option = create("option", "", rarity.label);
    option.value = rarity.value;
    option.selected = node.value === rarity.value;
    select.append(option);
  });
  if (!RARITIES.some((rarity) => rarity.value === node.value)) {
    const option = create("option", "", node.value || "Personalizada");
    option.value = node.value || "Custom";
    option.selected = true;
    select.append(option);
  }
  const updateColor = () => {
    const color = RARITIES.find((rarity) => rarity.value === select.value)?.color || "#a8b0ba";
    shell.style.setProperty("--rarity-color", color);
  };
  select.addEventListener("change", () => {
    node.value = select.value;
    updateColor();
    onMutate();
  });
  shell.append(dot, select);
  updateColor();
  container.append(shell);
}

function renderColorEditor(node, container, onMutate) {
  let rgb = parseColor3(node.code) || [255, 255, 255];
  let hsv = rgbToHsv(rgb);
  const editor = create("div", "color3-editor");
  const wheelArea = create("div", "color-wheel-area");
  const wheel = create("div", "color-wheel");
  const pointer = create("span", "color-wheel-pointer");
  wheel.append(pointer);
  wheelArea.append(wheel);

  const controls = create("div", "color-controls");
  const previewRow = create("div", "color-preview-row");
  const native = create("input", "native-color-input");
  native.type = "color";
  native.setAttribute("aria-label", "Selecionar cor");
  const codeLabel = create("code", "color3-code");
  previewRow.append(native, codeLabel);

  const valueLabel = create("label", "color-value-control");
  valueLabel.append(create("span", "", "Luminosidade"));
  const valueSlider = create("input");
  valueSlider.type = "range";
  valueSlider.min = "0";
  valueSlider.max = "100";
  valueSlider.value = String(Math.round(hsv[2] * 100));
  valueLabel.append(valueSlider);

  const channelRow = create("div", "color-channel-row");
  const channelInputs = ["R", "G", "B"].map((channel, index) => {
    const label = create("label");
    label.append(create("span", "", channel));
    const input = create("input", "input");
    input.type = "number";
    input.min = "0";
    input.max = "255";
    input.value = String(rgb[index]);
    label.append(input);
    channelRow.append(label);
    return input;
  });

  const sync = (mutated = true) => {
    rgb = hsvToRgb(hsv);
    const hex = rgbToHex(rgb);
    node.code = `Color3.fromRGB(${rgb.join(", ")})`;
    native.value = hex;
    codeLabel.textContent = node.code;
    channelInputs.forEach((input, index) => { input.value = String(rgb[index]); });
    const angle = hsv[0] * Math.PI * 2 - Math.PI / 2;
    const radius = hsv[1] * 44;
    pointer.style.left = `${50 + Math.cos(angle) * radius}%`;
    pointer.style.top = `${50 + Math.sin(angle) * radius}%`;
    pointer.style.backgroundColor = hex;
    wheelArea.style.setProperty("--color-value", String(hsv[2]));
    if (mutated) onMutate();
  };

  const chooseFromWheel = (event) => {
    const rect = wheel.getBoundingClientRect();
    const x = event.clientX - rect.left - rect.width / 2;
    const y = event.clientY - rect.top - rect.height / 2;
    const radius = rect.width / 2;
    hsv[0] = (Math.atan2(y, x) + Math.PI / 2 + Math.PI * 2) % (Math.PI * 2) / (Math.PI * 2);
    hsv[1] = Math.max(0, Math.min(1, Math.sqrt(x * x + y * y) / radius));
    sync();
  };
  wheel.addEventListener("pointerdown", (event) => {
    wheel.setPointerCapture(event.pointerId);
    chooseFromWheel(event);
  });
  wheel.addEventListener("pointermove", (event) => {
    if (wheel.hasPointerCapture(event.pointerId)) chooseFromWheel(event);
  });
  valueSlider.addEventListener("input", () => { hsv[2] = Number(valueSlider.value) / 100; sync(); });
  native.addEventListener("input", () => { rgb = hexToRgb(native.value); hsv = rgbToHsv(rgb); valueSlider.value = String(Math.round(hsv[2] * 100)); sync(); });
  channelInputs.forEach((input, index) => input.addEventListener("input", () => {
    const next = [...rgb];
    next[index] = Math.max(0, Math.min(255, Number(input.value) || 0));
    rgb = next;
    hsv = rgbToHsv(rgb);
    valueSlider.value = String(Math.round(hsv[2] * 100));
    sync();
  }));

  controls.append(previewRow, valueLabel, channelRow);
  editor.append(wheelArea, controls);
  sync(false);
  container.append(editor);
}

function renderScalar(node, container, onMutate) {
  if (node.type === "string") {
    const multiline = String(node.value || "").length > 90 || String(node.value || "").includes("\n");
    const input = create(multiline ? "textarea" : "input", multiline ? "textarea" : "input");
    if (!multiline) input.type = "text";
    input.value = node.value ?? "";
    input.addEventListener("input", () => { node.value = input.value; onMutate(); });
    container.append(input);
  } else if (node.type === "number") {
    const input = create("input", "input");
    input.type = "number";
    input.step = "any";
    input.value = String(node.value ?? 0);
    input.addEventListener("input", () => {
      const value = Number(input.value);
      if (Number.isFinite(value)) { node.value = value; onMutate(); }
    });
    container.append(input);
  } else if (node.type === "boolean") {
    const label = create("label", "boolean-control");
    const input = create("input");
    input.type = "checkbox";
    input.checked = !!node.value;
    input.addEventListener("change", () => { node.value = input.checked; onMutate(); });
    label.append(input, document.createTextNode(node.value ? "Ativado" : "Desativado"));
    input.addEventListener("change", () => { label.lastChild.textContent = input.checked ? "Ativado" : "Desativado"; });
    container.append(label);
  } else if (node.type === "raw") {
    const textarea = create("textarea", "textarea code-input");
    textarea.spellcheck = false;
    textarea.value = node.code ?? "";
    textarea.addEventListener("input", () => { node.code = textarea.value; onMutate(); });
    container.append(textarea);
  } else if (node.type === "nil") {
    container.append(create("span", "nil-value", "nil"));
  }
}

function uniqueFieldName(table) {
  const names = new Set(table.entries.filter((entry) => entry.key.kind === "named").map((entry) => entry.key.value));
  let index = 1;
  let name = "NovoCampo";
  while (names.has(name)) { index += 1; name = `NovoCampo${index}`; }
  return name;
}

function renderTable(table, label = "Dados", depth = 0) {
  const wrapper = create("section", `data-table${depth >= 2 ? " deep-table" : ""}`);
  wrapper.dataset.depth = String(depth);
  const heading = create("header", "table-heading");
  const title = create("div");
  title.append(create("strong", "", label), create("span", "", `${table.entries.length} ${table.entries.length === 1 ? "campo" : "campos"}`));
  const actions = create("div", "mini-actions");
  const addField = create("button", "mini-button", "+ Campo");
  const addItem = create("button", "mini-button", "+ Item");
  addField.type = addItem.type = "button";
  addField.addEventListener("click", () => {
    table.entries.push({ key: { kind: "named", value: uniqueFieldName(table) }, value: defaultNode("string") });
    markDirty(); renderForm();
  });
  addItem.addEventListener("click", () => {
    table.entries.push({ key: { kind: "array" }, value: defaultNode("table") });
    markDirty(); renderForm();
  });
  actions.append(addField, addItem);
  heading.append(title, actions);
  wrapper.append(heading);

  const entries = create("div", "table-entries");
  if (!table.entries.length) entries.append(create("div", "empty-table", "Tabela vazia. Adicione um campo ou item."));
  table.entries.forEach((entry, index) => {
    const row = create("div", `field-row${entry.value.type === "table" ? " table-field-row" : ""}`);
    const key = create("div", "field-key");
    if (entry.key.kind === "named") {
      const input = create("input", "input");
      input.value = entry.key.value ?? "";
      input.setAttribute("aria-label", `Nome do campo ${index + 1}`);
      input.addEventListener("input", () => { entry.key.value = input.value; markDirty(); });
      key.append(input);
    } else if (entry.key.kind === "index") {
      const input = create("input", "input");
      input.value = scalarLabel(entry.key.value);
      input.setAttribute("aria-label", `Índice ${index + 1}`);
      input.addEventListener("input", () => {
        if (entry.key.value.type === "number" && Number.isFinite(Number(input.value))) entry.key.value.value = Number(input.value);
        else { entry.key.value = { type: "string", value: input.value }; }
        markDirty();
      });
      key.append(input);
    } else {
      key.append(create("span", "array-index", `#${index + 1}`));
    }

    const selector = typeSelect(entry.value, (type) => {
      entry.value = defaultNode(type);
      markDirty(); renderForm();
    });
    const value = create("div", `field-value${entry.value.type === "table" ? " nested-value" : ""}`);
    if (entry.value.type === "table") {
      const childLabel = entry.key.kind === "named" ? entry.key.value : `Item ${index + 1}`;
      const details = create("details", "nested-table-details");
      details.open = depth < 1;
      const summary = create("summary");
      summary.append(create("strong", "", childLabel), create("span", "", `${entry.value.entries.length} campos`));
      details.append(summary, renderTable(entry.value, childLabel, depth + 1));
      value.append(details);
    } else if (entry.key.kind === "named" && entry.key.value === "Rarity" && entry.value.type === "string") {
      renderRarityEditor(entry.value, value, markDirty);
    } else if (isColorField(entry)) {
      renderColorEditor(entry.value, value, markDirty);
    } else {
      renderScalar(entry.value, value, markDirty);
    }

    const remove = create("button", "remove-field", "×");
    remove.type = "button";
    remove.title = "Remover campo";
    remove.setAttribute("aria-label", `Remover campo ${index + 1}`);
    remove.addEventListener("click", () => {
      table.entries.splice(index, 1);
      markDirty(); renderForm();
    });
    row.append(key, selector, value, remove);
    entries.append(row);
  });
  wrapper.append(entries);
  return wrapper;
}

function renderAnalysis() {
  elements.analysis.replaceChildren();
  const analysis = state.current?.analysis || { warnings: [], insights: [] };
  analysis.warnings.forEach((message) => elements.analysis.append(create("div", "analysis-message", message)));
  analysis.insights.forEach((message) => elements.analysis.append(create("div", "analysis-message info", message)));
}

function currentDataScope() {
  return state.current?.path.split("/")[1] || "";
}

function renderPresetBar() {
  const scope = currentDataScope();
  const relevant = FIELD_PRESETS.filter((preset) => preset.scopes.includes(scope));
  if (!relevant.length || state.ast?.type !== "table") return null;
  const bar = create("section", "preset-bar");
  const copy = create("div", "preset-copy");
  copy.append(create("span", "eyebrow", "CAMPOS PRONTOS"), create("p", "", "Adicione campos comuns já configurados com o tipo certo."));
  const actions = create("div", "preset-actions");
  relevant.forEach((preset) => {
    const exists = !!namedEntry(state.ast, preset.key);
    const button = create("button", `preset-chip${exists ? " exists" : ""}`, exists ? `✓ ${preset.label}` : `+ ${preset.label}`);
    button.type = "button";
    button.disabled = exists;
    button.addEventListener("click", () => {
      setNamedEntry(state.ast, preset.key, preset.node());
      markDirty();
      renderForm();
    });
    actions.append(button);
  });
  bar.append(copy, actions);
  return bar;
}

function renderForm() {
  elements.form.replaceChildren();
  if (!state.current?.editable || !state.ast) {
    elements.form.append(create("div", "unsupported", state.current?.reason || "Este arquivo não retorna uma tabela literal editável."));
    return;
  }
  const presets = renderPresetBar();
  if (presets) elements.form.append(presets);
  elements.form.append(renderTable(state.ast, "Tabela principal"));
}

function dialogGroups() {
  if (state.ast?.type !== "table") return [];
  return state.ast.entries.filter((entry) => entry.key?.kind === "named" && entry.value?.type === "table");
}

function dialogNodes(group) {
  if (group?.value?.type !== "table") return [];
  return group.value.entries
    .filter((entry) => entry.key?.kind === "index" && entry.key.value?.type === "number" && entry.value?.type === "table")
    .sort((left, right) => Number(left.key.value.value) - Number(right.key.value.value));
}

function nextDialogNodeId(nodes) {
  const ids = nodes.map((entry) => Number(entry.key.value.value));
  return ids.length ? Math.max(...ids) + 1 : 1;
}

function newDialogAnswer() {
  return {
    type: "table",
    entries: [
      { key: { kind: "named", value: "text" }, value: { type: "string", value: "Nova resposta" } },
      { key: { kind: "named", value: "actionType" }, value: { type: "string", value: "end" } },
    ],
  };
}

function newDialogNode(npcName = "NPC") {
  return {
    type: "table",
    entries: [
      { key: { kind: "named", value: "npcName" }, value: { type: "string", value: npcName } },
      { key: { kind: "named", value: "npcText" }, value: { type: "string", value: "Novo diálogo" } },
      {
        key: { kind: "named", value: "answers" },
        value: { type: "table", entries: [{ key: { kind: "index", value: { type: "number", value: 1 } }, value: newDialogAnswer() }] },
      },
    ],
  };
}

function renderCodeHook(table, key, label, defaultCode) {
  const shell = create("div", "dialog-code-hook");
  const entry = namedEntry(table, key);
  if (!entry) {
    const add = create("button", "hook-add-button", `+ ${label}`);
    add.type = "button";
    add.addEventListener("click", () => {
      setNamedEntry(table, key, { type: "raw", code: defaultCode });
      markDirty(); renderDialogEditor();
    });
    shell.append(add);
    return shell;
  }
  const details = create("details", "code-hook-details");
  const summary = create("summary", "", label);
  details.append(summary);
  const textarea = create("textarea", "textarea code-input");
  textarea.value = entry.value.type === "raw" ? entry.value.code : scalarLabel(entry.value);
  textarea.spellcheck = false;
  textarea.addEventListener("input", () => {
    entry.value = { type: "raw", code: textarea.value };
    markDirty();
  });
  const remove = create("button", "hook-remove-button", `Remover ${label.toLowerCase()}`);
  remove.type = "button";
  remove.addEventListener("click", () => {
    removeNamedEntry(table, key);
    markDirty(); renderDialogEditor();
  });
  details.append(textarea, remove);
  shell.append(details);
  return shell;
}

function labeledDialogInput(labelText, value, onInput, multiline = false) {
  const label = create("label", "dialog-field");
  label.append(create("span", "", labelText));
  const input = create(multiline ? "textarea" : "input", multiline ? "textarea dialog-textarea" : "input");
  if (!multiline) input.type = "text";
  input.value = value;
  input.addEventListener("input", () => onInput(input.value));
  label.append(input);
  return label;
}

function renderDialogAnswer(answerEntry, answerIndex, nodes, answersTable) {
  const answer = answerEntry.value;
  const card = create("article", "answer-block");
  const header = create("header");
  header.append(create("strong", "", `Resposta ${answerIndex + 1}`));
  const remove = create("button", "remove-field", "×");
  remove.type = "button";
  remove.title = "Remover resposta";
  remove.addEventListener("click", () => {
    answersTable.entries.splice(answerIndex, 1);
    markDirty(); renderDialogEditor();
  });
  header.append(remove);

  const textEntry = namedEntry(answer, "text") || setNamedEntry(answer, "text", { type: "string", value: "" });
  const textInput = labeledDialogInput("Texto da resposta", scalarLabel(textEntry.value), (value) => {
    textEntry.value = { type: "string", value };
    markDirty();
  });

  const routing = create("div", "answer-routing");
  const routeLabel = create("label", "dialog-field");
  routeLabel.append(create("span", "", "Próximo node"));
  const route = create("select", "select");
  const nextEntry = namedEntry(answer, "nextDialog");
  const currentRoute = nextEntry?.value?.type === "number" ? String(nextEntry.value.value) : nextEntry?.value?.type === "raw" ? "dynamic" : "end";
  [["end", "Encerrar diálogo"], ...nodes.map((node) => [String(node.key.value.value), `Node ${node.key.value.value}`]), ["dynamic", "Dinâmico (função)"]]
    .forEach(([value, label]) => {
      const option = create("option", "", label);
      option.value = value;
      option.selected = currentRoute === value;
      route.append(option);
    });
  route.addEventListener("change", () => {
    if (route.value === "end") {
      removeNamedEntry(answer, "nextDialog");
      setNamedEntry(answer, "actionType", { type: "string", value: "end" });
    } else if (route.value === "dynamic") {
      setNamedEntry(answer, "nextDialog", { type: "raw", code: "function(Player)\n\treturn 1\nend" });
      removeNamedEntry(answer, "actionType");
    } else {
      setNamedEntry(answer, "nextDialog", { type: "number", value: Number(route.value) });
      removeNamedEntry(answer, "actionType");
    }
    markDirty(); renderDialogEditor();
  });
  routeLabel.append(route);
  routing.append(routeLabel);
  if (currentRoute === "dynamic") {
    routing.append(renderCodeHook(answer, "nextDialog", "Roteamento dinâmico", "function(Player)\n\treturn 1\nend"));
  }

  const logic = create("details", "answer-logic");
  logic.append(create("summary", "", "Validações e callbacks"));
  const hooks = create("div", "answer-hooks");
  hooks.append(
    renderCodeHook(answer, "validateAnswer", "Validação da resposta", "function(Player)\n\treturn true\nend"),
    renderCodeHook(answer, "callback", "Callback", "function(Player)\n\t-- Execute uma ação\nend"),
    renderCodeHook(answer, "customText", "Texto dinâmico", "function(Player)\n\treturn \"Resposta dinâmica\"\nend"),
  );
  logic.append(hooks);
  card.append(header, textInput, routing, logic);
  return card;
}

function dialogRoute(answer) {
  const nextDialog = namedEntry(answer, "nextDialog")?.value;
  if (nextDialog?.type === "number") return { type: "node", target: Number(nextDialog.value) };
  if (nextDialog?.type === "raw") return { type: "dynamic", label: "Rota dinâmica" };
  return { type: "end", label: "Encerrar" };
}

function focusDialogNode(nodeId) {
  const target = document.querySelector(`[data-dialog-node-id="${nodeId}"]`);
  if (!target) return;
  target.scrollIntoView({ behavior: "smooth", block: "start" });
  target.classList.remove("flow-highlight");
  window.requestAnimationFrame(() => target.classList.add("flow-highlight"));
  window.setTimeout(() => target.classList.remove("flow-highlight"), 1800);
}

function dialogNodeButton(nodeId, className = "flow-node-button") {
  const button = create("button", className, `Node ${nodeId}`);
  button.type = "button";
  button.addEventListener("click", () => focusDialogNode(nodeId));
  return button;
}

function renderDialogFlowMap(nodes) {
  const map = create("section", "dialog-flow-map");
  const header = create("header", "dialog-flow-map-header");
  const copy = create("div");
  copy.append(create("span", "eyebrow", "MAPA DE CONEXÕES"), create("h3", "", "Caminhos do diálogo"));
  const legend = create("div", "dialog-flow-legend");
  [["node", "Outro node"], ["dynamic", "Dinâmico"], ["end", "Fim"]].forEach(([type, label]) => {
    const item = create("span", `flow-legend-item ${type}`);
    item.append(create("i"), document.createTextNode(label));
    legend.append(item);
  });
  header.append(copy, legend);
  map.append(header);

  const routes = create("div", "dialog-flow-routes");
  nodes.forEach((nodeEntry) => {
    const nodeId = Number(nodeEntry.key.value.value);
    const answers = namedEntry(nodeEntry.value, "answers")?.value;
    const answerEntries = answers?.type === "table"
      ? answers.entries.filter((entry) => entry.value?.type === "table")
      : [];
    const visibleAnswers = answerEntries.length ? answerEntries : [{ value: null }];

    visibleAnswers.forEach((answerEntry, answerIndex) => {
      const answer = answerEntry.value;
      const route = answer ? dialogRoute(answer) : { type: "end", label: "Sem respostas" };
      const row = create("div", `dialog-flow-row route-${route.type}`);
      const source = dialogNodeButton(nodeId, "flow-node-button source");
      if (answerIndex > 0) source.classList.add("continued");

      const connector = create("div", "dialog-flow-connector");
      const answerText = answer ? scalarLabel(namedEntry(answer, "text")?.value) : "Sem respostas configuradas";
      const label = create("div", "flow-answer-copy");
      label.append(create("strong", "", answerText === "—" ? `Resposta ${answerIndex + 1}` : answerText));
      const chips = create("span", "flow-hook-chips");
      if (answer && namedEntry(answer, "validateAnswer")) chips.append(create("b", "validation", "Validação"));
      if (answer && namedEntry(answer, "callback")) chips.append(create("b", "callback", "Callback"));
      if (answer && namedEntry(answer, "customText")) chips.append(create("b", "dynamic", "Texto dinâmico"));
      if (chips.childElementCount) label.append(chips);
      connector.append(label, create("span", "flow-stroke"));

      let destination;
      if (route.type === "node") {
        destination = dialogNodeButton(route.target, "flow-node-button target");
        if (!nodes.some((candidate) => Number(candidate.key.value.value) === route.target)) {
          destination.classList.add("missing");
          destination.title = "Este node não existe";
        }
      } else {
        destination = create("span", `flow-destination ${route.type}`, route.label);
      }
      row.append(source, connector, destination);
      routes.append(row);
    });
  });
  map.append(routes);
  return map;
}

function renderDialogNode(nodeEntry, nodeIndex, group, nodes) {
  const node = nodeEntry.value;
  const nodeId = Number(nodeEntry.key.value.value);
  const card = create("article", "dialog-node-card");
  card.dataset.dialogNodeId = String(nodeId);
  const header = create("header", "dialog-node-header");
  const badge = create("span", "node-id", String(nodeId));
  const heading = create("div");
  heading.append(create("strong", "", `Node ${nodeId}`), create("span", "", `${namedEntry(node, "answers")?.value?.entries?.length || 0} respostas`));
  const remove = create("button", "remove-field", "×");
  remove.type = "button";
  remove.title = "Remover node";
  remove.addEventListener("click", () => {
    if (!window.confirm(`Remover o node ${nodeId}? Respostas que apontam para ele precisarão ser revisadas.`)) return;
    const index = group.value.entries.indexOf(nodeEntry);
    if (index >= 0) group.value.entries.splice(index, 1);
    markDirty(); renderDialogEditor();
  });
  header.append(badge, heading, remove);

  const npcName = namedEntry(node, "npcName") || setNamedEntry(node, "npcName", { type: "string", value: "NPC" });
  const npcText = namedEntry(node, "npcText") || setNamedEntry(node, "npcText", { type: "string", value: "" });
  const body = create("div", "dialog-node-body");
  body.append(
    labeledDialogInput("Nome do NPC", scalarLabel(npcName.value), (value) => { npcName.value = { type: "string", value }; markDirty(); }),
    labeledDialogInput("Texto do NPC", scalarLabel(npcText.value), (value) => { npcText.value = { type: "string", value }; markDirty(); }, true),
    renderCodeHook(node, "customText", "Texto dinâmico do NPC", "function(Player)\n\treturn \"Texto dinâmico\"\nend"),
  );

  let answersEntry = namedEntry(node, "answers");
  if (!answersEntry || answersEntry.value.type !== "table") answersEntry = setNamedEntry(node, "answers", { type: "table", entries: [] });
  const answers = create("section", "answers-section");
  const answersHeader = create("header");
  answersHeader.append(create("strong", "", "Respostas"));
  const addAnswer = create("button", "mini-button", "+ Resposta");
  addAnswer.type = "button";
  addAnswer.addEventListener("click", () => {
    const nextIndex = answersEntry.value.entries.length + 1;
    answersEntry.value.entries.push({ key: { kind: "index", value: { type: "number", value: nextIndex } }, value: newDialogAnswer() });
    markDirty(); renderDialogEditor();
  });
  answersHeader.append(addAnswer);
  answers.append(answersHeader);
  if (!answersEntry.value.entries.length) answers.append(create("div", "empty-table", "Nenhuma resposta configurada."));
  answersEntry.value.entries.forEach((answer, index) => {
    if (answer.value?.type === "table") answers.append(renderDialogAnswer(answer, index, nodes, answersEntry.value));
  });
  card.append(header, body, answers);
  return card;
}

function renderDialogEditor() {
  elements.dialog.replaceChildren();
  if (!state.current?.path.startsWith("dialogs/") || state.ast?.type !== "table") {
    elements.dialog.append(create("div", "visual-empty", "Abra um arquivo de NPC Dialogs para usar o editor em blocos."));
    return;
  }
  const groups = dialogGroups();
  if (!state.dialogGroup || !groups.some((group) => group.key.value === state.dialogGroup)) {
    state.dialogGroup = groups[0]?.key.value || null;
  }
  const toolbar = create("section", "dialog-toolbar");
  const groupTabs = create("div", "dialog-group-tabs");
  groups.forEach((group) => {
    const button = create("button", `dialog-group-tab${group.key.value === state.dialogGroup ? " active" : ""}`, group.key.value);
    button.type = "button";
    button.addEventListener("click", () => { state.dialogGroup = group.key.value; renderDialogEditor(); });
    groupTabs.append(button);
  });
  const addGroup = create("button", "button primary", "+ Grupo de diálogo");
  addGroup.type = "button";
  addGroup.addEventListener("click", () => {
    const names = new Set(groups.map((group) => group.key.value));
    let index = 1;
    let name = "NovoGrupo";
    while (names.has(name)) { index += 1; name = `NovoGrupo${index}`; }
    state.ast.entries.push({
      key: { kind: "named", value: name },
      value: {
        type: "table",
        entries: [
          { key: { kind: "index", value: { type: "number", value: 1 } }, value: newDialogNode("NPC") },
          { key: { kind: "named", value: "priority" }, value: { type: "number", value: 0 } },
        ],
      },
    });
    state.dialogGroup = name;
    markDirty(); renderDialogEditor();
  });
  toolbar.append(groupTabs, addGroup);
  elements.dialog.append(toolbar);

  const group = groups.find((candidate) => candidate.key.value === state.dialogGroup);
  if (!group) {
    elements.dialog.append(create("div", "visual-empty", "Crie um grupo para começar o diálogo."));
    return;
  }

  const groupPanel = create("section", "dialog-group-panel");
  const groupMeta = create("div", "dialog-group-meta");
  const groupName = labeledDialogInput("Nome do grupo", group.key.value, (value) => {
    group.key.value = value;
    state.dialogGroup = value;
    markDirty();
  });
  const priorityEntry = namedEntry(group.value, "priority") || setNamedEntry(group.value, "priority", { type: "number", value: 0 });
  const priority = labeledDialogInput("Prioridade", scalarLabel(priorityEntry.value), (value) => {
    priorityEntry.value = { type: "number", value: Number(value) || 0 };
    markDirty();
  });
  priority.querySelector("input").type = "number";
  const deleteGroup = create("button", "button danger", "Remover grupo");
  deleteGroup.type = "button";
  deleteGroup.addEventListener("click", () => {
    if (!window.confirm(`Remover o grupo ${group.key.value}?`)) return;
    const index = state.ast.entries.indexOf(group);
    if (index >= 0) state.ast.entries.splice(index, 1);
    state.dialogGroup = null;
    markDirty(); renderDialogEditor();
  });
  groupMeta.append(groupName, priority, deleteGroup);
  groupPanel.append(groupMeta, renderCodeHook(group.value, "validation", "Validação do grupo", "function(Player)\n\treturn true\nend"));
  elements.dialog.append(groupPanel);

  const nodes = dialogNodes(group);
  const nodeHeading = create("div", "dialog-node-heading");
  const headingCopy = create("div");
  headingCopy.append(create("span", "eyebrow", "FLUXO"), create("h2", "", `${nodes.length} nodes no grupo`));
  const addNode = create("button", "button secondary", "+ Node");
  addNode.type = "button";
  addNode.addEventListener("click", () => {
    const id = nextDialogNodeId(nodes);
    const npcName = scalarLabel(namedEntry(nodes[0]?.value, "npcName")?.value);
    group.value.entries.splice(nodes.length, 0, { key: { kind: "index", value: { type: "number", value: id } }, value: newDialogNode(npcName === "—" ? "NPC" : npcName) });
    markDirty(); renderDialogEditor();
  });
  nodeHeading.append(headingCopy, addNode);
  const canvas = create("section", "dialog-node-canvas");
  const grid = create("div", "dialog-node-grid");
  nodes.forEach((node, index) => grid.append(renderDialogNode(node, index, group, nodes)));
  canvas.append(renderDialogFlowMap(nodes), grid);
  elements.dialog.append(nodeHeading, canvas);
}

function quoteString(value) {
  return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "\\r").replace(/\n/g, "\\n").replace(/\t/g, "\\t")}"`;
}

function serializeClient(node, depth = 0) {
  if (node.type === "string") return quoteString(node.value ?? "");
  if (node.type === "number") return String(node.value);
  if (node.type === "boolean") return node.value ? "true" : "false";
  if (node.type === "nil") return "nil";
  if (node.type === "raw") return String(node.code || "").trim();
  if (node.type === "table") {
    if (!node.entries.length) return "{}";
    const indent = "\t".repeat(depth + 1);
    const lines = node.entries.map((entry) => {
      let prefix = "";
      if (entry.key.kind === "named") prefix = /^[A-Za-z_][A-Za-z0-9_]*$/.test(entry.key.value) ? `${entry.key.value} = ` : `[${quoteString(entry.key.value)}] = `;
      else if (entry.key.kind === "index") prefix = `[${serializeClient(entry.key.value, depth + 1)}] = `;
      const value = serializeClient(entry.value, depth + 1).replace(/\n/g, `\n${indent}`);
      return `${indent}${prefix}${value},`;
    });
    return `{\n${lines.join("\n")}\n${"\t".repeat(depth)}}`;
  }
  return "nil";
}

function generatedSource() {
  if (!state.current?.editable || !state.ast) return state.current?.source || "";
  return `${state.current.source.slice(0, state.current.tableStart)}${serializeClient(state.ast)}${state.current.source.slice(state.current.tableEnd)}`;
}

function renderCodePreview() {
  elements.code.textContent = generatedSource();
}

function findWeightedLists(node, path = "Dados", results = []) {
  if (node?.type !== "table") return results;
  const values = node.entries.map((entry) => entry.value);
  const items = values.filter((value) => value?.type === "table" && namedEntry(value, "Weight")?.value?.type === "number");
  if (items.length) results.push({ path, items });
  node.entries.forEach((entry, index) => findWeightedLists(entry.value, `${path} › ${entry.key.value ?? index + 1}`, results));
  return results;
}

function renderDrops() {
  const lists = findWeightedLists(state.ast);
  return lists.map((list) => {
    const section = create("section", "visual-section");
    section.append(create("h2", "", `Drops · ${list.path}`));
    const max = Math.max(100, ...list.items.map((item) => Number(namedEntry(item, "Weight").value.value)));
    list.items.forEach((item, index) => {
      const weight = Number(namedEntry(item, "Weight").value.value);
      const name = scalarLabel(namedEntry(item, "Name")?.value) || `Item ${index + 1}`;
      const row = create("div", "drop-row");
      const track = create("div", "drop-track");
      const fill = create("div", "drop-fill");
      fill.style.width = `${Math.max(0, Math.min(100, (weight / max) * 100))}%`;
      track.append(fill);
      row.append(create("span", "drop-name", name), track, create("span", "drop-weight", `${weight}%`));
      section.append(row);
    });
    return section;
  });
}

function renderSkillNode(node) {
  const wrapper = create("div", "skill-node-wrap");
  const card = create("article", "skill-node");
  card.append(create("strong", "", scalarLabel(namedEntry(node, "Name")?.value) || "Skill"));
  const description = namedEntry(node, "Description")?.value;
  if (description) card.append(create("p", "", scalarLabel(description)));
  wrapper.append(card);
  const branches = namedEntry(node, "Branches")?.value;
  if (branches?.type === "table" && branches.entries.length) {
    const children = create("div", "skill-children");
    branches.entries.forEach((entry) => {
      if (entry.value?.type === "table") children.append(renderSkillNode(entry.value));
    });
    wrapper.append(children);
  }
  return wrapper;
}

function renderSkillTree() {
  const branches = namedEntry(state.ast, "Branches")?.value;
  if (branches?.type !== "table" || !branches.entries.length) return null;
  const section = create("section", "visual-section");
  section.append(create("h2", "", "Árvore de progressão"));
  const tree = create("div", "skill-tree");
  branches.entries.forEach((entry) => {
    if (entry.value?.type === "table") tree.append(renderSkillNode(entry.value));
  });
  section.append(tree);
  return section;
}

function renderColor() {
  const color = namedEntry(state.ast, "Color")?.value;
  if (color?.type !== "raw") return null;
  const match = color.code.match(/Color3\.fromRGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/);
  if (!match) return null;
  const section = create("section", "visual-section");
  section.append(create("h2", "", "Cor principal"));
  const preview = create("div", "color-preview");
  const swatch = create("div", "color-swatch");
  swatch.style.backgroundColor = `rgb(${match[1]}, ${match[2]}, ${match[3]})`;
  preview.append(swatch, create("code", "", `RGB ${match[1]}, ${match[2]}, ${match[3]}`));
  section.append(preview);
  return section;
}

function renderSummary() {
  if (state.ast?.type !== "table") return null;
  const scalars = state.ast.entries.filter((entry) => entry.key.kind === "named" && entry.value.type !== "table").slice(0, 12);
  if (!scalars.length) return null;
  const section = create("section", "visual-section");
  section.append(create("h2", "", "Resumo"));
  const grid = create("div", "summary-grid");
  scalars.forEach((entry) => {
    const card = create("div", "summary-item");
    card.append(create("span", "", entry.key.value), create("strong", "", scalarLabel(entry.value)));
    grid.append(card);
  });
  section.append(grid);
  return section;
}

function renderVisuals() {
  elements.visual.replaceChildren();
  if (!state.ast) {
    elements.visual.append(create("div", "visual-empty", "Este arquivo não possui uma tabela que possa ser visualizada."));
    return;
  }
  const sections = [...renderDrops(), renderSkillTree(), renderColor(), renderSummary()].filter(Boolean);
  if (!sections.length) {
    elements.visual.append(create("div", "visual-empty", "Não há uma visualização especial para este formato. O editor de campos continua totalmente disponível."));
    return;
  }
  elements.visual.append(...sections);
}

function detailRow(label, value) {
  const row = create("div");
  row.append(create("dt", "", label), create("dd", "", value));
  return row;
}

function renderEditor() {
  elements.filePath.textContent = state.current.displayPath;
  elements.fileTitle.textContent = itemTitle();
  elements.fileMeta.textContent = `${state.current.category} · ${Math.round(state.current.source.length / 1024 * 10) / 10} KB`;
  elements.fileDetails.replaceChildren(
    detailRow("Caminho", state.current.displayPath),
    detailRow("Categoria", state.current.category),
    detailRow("Modificado", new Date(state.current.modifiedAt).toLocaleString("pt-BR")),
    detailRow("Formato", state.current.editable ? "Tabela Luau editável" : "Código livre"),
  );
  renderAnalysis();
  renderForm();
  const isDialog = state.current.path.startsWith("dialogs/");
  elements.dialogTab.classList.toggle("hidden", !isDialog);
  renderDialogEditor();
  renderVisuals();
  renderCodePreview();
  markClean();
  switchTab(state.activeTab);
}

function switchTab(name) {
  if (name === "dialog" && !state.current?.path.startsWith("dialogs/")) name = "form";
  state.activeTab = name;
  document.querySelectorAll(".tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.tab === name));
  document.querySelectorAll(".tab-panel").forEach((panel) => panel.classList.toggle("active", panel.id === `tab-${name}`));
  if (name === "code") renderCodePreview();
  if (name === "visual") renderVisuals();
  if (name === "dialog") renderDialogEditor();
}

async function saveCurrent() {
  if (!state.current?.editable || !state.ast || !state.dirty) return;
  elements.save.disabled = true;
  try {
    const result = await api("/api/save", {
      method: "POST",
      body: JSON.stringify({ path: state.current.path, hash: state.current.hash, ast: state.ast }),
    });
    state.current.source = result.source;
    state.current.hash = result.hash;
    state.current.modifiedAt = result.modifiedAt;
    state.current.analysis = result.analysis;
    const refreshed = await api(`/api/file?path=${encodeURIComponent(state.current.path)}`);
    state.current = refreshed;
    state.ast = clone(refreshed.ast);
    state.originalAst = clone(refreshed.ast);
    renderEditor();
    toast("Arquivo salvo no VS Code", `Backup criado em ${result.backup}`);
  } catch (error) {
    elements.save.disabled = false;
    const details = error.details?.length ? ` ${error.details.join(" ")}` : "";
    toast(error.status === 409 ? "Arquivo alterado fora do site" : "Não foi possível salvar", `${error.message}${details}`, "error");
  }
}

async function resetCurrent() {
  if (!state.dirty || !(await confirmDiscard())) return;
  state.ast = clone(state.originalAst);
  renderEditor();
}

async function showDashboard() {
  if (!(await confirmDiscard())) return;
  state.current = null;
  state.ast = null;
  state.originalAst = null;
  state.dialogGroup = null;
  state.dirty = false;
  elements.editor.classList.add("hidden");
  elements.dashboard.classList.remove("hidden");
  history.replaceState(null, "", location.pathname);
  renderFileTree();
}

async function bootstrap() {
  try {
    const data = await api("/api/bootstrap");
    state.token = data.token;
    state.tree = data.tree;
    state.files = flattenTree(data.tree);
    elements.repoRoot.textContent = data.repoRoot;
    renderFileTree();
    renderDashboard();
    const query = new URLSearchParams(location.search);
    const requestedFile = query.get("file");
    const requestedTab = query.get("tab");
    if (requestedFile && state.files.some((file) => file.apiPath === requestedFile)) {
      await openFile(requestedFile);
      if (["form", "dialog", "visual", "code"].includes(requestedTab)) switchTab(requestedTab);
    }
  } catch (error) {
    toast("Index Studio não iniciou", error.message, "error");
  }
}

elements.search.addEventListener("input", () => {
  state.search = elements.search.value.trim().toLowerCase();
  renderFileTree();
});
elements.save.addEventListener("click", saveCurrent);
elements.reset.addEventListener("click", resetCurrent);
document.querySelector("#back-dashboard").addEventListener("click", showDashboard);
document.querySelector("#copy-code").addEventListener("click", async () => {
  await navigator.clipboard.writeText(generatedSource());
  toast("Código copiado");
});
document.querySelectorAll(".tab").forEach((tab) => tab.addEventListener("click", () => switchTab(tab.dataset.tab)));
document.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
    event.preventDefault();
    saveCurrent();
  }
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    elements.search.focus();
    elements.search.select();
  }
});
window.addEventListener("beforeunload", (event) => {
  if (state.dirty) event.preventDefault();
});

bootstrap();
