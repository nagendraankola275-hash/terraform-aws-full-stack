# ----------------------------
# Root main.tf
# ----------------------------

# 1️⃣ VPC Module
module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  availability_zone  = "ap-south-1a"
}

# 2️⃣ Internet Gateway
module "igw" {
  source       = "./modules/igw"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

# 3️⃣ Route Table
module "route_table" {
  source       = "./modules/route_table"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  igw_id       = module.igw.igw_id
  subnet_id    = module.vpc.public_subnet_id
}

# 4️⃣ Security Group
module "security_group" {
  source       = "./modules/security_group"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

# 5️⃣ IAM Role + Policy
module "iam" {
  source        = "./modules/iam"
  project_name  = var.project_name
  assume_role   = "ec2.amazonaws.com"
  policy_arn    = "arn:aws:iam::aws:policy/AmazonS3FullAccess"  # example policy
}

# 6️⃣ S3 Bucket
module "s3" {
  source       = "./modules/s3"
  project_name = var.project_name
}

# 7️⃣ RDS Module
module "rds" {
  source          = "./modules/rds"
  project_name    = var.project_name
  db_name         = "projectdb"
  db_username     = "admin"
  db_password     = "Admin#12345"
  sg_id           = module.security_group.sg_id
  db_subnet_group = module.vpc.db_subnet_group_name
}

module "alb" {
  source          = "./modules/alb"
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  sg_id           = module.security_group.sg_id
}

module "asg" {
  source            = "./modules/asg"
  ami_id            = "ami-02d26659fd82cf299"  # your working AMI
  instance_type     = "t3.micro"
  key_name          = "nagendra-key"           # your existing key
  security_group_id = module.security_group.sg_id
  subnet_ids        = module.vpc.public_subnets
  target_group_arn  = module.alb.target_group_arn
}

module "cloudwatch" {
  source       = "./modules/cloudwatch"
  asg_name     = module.asg.asg_name
  alarm_actions = [] # Later we’ll plug SNS ARN here
}

module "sns" {
  source      = "./modules/sns"
  alert_email = "nagendraankola127@gmail.com"
}

# CloudFront Module
module "cloudfront" {
  source               = "./modules/cloudfront"
  project_name         = var.project_name
  s3_bucket_name       = module.s3.bucket_name
  s3_bucket_domain_name = module.s3.bucket_domain_name
}

module "lambda" {
  source          = "./modules/lambda"
  project_name    = var.project_name
  lambda_zip_path = "lambda_function.zip"
}

module "api_gateway" {
  source               = "./modules/api_gateway"
  lambda_function_name = module.lambda.lambda_function_name
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
  region               = var.region
}

# 8️⃣ EC2 Instance
resource "aws_instance" "demo_ec2" {
  ami                    = "ami-00af95fa354fdb788" # Amazon Linux 2 AMI
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [module.security_group.sg_id]
  key_name               = "nagendra-key"

  # Attach IAM Role
  iam_instance_profile = module.iam.instance_profile_name

  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
