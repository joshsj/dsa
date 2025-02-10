import pathLib from "path";
import fs from "fs/promises";
import fsSync from "fs";
import mustache from "mustache";
import katex from "katex";
import { marked } from "marked";
import yaml from "yaml";

const createMustacheOptions = config => {
	const aliases = {
		"@lib": "../lib",
		"@notes": "../notes",
	};

	const unalias = path => {
		const alias = Object.keys(aliases).find(alias => path.startsWith(alias));

		return alias ? path.replace(alias, aliases[alias]) : path;
	};

	const expand = path =>
		pathLib.isAbsolute(path)
			? path
			: pathLib.resolve(import.meta.dirname, unalias(path));

	return {
		math() {
			return (text, render) => katex.renderToString(render(text));
		},

		dmath() {
			return (text, render) => katex.renderToString(render(text), { displayMode: true });
		},

		bigo() {
			return (text, render) => this.math()(`O(${text})`, render);
		},

		include() {
			const rangeRegex = /^(?<path>.+)\[(?<start>\d+)\.\.(?<end>\d+)\]$/;

			return path => {
				path = path.trim();

				const match = rangeRegex.exec(path);

				if (!match) {
					return fsSync.readFileSync(expand(path), "utf8");
				}

				let { start, end } = match.groups;

				return fsSync
					.readFileSync(expand(match.groups.path), "utf8")
					.split("\n")
					.slice(parseInt(start) - 1, parseInt(end))
					.join("\n");
			};

		},

		aside() {
			return (text, render) => `<aside>${render(text)}</aside>`;
		},

		ref() {
			return text => {
				const { title, url } = config.references.find(x => x.id === text);

				return `[${title}](${url})`;
			}
		}
	}
};

const ensureDir = async dir => {
	try {
		await fs.mkdir(dir, { recursive: true });
	} catch { }
};

const paths = (() => {
	const root = import.meta.dirname;
	const p = (...parts) => pathLib.resolve(root, ...parts);
	const buildDir = process.argv[2] || p("build");

	return {
		root,
		buildDir,
		notesDir: p("..", "notes"),
		templatesDir: p("templates"),
		staticDir: p("static"),
		configPath: p("config.yml"),
	};
})();

const config = yaml.parse(await fs.readFile(paths.configPath, "utf8"));

(async () => {
	console.log("Paths", paths);

	const mustacheOptions = createMustacheOptions(config);

	const templates = {
		index: await fs.readFile(pathLib.join(paths.templatesDir, "index.html"), "utf8"),
		page: await fs.readFile(pathLib.join(paths.templatesDir, "page.html"), "utf8"),
	};

	console.log("Creating build directory");
	await ensureDir(paths.buildDir);

	for await (const page of config.pages) {
		console.log(`Building ${page.srcPath}`);

		const markdownAndMustache = await fs.readFile(pathLib.resolve(paths.notesDir, page.srcPath), "utf8");
		const markdown = mustache.render(markdownAndMustache, mustacheOptions);

		page.body = marked.parse(markdown);
		page.url = page.srcPath.replace(".md", "");

		const pageHtml = mustache.render(templates.page, page);
		await ensureDir(pathLib.join(paths.buildDir, page.url));

		console.log(`Writing ${page.url}`);
		await fs.writeFile(pathLib.join(paths.buildDir, page.url, "index.html"), pageHtml, "utf8");
	}

	console.log("Building index.html");
	const indexHtml = mustache.render(templates.index, config);

	console.log("Writing index.html");
	await fs.writeFile(pathLib.join(paths.buildDir, "index.html"), indexHtml, "utf8");

	console.log("Copying static files");
	const staticFileNames = await fs.readdir(paths.staticDir, "utf8");

	await Promise.all(
		staticFileNames.map(
			x => fs.copyFile(pathLib.join(paths.staticDir, x), pathLib.join(paths.buildDir, x))
		)
	);
})();
