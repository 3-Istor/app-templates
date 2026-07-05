# ==============================================================================
# GRAFANA MULTI-TENANCY ISOLATION
# ==============================================================================

# 1. Create a dedicated Organization for the project
resource "grafana_organization" "project_org" {
  name         = "Project ${title(var.project_name)}"
  create_users = false
}

# 2. Add the LOKI Data Source (Isolated Logs)
resource "grafana_data_source" "loki" {
  org_id      = grafana_organization.project_org.org_id
  type        = "loki"
  name        = "Logs - ${title(var.project_name)}"
  url         = "http://loki-gateway.observability.svc.cluster.local:80"
  access_mode = "proxy"

  http_headers = {
    "X-Scope-OrgID" = var.project_name
  }
}

# 3. Add the VictoriaMetrics Data Source (Isolated Metrics)
resource "grafana_data_source" "victoriametrics" {
  org_id = grafana_organization.project_org.org_id
  type   = "prometheus"
  name   = "Metrics - ${title(var.project_name)}"

  # VictoriaMetrics handles multi-tenancy directly through the URL path
  url         = "http://vm-vmauth.observability.svc.cluster.local:8427/select/${var.project_name}/prometheus"
  access_mode = "proxy"
  is_default  = true
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
    "$${DS_LOKI}",
    grafana_data_source.loki.uid
  )
  overwrite = true
}
