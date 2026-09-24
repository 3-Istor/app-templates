# deploy/values-frontend.yaml
replicaCount: 1

image:
  repository: ghcr.io/${github_owner}/${app_name}/frontend
  tag: "latest"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 3001

secrets:
  enabled: true
  vaultPath: "project-${project_name}/${app_name}"
  vaultRole: "${project_name}-${app_name}-role"

env:
  - name: BACKEND_HOST
    value: "http://${project_name}-${app_name}-backend-cnp-generic-app:8000"

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
  # Every project gets its own connector in <project>-system now (D-06) —
  # an app-level connector would be a second, redundant one.
  tunnel:
    perRelease: false

auth:
  realm: "${project_name}"
  clientId: "cnp-${project_name}-${app_name}"

resources:
  requests:
    cpu: "50m"
    memory: "256Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"

monitoring:
  enabled: true
  path: "/"

offhours:
  enabled: true
  sleepAt: "0 1 * * *"
  wakeAt: "0 7 * * *"
  timezone: "Europe/Paris"
