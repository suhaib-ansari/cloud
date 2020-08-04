provider "aws" {
  region  = "ap-south-1"
  profile = "suhaib"
}


resource "aws_vpc" "myvpc1" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
tags = {
    Name = "mainvpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "publicsubnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  
  tags = {
    Name = "privatesubnet"
  }
}
######## Internat gateway#############################
resource "aws_internet_gateway" "gw" {
  depends_on = [aws_vpc.myvpc1,aws_subnet.public,aws_subnet.private]
  vpc_id = aws_vpc.myvpc1.id

  tags = {
    Name = "my-internet-gateway1"
  }
}

####### route table for public subnet####################################
resource "aws_route_table" "myroutetable1" {
   depends_on = [aws_internet_gateway.gw,]
  
  vpc_id = aws_vpc.myvpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Myroutetable1"
  }
}
// ------create association for myvpc1subnet1--------------------------------
resource "aws_route_table_association" "asso" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.myroutetable1.id
}



#######create eip #############################
resource "aws_eip" "eip" {
  vpc      = true
}

######## create nat gateway###############################
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public.id
}

############# route table for private  #######################
resource "aws_route_table" "myroutetable2" {
   depends_on = [aws_nat_gateway.nat,]
  
  vpc_id = aws_vpc.myvpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "Myroutetable2"
  }
}

// ------create association for myvpc1subnet2--------------------------------
resource "aws_route_table_association" "asso1" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.myroutetable2.id
}

########## security group for wordpress ################


resource "aws_security_group" "pusgwp" {
  depends_on = [aws_vpc.myvpc1]
  name        = "my wordpress security"
  description = "Allow http ssh mysqlport"
  vpc_id      = aws_vpc.myvpc1.id

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow mysql port"
    from_port   = 3306
    to_port     = 3306
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
    Name = "wordpress_sg"
  }
}

#################### Security group for mySql###########################################

 resource "aws_security_group" "prsgmysql" {
   depends_on = [aws_vpc.myvpc1]
  name        = "my mysql security"
  description = "Allow mysqlport"
  vpc_id      = aws_vpc.myvpc1.id
  ingress {
    description = "allow mysql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.pusgwp.id ]
  }
 
 
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg"
  }
}


####### security group for basin host ################
resource "aws_security_group" "basin" {
  depends_on = [aws_vpc.myvpc1]
  name        = "my basin host security"
  description = "Allow  ssh "
  vpc_id      = aws_vpc.myvpc1.id

  ingress {
    description = "allow SSH"
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
    Name = "basinhost_sg"
  }
}

########security group for maintainus ##########################
resource "aws_security_group" "main"{
  depends_on = [aws_vpc.myvpc1]  
  name        = "my maintainus security"
  vpc_id      = aws_vpc.myvpc1.id
    ingress {
    description = "allow basin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ aws_security_group.basin.id ]
  }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "main_sg"
  }
}



resource "aws_instance" "wordpress" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [ aws_security_group.pusgwp.id ] 
  associate_public_ip_address = true
  key_name = "key" 

  tags = {
    Name = "Wordpress"
  }
}

resource "aws_instance" "basin" {
  ami           = "ami-0ebc1ac48dfd14136"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [ aws_security_group.basin.id ]
  associate_public_ip_address = true
  key_name = "key" 

  tags = {
    Name = "basinos"
  }
}



resource "aws_instance" "mysql" {
  ami           = "ami-76166b19"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = [ aws_security_group.prsgmysql.id ,
                            aws_security_group.main.id ] 

  key_name = "key" 

  tags = {
    Name = "mysql"
  }
}
