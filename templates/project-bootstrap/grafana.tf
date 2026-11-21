# ==============================================================================
# GRAFANA MULTI-TENANCY ISOLATION
# ==============================================================================

# 1. Create a dedicated Organization for the project
resource "grafana_organization" "project_org" {
  name         = "Project ${title(var.project_name)}"
  create_users = false
}

# 2. Add the VictoriaLogs Data Source (Isolated Logs)
resource "grafana_data_source" "victorialogs" {
  org_id = grafana_organization.project_org.org_id
  type   = "victoriametrics-logs-datasource"
  name   = "Logs - ${title(var.project_name)}"

  # Same vmauth user as the metrics: vmauth-projects, configured by the CMP,
  # pins the project's namespaces on every LogsQL read. Project admins are
  # Grafana Editors, who cannot edit a datasource to lift that filter.
  url         = "http://vmauth-projects.observability.svc.cluster.local:8427"
  access_mode = "proxy"

  basic_auth_enabled  = true
  basic_auth_username = "project-${var.project_name}"
  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.metrics_password
  })
}

# 3. Add the VictoriaMetrics Data Source (Isolated Metrics)
resource "grafana_data_source" "victoriametrics" {
  org_id = grafana_organization.project_org.org_id
  type   = "prometheus"
  name   = "Metrics - ${title(var.project_name)}"

  # vmauth lets this project's user read only the project's namespaces: it
  # adds extra_filters to every query (users written by the CMP).
  url         = "http://vm-victoria-metrics-cluster-vmauth.observability.svc.cluster.local:8427"
  access_mode = "proxy"
  is_default  = true

  basic_auth_enabled  = true
  basic_auth_username = "project-${var.project_name}"
  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.metrics_password
  })
}

# ==============================================================================
# DEFAULT DASHBOARDS
# ==============================================================================

# 1. Pods Resources Dashboard (11594)
resource "grafana_dashboard" "k8s_pods" {
  org_id = grafana_organization.project_org.org_id

  config_json = replace(
    file("${path.module}/dashboards/k8s-pods.json"),
    "$${DS_PROMETHEUS}",
    grafana_data_source.victoriametrics.uid
  )
  overwrite = true
}

# 2. Application Logs Dashboard
resource "grafana_dashboard" "app_logs" {
  org_id = grafana_organization.project_org.org_id

  config_json = replace(
    file("${path.module}/dashboards/app-logs.json"),
    "$${DS_VICTORIALOGS}",
    grafana_data_source.victorialogs.uid
  )
  overwrite = true
}
