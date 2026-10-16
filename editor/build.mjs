// Bundles src/main.js into ../Resources/editor/editor.js and copies index.html next to it.
import { build } from "esbuild";
import { copyFileSync, mkdirSync } from "node:fs";

const out = new URL("../Resources/editor/", import.meta.url).pathname;
mkdirSync(out, { recursive: true });
await build({
  entryPoints: ["src/main.js"], bundle: true, minify: true, format: "iife", target: "safari17",
  legalComments: "none", outfile: `${out}editor.js`,
});
copyFileSync("src/index.html", `${out}index.html`);
