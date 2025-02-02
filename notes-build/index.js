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
	const { dirname } = import.meta;
	const notesDir = pathLib.resolve(dirname, "..", "notes");

	const config = yaml.parse(await fs.readFile(pathLib.resolve(dirname, "config.yml"), "utf8"));

	for await (const page of config.pages) {
		const markdownAndMustache = await fs.readFile(
			pathLib.resolve(notesDir, page.Path),
			"utf8"
		);

		const markdown = mustache.render(markdownAndMustache, mustacheOptions);

		page.html = marked.parse(markdown);
	}

	const indexMoustache = await fs.readFile(pathLib.resolve(dirname, "index.html"), "utf8");
	const indexHtml = mustache.render(indexMoustache, config);

	swallow(() => fs.mkdir("build"));

	await fs.writeFile(pathLib.resolve(dirname, "build", "index.html"), indexHtml, "utf8");
})();
