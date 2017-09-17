A bash script using awscli that creates an entire vpc with a public and private subnet and a webserver running apache in the private subnet. This is a breakdown of what the script does. To install apache on the instances in the private subnet during a scale up, I run a t2.micro instance in the public subnet running tinyproxy. Not the best idea, but I had to get the job done.

1. Create a role with s3 access.
2. Launch an ec2 instance with a role inside the private subnet of VPC, and install apache through
bootstrapping.( The script automatically creates a VPC and the required subnets. Various parameters may be configured at the start of create.sh. The cidr blocks are however hardcoded to 192.168.0.0/16
3. Create a load balancer in public subnet.
4. Add the ec2 instance, under the load balancer
5. Create an auto scaling group with minimum size of 1 and maximum size of 3 with load balancer
created in step 3.
6. Add the created instances under the auto scaling group.
7. Write a life cycle policy with the following parameters:
scale in : CPU utilization > 80%
scale out : CPU Utilization < 60%

To execute:

Give executable permissions to create.sh and autostop.sh
Create.sh will create a vpc, launch an instance, attach to load-balancer,create autoscaling groups and an auto scaling policy

For bootstapping apache for the first instance, I temporarily attached an internet gateway to the private subnet. It gets detached as soon as apache is installed.
To install apache on the automatically scaled up instances, I lauch a t2 micro instance in the private subnet, install a proxy server(tinyproxy) on it and make the newly launched instance apt-get through the proxy. The security group for the proxy only allows inbound traffic to 8888 from the instance security group.