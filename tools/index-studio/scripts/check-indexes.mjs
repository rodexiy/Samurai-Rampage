import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseLuauModule, serializeModule, validateAst } from "../lib/luau-table.mjs";

const toolDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = path.resolve(toolDir, "../..");
const roots = [
  path.join(repoRoot, "src", "ReplicatedStorage", "Index"),
  path.join(repoRoot, "src", "ServerStorage", "Index"),
  path.join(repoRoot, "src", "ServerStorage", "Services", "DialogService", "Dialogs"),
];

async function filesUnder(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...await filesUnder(absolute));
    else if (entry.isFile() && entry.name.endsWith(".luau")) result.push(absolute);
  }
  return result;
}

let editable = 0;
let unsupported = 0;
const failures = [];

for (const root of roots) {
  for (const file of await filesUnder(root)) {
    const source = await readFile(file, "utf8");
    try {
      const parsed = parseLuauModule(source);
      if (!parsed.editable) {
        unsupported += 1;
        continue;
      }
      const errors = validateAst(parsed.ast);
      if (errors.length) throw new Error(errors.join(" "));
      const serialized = serializeModule(source, parsed, parsed.ast);
      const reparsed = parseLuauModule(serialized);
      if (!reparsed.editable) throw new Error("O arquivo serializado não pôde ser lido novamente.");
      editable += 1;
    } catch (error) {
      failures.push(`${path.relative(repoRoot, file)}: ${error.message}`);
    }
  }
}

console.log(`Editáveis: ${editable}`);
console.log(`Ignorados (sem return de tabela literal): ${unsupported}`);
if (failures.length) {
  console.error(`Falhas: ${failures.length}`);
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
} else {
  console.log("Todos os arquivos editáveis passaram pelo parse e round-trip.");
}
