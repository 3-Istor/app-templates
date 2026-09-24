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
  hostname: "${hostname}"
  sso_protected: true
  realm: "${project_name}"
  # Every project gets its own connector and Gateway in <project>-system now
  # (D-06) — an app-level connector would be a second, redundant one, and the
  # shared Gateway's listeners don't allow routes from a project that now
  # owns its own Gateway.
  tunnel:
    perRelease: false
  gateway:
    name: "${project_name}-gateway"
    namespace: "${project_name}-system"

auth:
  realm: "${project_name}"
  clientId: "cnp-${project_name}-${app_name}"

db:
  enabled: true
  name: ${app_name}
  storage: "1Gi"
  storageClass: "${storage_class}"

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
