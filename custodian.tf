data "aws_caller_identity" "current" {}

resource "aws_kms_key" "custodian_lambda_key" {
  #TODO: if kms key not exists create
  description             = "This key is used to encrypt custodian lambda function"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_policy.json
}

resource "aws_kms_alias" "custodian_lambda_key" {
  name          = "platform/custodianlambda"
  target_key_id = aws_kms_key.custodian_lambda_key.key_id
}

resource "local_file" "policy_file" {
  filename = "./lambda/custodian/config.json"
  content = templatefile("./lambda/custodian/policy.tpl", {
    lambda_role_arn = aws_iam_role.CustodianLambda.arn,
    lambda_schedule = "rate(1 hour)"
  })
  depends_on = [aws_iam_role.CustodianLambda]
}

data "archive_file" "custodian_lambda_archive" {
  output_path = "./lambda/custodian.zip"
  type        = "zip"
  source_dir  = "lambda/custodian"
  depends_on  = [local_file.policy_file]
}




module "cloud_custodian_lambda" {
  source                 = "github.com/terraform-aws-modules/terraform-aws-lambda"
  function_name          = "ResourceScheduler"
  description            = "Resource Scheduler"
  handler                = "custodian_policy.runcustodian_policy.run"
  runtime                = "python3.11"
  create_package         = false
  local_existing_package = data.archive_file.custodian_lambda_archive.output_path
  kms_key_arn            = aws_kms_key.custodian_lambda_key.arn
  lambda_role            = aws_iam_role.CustodianLambda.arn
  tags                   = { custodian-info = "mode=periodic:version=0.9.31" }
  depends_on             = [data.archive_file.custodian_lambda_archive]
  timeout                = 300
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
}

resource "aws_cloudwatch_event_target" "profile_generator_lambda_target" {
  arn  = module.cloud_custodian_lambda.arn
  rule = aws_cloudwatch_event_rule.cloud_custodian_lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rw_fallout_retry_step_deletion_lambda" {
  statement_id   = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = module.cloud_custodian_lambda.name
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.cloud_custodian_lambda_event_rule.arn
  source_account = data.aws_caller_identity.current.account_id
}


