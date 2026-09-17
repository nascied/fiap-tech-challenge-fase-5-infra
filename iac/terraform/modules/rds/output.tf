# Outputs Banco de dados
output "aws_db_instance_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this[*].endpoint
}

output "aws_db_instance_hostname" {
  description = "RDS hostname"
  value       = aws_db_instance.this[*].address
}

output "aws_db_instance_port" {
  description = "RDS port"
  value       = aws_db_instance.this[*].port
}

output "aws_db_instance_name" {
  description = "Database name"
  value       = aws_db_instance.this[*].db_name
}

output "aws_db_instance_master_user" {
  description = "Master username"
  value       = aws_db_instance.this[*].username
}

# output "aws_db_instance_connection_string" {
#   description = "PostgreSQL connection string"
#   value       = "postgresql://${aws_db_instance.this[*].username}@${aws_db_instance.this[*].address}:${aws_db_instance.this[*].port}/${aws_db_instance.this[*].db_name}"
#   sensitive   = true
# }

output "aws_db_instance_connection_strings" {
  description = "Lista de connection strings dos bancos RDS"
  value = [
    for db in aws_db_instance.this :
    "postgresql://${db.username}:${db.password}@${db.address}:${db.port}/${db.db_name}"
  ]
  sensitive = true
}