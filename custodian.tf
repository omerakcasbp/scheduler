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
  tags                    = var.tags
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

resource "aws_security_group" "rssg" {
  name        = "ResourceSchedulerSG"
  description = "Resource Scheduler SG"
  vpc_id      = module.module_pip_read.vpcs.shared[local.vpc_env].id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = var.tags

}

module "cloud_custodian_lambda" {
  source                     = "github.com/terraform-aws-modules/terraform-aws-lambda"
  function_name              = "ResourceScheduler"
  description                = "Resource Scheduler"
  handler                    = "custodian_policy.runcustodian_policy.run"
  runtime                    = "python3.11"
  create_package             = false
  local_existing_package     = data.archive_file.custodian_lambda_archive.output_path
  kms_key_arn                = aws_kms_key.custodian_lambda_key.arn
  lambda_role                = aws_iam_role.CustodianLambda.arn
  tags                       = merge({ custodian-info = "mode=periodic:version=0.9.31" }, var.tags)
  depends_on                 = [data.archive_file.custodian_lambda_archive, aws_kms_key.custodian_lambda_key]
  timeout                    = 300
  cloudwatch_logs_kms_key_id = aws_kms_key.custodian_lambda_key.arn
  vpc_subnet_ids             = [for s in module.module_pip_read.vpcs.shared[var.vpc_env].private_subnets : s.id]
  vpc_security_group_ids     = [aws_security_group.rssg.id]
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
  tags               = var.tags
}

resource "aws_iam_role_policy" "default" {
  name   = "CustodianLambda"
  role   = aws_iam_role.CustodianLambda.id
  policy = data.aws_iam_policy_document.custodian_lambda_policy.json
}

resource "aws_iam_role_policy" "default-vpc" {
  name   = "CustodianLambdaVPC"
  role   = aws_iam_role.CustodianLambda.id
  policy = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
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


resource "aws_cloudwatch_event_rule" "cloud_custodian_lambda_event_rule" {
  name                = "cloud-custodian-lambda-event-rule"
  description         = "scheduled every 1 hour"
  schedule_expression = "cron(1 * * * ? *)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "profile_generator_lambda_target" {
  arn  = module.cloud_custodian_lambda.lambda_cloudwatch_log_group_arn
  rule = aws_cloudwatch_event_rule.cloud_custodian_lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rw_fallout_retry_step_deletion_lambda" {
  statement_id   = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = module.cloud_custodian_lambda.lambda_function_name
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.cloud_custodian_lambda_event_rule.arn
  source_account = data.aws_caller_identity.current.account_id
}