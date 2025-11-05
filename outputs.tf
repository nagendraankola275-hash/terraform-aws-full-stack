output "ec2_public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.demo_ec2.public_ip
}

output "api_gateway_invoke_url" {
  description = "API Gateway endpoint to trigger the Lambda"
  value       = module.api_gateway.api_invoke_url
}

