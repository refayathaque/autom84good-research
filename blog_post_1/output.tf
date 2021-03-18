output "certificate-domain-validation-options" {
  value = aws_acm_certificate.certificate.domain_validation_options
}

output "cloudfront-distribution-domain-name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

output "cloudfront-distribution-status" {
  value = aws_cloudfront_distribution.distribution.status
}

output "route-53-hosted-zone-name-servers" {
  value = aws_route53_zone.primary.name_servers
}