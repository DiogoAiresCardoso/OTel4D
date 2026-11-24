"""Run OTel4D's dependency-free repository checks (Python 3.11+)."""

import os
from pathlib import Path
import re
import subprocess
import sys
import tomllib
from xml.etree import ElementTree
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
POLICIES = (
    "PRINCIPLES ARCHITECTURE CODING_STANDARDS REUSABILITY SECURITY_STANDARDS "
    "TESTING_STANDARDS UI_UX_STANDARDS QUALITY_GATES DEFINITION_OF_DONE AI_GUARDRAILS"
).split()
REQUIRED = {
    "AGENTS.md", "source/AGENTS.md", "tests/AGENTS.md", "README.md", "CONTRIBUTING.md",
    "GOVERNANCE.md", "CODE_OF_CONDUCT.md", "SECURITY.md", "LICENSE", "CHANGELOG.md",
    ".github/pull_request_template.md", ".github/CODEOWNERS", ".github/workflows/quality.yml",
    ".github/rulesets/gitflow.json", ".codex/rules/git-safety.rules",
    "docs/adr/0001-library-mvc-and-otlp-http.md", "docs/adr/0003-hexagonal-telemetry.md",
    *(f"docs/engineering/{name}.md" for name in POLICIES),
}
GENERATED_SUFFIXES = (".dproj.local", ".groupproj.local", ".identcache", ".dsk", ".dcu", ".dcp", ".bpl", ".tds", ".stat")
SECRET_MARKERS = re.compile(
    r"-----BEGIN (?:OPENSSH |RSA |EC |DSA |ENCRYPTED )?PRIVATE KEY-----"
    r"|\bgh[pousr]_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{50,}\b"
)
PASCAL_NONCODE = re.compile(r"'(?:''|[^'\r\n])*'|//[^\n]*|\{[^}]*\}|\(\*.*?\*\)", re.S)
PASCAL_CLASS = re.compile(
    r"\b([a-z_]\w*)\s*(?:<[^<>]*(?:<[^<>]*>[^<>]*)*>)?\s*=\s*class\b(?!\s*(?:of\b|;))",
    re.I,
)
FORBIDDEN_IMPORTS = (
    "vcl", "fmx", "firedac", "system.net", "otel.view", "otel.controller",
    "otel.transport", "otel4d.view", "otel4d.controller", "otel4d.transport",
    "otel.codec", "otel4d.codec", "system.json", "idhttp",
)
MD_LINK = re.compile(r"\[[^\]\n]*\]\((?:<([^>\n]+)>|([^\s)]+))(?:\s+\"[^\"]*\")?\)")


def repository_files(root):
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root, check=True, stdout=subprocess.PIPE,
    )
    return sorted({Path(os.fsdecode(name)) for name in result.stdout.split(b"\0") if name})


def markdown_issues(root, path, content):
    fence = None
    for number, line in enumerate(content.splitlines(), 1):
        marker = re.match(r"^[ ]{0,3}(\x60{3,}|~{3,})(.*)$", line)
        if marker:
            value, rest = marker.groups()
            if fence is None:
                fence = value
            elif value[0] == fence[0] and len(value) >= len(fence) and not rest.strip():
                fence = None
            continue
        if fence:
            continue
        for match in MD_LINK.finditer(re.sub(r"\x60[^\x60]*\x60", "", line)):
            target = (match[1] or match[2]).split("#", 1)[0]
            if not target or re.match(r"^(?:[a-z][a-z0-9+.-]*:|//)", target, re.I):
                continue
            relative = unquote(target)
            base = root if relative.startswith("/") else root / path.parent
            destination = (base / relative.lstrip("/")).resolve()
            if not destination.is_relative_to(root) or not destination.exists():
                yield f"{path}:{number}: unresolved repository link: {relative}"


PLATFORM_IMPORTS = ("winapi", "system.win", "vcl", "fmx", "firedac", "system.net",
                    "data.win", "system.ioutils", "idhttp")
ALLOWED_CORE_LAYERS = {"domain": {"domain"}, "application": {"domain", "application"}}


def delphi_imports(code):
    for clause in re.finditer(r"\buses\s+(.*?);", code, re.I | re.S):
        for unit in clause[1].split(","):
            identifier = re.match(r"\s*([\w.]+)", unit)
            if identifier:
                yield identifier[1]


def layer_issues(path, content, units):
    if len(path.parts) < 3 or path.parts[0] != "source":
        return
    layer = path.parts[1]
    if layer not in ALLOWED_CORE_LAYERS:
        return
    for imported in delphi_imports(PASCAL_NONCODE.sub(" ", content)):
        name = imported.lower()
        target = units.get(name)
        if target and target.parts[1] not in ALLOWED_CORE_LAYERS[layer]:
            yield f"{path}: {layer} depends on outer unit {imported}"
        if any(name == prefix or name.startswith(prefix + ".") for prefix in PLATFORM_IMPORTS):
            yield f"{path}: {layer} depends on platform unit {imported}"


def package_issues(root, package):
    project = package.with_suffix(".dproj")
    if not (root / project).is_file():
        return
    code = (root / package).read_text(encoding="utf-8-sig", errors="replace")
    declarations = {name.replace("\\", "/").lower() for name in
                    re.findall(r"\bin\s+'([^']+\.pas)'", code, re.I)}
    references = {node.attrib["Include"].replace("\\", "/").lower()
                  for node in ElementTree.parse(root / project).iter()
                  if node.tag.endswith("DCCReference") and node.attrib["Include"].lower().endswith(".pas")}
    if declarations != references:
        yield f"{package}: unit references differ from {project}: {sorted(declarations ^ references)}"


def model_issues(path, content):
    code = PASCAL_NONCODE.sub(" ", content)
    if not re.search(r"\bunit\s+otel(?:4d)?\.model(?:\.|\s*;)", code, re.I):
        return
    for clause in re.finditer(r"\buses\s+(.*?);", code, re.I | re.S):
        for unit in clause[1].split(","):
            identifier = re.match(r"\s*([\w.]+)", unit)
            if identifier:
                name = identifier[1].lower()
                if any(name == prefix or name.startswith(prefix + ".") for prefix in FORBIDDEN_IMPORTS):
                    yield f"{path}: Model depends on {identifier[1]}"


def unit_class_issues(path, content):
    # Keep newlines in masked comments and literals so findings point at declarations.
    code = PASCAL_NONCODE.sub(lambda match: re.sub(r"[^\r\n]", " ", match[0]), content)
    first = None
    for match in PASCAL_CLASS.finditer(code):
        name = match[1]
        if first is None:
            first = name
        elif name.casefold() != first.casefold():
            line = code.count("\n", 0, match.start()) + 1
            yield f"{path}:{line}: {name} must have its own unit. This file already defines {first}."


def skill_issues(path, content):
    front = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", content, re.S)
    if not front:
        yield f"{path}: missing skill front matter"
        return
    # Project metadata uses single-line plain scalars for both discovery fields.
    entries = re.findall(r"^(name|description):[ \t]+(.*)$", front[1], re.M)
    fields = dict(entries)
    if len(fields) != len(entries):
        yield f"{path}: duplicate skill metadata key"
    name = fields.get("name", "").strip()
    if name != path.parent.name or len(name) > 64 or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        yield f"{path}: skill name must match its hyphenated directory"
    description = re.split(r"(?:^|\s)#", fields.get("description", ""), maxsplit=1)[0].strip()
    if (not description or description[0] in "|>!&*{}[]'\"%@`"
            or re.search(r":(?:\s|$)", description)
            or description.lower() in {"true", "false", "null", "~"}):
        yield f"{path}: expected a nonempty, single-line plain YAML description"


def agent_issues(path, content, names):
    try:
        config = tomllib.loads(content)
    except tomllib.TOMLDecodeError as exc:
        yield f"{path}: invalid agent TOML ({exc})"
        return
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(config.get(field), str) or not config[field].strip():
            yield f"{path}: missing agent {field}"
    name = config.get("name")
    if isinstance(name, str):
        if name in names:
            yield f"{path}: duplicate agent name {name}"
        names.add(name)


def file_issues(root, path, names):
    location = root / path
    if location.is_symlink():
        # Check the Git path inventory without following links outside the checkout.
        return
    if path.name.lower().endswith(GENERATED_SUFFIXES):
        yield f"{path}: local Delphi build or IDE artifact"
        return
    content = location.read_bytes()
    if b"\0" in content[:8192]:
        return
    # Delphi source may use a legacy Windows encoding. Policy markers are ASCII.
    source = content.decode("utf-8-sig", errors="replace")
    for number, line in enumerate(source.splitlines(), 1):
        if SECRET_MARKERS.search(line):
            yield f"{path}:{number}: possible credential (value withheld)"
    if path.suffix.lower() == ".md":
        yield from markdown_issues(root, path, source)
    if path.match(".agents/skills/*/SKILL.md"):
        yield from skill_issues(path, source)
    if path.match(".codex/agents/*.toml"):
        yield from agent_issues(path, source, names)
    extension = path.suffix.lower()
    if extension in {".pas", ".dpr", ".dpk"}:
        yield from unit_class_issues(path, source)
    if extension == ".pas":
        yield from model_issues(path, source)
    if path.as_posix() == "docs/engineering/AI_GUARDRAILS.md":
        actual = re.findall(r"^\| (AI-\d{3}) \|", source, re.M)
        if actual != [f"AI-{number:03}" for number in range(1, 29)]:
            yield f"{path}: expected one row each for AI-001 through AI-028 in order"


def project_issues(root):
    paths = [p for p in repository_files(root) if (root / p).is_symlink() or (root / p).is_file()]
    present = {p.as_posix() for p in paths}
    for missing in sorted(REQUIRED - present):
        yield f"{missing}: required project file is missing"
    for pattern in (".agents/skills/*/SKILL.md", ".codex/agents/*.toml"):
        if not any(p.match(pattern) for p in paths):
            yield f"{pattern}: missing project configuration"
    names = set()
    units = {path.stem.lower(): path for path in paths
             if len(path.parts) > 2 and path.parts[0] == "source" and path.suffix.lower() == ".pas"}
    for path in paths:
        yield from file_issues(root, path, names)
        if units.get(path.stem.lower()) == path and not (root / path).is_symlink():
            yield from layer_issues(path, (root / path).read_text(encoding="utf-8-sig", errors="replace"), units)
        if path.suffix.lower() == ".dpk":
            yield from package_issues(root, path)


if __name__ == "__main__":
    problems = list(project_issues(ROOT))
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        sys.exit(1)
    print("Repository checks passed.")
