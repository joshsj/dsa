import pathLib from "path";
import fs from "fs/promises";
import fsSync from "fs";
import mustache from "mustache";
import katex from "katex";
import { marked } from "marked";
import yaml from "yaml";

const mustacheOptions = (() => {
	const importAliases = {
		"@lib": "../lib",
	}

	const unalias = path => {
		for (const alias in importAliases) {
			if (path.startsWith(alias)) {
				return path.replace(alias, importAliases[alias]);
			}
		};

		return path;
	};

	return {
		math() {
			return (text, render) => katex.renderToString(render(text));
		},

		include() {
			return path => fsSync.readFileSync(
				pathLib.resolve(import.meta.dirname, unalias(path)),
				"utf8"
			);
		}
	}
})();

const swallow = async p => {
	try {
		await p();
	} catch {}
};

(async () => {
	const { dirname: indexDir } = import.meta;
	const notesDir = pathLib.resolve(indexDir, "..", "notes");
	const configPath = pathLib.resolve(indexDir, "config.yml");
	const buildPath = pathLib.resolve(indexDir, "build", "index.html");

	console.log("Paths", { indexDir, notesDir, configPath, buildPath });

	const config = yaml.parse(await fs.readFile(configPath, "utf8"));

	for await (const page of config.pages) {
		const path = pathLib.resolve(notesDir, page.srcPath);
		console.log(`Building ${path}`);

		const markdownAndMustache = await fs.readFile(path, "utf8");
		const markdown = mustache.render(markdownAndMustache, mustacheOptions);

		page.html = marked.parse(markdown);
	}

	console.log("Building index.html")
	const indexMoustache = await fs.readFile(pathLib.resolve(indexDir, "index.html"), "utf8");
	const indexHtml = mustache.render(indexMoustache, config);

	console.log("Writing index.html");
	swallow(() => fs.mkdir("build"));
	await fs.writeFile(buildPath, indexHtml, "utf8");
})();
