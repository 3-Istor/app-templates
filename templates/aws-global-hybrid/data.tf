resource "random_integer" "rule_priority" {
  min = 1
  max = 49000
}

data "terraform_remote_state" "base_infra" {
  backend = "s3"
  config = {
    bucket = "3-istor-tf-infra-aws"
    key    = "aws/terraform.tfstate"
    region = "eu-west-3"
  }
}
