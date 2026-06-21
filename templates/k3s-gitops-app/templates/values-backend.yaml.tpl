# deploy/values-backend.yaml
replicaCount: 1

image:
  repository: ghcr.io/${github_owner}/${app_name}/backend
  tag: "latest"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 8000
      targetPort: 8000

project_name: "${project_name}"
app_name: "${app_name}"

secrets:
  enabled: true
  vaultPath: "project-${project_name}/${app_name}"
  vaultRole: "${project_name}-${app_name}-role"

imagePullSecrets:
  - name: app-registry

ingress:
  enabled: false

auth:
  realm: "${project_name}"
  clientId: "cnp-${project_name}-${app_name}"

resources:
  requests:
    cpu: "50m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"

db:
  enabled: true
  name: ${app_name}
  storage: "1Gi"

monitoring:
  enabled: true
  path: "/health"

offhours:
  enabled: true
  sleepAt: "0 1 * * *"
  wakeAt: "0 7 * * *"
  timezone: "Europe/Paris"
