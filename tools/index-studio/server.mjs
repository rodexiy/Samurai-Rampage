import { createHash, randomBytes } from "node:crypto";
import { createReadStream } from "node:fs";
import { mkdir, readFile, readdir, rename, stat, unlink, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  analyzeAst,
  parseLuauModule,
  serializeModule,
  validateAst,
} from "./lib/luau-table.mjs";

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(TOOL_DIR, "../..");
const PUBLIC_DIR = path.join(TOOL_DIR, "public");
const BACKUP_DIR = path.join(TOOL_DIR, ".backups");
const HOST = "127.0.0.1";
const PORT = Number(process.env.INDEX_STUDIO_PORT || 4317);
const SESSION_TOKEN = randomBytes(24).toString("hex");

const INDEX_ROOTS = [
  {
    id: "replicated",
    label: "ReplicatedStorage / Index",
    absolute: path.join(REPO_ROOT, "src", "ReplicatedStorage", "Index"),
  },
  {
    id: "server",
    label: "ServerStorage / Index",
    absolute: path.join(REPO_ROOT, "src", "ServerStorage", "Index"),
  },
  {
    id: "dialogs",
    label: "NPC Dialogs",
    absolute: path.join(REPO_ROOT, "src", "ServerStorage", "Services", "DialogService", "Dialogs"),
  },
];

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

function json(response, statusCode, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(body);
}

function text(response, statusCode, payload, contentType = "text/plain; charset=utf-8") {
  response.writeHead(statusCode, {
    "Content-Type": contentType,
    "Content-Length": Buffer.byteLength(payload),
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(payload);
}

function hashSource(source) {
  return createHash("sha256").update(source).digest("hex");
}

function normalizeRelative(input) {
  if (typeof input !== "string" || !input || input.includes("\0")) throw new Error("Caminho inválido.");
  const normalized = input.replace(/\\/g, "/").replace(/^\/+/, "");
  if (normalized.split("/").some((part) => part === ".." || part === "")) throw new Error("Caminho inválido.");
  return normalized;
}

function resolveIndexFile(relativePath) {
  const normalized = normalizeRelative(relativePath);
  const root = INDEX_ROOTS.find((candidate) => normalized.startsWith(`${candidate.id}/`));
  if (!root) throw new Error("O arquivo não pertence a um diretório de dados permitido.");
  const insideRoot = normalized.slice(root.id.length + 1);
  if (!insideRoot.endsWith(".luau")) throw new Error("Somente arquivos .luau podem ser editados.");
  const absolute = path.resolve(root.absolute, insideRoot);
  const rootPrefix = `${path.resolve(root.absolute)}${path.sep}`;
  if (!absolute.startsWith(rootPrefix)) throw new Error("O caminho saiu do diretório de dados permitido.");
  return { root, normalized, insideRoot, absolute };
}

async function walkDirectory(absolute, prefix = "") {
  const entries = await readdir(absolute, { withFileTypes: true });
  entries.sort((a, b) => {
    if (a.isDirectory() !== b.isDirectory()) return a.isDirectory() ? -1 : 1;
    return a.name.localeCompare(b.name, "pt-BR", { sensitivity: "base" });
  });
  const nodes = [];
  for (const entry of entries) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    const entryPath = path.join(absolute, entry.name);
    if (entry.isDirectory()) {
      nodes.push({ type: "directory", name: entry.name, path: relative, children: await walkDirectory(entryPath, relative) });
    } else if (entry.isFile() && entry.name.endsWith(".luau")) {
      const info = await stat(entryPath);
      nodes.push({
        type: "file",
        name: entry.name.replace(/\.luau$/, ""),
        fileName: entry.name,
        path: relative,
        size: info.size,
        modifiedAt: info.mtime.toISOString(),
      });
    }
  }
  return nodes;
}

async function buildTree() {
  return Promise.all(INDEX_ROOTS.map(async (root) => ({
    id: root.id,
    label: root.label,
    type: "root",
    children: await walkDirectory(root.absolute),
  })));
}

function categoryFor(resolved) {
  const parts = resolved.insideRoot.split("/");
  return parts.length > 1 ? parts[0] : resolved.root.label;
}

async function readBody(request, maxBytes = 2_000_000) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxBytes) throw new Error("Requisição grande demais.");
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  try {
    return raw ? JSON.parse(raw) : {};
  } catch {
    throw new Error("JSON inválido.");
  }
}

function requireMutationToken(request) {
  const origin = request.headers.origin;
  if (origin && origin !== `http://${HOST}:${PORT}`) throw new Error("Origem não permitida.");
  if (request.headers["x-index-studio-token"] !== SESSION_TOKEN) throw new Error("Sessão local inválida. Recarregue a página.");
}

async function createBackup(resolved, source) {
  const safeParts = resolved.normalized.split("/").map((part) => part.replace(/[^A-Za-z0-9._-]/g, "_"));
  const destinationDir = path.join(BACKUP_DIR, ...safeParts.slice(0, -1), safeParts.at(-1));
  await mkdir(destinationDir, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const backupPath = path.join(destinationDir, `${timestamp}.luau`);
  await writeFile(backupPath, source, "utf8");
  return path.relative(TOOL_DIR, backupPath).replace(/\\/g, "/");
}

async function atomicWrite(filePath, content) {
  const tempPath = `${filePath}.index-studio-${process.pid}-${Date.now()}.tmp`;
  await writeFile(tempPath, content, "utf8");
  try {
    await rename(tempPath, filePath);
  } catch (error) {
    await unlink(tempPath).catch(() => {});
    throw error;
  }
}

async function serveStatic(response, pathname) {
  const requested = pathname === "/" ? "index.html" : pathname.slice(1);
  const absolute = path.resolve(PUBLIC_DIR, requested);
  if (!absolute.startsWith(`${PUBLIC_DIR}${path.sep}`) && absolute !== path.join(PUBLIC_DIR, "index.html")) return false;
  let info;
  try {
    info = await stat(absolute);
  } catch {
    return false;
  }
  if (!info.isFile()) return false;
  response.writeHead(200, {
    "Content-Type": MIME_TYPES[path.extname(absolute)] || "application/octet-stream",
    "Content-Length": info.size,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'",
  });
  createReadStream(absolute).pipe(response);
  return true;
}

async function handleApi(request, response, url) {
  if (request.method === "GET" && url.pathname === "/api/bootstrap") {
    return json(response, 200, {
      token: SESSION_TOKEN,
      repoName: path.basename(REPO_ROOT),
      repoRoot: REPO_ROOT,
      tree: await buildTree(),
      serverTime: new Date().toISOString(),
    });
  }

  if (request.method === "GET" && url.pathname === "/api/file") {
    const resolved = resolveIndexFile(url.searchParams.get("path"));
    const source = await readFile(resolved.absolute, "utf8");
    let parsed;
    try {
      parsed = parseLuauModule(source);
    } catch (error) {
      parsed = { editable: false, reason: error.message };
    }
    const analysis = parsed.editable ? analyzeAst(parsed.ast, `/${resolved.insideRoot}`) : { warnings: [], insights: [] };
    return json(response, 200, {
      path: resolved.normalized,
      displayPath: path.relative(REPO_ROOT, resolved.absolute).replace(/\\/g, "/"),
      category: categoryFor(resolved),
      source,
      hash: hashSource(source),
      modifiedAt: (await stat(resolved.absolute)).mtime.toISOString(),
      ...parsed,
      analysis,
    });
  }

  if (request.method === "POST" && url.pathname === "/api/save") {
    requireMutationToken(request);
    const body = await readBody(request);
    const resolved = resolveIndexFile(body.path);
    const currentSource = await readFile(resolved.absolute, "utf8");
    const currentHash = hashSource(currentSource);
    if (body.hash !== currentHash) {
      return json(response, 409, {
        error: "O arquivo mudou no VS Code depois que foi aberto. Recarregue antes de salvar para não sobrescrever alterações.",
        currentHash,
      });
    }

    const astErrors = validateAst(body.ast);
    if (astErrors.length > 0) return json(response, 422, { error: "Os dados possuem erros.", details: astErrors });
    const parsed = parseLuauModule(currentSource);
    if (!parsed.editable) return json(response, 422, { error: parsed.reason });
    const nextSource = serializeModule(currentSource, parsed, body.ast);
    const verification = parseLuauModule(nextSource);
    if (!verification.editable) return json(response, 422, { error: "O resultado não contém uma tabela retornada válida." });
    const verificationErrors = validateAst(verification.ast);
    if (verificationErrors.length > 0) return json(response, 422, { error: "A validação do arquivo gerado falhou.", details: verificationErrors });

    const backup = await createBackup(resolved, currentSource);
    await atomicWrite(resolved.absolute, nextSource);
    return json(response, 200, {
      ok: true,
      hash: hashSource(nextSource),
      source: nextSource,
      modifiedAt: (await stat(resolved.absolute)).mtime.toISOString(),
      backup,
      analysis: analyzeAst(body.ast, `/${resolved.insideRoot}`),
    });
  }

  if (request.method === "POST" && url.pathname === "/api/validate-source") {
    requireMutationToken(request);
    const body = await readBody(request);
    const parsed = parseLuauModule(String(body.source || ""));
    const errors = parsed.editable ? validateAst(parsed.ast) : [parsed.reason];
    return json(response, errors.length ? 422 : 200, { ok: errors.length === 0, errors, parsed });
  }

  return json(response, 404, { error: "Endpoint não encontrado." });
}

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url, `http://${HOST}:${PORT}`);
    if (url.pathname.startsWith("/api/")) return await handleApi(request, response, url);
    if (request.method !== "GET") return json(response, 405, { error: "Método não permitido." });
    if (await serveStatic(response, url.pathname)) return;
    return text(response, 404, "Página não encontrada.");
  } catch (error) {
    const status = /Caminho|permitid|Sessão|Origem/.test(error.message) ? 403 : 500;
    console.error(error);
    return json(response, status, { error: error.message || "Erro interno." });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`\nIndex Studio está rodando em http://${HOST}:${PORT}`);
  console.log(`Projeto: ${REPO_ROOT}`);
  console.log("Pressione Ctrl+C para encerrar.\n");
});

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.error(`A porta ${PORT} já está em uso. Defina INDEX_STUDIO_PORT para usar outra.`);
    process.exitCode = 1;
    return;
  }
  throw error;
});
