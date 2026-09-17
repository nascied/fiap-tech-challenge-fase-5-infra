locals {
  # Nomes de bucket S3 são únicos GLOBALMENTE (entre contas AWS diferentes,
  # não só dentro da conta). "fiap-tc-f5-iac" (o padrão "óbvio" a partir do
  # prefixo usado no resto do projeto) já está em uso por outra conta —
  # provavelmente outro aluno da turma seguindo a mesma convenção do
  # enunciado — por isso o prefixo aqui é mais específico
  # ("fiap-tc-f5-solidarytech", com o nome do projeto). Precisa bater
  # exatamente com o "bucket" em backends/dev.tfbackend e backends/prd.tfbackend.
  resource_prefix_name = "fiap-tc-f5-solidarytech"
  bucket_name          = "${local.resource_prefix_name}-${var.aws_s3_bucket_name}"
}