output "realm" {
  description = "Name of the project's staging realm"
  value       = keycloak_realm.staging.realm
}
