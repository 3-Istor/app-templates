# deploy/values.yaml (Static App)
replicaCount: 1

image:
  # No suffix for static single-container apps!
  repository: ghcr.io/${github_owner}/${app_name}
  tag: "latest"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 80 # Nginx default port

secrets:
  enabled: true
  vaultPath: "project-${project_name}/${app_name}"

imagePullSecrets:
  - name: app-registry

project_name: "${project_name}"
app_name: "${app_name}"

ingress:
  enabled: true
  hostname: "${app_name}.3istor.com"
  sso_protected: true

db:
  enabled: true
  name: ${app_name}
  storage: "1Gi"

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "100m"
    # Kyverno compliance: requests == limits
    memory: "128Mi"
