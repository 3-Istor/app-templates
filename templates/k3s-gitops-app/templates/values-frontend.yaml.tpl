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

ingress:
  enabled: true
  hostname: "${app_name}-${project_name}.3istor.com"
  sso_protected: true

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
