
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t3.nano"

  tags = {
    Name = "HelloWorld"
  }
}


module "blog_vpc" {

  source = "terraform-aws-modules/vpc/aws"
  name   = "blog_dev"
  cidr   = "10.0.0.0/16"

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  azs             = ["us-east-2a",  "us-east-2b"]

  tags ={
    Terraform = "true" #  Metadata for AWS
    }
}

module "blog_sg"  {
  source      = "terraform-aws-modules/security-group/aws"
  version     =  "v4.5.0"

  vpc_id          =        module.blog_vpc.vpc_id
  name            =        "blog_sg"

  ingress_rules   =        ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks  =    ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

}

#  --------------------------------------



module "myalb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "myblog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]  # security_group_id needs to be defined, the module's author has defined it..


  listeners = {
    myblog-http = {
      port     = 80
      protocol = "HTTP"
      forward  =   {
        target_group_arn  = aws_lb_target_group.myblog.arn
      }

      tags = {
        Environment = "Development"
      }
    }
  }

}

resource "aws_lb_target_group" "myblog" {
  name        = "myblog-target-group"
  port        = 80
  protocol    = "HTTP"
  # target-type defaults to instance type
  vpc_id      = module.blog_vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "myblog-glue" {
  target_group_arn    = aws_lb_target_group.myblog.arn
  target_id           = aws_instance.blog.id
  port                = 80
}


