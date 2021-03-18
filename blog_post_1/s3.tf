resource "aws_s3_bucket" "website_static_files" {
  bucket = var.BUCKET_NAME
  # acl    = "public-read"
  acl    = "private"
  policy = data.aws_iam_policy_document.bucket_website_hosting.json
  website {
    index_document = "index.html"
  }
  force_destroy = true
}
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#static-website-hosting
data "aws_iam_policy_document" "bucket_website_hosting" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    principals {
      # identifiers = ["*"]
      identifiers = [
      aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
      type = "AWS"
    }
    # https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_principal.html
    resources = [
      "arn:aws:s3:::${var.BUCKET_NAME}",
      "arn:aws:s3:::${var.BUCKET_NAME}/*",
      // need both as we're getting objects INSIDE the bucket and also listing the bucket
    ]
  }
}

# https://learn.hashicorp.com/tutorials/terraform/aws-iam-policy#refactor-your-policy
# Upload `index.html` to S3
resource "null_resource" "upload_static_files" {
  provisioner "local-exec" {
    command = "aws s3 cp index.html s3://${var.BUCKET_NAME}"
    // use `sync` for uploading directories
  }

  depends_on = [aws_s3_bucket.website_static_files]
}
# https://docs.aws.amazon.com/cli/latest/userguide/cli-services-s3-commands.html#using-s3-commands-managing-objects-sync