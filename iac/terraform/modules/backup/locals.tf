locals {
  # Nomes de bucket S3 são únicos globalmente (entre contas AWS diferentes,
  # não só dentro da conta) — já tivemos colisão real com outro aluno da
  # turma no bucket do state (fiap-tc-f5-iac, ver bootstrap-backend/locals.tf).
  # Sufixo com o account_id (sempre único) evita esse mesmo problema aqui,
  # sem precisar escolher um nome "criativo" só pra torcer que ninguém mais
  # usou.
  velero_bucket_name = "${var.velero_bucket_name}-${data.aws_caller_identity.current.account_id}"
}
