"""Regression checks for the repository gates. Run with unittest discovery."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools import check_project as gate


class RepositoryGuardrailTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()

    def write(self, name, content):
        path = Path(name)
        (self.root / path.parent).mkdir(parents=True, exist_ok=True)
        (self.root / path).write_text(content, encoding="utf-8")
        return path

    def test_markdown_checks_file_from_document_directory(self):
        self.write("docs/a guide.md", "# Guide")
        text = "[Guide](<a guide.md#readme>)\n[Absent](missing.md)\n[External](https://example.org/)"
        issues = list(gate.markdown_issues(self.root, Path("docs/index.md"), text))
        self.assertEqual(len(issues), 1)
        self.assertIn("missing.md", issues[0])

    def test_markdown_ignores_example_links_in_code(self):
        fence = chr(96) * 3
        text = f"{fence}md\n[Example](absent.md)\n{fence}\n"
        self.assertEqual(list(gate.markdown_issues(self.root, Path("README.md"), text)), [])

    def test_markdown_rejects_links_outside_repository(self):
        issues = list(gate.markdown_issues(self.root, Path("README.md"), "[Parent](../)"))
        self.assertEqual(len(issues), 1)

    def test_github_root_relative_links_resolve_from_nested_documents(self):
        self.write("CONTRIBUTING.md", "# Contributing")
        text = "[Contribute](/CONTRIBUTING.md)"
        self.assertEqual(list(gate.markdown_issues(self.root, Path("docs/guide.md"), text)), [])

    def test_model_checks_interface_and_implementation_imports(self):
        text = """unit OTel.Model.Trace;
interface
uses System.SysUtils, FireDAC.Comp.Client;
implementation
uses (* imported below *) OTel.View.Protobuf in 'View.pas', System.Classes;
end."""
        issues = list(gate.model_issues(Path("Trace.pas"), text))
        self.assertEqual(len(issues), 2)
        self.assertIn("FireDAC.Comp.Client", issues[0])
        self.assertIn("OTel.View.Protobuf", issues[1])

    def test_comments_literals_and_transport_units_do_not_trigger_model_check(self):
        text = """unit OTel4D.Model.Trace;
interface
uses System.SysUtils;
{ uses Vcl.Forms; }
implementation
// uses FMX.Forms;
const Msg = 'It''s fine to mention uses FireDAC.Comp.Client;';
end."""
        self.assertEqual(list(gate.model_issues(Path("Trace.pas"), text)), [])
        adapter = "unit OTel.Transport.HTTP; interface uses System.Net.HttpClient; implementation end."
        self.assertEqual(list(gate.model_issues(Path("HTTP.pas"), adapter)), [])

    def test_secret_scan_redacts_values_and_reports_line(self):
        example = "gh" + "p_" + ("A" * 36)
        path = self.write("demo.ini", "first line\n" + example)
        issues = list(gate.file_issues(self.root, path, set()))
        self.assertEqual(len(issues), 1)
        self.assertIn(":2:", issues[0])
        self.assertNotIn(example, issues[0])

    def test_ignored_files_stay_out_but_tracked_ide_files_are_reported(self):
        def git(*args):
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

        git("init", "--quiet")
        self.write(".gitignore", "*.dproj.local\n")
        path = self.write("Demo.dproj.local", "IDE state")
        self.assertNotIn(path, gate.repository_files(self.root))
        git("add", "--force", str(path))
        self.assertIn(path, gate.repository_files(self.root))
        self.assertTrue(list(gate.file_issues(self.root, path, set())))

    def test_skill_discovery_requires_the_directory_name_and_description(self):
        path = Path(".agents/skills/trace-test/SKILL.md")
        valid = "---\nname: trace-test\ndescription: Verify a trace.\n---\nRun the check."
        self.assertEqual(list(gate.skill_issues(path, valid)), [])
        self.assertTrue(list(gate.skill_issues(path, valid.replace("trace-test", "wrong"))))
        self.assertTrue(list(gate.skill_issues(path, valid.replace("description:", "notes:"))))

    def test_empty_or_malformed_skill_descriptions_fail(self):
        path = Path(".agents/skills/trace-test/SKILL.md")
        for invalid in ("# add documentation", ">", "Run checks: lint and tests", "null"):
            with self.subTest(invalid=invalid):
                content = f"---\nname: trace-test\ndescription: {invalid}\n---\nTest."
                self.assertTrue(list(gate.skill_issues(path, content)))

    def test_agent_roles_have_required_fields_and_unique_names(self):
        path = Path(".codex/agents/reviewer.toml")
        valid = 'name = "reviewer"\ndescription = "Review"\ndeveloper_instructions = "Inspect"'
        names = set()
        self.assertEqual(list(gate.agent_issues(path, valid, names)), [])
        self.assertTrue(list(gate.agent_issues(path, valid, names)))
        self.assertTrue(list(gate.agent_issues(path, "[broken", set())))
        self.assertTrue(list(gate.agent_issues(path, 'name = "reviewer"', set())))

    def test_rule_table_rejects_duplicate_or_missing_identifiers(self):
        path = self.write("docs/engineering/AI_GUARDRAILS.md", "| AI-001 | One |\n" * 28)
        self.assertTrue(list(gate.file_issues(self.root, path, set())))

    def test_template_protects_both_gitflow_branches_with_the_ci_job(self):
        config = json.loads((gate.ROOT / ".github/rulesets/gitflow.json").read_bytes())
        self.assertEqual(set(config["conditions"]["ref_name"]["include"]), {"refs/heads/main", "refs/heads/develop"})
        rules = {rule["type"]: rule.get("parameters") for rule in config["rules"]}
        self.assertIn("non_fast_forward", rules)
        self.assertIn("deletion", rules)
        self.assertGreaterEqual(rules["pull_request"]["required_approving_review_count"], 1)
        checks = rules["required_status_checks"]["required_status_checks"]
        workflow = (gate.ROOT / ".github/workflows/quality.yml").read_text(encoding="utf-8")
        self.assertIn("Repository checks", {check["context"] for check in checks})
        self.assertIn("    name: Repository checks", workflow.splitlines())
