# provider
provider "aws" {
  region = var.AWS_REGION
}

# S3
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
# ACM
resource "aws_acm_certificate" "certificate" {
  domain_name       = var.DOMAIN_NAME
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_acm_certificate_validation" "certificate" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}
# Route53
resource "aws_route53_zone" "primary" {
  name = var.DOMAIN_NAME
}
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}
resource "aws_route53_record" "cloudfront" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.DOMAIN_NAME
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
# CloudFront
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {}
resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.website_static_files.bucket_regional_domain_name
    origin_id   = "bucket-${aws_s3_bucket.website_static_files.bucket}"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  # By default, show index.html file
  default_root_object = "index.html"
  enabled             = true
  aliases             = [var.DOMAIN_NAME]

  # If there is a 404, return index.html with a HTTP 200 Response
  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "bucket-${aws_s3_bucket.website_static_files.bucket}"

    # Forward all query strings, cookies and headers
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#viewer_protocol_policy
    viewer_protocol_policy = "redirect-to-https"
  }

  # Edge locations included in this price class are US, Mexico, Canada, Europe and Israel only
  # https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_DistributionConfig.html
  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
      # https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
    }
  }

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#acm_certificate_arn
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.certificate.arn
    ssl_support_method  = "sni-only"
  }
}