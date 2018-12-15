terraform {
  backend "s3" {
    bucket = "terraform-states.tobyjsullivan.com"
    key = "states/starlit/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {}

resource "aws_sqs_queue" "pending_crawls" {
  name_prefix = "starlit-pending-crawls"
}

output "queue_arn" {
  value = "${aws_sqs_queue.pending_crawls.arn}"
}
