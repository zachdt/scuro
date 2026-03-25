provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(var.tags, {
    Project = "scuro"
    Stack   = var.name
  })

  cloudwatch_log_group_name = "/scuro/${var.name}/services"

  interface_endpoints = toset(concat(
    [
      "ssm",
      "ssmmessages",
      "ec2messages"
    ],
    var.enable_cloudwatch_logs ? ["logs"] : [],
    var.enable_sqs_queue ? ["sqs"] : []
  ))

  runtime_env_parameter_arn     = var.runtime_env_parameter_name != "" ? "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.runtime_env_parameter_name, "/")}" : null
  public_rpc_origin_header_name = "X-Scuro-Origin-Secret"
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.enable_public_rpc

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-${var.availability_zone}"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-private"
  })
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_internet_gateway" "this" {
  count  = var.enable_public_rpc ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_route" "public_default" {
  count                  = var.enable_public_rpc ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_security_group" "instance" {
  name        = "${var.name}-instance"
  description = "Public RPC ingress only when enabled; no SSH or admin ingress"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-instance"
  })
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "Allow HTTPS from the Scuro host to VPC endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.instance.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-endpoints"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.value}"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "${var.name}-s3"
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.name}-artifacts-"
  force_destroy = var.bucket_force_destroy

  tags = merge(local.common_tags, {
    Name = "${var.name}-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_password" "public_rpc_secret" {
  count   = var.enable_public_rpc ? 1 : 0
  length  = 32
  special = false
}

resource "aws_sqs_queue" "proof_dlq" {
  count = var.enable_sqs_queue ? 1 : 0

  name = "${var.name}-proof-dlq"

  tags = merge(local.common_tags, {
    Name = "${var.name}-proof-dlq"
  })
}

resource "aws_sqs_queue" "proof" {
  count = var.enable_sqs_queue ? 1 : 0

  name                       = "${var.name}-proof"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.proof_dlq[0].arn
    maxReceiveCount     = 5
  })

  tags = merge(local.common_tags, {
    Name = "${var.name}-proof"
  })
}

resource "aws_cloudwatch_log_group" "services" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = local.cloudwatch_log_group_name
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_iam_role" "instance" {
  name = "${var.name}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "runtime" {
  name = "${var.name}-runtime"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
      ],
      var.enable_sqs_queue ? [
        {
          Effect = "Allow"
          Action = [
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:ReceiveMessage",
            "sqs:SendMessage"
          ]
          Resource = [
            aws_sqs_queue.proof[0].arn,
            aws_sqs_queue.proof_dlq[0].arn
          ]
        }
      ] : [],
      var.enable_cloudwatch_logs ? [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents"
          ]
          Resource = [
            aws_cloudwatch_log_group.services[0].arn,
            "${aws_cloudwatch_log_group.services[0].arn}:*"
          ]
        }
      ] : [],
      var.runtime_env_parameter_name != "" ? [
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter",
            "ssm:GetParameters"
          ]
          Resource = [local.runtime_env_parameter_arn]
        }
    ] : [])
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance"
  role = aws_iam_role.instance.name
}

resource "aws_instance" "host" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  vpc_security_group_ids      = [aws_security_group.instance.id]
  monitoring                  = false
  associate_public_ip_address = var.enable_public_rpc

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    stack_name                 = var.name
    region                     = var.region
    root_volume_size           = var.root_volume_size
    bucket                     = aws_s3_bucket.artifacts.bucket
    queue_url                  = var.enable_sqs_queue ? aws_sqs_queue.proof[0].id : ""
    queue_name                 = var.enable_sqs_queue ? aws_sqs_queue.proof[0].name : ""
    runtime_env_parameter_name = var.runtime_env_parameter_name
    cloudwatch_log_group_name  = var.enable_cloudwatch_logs ? local.cloudwatch_log_group_name : ""
    enable_public_rpc          = var.enable_public_rpc ? "1" : "0"
    public_rpc_shared_secret   = var.enable_public_rpc ? random_password.public_rpc_secret[0].result : ""
  })

  tags = merge(local.common_tags, {
    Name = "${var.name}-host"
  })
}

resource "aws_cloudfront_cache_policy" "public_rpc" {
  count = var.enable_public_rpc ? 1 : 0

  name        = "${var.name}-public-rpc"
  default_ttl = 0
  max_ttl     = 1
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Access-Control-Request-Headers",
          "Access-Control-Request-Method",
          "Content-Type",
          "Origin"
        ]
      }
    }

    query_strings_config {
      query_string_behavior = "all"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_origin_request_policy" "public_rpc" {
  count = var.enable_public_rpc ? 1 : 0

  name = "${var.name}-public-rpc"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "Content-Type",
        "Origin"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_distribution" "public_rpc" {
  count               = var.enable_public_rpc ? 1 : 0
  enabled             = true
  comment             = "${var.name} public RPC"
  wait_for_deployment = true
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_instance.host.public_dns
    origin_id   = "${var.name}-public-rpc"

    custom_header {
      name  = local.public_rpc_origin_header_name
      value = random_password.public_rpc_secret[0].result
    }

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${var.name}-public-rpc"

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = aws_cloudfront_cache_policy.public_rpc[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.public_rpc[0].id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-rpc"
  })
}
