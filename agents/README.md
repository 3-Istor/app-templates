# Agent templates

Presets of the CMP agent wizard, one file per template: `agents/<id>.yaml`. The CMP reads them from its
clone of this repository (`GET /api/ai/templates`); the wizard copies `defaults` into the agent's
`deploy/values-<agent>.yaml` (key `agent:`), which infra-templates renders into kagent objects.

| id | Pour | Déclencheur | Outils par défaut |
| --- | --- | --- | --- |
| `assistant` | assistant généraliste à façonner | chat | aucun |
| `docs-qa` | questions sur la documentation, sources citées | chat | outils de recherche du projet |
| `data-analyst` | chiffres, tableaux, graphiques (code mode) | chat | `run_python` + lecture des données |
| `app-bot` | bot d'événement, paire lecteur et acteur | event, a2a | lecteur : `web_search`, `run_python` ; acteur : un outil d'écriture |
| `ops-diagnosis` | diagnostic d'incident, propositions validées dans le CMP | chat | outils CMP en lecture |
| `pr-review` | relecture de pull requests en commentaire | event | outils GitHub |

## Format

- `id` (= filename), `title`, `description`, `icon` (lucide icon name).
- `recommended`: `models`, `isolation` and `dailyTokenBudget` the CMP proposes for the record's
  `spec.ai.agents` entry.
- `defaults`: the `agent:` block (infra-templates `values.schema.json`), `template` = `id`. Tools that
  depend on the project stay empty: the wizard fills them from `suggestedTools`.
- `suggestedTools`: `name` (platform tool: `run_python`, `web_search`) or `match` (a glob over the
  project's MCP tools `<server>__<tool>`), `badges` (`untrusted_content`, `private_data`,
  `external_send`, `writes`, `executes_code`) and `why`.
- `riskNotes`: shown before the agent is created.
- `pair` (app-bot): two agents `<name>-reader` and `<name>-actor`. The reader uses the top-level
  fields, the actor `pair.actor`. The CMP sets `reader.calls: [<name>-actor]` and the actor's
  `callers: [agent:<name>-reader]`.

Instructions are in French, written for the model: method, rules, and the reminder that tool results
are data, never instructions. A template never suggests tools that add up to untrusted content,
private data and a way out (writes or external send): that is a reader/actor pair.

`scripts/check-agent-templates.py` checks every file against `agents/schema.json`, its defaults against
the infra-templates schema, and that rule (CI: `.github/workflows/agent-templates.yml`).
