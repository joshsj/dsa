import pathLib from "path";
import fs from "fs/promises";
import fsSync from "fs";
import mustache from "mustache";
import katex from "katex";
import { marked } from "marked";
import yaml from "yaml";

function frow(err) {
	throw err;
}

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

	const byId = (prop, id) => {
		id = id.trim();

        return config[prop].find(x => x.id === id) || frow(`Could not find ${id} in ${prop}`);
    };

	const renamed = text => {
		const [id, rename, ...rest] = text.split(":").map(x => x.trim());

		if (rest.length) {
			throw `'${text}' is malformed`;
		}

		return { id, rename };
	};

	// Render functions append \n to ensure markdown renderer will not preserve the source
	return {
		math() {
			return (text) => katex.renderToString(text);
		},

		dmath() {
			return (text) => katex.renderToString(text, { displayMode: true });
		},

		bigo() {
			return (text, render) => this.math()(`O(${text})`, render);
		},

		dfn() {
			return id => {
				const { title, definition } = byId("terms", id);

                return `<dfn title="${definition}">${title.toLowerCase()}</dfn>`;
            };
		},

		dl() {
			return lines => {
				lines = lines.trim();

				let { terms } = config;

				if (lines !== "*") {
					const ids = lines.split(/[ \t\n]/).filter(x => x).map(x => x.trim());
					terms = config.terms.filter(x => ids.includes(x.id));
				}

				const defs = terms.map(({ title, definition, see }) => {
					// TODO: idk how I wan't this to look, title attr will do for now
					const seeDefs = see?.length ? "See: " + see.map(x => byId("terms", x).title).join(", ") : "";

					return `<dt title="${seeDefs}">${title}</dt><dd>${definition}</dd>`;
				}).join("");

				return `<dl>${defs}</dl>\n`;
			};
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
			return (text, render) => `<aside>\n\n${render(text)}\n\n</aside>\n`;
		},

		ref() {
			return text => {
				const { id, rename } = renamed(text);
				const { title, url } = byId("references", id);

				return `[${rename || title}](${url})`;
			}
		},

		page() {
			return text => {
				const { id, rename } = renamed(text);
				const { title, url, hidden } = byId("pages", id);
				const displayText = rename || title.toLowerCase();

				return !hidden ? `[${displayText}](../${url})` : displayText;
			};
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
	const notesDir = p("..", "notes");

	return {
		root,
		buildDir,
		notesDir,
		templatesDir: p("templates"),
		staticDir: p("static"),
		configPath: pathLib.resolve(notesDir, "config.yml"),
	};
})();


(async () => {
	const config = yaml.parse(await fs.readFile(paths.configPath, "utf8"));

	console.log("Paths", paths);

	const mustacheContext = { ...config, ...createMustacheOptions(config) };

	const templates = {
		index: await fs.readFile(pathLib.join(paths.templatesDir, "index.html"), "utf8"),
		page: await fs.readFile(pathLib.join(paths.templatesDir, "page.html"), "utf8"),
	};

	for (const page of config.pages) {
		page.url = page.srcPath.replace(".md", "");
	}

	console.log("Creating build directory");
	await ensureDir(paths.buildDir);

	for (const page of config.pages) {
		console.log(`Building ${page.srcPath}`);

		const markdownAndMustache = await fs.readFile(pathLib.resolve(paths.notesDir, page.srcPath), "utf8");
		const markdown = mustache.render(markdownAndMustache, mustacheContext);

		page.body = marked.parse(markdown);

		const pageHtml = mustache.render(templates.page, { this: page, ...mustacheContext, });
		await ensureDir(pathLib.join(paths.buildDir, page.url));

		console.log(`Writing ${page.url}`);
		await fs.writeFile(pathLib.join(paths.buildDir, page.url, "index.html"), pageHtml, "utf8");
	}

	console.log("Building index.html");
	const indexHtml = mustache.render(templates.index, mustacheContext);

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
