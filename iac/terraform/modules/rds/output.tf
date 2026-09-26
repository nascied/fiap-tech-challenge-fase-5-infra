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
  # urlencode() na senha: random_password.this permite caracteres reservados em URI
  # (override_special = "!#$%&*()-_=+[]{}<>:?", em main.tf) — sem isso, um "%" sorteado
  # (não seguido de 2 dígitos hex) quebra o parsing da URI em qualquer client (psql,
  # libpq, etc.) com "invalid percent-encoded token". Bug probabilístico: só se
  # manifesta quando o gerador escolhe um desses caracteres. Username não passa por
  # urlencode() porque não é gerado aleatoriamente (vem fixo do .tfvars).
  value = [
    for db in aws_db_instance.this :
    "postgresql://${db.username}:${urlencode(db.password)}@${db.address}:${db.port}/${db.db_name}"
  ]
  sensitive = true
}