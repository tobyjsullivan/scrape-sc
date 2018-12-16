terraform {
  backend "s3" {
    bucket = "terraform-states.tobyjsullivan.com"
    key    = "states/starlit/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "random" {}

variable "lambda_package" {
  default = "./build/handler.zip"
}

data "aws_region" "current" {}

resource "aws_sqs_queue" "pending_crawls" {
  name_prefix                = "starlit-pending-crawls"
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "inventory_data" {
  name_prefix = "starlit-inventory-data"
}

resource "random_id" "handler_id" {
  byte_length = 8
}

resource "aws_iam_role" "lambda_role" {
  name_prefix = "starlit-handler"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_logs" {
  name_prefix = "starlit-handler-logging"
  role        = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "pending_crawls_queue" {
  name_prefix = "starlit-pending-crawls"
  role        = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.pending_crawls.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "inventory_data_queue" {
  name_prefix = "starlit-inventory-data"
  role        = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:SendMessage",
        "sqs:SendMessageBatch",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.inventory_data.arn}"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "crawler" {
  filename                       = "${var.lambda_package}"
  source_code_hash               = "${base64sha256(file(var.lambda_package))}"
  function_name                  = "crawl-handler-${random_id.handler_id.hex}"
  handler                        = "handler.eventHandler"
  timeout                        = 30
  reserved_concurrent_executions = 10
  runtime                        = "nodejs8.10"
  role                           = "${aws_iam_role.lambda_role.arn}"

  environment {
    variables {
      "RESULT_QUEUE_URL" = "${aws_sqs_queue.inventory_data.id}"
    }
  }
}

resource "aws_lambda_event_source_mapping" "pending_crawls" {
  event_source_arn = "${aws_sqs_queue.pending_crawls.arn}"
  function_name    = "${aws_lambda_function.crawler.arn}"
}

output "pending_crawls_queue_url" {
  value = "${aws_sqs_queue.pending_crawls.id}"
}

output "inventory_data_queue_url" {
  value = "${aws_sqs_queue.inventory_data.id}"
}
