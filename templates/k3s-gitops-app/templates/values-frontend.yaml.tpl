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
      port: 8000
      targetPort: 8000

secrets:
  enabled: true
  vaultPath: "kvv2/projects/${project_name}/${app_name}"

imagePullSecrets:
  - name: app-registry

resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
