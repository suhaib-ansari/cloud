# Configure the AWS Provider
provider "aws" {
  region  = "ap-south-1"
  profile = "suhaib" 

}
# creating a key pair##########################

resource "tls_private_key" "privatekey" {
  algorithm   = "RSA"
  rsa_bits  = "4096"
}

resource aws_key_pair "key_pair" {
  key_name   = "key1"
  public_key = tls_private_key.privatekey.public_key_openssh
}



##########creating security group ###############################################

resource "aws_security_group" "security" {
  
  vpc_id      = "vpc-01778247133cf21f7"

  ingress {
    description = "Creating HTTP security rule"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
}

  ingress {
    description = "Creating SSH security rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task2-sg"
  }
}



########### creating a instance ###########################################

resource "aws_instance" "suhaib" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.security.id ]
  key_name = "key1"


connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.privatekey.private_key_pem
    host     = aws_instance.suhaib.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git php -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "task2os"
  }
}

########################### create EFS ########################3333

resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs"

  tags = {
    Name = "my-efs"
  }
}

resource "aws_efs_mount_target" "mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_instance.suhaib.subnet_id

}

resource "null_resource" "connect" {

depends_on = [  aws_efs_mount_target.mount,
]  
  

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.privatekey.private_key_pem
    host     = aws_instance.suhaib.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nfs-utils",
      "sudo echo ${aws_efs_file_system.efs.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
      "sudo mount  ${aws_efs_file_system.efs.dns_name}:/  /var/www/html",
      "sudo git clone https://github.com/suhaib-ansari/cloud.git  /var/www/html",
      
    ]
  }
  }



resource "aws_s3_bucket" "srbn" {

   depends_on = [
    null_resource.connect,
  ]
    bucket  = "suhaib8448"
    acl = "private"
    force_destroy = true


provisioner "local-exec" {
        command     = "git clone https://github.com/suhaib-ansari/cloud.git    folder"
    }

   provisioner "local-exec" {
        when        =   destroy
        command     =   "echo Y | rmdir /s folder"
    }

}
resource "aws_s3_bucket_object" "image-upload" {
    bucket  = aws_s3_bucket.srbn.bucket
    key     = "suhaib.jpg"                                           
    source  = "folder/suhaib.jpg"
    acl = "public-read"
}


#### creating cloud front distribution########################################

locals {
  s3_origin_id = "aws_s3_bucket.srbn.id"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.srbn.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
}
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "suhaib.jpg"

  logging_config {
    include_cookies = false
    bucket          =  aws_s3_bucket.srbn.bucket_domain_name

  }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
 

resource "null_resource" "nullremote2"  {

depends_on = [

     aws_cloudfront_distribution.s3_distribution,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.privatekey.private_key_pem
    host     = aws_instance.suhaib.public_ip
  }

provisioner "remote-exec" {
  inline = [
   "sudo su << EOF",
   "echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/suhaib.jpg'  width='400' lenght='500' >\" >> /var/www/html/suhaib.html",
   "EOF"
  ]
}
}

/*________ start chrome and access  the website __________ 10.*/


resource "null_resource" "nulllocal1"  {

  depends_on = [
    null_resource.nullremote2,
  ]

	provisioner "local-exec" {
	    command = " start chrome  ${aws_instance.suhaib.public_ip}/suhaib.html"
  	}
}




