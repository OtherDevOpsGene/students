# Get existing Route53 zone
data "aws_route53_zone" "domain" {
  name = var.domain_name
}

# Create ACM certificate for the API domain
resource "aws_acm_certificate" "api_cert" {
  domain_name       = var.api_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS records for ACM validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.domain.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# API Gateway custom domain
resource "aws_api_gateway_domain_name" "api" {
  domain_name              = var.api_fqdn
  regional_certificate_arn = aws_acm_certificate.api_cert.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  depends_on = [aws_acm_certificate_validation.cert_validation]
}

# API Gateway base path mapping
resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.email_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}

# Route53 record for the API Gateway custom domain
resource "aws_route53_record" "api" {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.domain.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api.regional_zone_id
    evaluate_target_health = true
  }
}

# Additional output for custom domain
output "api_custom_domain" {
  value = "https://${aws_api_gateway_domain_name.api.domain_name}"
}
