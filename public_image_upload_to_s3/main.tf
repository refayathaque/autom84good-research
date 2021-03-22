variable "AWS_REGION" {
  default = "us-east-1"
  type    = string
}

variable "BUCKET_NAME" {
  default = "autom84good-research-public-images"
  type    = string
}

# variable "OBJECT_KEY" {
#   default = "helloWorld"
#   type    = string
# }

# variable "OBJECT_PATH" {
#   default = "./someObject.png"
# }

provider "aws" {
  region = var.AWS_REGION
}

resource "aws_s3_bucket" "public_images" {
  bucket        = var.BUCKET_NAME
  acl           = "public-read"
  policy        = data.aws_iam_policy_document.bucket.json
  force_destroy = true
}

data "aws_iam_policy_document" "bucket" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    resources = [
      "arn:aws:s3:::${var.BUCKET_NAME}/*",
    ]
  }
}

# resource "aws_s3_bucket_object" "image" {
#   bucket = var.BUCKET_NAME
#   key    = var.OBJECT_KEY
#   acl    = "public-read"
#   source = var.OBJECT_PATH
#   etag   = filemd5(var.OBJECT_PATH)
#   depends_on = [aws_s3_bucket.public_images]
# }

resource "aws_s3_bucket_object" "image" {
  for_each   = fileset("images/", "*")
  bucket     = var.BUCKET_NAME
  key        = each.value
  acl        = "public-read"
  source     = "images/${each.value}"
  etag       = filemd5("images/${each.value}")
  depends_on = [aws_s3_bucket.public_images]
}
# https://linoxide.com/upload-files-to-s3-using-terraform/