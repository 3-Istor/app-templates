provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "app_cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.app_name
  content = data.terraform_remote_state.base_infra.outputs.alb_dns_name
  type    = "CNAME"
  proxied = true
}
