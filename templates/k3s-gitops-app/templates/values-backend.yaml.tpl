# deploy/values-backend.yaml
replicaCount: 1

image:
  repository: ghcr.io/${github_owner}/${app_name}/backend
  # Built by the repo's first CI run; Image Updater then writes released versions.
  tag: "${image_tag}"

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
  storageClass: "${storage_class}"
  backup:
    enabled: ${db_backup}

# The image creates no tables itself (CNP migration standard v1): the platform
# runs its migration entrypoint as a Job once the database is Ready and before
# each new version starts. A failed migration keeps the running version.
migrations:
  enabled: true
  command: ["/app/migrate"]

monitoring:
  enabled: true
  path: "/health"

# The template backend serves /health without a database round trip, so both
# probes use it: a database outage must not restart every pod.
livenessProbe:
  enabled: true
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

readinessProbe:
  enabled: true
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# GET /metrics on the app port: request rate, errors and latency by route, and
# the app's own business metrics.
metrics:
  enabled: true
  path: /metrics

# OpenTelemetry traces to the platform collector. sampleRatio keeps that share
# of the traces that start here.
tracing:
  enabled: true
  sampleRatio: "1.0"

offhours:
  enabled: true
  sleepAt: "0 1 * * *"
  wakeAt: "0 7 * * *"
  timezone: "Europe/Paris"
