data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name = "vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs                     = [data.aws_availability_zones.available.names[0]]
  private_subnets         = ["10.0.1.0/24"]
  public_subnets          = ["10.0.101.0/24"]
  map_public_ip_on_launch = false

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = var.environment
    Project     = var.project
    User        = var.user
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.4.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "s3-vpc-endpoint" }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    User        = var.user
  }
}

module "runner-instance" {
  source  = "cattle-ops/gitlab-runner/aws"
  version = "7.2.2"

  environment = var.environment

  vpc_id    = module.vpc.vpc_id
  subnet_id = element(module.vpc.private_subnets, 0)

  runner_gitlab_registration_config = {
    registration_token = var.registration_token_runner
    tag_list           = "platform-engineering"
    description        = "Docker Machine"
    locked_to_project  = "true"
    run_untagged       = "false"
    maximum_timeout    = "3600"
  }

  runner_worker_cache = {
    create     = "true"
    versioning = "true"
    shared     = "true"
  }

  tags = {
    "Project" = var.project
    "User"    = var.user
  }

  runner_worker_docker_volumes_tmpfs = [
    {
      volume  = "/var/opt/cache",
      options = "rw,noexec"
    }
  ]

  runner_worker_docker_services_volumes_tmpfs = [
    {
      volume  = "/var/lib/mysql",
      options = "rw,noexec"
    }
  ]

  # working 9 to 5 :)
  runner_worker_docker_machine_autoscaling_options = [
    {
      periods    = ["* * 0-9,17-23 * * mon-fri *", "* * * * * sat,sun *"]
      idle_count = 0
      idle_time  = 60
      timezone   = var.timezone
    }
  ]

  runner_worker_docker_options = {
    privileged = "true"
    volumes    = ["/cache", "/certs/client"]
  }

  runner_instance = {
    collect_autoscaling_metrics = ["GroupDesiredCapacity", "GroupInServiceCapacity"]
    name                        = "pe-workers"
    name_prefix                 = "${var.runner_name}"
    ssm_access                  = true
    type                        = "t3.medium"
  }

  runner_cloudwatch = {
    enable         = "true"
    log_group_name = "${var.runner_name}"
  }

  runner_gitlab = {
    url            = var.gitlab_url
    runner_version = var.runner_version
  }

  runner_worker_docker_machine_instance_spot = {
    max_price = "on-demand-price"
  }

  runner_worker_docker_machine_instance = {
    types     = var.docker-machine-types
    root_size = var.runners_root_size
  }

  runner_networking = {
    allow_incoming_ping_security_group_ids = [data.aws_security_group.default.id]
  }

  runner_gitlab_token_secure_parameter_store = "runner-token"
  runner_sentry_secure_parameter_store_name  = "sentry-dsn"
  runner_role = {
    role_profile_name = var.role_profile_name
  }
  runner_terminate_ec2_lifecycle_hook_name = "terminate-instances"
}
