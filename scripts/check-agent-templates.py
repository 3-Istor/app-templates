#!/usr/bin/env python3
"""Check the agent templates of agents/ before the CMP lists them.

Each file matches agents/schema.json and is named after its id; its defaults
(and an actor's) validate against the agent: block of infra-templates'
values.schema.json, the chart that renders them; and the tools it suggests
never add up to the three risks of the Rule of Two: untrusted content,
private data, and a way out (writes or external send).

Usage: check-agent-templates.py <infra-templates values.schema.json>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

AGENTS_DIR = Path(__file__).resolve().parent.parent / "agents"
WAYS_OUT = {"writes", "external_send"}


def risks(suggested: list[dict]) -> set[str]:
    return {badge for tool in suggested for badge in tool["badges"]}


def check(path: Path, template_schema: Draft202012Validator, agent_schema: Draft202012Validator) -> list[str]:
    template = yaml.safe_load(path.read_text(encoding="utf-8"))
    errors = [f"{path.name}: {'/'.join(map(str, e.absolute_path)) or '<root>'}: {e.message}" for e in template_schema.iter_errors(template)]
    if errors:
        return errors
    if template["id"] != path.stem:
        errors.append(f"{path.name}: id '{template['id']}' does not match the filename")

    agents = [("defaults", template["defaults"], template["suggestedTools"], template["recommended"])]
    if "pair" in template:
        actor = template["pair"]["actor"]
        agents.append(("pair.actor.defaults", actor["defaults"], actor["suggestedTools"], actor["recommended"]))

    for where, defaults, suggested, recommended in agents:
        for error in agent_schema.iter_errors(defaults):
            errors.append(f"{path.name}: {where}/{'/'.join(map(str, error.absolute_path))}: {error.message}")
        if defaults.get("template") != template["id"]:
            errors.append(f"{path.name}: {where}.template must be '{template['id']}'")
        if defaults.get("model") not in recommended["models"]:
            errors.append(f"{path.name}: {where}.model is not one of its recommended models")
        badges = risks(suggested)
        if {"untrusted_content", "private_data"} <= badges and badges & WAYS_OUT:
            errors.append(
                f"{path.name}: {where} suggests tools that combine untrusted content, private data "
                f"and {', '.join(sorted(badges & WAYS_OUT))}: split it into a reader and an actor"
            )
        names = {tool["name"] for tool in suggested if "name" in tool}
        for tool in defaults.get("tools", []):
            if "__" not in tool and tool not in names:
                errors.append(f"{path.name}: {where} enables {tool} without suggesting it with its badges")
    return errors


def main() -> int:
    chart_schema = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    agent_block = chart_schema.get("properties", {}).get("agent")
    if agent_block is None:
        print("✗ the infra-templates schema has no agent block", file=sys.stderr)
        return 1
    agent_block = {**agent_block, "definitions": chart_schema.get("definitions", {})}
    agent_schema = Draft202012Validator(agent_block)
    template_schema = Draft202012Validator(json.loads((AGENTS_DIR / "schema.json").read_text(encoding="utf-8")))

    paths = sorted(AGENTS_DIR.glob("*.yaml"))
    errors = [error for path in paths for error in check(path, template_schema, agent_schema)]
    if errors:
        print(f"✗ {len(errors)} agent template problem(s):", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    print(f"✓ {len(paths)} agent template(s) valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
