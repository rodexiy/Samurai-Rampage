const IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;

function isWhitespace(char) {
  return char === " " || char === "\t" || char === "\r" || char === "\n";
}

function isIdentifierStart(char) {
  return !!char && /[A-Za-z_]/.test(char);
}

function isIdentifierPart(char) {
  return !!char && /[A-Za-z0-9_]/.test(char);
}

function skipQuoted(source, start, quote) {
  let index = start + 1;
  while (index < source.length) {
    if (source[index] === "\\") {
      index += 2;
      continue;
    }
    if (source[index] === quote) return index + 1;
    index += 1;
  }
  return source.length;
}

function longBracketLevel(source, start) {
  if (source[start] !== "[") return null;
  let index = start + 1;
  while (source[index] === "=") index += 1;
  if (source[index] !== "[") return null;
  return { level: index - start - 1, contentStart: index + 1 };
}

function skipLongBracket(source, start) {
  const opening = longBracketLevel(source, start);
  if (!opening) return start;
  const close = `]${"=".repeat(opening.level)}]`;
  const closeIndex = source.indexOf(close, opening.contentStart);
  return closeIndex === -1 ? source.length : closeIndex + close.length;
}

function skipTrivia(source, start) {
  let index = start;
  while (index < source.length) {
    if (isWhitespace(source[index])) {
      index += 1;
      continue;
    }
    if (source[index] === "-" && source[index + 1] === "-") {
      const longStart = index + 2;
      if (longBracketLevel(source, longStart)) {
        index = skipLongBracket(source, longStart);
      } else {
        const lineEnd = source.indexOf("\n", index + 2);
        index = lineEnd === -1 ? source.length : lineEnd + 1;
      }
      continue;
    }
    break;
  }
  return index;
}

function readIdentifier(source, start) {
  if (!isIdentifierStart(source[start])) return null;
  let index = start + 1;
  while (isIdentifierPart(source[index])) index += 1;
  return { value: source.slice(start, index), start, end: index };
}

function readNumber(source, start) {
  const match = source.slice(start).match(/^(?:0[xX][0-9a-fA-F]+(?:\.[0-9a-fA-F]*)?(?:[pP][+-]?\d+)?|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/);
  if (!match) return null;
  return { value: match[0], start, end: start + match[0].length };
}

function decodeString(raw) {
  const body = raw.slice(1, -1);
  return body.replace(/\\(\d{1,3}|x[0-9a-fA-F]{2}|u\{[0-9a-fA-F]+\}|[abfnrtv\\"'`])/g, (_, escape) => {
    if (/^\d/.test(escape)) return String.fromCharCode(Number(escape));
    if (escape[0] === "x") return String.fromCharCode(Number.parseInt(escape.slice(1), 16));
    if (escape.startsWith("u{")) return String.fromCodePoint(Number.parseInt(escape.slice(2, -1), 16));
    const values = { a: "\u0007", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\v" };
    return values[escape] ?? escape;
  });
}

function readToken(source, start) {
  const index = skipTrivia(source, start);
  if (index >= source.length) return { type: "eof", value: "", start: index, end: index };
  const char = source[index];

  if (char === '"' || char === "'" || char === "`") {
    const end = skipQuoted(source, index, char);
    return { type: "string", value: source.slice(index, end), start: index, end };
  }
  if (char === "[") {
    const end = skipLongBracket(source, index);
    if (end !== index) return { type: "string", value: source.slice(index, end), start: index, end };
  }
  const identifier = readIdentifier(source, index);
  if (identifier) return { type: "identifier", ...identifier };
  const number = readNumber(source, index);
  if (number) return { type: "number", ...number };

  const two = source.slice(index, index + 2);
  if (["==", "~=", "<=", ">=", "::", "..", "//", "+=", "-=", "*=", "/="].includes(two)) {
    return { type: "symbol", value: two, start: index, end: index + 2 };
  }
  return { type: "symbol", value: char, start: index, end: index + 1 };
}

function isValueDelimiter(token) {
  return token.type === "eof" || token.value === "," || token.value === ";" || token.value === "}" || token.value === "]";
}

function scanRawExpression(source, start) {
  let index = start;
  let paren = 0;
  let bracket = 0;
  let brace = 0;
  let blockDepth = 0;

  while (index < source.length) {
    const char = source[index];
    if (char === '"' || char === "'" || char === "`") {
      index = skipQuoted(source, index, char);
      continue;
    }
    if (char === "[") {
      const longEnd = skipLongBracket(source, index);
      if (longEnd !== index) {
        index = longEnd;
        continue;
      }
      bracket += 1;
      index += 1;
      continue;
    }
    if (char === "]") {
	  if (paren === 0 && bracket === 0 && brace === 0 && blockDepth === 0) break;
      bracket = Math.max(0, bracket - 1);
      index += 1;
      continue;
    }
    if (char === "(" ) { paren += 1; index += 1; continue; }
    if (char === ")" ) { paren = Math.max(0, paren - 1); index += 1; continue; }
    if (char === "{") { brace += 1; index += 1; continue; }
    if (char === "}") {
      if (paren === 0 && bracket === 0 && brace === 0 && blockDepth === 0) break;
      brace = Math.max(0, brace - 1);
      index += 1;
      continue;
    }
    if (char === "-" && source[index + 1] === "-") {
      const afterComment = skipTrivia(source, index);
      index = afterComment === index ? index + 2 : afterComment;
      continue;
    }
    if (isIdentifierStart(char)) {
      const identifier = readIdentifier(source, index);
      const word = identifier.value;
      if (["function", "if", "for", "while"].includes(word)) blockDepth += 1;
      else if (word === "repeat") blockDepth += 1;
      else if (word === "end" || word === "until") blockDepth = Math.max(0, blockDepth - 1);
      index = identifier.end;
      continue;
    }
    if ((char === "," || char === ";") && paren === 0 && bracket === 0 && brace === 0 && blockDepth === 0) break;
    index += 1;
  }

  return { code: source.slice(start, index).trim(), end: index };
}

class TableParser {
  constructor(source, start) {
    this.source = source;
    this.position = start;
  }

  peek() {
    return readToken(this.source, this.position);
  }

  consume(value) {
    const token = this.peek();
    if (value !== undefined && token.value !== value) {
      throw new Error(`Esperado '${value}' na posição ${token.start}, encontrado '${token.value}'.`);
    }
    this.position = token.end;
    return token;
  }

  parseSimpleOrRaw() {
    const token = this.peek();
    const next = readToken(this.source, token.end);
    if (token.type === "string" && isValueDelimiter(next)) {
      this.position = token.end;
      const interpolated = token.value[0] === "`" && /(^|[^\\])\{/.test(token.value.slice(1, -1));
      if (interpolated) return { type: "raw", code: token.value };
      return { type: "string", value: decodeString(token.value) };
    }
    if (token.type === "number" && isValueDelimiter(next)) {
      this.position = token.end;
      const numericValue = Number(token.value);
      return Number.isFinite(numericValue)
        ? { type: "number", value: numericValue }
        : { type: "raw", code: token.value };
    }
    if (token.type === "identifier" && isValueDelimiter(next)) {
      if (token.value === "true" || token.value === "false") {
        this.position = token.end;
        return { type: "boolean", value: token.value === "true" };
      }
      if (token.value === "nil") {
        this.position = token.end;
        return { type: "nil" };
      }
    }

    const raw = scanRawExpression(this.source, token.start);
    if (!raw.code) throw new Error(`Expressão vazia na posição ${token.start}.`);
    this.position = raw.end;
    return { type: "raw", code: raw.code };
  }

  parseValue() {
    const token = this.peek();
    if (token.value === "{") return this.parseTable();
    return this.parseSimpleOrRaw();
  }

  parseTable() {
    const opening = this.consume("{");
    const entries = [];

    while (true) {
      const token = this.peek();
      if (token.type === "eof") throw new Error("Tabela Luau não foi fechada com '}'.");
      if (token.value === "}") {
        const closing = this.consume("}");
        return { type: "table", entries, start: opening.start, end: closing.end };
      }

      let key = { kind: "array" };
      let value;

      if (token.value === "[") {
        this.consume("[");
        const keyValue = this.parseValue();
        this.consume("]");
        this.consume("=");
        key = { kind: "index", value: keyValue };
        value = this.parseValue();
      } else if (token.type === "identifier") {
        const afterIdentifier = readToken(this.source, token.end);
        if (afterIdentifier.value === "=") {
          this.position = token.end;
          this.consume("=");
          key = { kind: "named", value: token.value };
          value = this.parseValue();
        } else {
          value = this.parseValue();
        }
      } else {
        value = this.parseValue();
      }

      entries.push({ key, value });
      const delimiter = this.peek();
      if (delimiter.value === "," || delimiter.value === ";") this.consume(delimiter.value);
      else if (delimiter.value !== "}") {
        throw new Error(`Esperado ',' ou '}' na posição ${delimiter.start}.`);
      }
    }
  }
}

function findReturnedTable(source) {
  let position = 0;
  let returned = null;
  const assignedTables = new Map();
  while (position < source.length) {
    const token = readToken(source, position);
    if (token.type === "eof") break;
    if (token.type === "identifier" && token.value === "return") {
      const next = readToken(source, token.end);
      if (next.value === "{") returned = { kind: "table", value: next.start };
      else if (next.type === "identifier") returned = { kind: "identifier", value: next.value };
    }
    if (token.type === "identifier") {
      let nameToken = token;
      if (token.value === "local") nameToken = readToken(source, token.end);
      if (nameToken.type === "identifier") {
        const equals = readToken(source, nameToken.end);
        const value = equals.value === "=" ? readToken(source, equals.end) : null;
        if (value?.value === "{") assignedTables.set(nameToken.value, value.start);
      }
    }
    position = Math.max(token.end, position + 1);
  }
  if (returned?.kind === "table") return returned.value;
  if (returned?.kind === "identifier") return assignedTables.get(returned.value) ?? null;
  return null;
}

export function parseLuauModule(source) {
  const tableStart = findReturnedTable(source);
  if (tableStart === null) {
    return { editable: false, reason: "Nenhuma tabela literal após 'return' foi encontrada." };
  }

  const parser = new TableParser(source, tableStart);
  const ast = parser.parseTable();
  return {
    editable: true,
    ast: stripRanges(ast),
    tableStart: ast.start,
    tableEnd: ast.end,
  };
}

function stripRanges(node) {
  if (!node || typeof node !== "object") return node;
  if (node.type === "table") {
    return {
      type: "table",
      entries: node.entries.map((entry) => ({
        key: {
          ...entry.key,
          ...(entry.key.value && typeof entry.key.value === "object" ? { value: stripRanges(entry.key.value) } : {}),
        },
        value: stripRanges(entry.value),
      })),
    };
  }
  return { ...node };
}

function quoteString(value) {
  return `"${String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n")
    .replace(/\t/g, "\\t")}"`;
}

function normalizeRawIndent(code, indent) {
  const lines = String(code ?? "").trim().replace(/\r\n/g, "\n").split("\n");
  if (lines.length === 1) return lines[0];
  const tail = lines.slice(1).filter((line) => line.trim());
  const minimum = tail.length
    ? Math.min(...tail.map((line) => (line.match(/^[\t ]*/) ?? [""])[0].replace(/ {4}/g, "\t").length))
    : 0;
  return [lines[0].trimStart(), ...lines.slice(1).map((line) => `${indent}${line.slice(minimum)}`)].join("\n");
}

export function serializeNode(node, depth = 0) {
  if (!node || typeof node !== "object") throw new Error("Nó de dado inválido.");
  switch (node.type) {
    case "string": return quoteString(node.value ?? "");
    case "number": {
      const value = Number(node.value);
      if (!Number.isFinite(value)) throw new Error("Número inválido.");
      return String(value);
    }
    case "boolean": return node.value ? "true" : "false";
    case "nil": return "nil";
    case "raw": {
      const code = String(node.code ?? "").trim();
      if (!code) throw new Error("Expressão Luau vazia.");
      return normalizeRawIndent(code, "\t".repeat(depth));
    }
    case "table": {
      if (!Array.isArray(node.entries)) throw new Error("Tabela sem lista de campos.");
      if (node.entries.length === 0) return "{}";
      const indent = "\t".repeat(depth + 1);
      const lines = node.entries.map((entry) => {
        let prefix = "";
        if (entry.key?.kind === "named") {
          const key = String(entry.key.value ?? "");
          prefix = IDENTIFIER.test(key) ? `${key} = ` : `[${quoteString(key)}] = `;
        } else if (entry.key?.kind === "index") {
          prefix = `[${serializeNode(entry.key.value, depth + 1)}] = `;
        }
        return `${indent}${prefix}${serializeNode(entry.value, depth + 1)},`;
      });
      return `{\n${lines.join("\n")}\n${"\t".repeat(depth)}}`;
    }
    default: throw new Error(`Tipo de dado desconhecido: ${node.type}`);
  }
}

export function serializeModule(source, parsed, ast) {
  const table = serializeNode(ast, 0);
  return `${source.slice(0, parsed.tableStart)}${table}${source.slice(parsed.tableEnd)}`;
}

export function validateAst(ast, limits = { depth: 30, entries: 5000 }) {
  let entries = 0;
  const errors = [];
  function visit(node, depth, path) {
    if (depth > limits.depth) {
      errors.push(`${path}: profundidade máxima excedida.`);
      return;
    }
    if (!node || typeof node !== "object" || typeof node.type !== "string") {
      errors.push(`${path}: nó inválido.`);
      return;
    }
    if (node.type === "table") {
      if (!Array.isArray(node.entries)) {
        errors.push(`${path}: entries precisa ser uma lista.`);
        return;
      }
      const seen = new Set();
      for (let index = 0; index < node.entries.length; index += 1) {
        entries += 1;
        if (entries > limits.entries) {
          errors.push("Quantidade máxima de campos excedida.");
          return;
        }
        const entry = node.entries[index];
        if (!entry?.key || !["named", "index", "array"].includes(entry.key.kind)) {
          errors.push(`${path}[${index}]: chave inválida.`);
          continue;
        }
        if (entry.key.kind === "named") {
          const key = String(entry.key.value ?? "");
          if (!key) errors.push(`${path}[${index}]: nome do campo vazio.`);
          if (seen.has(key)) errors.push(`${path}: campo duplicado '${key}'.`);
          seen.add(key);
        }
        visit(entry.value, depth + 1, `${path}.${entry.key.value ?? index + 1}`);
      }
    } else if (node.type === "number" && !Number.isFinite(Number(node.value))) {
      errors.push(`${path}: número inválido.`);
    } else if (node.type === "raw" && !String(node.code ?? "").trim()) {
      errors.push(`${path}: código Luau vazio.`);
    } else if (!["string", "number", "boolean", "nil", "raw"].includes(node.type)) {
      errors.push(`${path}: tipo '${node.type}' não suportado.`);
    }
  }
  visit(ast, 0, "root");
  return errors;
}

function namedValue(table, name) {
  if (table?.type !== "table") return undefined;
  return table.entries.find((entry) => entry.key?.kind === "named" && entry.key.value === name)?.value;
}

export function analyzeAst(ast, relativePath = "") {
  const warnings = [];
  const insights = [];
  const nameNode = namedValue(ast, "Name");
  if (nameNode?.type === "string") insights.push(`Nome: ${nameNode.value}`);

  if (relativePath.includes("/Items/") && !relativePath.endsWith("/init.luau")) {
    for (const required of ["Name", "Class", "MaxStack"]) {
      if (!namedValue(ast, required)) warnings.push(`Item sem campo recomendado '${required}'.`);
    }
  }

  function visit(node, path) {
    if (node?.type !== "table") return;
    const weighted = node.entries
      .map((entry) => entry.value)
      .filter((value) => value?.type === "table" && namedValue(value, "Weight")?.type === "number");
    if (weighted.length > 0) {
      const total = weighted.reduce((sum, value) => sum + Number(namedValue(value, "Weight").value), 0);
      insights.push(`Pesos em ${path}: ${total}`);
      if (Math.abs(total - 100) > 0.001) warnings.push(`Os pesos em ${path} somam ${total}, não 100.`);
    }
    node.entries.forEach((entry, index) => visit(entry.value, `${path}.${entry.key?.value ?? index + 1}`));
  }
  visit(ast, "root");
  return { warnings, insights };
}
