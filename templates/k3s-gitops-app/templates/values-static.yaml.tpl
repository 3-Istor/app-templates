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
  enabled: false

imagePullSecrets:
  - name: app-registry

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "100m"
    # Kyverno compliance: requests == limits
    memory: "128Mi"
