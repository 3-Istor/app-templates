# scripts

| Script | What it does |
| --- | --- |
| `cnp-clean.sh` | Destroys everything CNP provisioned for a project or a whole cloud, and reports what is left. See `--help`. |
| `secrets.sh` | Provider credentials. **Gitignored** — create it locally, never commit it. |

## On `cleanup-cnp-demo.sh`

Removed. It scanned every `.tfstate` under `cnp/` in the bucket, guessed what
each one was from its contents, and destroyed all of them. There was no way to
say "only this project" or "only this cloud", and no dry run.

`cnp-clean.sh` replaces it: the scope is always explicit, dry-run is the default,
and the state layout (`cmp/<cloud>/projects/<project>/`) makes the scope a prefix
listing instead of a guess.
