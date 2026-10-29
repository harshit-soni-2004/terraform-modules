output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, one per Availability Zone. External ALB, NAT, and DMZ web."
  value       = aws_subnet.public[*].id
  depends_on  = [aws_route_table_association.public, aws_nat_gateway.this]
}

output "dmz_subnet_ids" {
  description = "Private subnets carved for the dmz CIDR range. DMZ web instances are not placed here."
  value       = aws_subnet.dmz[*].id
  depends_on  = [aws_route.dmz_nat, aws_route_table_association.dmz]
}

output "mz_subnet_ids" {
  description = "MZ subnet IDs. Private, default route to NAT."
  value       = aws_subnet.mz[*].id
  depends_on  = [aws_route.mz_nat, aws_route_table_association.mz]
}

output "data_subnet_ids" {
  description = "Data subnet IDs. Private. NAT default route exists only when enable_data_nat_route is true."
  value       = aws_subnet.data[*].id
  depends_on  = [aws_route.data_nat, aws_route_table_association.data]
}

output "nat_gateway_id" {
  description = "The single NAT Gateway ID."
  value       = aws_nat_gateway.this.id
}
