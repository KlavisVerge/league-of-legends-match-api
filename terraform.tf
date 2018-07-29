terraform {
  backend "local" {
    path = "tf_backend/league-of-legends-match-api.tfstate"
  }
}

variable "REST_API_ID" {}
variable "PARENT_ID" {}
variable "AWS_ACCESS_KEY" {}
variable "AWS_SECRET_ACCESS_KEY" {}
variable "API_KEY" {}

data "aws_iam_role" "role" {
  name = "apis-for-all-service-account"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "${var.AWS_ACCESS_KEY}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
}

resource "aws_api_gateway_resource" "league-of-legends-match-api-resource" {
  rest_api_id = "${var.REST_API_ID}"
  parent_id   = "${var.PARENT_ID}"
  path_part   = "league-of-legends-match-api"
}

resource "aws_lambda_function" "league-of-legends-match-api-function" {
  filename      = "league-of-legends-match-api.zip"
  function_name = "league-of-legends-match-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/league-of-legends-match-api.handler"
  source_code_hash = "${base64sha256(file("league-of-legends-match-api.zip"))}"
  runtime          = "nodejs6.10"
  timeout          = 20

  environment {
    variables {
      API_KEY = "${var.API_KEY}"
    }
  }
}

resource "aws_lambda_permission" "league-of-legends-match-permission" {
  function_name = "${aws_lambda_function.league-of-legends-match-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "league-of-legends-match-api-method-post" {
  rest_api_id   = "${var.REST_API_ID}"
  resource_id   = "${aws_api_gateway_resource.league-of-legends-match-api-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "league-of-legends-match-api-integration" {
  rest_api_id             = "${var.REST_API_ID}"
  resource_id             = "${aws_api_gateway_resource.league-of-legends-match-api-resource.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.league-of-legends-match-api-function.invoke_arn}"
}

module "CORS_FUNCTION_DETAILS" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.league-of-legends-match-api-resource.id}"
  rest_api_id = "${var.REST_API_ID}"
}
