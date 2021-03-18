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