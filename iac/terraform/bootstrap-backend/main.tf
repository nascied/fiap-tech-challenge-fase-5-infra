# O recurso nativo `aws_s3_bucket` não funciona nesta conta: mesmo criando o
# bucket sem nenhuma configuração extra, o provider AWS faz um Read logo
# depois do Create pra popular o state inteiro — inclusive uma chamada
# GetBucketObjectLockConfiguration — e a Service Control Policy da conta AWS
# Academy nega essa chamada explicitamente, em toda a organização (não é uma
# permissão IAM que dê pra ajustar; é um "explicit deny" de SCP, acima de
# qualquer role/policy da conta). Criar o bucket direto (console ou
# `aws s3api create-bucket`) funciona normalmente — não passa por esse Read —
# então replicamos isso aqui via CLI num `null_resource`, em vez do recurso
# nativo do provider.
resource "null_resource" "bucket" {
  triggers = {
    bucket_name = local.bucket_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      if aws s3api head-bucket --bucket "${self.triggers.bucket_name}" 2>/dev/null; then
        echo "Bucket ${self.triggers.bucket_name} já existe, nada a fazer."
      else
        aws s3api create-bucket --bucket "${self.triggers.bucket_name}"
      fi
    EOT
  }

  # Simetria com o create acima, pra `terraform destroy` neste diretório
  # remover o bucket (só chega a rodar se o bucket estiver vazio de propósito
  # — sem --force indiscriminado, pra não apagar state real sem querer).
  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rb \"s3://${self.triggers.bucket_name}\" || true"
  }
}
