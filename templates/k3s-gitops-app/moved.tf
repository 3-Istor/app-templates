# Preserve addresses of catalog deployments created before repository_mode.
moved {
  from = github_repository.app
  to   = github_repository.app[0]
}

moved {
  from = github_repository_file.values_frontend
  to   = github_repository_file.values_frontend[0]
}

moved {
  from = github_repository_file.security_workflow
  to   = github_repository_file.security_workflow[0]
}

moved {
  from = github_actions_secret.discord_webhook_url
  to   = github_actions_secret.discord_webhook_url[0]
}

moved {
  from = null_resource.delete_ghcr_packages
  to   = null_resource.delete_ghcr_packages[0]
}
