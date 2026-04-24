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

data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
