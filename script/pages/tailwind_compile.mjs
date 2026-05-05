#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { compile } from "tailwindcss";

const __dirname = dirname(fileURLToPath(import.meta.url));
const TAILWIND_ENTRY = resolve(__dirname, "../../node_modules/tailwindcss/index.css");

const CLASS_REGEX = /class\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))/g;

const readStdin = () =>
  new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    process.stdin.on("error", reject);
  });

const extractCandidates = (html) => {
  const candidates = new Set();
  let match;
  while ((match = CLASS_REGEX.exec(html)) !== null) {
    const value = match[2] ?? match[3] ?? match[4] ?? "";
    for (const token of value.split(/\s+/)) {
      const trimmed = token.trim();
      if (trimmed.length > 0) candidates.add(trimmed);
    }
  }
  return [...candidates];
};

const main = async () => {
  const html = await readStdin();
  const candidates = extractCandidates(html);
  const entryCss = await readFile(TAILWIND_ENTRY, "utf8");
  const compiler = await compile(entryCss, { base: dirname(TAILWIND_ENTRY) });
  const css = compiler.build(candidates);
  process.stdout.write(css);
};

main().catch((err) => {
  process.stderr.write(`tailwind_compile failed: ${err.stack || err.message || err}\n`);
  process.exit(1);
});
