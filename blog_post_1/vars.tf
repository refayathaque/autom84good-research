variable "AWS_REGION" {
  default = "us-east-1"
  type    = string
}
# region should be us-east-1 because https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#acm_certificate_arn

variable "BUCKET_NAME" {
  default = "autom84good-static-website-hosting-on-aws"
  type    = string
}

variable "DOMAIN_NAME" {
  default = "sojicar.com"
  type    = string
}