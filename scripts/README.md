# scripts

| Script | What it does |
| --- | --- |
| `cnp-clean.sh` | Destroys everything CNP provisioned for a project or a whole cloud, and reports what is left. See `--help`. |
| `test-cnp-clean.sh` | Offline test (stubbed `gh`) that `cnp-clean.sh` skips deletion-protected projects. Run `bash scripts/test-cnp-clean.sh`. |
| `vault-split-members.sh` | One-off: gives projects bootstrapped before the Vault read/write split a read-only members group and repairs their OIDC aliases. Idempotent, `--dry-run`. |
| `keycloak-split-realm-admin.sh` | One-off: replaces realm-admin with its individual roles on the tenant admin and `project-admins` of realms created before the split, so `cmp-provisioner` can apply them. Run with the master admin. Idempotent, `--dry-run`. |
| `secrets.sh` | Provider credentials. **Gitignored** — create it locally, never commit it. |

## On `cleanup-cnp-demo.sh`

Removed. It scanned every `.tfstate` under `cnp/` in the bucket, guessed what
each one was from its contents, and destroyed all of them. There was no way to
say "only this project" or "only this cloud", and no dry run.

`cnp-clean.sh` replaces it: the scope is always explicit, dry-run is the default,
and the state layout (`cmp/<cloud>/projects/<project>/`) makes the scope a prefix
listing instead of a guess.
