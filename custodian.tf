locals {
  vpc_env = var.vpc_env == "sbx" ? "sbx" : var.vpc_env
}
data "aws_caller_identity" "current" {}

module "module_pip_read" {
  source    = "app.terraform.io/devolksbank-ep/module-pip/terraform//modules/pip-read"
  version   = "1.0.2"
  providers = { aws.pip_read = aws.pip_read }
}



resource "aws_kms_key" "custodian_lambda_key" {
  description             = "This key is used to encrypt custodian lambda function"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_policy.json
}


resource "aws_kms_alias" "custodian_lambda_key" {
  name          = "alias/custodianlambda"
  target_key_id = aws_kms_key.custodian_lambda_key.key_id
}

resource "local_file" "policy_file" {
  filename = "${path.module}/lambda/custodian/config.json"
  content = templatefile("${path.module}/lambda/custodian/policy.tpl", {
    lambda_role_arn = aws_iam_role.CustodianLambda.arn,
    lambda_schedule = "rate(1 hour)"
  })
  depends_on = [aws_iam_role.CustodianLambda]
}

data "archive_file" "custodian_lambda_archive" {
  output_path = "${path.module}/lambda/custodian.zip"
  type        = "zip"
  source_dir  = "${path.module}/lambda/custodian"
  depends_on  = [local_file.policy_file]
}


#module "cloud_custodian_lambda" {
#  source                     = "github.com/terraform-aws-modules/terraform-aws-lambda"
#  function_name              = "ResourceScheduler"
#  description                = "Resource Scheduler"
#  handler                    = "custodian_policy.runcustodian_policy.run"
#  runtime                    = "python3.11"
#  create_package             = false
#  local_existing_package     = data.archive_file.custodian_lambda_archive.output_path
#  kms_key_arn                = aws_kms_key.custodian_lambda_key.arn
#  lambda_role                = aws_iam_role.CustodianLambda.arn
#  tags                       = merge({ custodian-info = "mode=periodic:version=0.9.31" }, var.tags)
#  depends_on                 = [data.archive_file.custodian_lambda_archive, aws_kms_key.custodian_lambda_key]
#  timeout                    = 300
#  cloudwatch_logs_kms_key_id = aws_kms_key.custodian_lambda_key.arn
#  vpc_subnet_ids             = [for s in module.module_pip_read.vpcs.shared[var.vpc_env].private_subnets : s.id]
#  vpc_security_group_ids     = [aws_security_group.rssg.id]
#}

module "cloud_custodian_lambda" {
  source      = "github.com/schubergphilis/terraform-aws-mcaf-lambda?ref=v1.1.0"
  name        = "ResourceScheduler"
  description = "Lambda for Resource Scheduler"
  providers   = { aws.lambda = aws }
  filename    = data.archive_file.custodian_lambda_archive.output_path
  kms_key_arn = aws_kms_key.custodian_lambda_key.arn
  policy      = data.aws_iam_policy_document.custodian_lambda_policy.json
  runtime     = "python3.11"
  subnet_ids  = [for s in module.module_pip_read.vpcs.shared[var.vpc_env].private_subnets : s.id]
  tags        = { custodian-info = "mode=periodic:version=0.9.31" }
  timeout     = 600
  handler     = "custodian_policy.runcustodian_policy.run"
  depends_on  = [data.archive_file.custodian_lambda_archive, aws_kms_key.custodian_lambda_key]
  source_code_hash = data.archive_file.custodian_lambda_archive.output_base64sha256
  security_group_egress_rules = [
    {
      description = "Security Group rule for Resource Scheduler"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = "0"
      to_port     = "65535"
    }
  ]

}


data "aws_iam_policy_document" "custodian_lambda" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["edgelambda.amazonaws.com", "lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "CustodianLambda" {
  name               = "CustodianLambda"
  assume_role_policy = data.aws_iam_policy_document.custodian_lambda.json
}

resource "aws_iam_role_policy" "default" {
  name   = "CustodianLambda"
  role   = aws_iam_role.CustodianLambda.id
  policy = data.aws_iam_policy_document.custodian_lambda_policy.json
}




data "aws_iam_policy_document" "custodian_lambda_policy" {
  statement {
    effect    = "Allow"
    resources = ["arn:aws:ec2:eu-central-1:${data.aws_caller_identity.current.account_id}:instance/*"]
    actions = [
      "ec2:StartInstances",
      "ec2:DescribeTags",
      "ec2:StopInstances",
      "ec2:DescribeInstanceStatus",
    ]
  }


  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:DescribeInstances"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]
    sid = "DecryptKMS"
    resources = [
      aws_kms_key.custodian_lambda_key.arn
    ]
  }

}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid = "EnableCloudWatchLogGroups"

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.eu-central-1.amazonaws.com"]
    }
    resources = ["arn:aws:kms:eu-central-1:${data.aws_caller_identity.current.account_id}:key/*"]

  }

  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
    actions   = ["kms:*"]
    resources = ["arn:aws:kms:eu-central-1:${data.aws_caller_identity.current.account_id}:key/*"]

  }
  statement {
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "states.amazonaws.com"]
    }
    resources = ["arn:aws:kms:eu-central-1:${data.aws_caller_identity.current.account_id}:key/*"]
    sid       = "Allow_Cloudwatch_for_CMK"
  }
}


resource "aws_cloudwatch_event_rule" "resource_scheduler_lambda_event_rule" {
  name                = "github-backup-lambda-event-rule"
  description         = "retry scheduled every 1 hour"
  schedule_expression = "cron(1 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "resource_scheduler_lambda_target" {
  arn  = module.cloud_custodian_lambda.arn
  rule = aws_cloudwatch_event_rule.resource_scheduler_lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_resourcescheduler_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.cloud_custodian_lambda.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.resource_scheduler_lambda_event_rule.arn
}

