# deploy/values.yaml (Static App)
replicaCount: 1

image:
  repository: ghcr.io/${github_owner}/${app_name}
  tag: "latest"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 80

secrets:
  enabled: true
  vaultPath: "project-${project_name}/${app_name}"
  vaultRole: "${project_name}-${app_name}-role"

imagePullSecrets:
  - name: app-registry

project_name: "${project_name}"
app_name: "${app_name}"

routes:
  ${app_name}:
    auth:
      enabled: true
      realm: "${project_name}"
      vault:
        path: "kvv2/projects/${project_name}/${app_name}/envoy-auth"
        role: "${project_name}-${app_name}-role"

ingress:
  enabled: true
  hostname: "${app_name}-${project_name}.3istor.com"
  sso_protected: true
  realm: "${project_name}"

auth:
  realm: "${project_name}"
  clientId: "cnp-${project_name}-${app_name}"

db:
  enabled: true
  name: ${app_name}
  storage: "1Gi"

resources:
  requests:
    cpu: "50m"
    memory: "128Mi"
  limits:
    cpu: "100m"
    memory: "128Mi"

monitoring:
  enabled: true
  path: "/"

offhours:
  enabled: true
  sleepAt: "0 1 * * *"
  wakeAt: "0 7 * * *"
  timezone: "Europe/Paris"
