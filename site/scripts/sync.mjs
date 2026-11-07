// Keeps the generated Markdown in step with its sources, so that nothing is copied by hand:
// - docs/options.md, from outskirts.schema.json;
// - the README sections between `<!-- docs:begin <page>#<anchor> -->` and `<!-- docs:end -->`, from docs/.
// `node scripts/sync.mjs` rewrites them; `--check` only compares, and also checks that every README link to
// outskirts.dev/docs points to an existing page and anchor.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DOCS_DIR, ORIGIN, REPO_DIR, SITE_DIR, loadPages, markdownHeadings, navigation, pageURL, resolveLink } from "./lib/docs.mjs";

const check = process.argv.includes("--check");
const problems = [];

/** Sections of the options reference, in order; every key of the schema belongs to exactly one. */
const CATEGORIES = [
  ["Project and build", ["project", "schemes", "build_arguments", "xcode_list_arguments", "clean_build", "skip_build", "skip_schemes_validation", "index_store_path", "strict_index", "json_package_manifest_path", "generic_project_config", "cache_max_age_days", "cache_max_size_gb"]],
  ["Files and scope", ["exclude_targets", "exclude_tests", "index_exclude", "report_exclude", "report_include", "retain_files", "changed_since", "changed_lines"]],
  ["Analyses", ["disable_redundant_public_analysis", "enable_redundant_public_members", "enable_open_final_analysis", "enable_empty_extension_analysis", "enable_redundant_access_level_analysis", "report_unused_type_parameters", "enable_unassigned_optional_analysis", "disable_unused_import_analysis", "enable_unused_system_imports", "superfluous_ignore_comments", "disable_platform_conditional_retention", "detect_unused_asset_catalog_colors", "detect_unused_asset_catalog_images", "detect_unused_metal_functions"]],
  ["Localized strings", ["disable_unused_localized_string_analysis", "localized_string_catalog_exclude", "localized_string_key_patterns", "localized_string_key_literal_match", "retain_runtime_localized_keys"]],
  ["Retention", ["retain_public", "retain_public_modules", "no_retain_spi", "retain_assign_only_properties", "retain_assign_only_property_types", "retain_objc_accessible", "retain_objc_annotated", "retain_js_accessible", "retain_unused_protocol_func_params", "retain_unused_parameters_without_default", "retain_swift_ui_previews", "retain_unused_imported_modules", "external_encodable_protocols", "external_codable_protocols", "external_test_case_classes", "retain_codable_properties", "retain_encodable_properties", "retain_equatable_properties", "retain_hashable_properties", "retain_synthesized_uses", "retain_attributes"]],
  ["Output", ["format", "relative_results", "relative_results_base", "write_results", "skip_stdout_results", "quiet", "verbose", "color", "strict", "disable_update_check"]],
  ["Baselines", ["baseline", "write_baseline", "prune_baseline", "strict_baseline"]],
];

/**
 * `scan` options that have no key in the configuration file, with the help of `outskirts help scan`, and the version
 * that added those absent from 3.20.0 (the next version, after the one in `Sources/Shared/Version.swift`).
 */
const COMMAND_LINE_ONLY = [
  ["--setup", "Guided setup: detects the project type, asks a few questions, then prints and runs the full scan command. Run it at the project root."],
  ["--project-root", "Root directory of the project, from which relative paths are resolved. Default: the current directory."],
  ["--config", "Configuration file. A relative path is resolved from `--project-root`. Default: `.outskirts.yml`, else `.periphery.yml`, in the project root."],
  ["--explain", "Explains why a declaration is reported, used or retained, before the results. Accepts a name (`draw()`, `draw` or `Beta.draw()`), a USR or a `file:line` location; repeat the option to explain several declarations, e.g. `--explain 'draw()' --explain Sources/Kit/Shape.swift:12`.", "3.22.0"],
];

/**
 * The version that added each configuration key absent from options-baseline.txt (the keys of the 3.20.0 schema).
 * Every new key needs an entry: the next version, after the one in `Sources/Shared/Version.swift`.
 */
const SINCE = { retain_public_modules: "3.21.0", strict_index: "3.21.0" };

/** Keys whose command line form is not `--` followed by the key in kebab case; `null` for configuration file only. */
const FLAGS = { build_arguments: "-- <args>", relative_results_base: "--relative-to", xcode_list_arguments: null };

for (const [file, generate] of [
  [join(DOCS_DIR, "options.md"), optionsReference],
  [join(REPO_DIR, "README.md"), readme],
]) {
  const expected = generate();
  const current = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (current === expected) continue;
  if (check) problems.push(`${file.slice(REPO_DIR.length + 1)} is out of date: run 'npm run sync' in site/ and commit the result`);
  else writeFileSync(file, expected);
}
if (check) checkReadmeLinks();

if (problems.length) {
  console.error(problems.join("\n"));
  process.exit(1);
}
console.log(check ? "ok: generated Markdown is up to date" : "synced docs/options.md and README.md");

// MARK: - Options reference

function optionsReference() {
  const schema = JSON.parse(readFileSync(join(REPO_DIR, "outskirts.schema.json"), "utf8"));
  const keys = Object.keys(schema.properties);
  const categorized = CATEGORIES.flatMap(([, list]) => list);
  for (const key of keys) {
    if (!categorized.includes(key)) throw new Error(`'${key}' has no section in CATEGORIES of site/scripts/sync.mjs`);
  }
  for (const key of categorized) {
    if (!keys.includes(key)) throw new Error(`CATEGORIES of site/scripts/sync.mjs names '${key}', which is not in outskirts.schema.json`);
  }

  const baseline = readFileSync(join(SITE_DIR, "scripts/options-baseline.txt"), "utf8").split("\n").filter(Boolean);
  for (const key of keys) {
    if (!baseline.includes(key) && !SINCE[key]) throw new Error(`'${key}' is new: give it a version in SINCE of site/scripts/sync.mjs`);
  }
  for (const [key, version] of Object.entries(SINCE)) {
    if (!keys.includes(key)) throw new Error(`SINCE of site/scripts/sync.mjs names '${key}', which is not in outskirts.schema.json`);
    if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`SINCE of site/scripts/sync.mjs: '${version}' is not a version`);
  }

  const references = crossReferences();
  const lines = [
    "---",
    "description: Every option of outskirts scan, with its configuration key, type and default, generated from the JSON Schema of the configuration file.",
    "---",
    "",
    "# Options",
    "",
    "Every option of the `scan` command, with its key in the configuration file, its type and its default. Run `outskirts help scan` for the help of your version, and see [Configuration](configuration.md) for how the command line and the file combine.",
    "",
    "- Every option that takes no value, except `--setup` and `--skip-stdout-results`, also has a `--no-` form, e.g. `--no-strict`.",
    "- Options that take a list accept several values after one flag, e.g. `--exclude-targets A B`; in the file, a single value is read as a list of one.",
    "- Relative paths are resolved from `--project-root`.",
    "",
    "This page is generated from [`outskirts.schema.json`](https://github.com/tiny-earth-moon/outskirts/blob/master/outskirts.schema.json), itself generated by `outskirts config schema`.",
    "",
    "## Command line only",
    "",
  ];
  for (const [flag, description, version] of COMMAND_LINE_ONLY) {
    const since = version ? [`Since ${version}.`, ""] : [];
    lines.push(`### \`${flag}\``, "", ...since, description, "", ...seeAlso(references, [flag]));
  }
  for (const [title, list] of CATEGORIES) {
    lines.push(`## ${title}`, "");
    for (const key of list) lines.push(...option(key, schema.properties[key], references));
  }
  lines.push(
    "## Other commands",
    "",
    "`outskirts check-update`, `outskirts clear-cache`, `outskirts config check`, `outskirts config schema` and `outskirts version`: see [Commands](getting-started.md#commands).",
    "",
  );
  return lines.join("\n");
}

function option(key, property, references) {
  const flag = key in FLAGS ? FLAGS[key] : `--${key.replaceAll("_", "-")}`;
  const heading = flag ? `### \`${flag}\`` : `### \`${key}\``;
  const facts = [`Key \`${key}\``];
  if (!flag) facts.push("configuration file only");
  facts.push(describeType(property, flag));
  facts.push(`default ${describeDefault(property)}`);
  const description = property.description.replace(/\s*\(command line: --[a-z-]+\)/, "").trim();
  const extra = key === "color" ? " `--no-color` is a hidden alias of `--color never`." : "";
  const since = SINCE[key] ? [`Since ${SINCE[key]}.`, ""] : [];
  return [heading, "", ...since, `${description}${extra}`, "", `${facts.join(" · ")}.`, "", ...seeAlso(references, [flag, key].filter(Boolean))];
}

function describeType(property, flag) {
  if (property.enum) return `one of ${property.enum.map((v) => `\`${v}\``).join(", ")}`;
  if (Array.isArray(property.type) && property.type.includes("boolean")) {
    return `${describeType({ type: "boolean" }, flag)}, or in the file a list of strings`;
  }
  const type = Array.isArray(property.type) ? "list" : property.type ?? "list";
  if (type === "boolean") return flag && !["--setup", "--skip-stdout-results"].includes(flag) ? `flag, \`--no-${flag.slice(2)}\` to switch off` : "flag";
  if (type === "list" || type === "array") return "list of strings";
  return type;
}

function describeDefault(property) {
  if (!("default" in property)) return "none";
  const value = property.default;
  if (Array.isArray(value)) return value.length ? value.map((v) => `\`${v}\``).join(", ") : "empty";
  return `\`${value}\``;
}

function seeAlso(references, tokens) {
  const found = [];
  for (const token of tokens) {
    for (const reference of references.get(token) ?? []) {
      if (!found.some((f) => f.link === reference.link)) found.push(reference);
    }
  }
  if (!found.length) return [];
  return [`See ${found.slice(0, 4).map((f) => `[${f.label}](${f.link})`).join(", ")}.`, ""];
}

/** Where each `--flag` or `key` is written in backticks in the other pages, as links to the enclosing section. */
function crossReferences() {
  const references = new Map();
  const pages = loadPages();
  const ordered = navigation(pages).flatMap((group) => group.items.map((item) => item.page));
  for (const page of [...ordered, ...pages.filter((p) => !ordered.includes(p))]) {
    if (["options.md", "README.md", "../CHANGELOG.md"].includes(page.file)) continue;
    const headings = markdownHeadings(page.body);
    let section = null;
    let index = 0;
    let fence = false;
    for (const line of page.body.split("\n")) {
      if (/^\s*```/.test(line)) fence = !fence;
      if (fence) continue;
      if (/^#{1,6}\s/.test(line)) {
        section = headings[index++];
        continue;
      }
      for (const match of line.matchAll(/`(--[a-z-]+|[a-z]+(?:_[a-z]+)+)(?=[`\s:=])/g)) {
        const token = match[1];
        const target = section && section.level > 1 ? section : null;
        const link = target ? `${page.file}#${target.slug}` : page.file;
        const label = target ? `${page.title}: ${target.text.replace(/`/g, "")}` : page.title;
        const list = references.get(token) ?? [];
        if (!list.some((r) => r.link === link)) list.push({ link, label });
        references.set(token, list);
      }
    }
  }
  return references;
}

// MARK: - README

function readme() {
  const pages = loadPages();
  const source = readFileSync(join(REPO_DIR, "README.md"), "utf8");
  return source.replace(/(<!-- docs:begin ([a-z-]*)(?:#([a-z0-9-]+))? -->\n)[\s\S]*?(<!-- docs:end -->)/g, (_, begin, name, anchor, end) => {
    if (name === "nav") return `${begin}\n${navigationList(pages)}\n\n${end}`;
    const page = pages.find((p) => p.name === name);
    if (!page) throw new Error(`README.md: docs:begin names '${name}', which is not a documentation page`);
    return `${begin}\n${extract(page, anchor)}\n\n${end}`;
  });
}

function navigationList(pages) {
  return navigation(pages)
    .map((group) => `- **${group.title}**: ${group.items.map((i) => `[${i.title}](${ORIGIN}${pageURL(i.page.name)})`).join(", ")}`)
    .join("\n");
}

/** The body of the section `anchor` of a page (without its heading), with links made absolute. */
function extract(page, anchor) {
  const lines = page.body.split("\n");
  const headings = markdownHeadings(page.body);
  const target = headings.find((h) => h.slug === anchor);
  if (!target) throw new Error(`README.md: ${page.source} has no section '#${anchor}'`);
  let index = 0;
  let fence = false;
  let start = -1;
  let end = lines.length;
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*```/.test(lines[i])) fence = !fence;
    if (fence || !/^#{1,6}\s/.test(lines[i])) continue;
    const heading = headings[index++];
    if (heading === target) start = i + 1;
    else if (start >= 0 && heading.level <= target.level) {
      end = i;
      break;
    }
  }
  return lines
    .slice(start, end)
    .join("\n")
    .trim()
    .replace(/(!?)\[([^\]]*)\]\(([^)\s]+)\)/g, (all, bang, text, href) => (bang ? all : `[${text}](${resolveLink(href, page.file, { absolute: true })})`));
}

function checkReadmeLinks() {
  const pages = loadPages();
  const source = readFileSync(join(REPO_DIR, "README.md"), "utf8");
  for (const match of source.matchAll(/https:\/\/outskirts\.dev(\/docs\/[^)\s"#]*)(?:#([^)\s"]+))?/g)) {
    const [, path, anchor] = match;
    const page = pages.find((p) => pageURL(p.name) === path);
    if (!page) {
      problems.push(`README.md links to ${ORIGIN}${path}, which is not a documentation page`);
      continue;
    }
    if (anchor && !markdownHeadings(page.body).some((h) => h.slug === anchor)) {
      problems.push(`README.md links to ${ORIGIN}${path}#${anchor}, which has no such section`);
    }
  }
}
