#!/bin/bash
#s3bucketname='ENTER-BUCKET-NAME-HERE'
region="us-west-2a"
s3bucketname="tp-st123"
launchConfigurationName="webServerConfigurationPrivateTesT"
#image id for ubuntu 16.04 in us-west-2a
imageId="ami-efd0428f"
#replace with keypairname
keyPair="MyKeyPair-test-privateNetwork-Test"
maxCpuUtil=80
minCpuUtil=60
iamRoles3Access="s3-access-ec2-basic-private-TesT"
iamInstanceProfileName="basicProfilePrivate-Test"
iams3accessPolicy="s3-access-permission-policy-private-TesT"
loadBalancerName="loadBalancerPrivateTest"
autoScalingGroupName="auto-scaling-private-network-test"
#cidr-block allocated to vpc is 192.168.0.0/16
#Replaces bucket name in bucket policy file to the one specified in bucket name variable
sed -i "s/BucketName/$s3bucketname/g" bucket-policy.json
aws iam create-role --role-name $iamRoles3Access --assume-role-policy-document file://policy-trust.json

aws iam create-instance-profile --instance-profile-name $iamInstanceProfileName

aws iam put-role-policy --role-name $iamRoles3Access  --policy-name $iams3accessPolicy --policy-document file://bucket-policy.json

aws iam add-role-to-instance-profile --role-name $iamRoles3Access --instance-profile-name $iamInstanceProfileName

#creating keypair and saving output to current directory
aws ec2 create-key-pair --key-name $keyPair --query 'KeyMaterial' --output text > MyKeyPair2.pem

vpcId=`aws ec2 create-vpc --cidr-block 192.168.0.0/16 | sed 's/ *//g' | grep -oP '(?<="VpcId":").*?(?=")'`

privateSubnetId=`aws ec2 create-subnet --vpc-id $vpcId --availability-zone $region --cidr-block 192.168.1.0/24 | sed 's/ *//g' | grep -oP '(?<="SubnetId":").*?(?=")'`

publicSubnetId=`aws ec2 create-subnet --vpc-id $vpcId --availability-zone $region --cidr-block 192.168.0.0/24 | sed 's/ *//g' | grep -oP '(?<="SubnetId":").*?(?=")'`


gatewayId=`aws ec2 create-internet-gateway | sed 's/ *//g' | grep -oP '(?<="InternetGatewayId":").*?(?=")'`

aws ec2 attach-internet-gateway --vpc-id $vpcId --internet-gateway-id $gatewayId

routeTableId=`aws ec2 create-route-table --vpc-id $vpcId |  sed 's/ *//g' | grep -oP '(?<="RouteTableId":").*?(?=")'`

aws ec2 create-route --route-table-id $routeTableId --destination-cidr-block 0.0.0.0/0 --gateway-id $gatewayId

aws ec2 associate-route-table  --subnet-id $publicSubnetId --route-table-id $routeTableId
associationIdPrivate=`aws ec2 associate-route-table  --subnet-id $privateSubnetId --route-table-id $routeTableId | sed 's/ *//g' | grep -oP '(?<="AssociationId":").*?(?=")'`
securityGroupInstance=`aws ec2 create-security-group --group-name instance-security-group --description "Security group for instance" --vpc-id $vpcId | sed 's/ *//g' | grep -oP '(?<="GroupId":").*?(?=")'`
securityGroupPublic=`aws ec2 create-security-group --group-name public-security-group --description "Security group for public" --vpc-id $vpcId | sed 's/ *//g' | grep -oP '(?<="GroupId":").*?(?=")'`


ip=`aws ec2 run-instances --image-id $imageId --count 1 --instance-type t2.micro --key-name $keyPair --security-group-ids $securityGroupInstance --subnet-id $privateSubnetId --iam-instance-profile Name=$iamInstanceProfileName --associate-public-ip-address --user-data file://userdata | sed 's/ *//g' | grep -oP '(?<="InstanceId":").*?(?=")'`
echo $ip;
sleep 2
while [[ -z "$public" ]]
do
    public=`aws ec2 describe-instances --instance-ids $ip | sed 's/ *//g' | grep -oP '(?<="PublicIpAddress":").*?(?=")'`
    sleep 2
done

aws ec2 authorize-security-group-ingress --group-id $securityGroupInstance --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securityGroupPublic --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securityGroupInstance --protocol tcp --port 22 --source-group $securityGroupPublic 
aws ec2 authorize-security-group-ingress --group-id $securityGroupInstance --protocol tcp --port 80 --source-group $securityGroupPublic
aws ec2 authorize-security-group-ingress --group-id $securityGroupPublic --protocol tcp --port 80 --cidr 0.0.0.0/0
# Adding below role for step 3
aws ec2 authorize-security-group-ingress --group-id $securityGroupPublic --protocol tcp --port 8888 --source-group $securityGroupInstance


sleep 2

while  [[ -z "$outpu" ]]
do
    echo ${public}/ping.html
outpu=`curl ${public}/ping.html | grep "syncCompletE"`
sleep 3
done

aws ec2 revoke-security-group-ingress --group-id $securityGroupInstance --protocol tcp --port 80 --cidr 0.0.0.0/0

aws ec2 disassociate-route-table --association-id $associationIdPrivate

aws elb create-load-balancer --load-balancer-name $loadBalancerName --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $publicSubnetId --security-groups $securityGroupPublic

sleep 2

aws elb register-instances-with-load-balancer --load-balancer-name $loadBalancerName --instances $ip
echo "DONE!!!"

#*********************************Setting up a proxy sever in public subnet for  bootstrapping autoscaled instances**************




#security group that allows access to proxy port from at least the private instance security groups
securityGroupId=$securityGroupPublic
#iAny subnet with igw attached
subnetId=$publicSubnetId
privateIp=` aws ec2 run-instances --image-id $imageId --count 1 --instance-type t2.micro --key-name $keyPair --security-group-ids  $securityGroupId --subnet-id $subnetId  --associate-public-ip-address --user-data file://userdataproxy | sed 's/ *//g' | grep -oP '(?<="PrivateIpAddress":").*?(?=")' | head -n 1`
echo "Private Ip=$privateIp"
#replaces the ip address to use as proxy during initial apache installatin 
sed -i "s/http_proxy=http:\/\/.*:/http_proxy=http:\/\/$privateIp:/g" userdataautoscaling

sleep 15

#******************************Setting up launch configuration and auto scaling groups********************************


privateSubnet=$privateSubnetId
aws autoscaling create-launch-configuration --launch-configuration-name $launchConfigurationName --key-name $keyPair --image-id $imageId --security-groups $securityGroupInstance --instance-type t2.micro --user-data file://userdataautoscaling --iam-instance-profile $iamInstanceProfileName


aws autoscaling create-auto-scaling-group --auto-scaling-group-name $autoScalingGroupName --launch-configuration-name $launchConfigurationName --min-size 1 --max-size 3 --desired-capacity 1 --default-cooldown 300  --termination-policies "OldestInstance" --availability-zones $region --load-balancer-names $loadBalancerName --health-check-type ELB --health-check-grace-period 120 --vpc-zone-identifier $privateSubnet

instanceId=`aws ec2 describe-instances --filters "Name=subnet-id,Values=$privateSubnet" | sed 's/ *//g' | grep -oP '(?<="InstanceId":").*?(?=")' | head -n 1`

aws autoscaling attach-instances --instance-ids $instanceId --auto-scaling-group-name $autoScalingGroupName 

#*********************Settting up Auto scaling policy*************************



autoScalingGroup=$autoScalingGroupName 
scaleuparn=`aws autoscaling put-scaling-policy --policy-name scale-up --auto-scaling-group-name $autoScalingGroup --scaling-adjustment 1 --adjustment-type ChangeInCapacity | sed 's/ *//g' | grep -oP '(?<=PolicyARN":").*?(?=")'`
scaledownarn=`aws autoscaling put-scaling-policy --policy-name scale-down --auto-scaling-group-name $autoScalingGroup --scaling-adjustment -1 --adjustment-type ChangeInCapacity | sed 's/ *//g' | grep -oP '(?<=PolicyARN":").*?(?=")'`

aws cloudwatch put-metric-alarm --alarm-name AddInstancePrivateNW --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold $maxCpuUtil --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$autoScalingGroup" --evaluation-periods 2 --alarm-actions $scaleuparn

aws cloudwatch put-metric-alarm --alarm-name RemoveInstancePrivateNW --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold $minCpuUtil --comparison-operator LessThanOrEqualToThreshold  --dimensions "Name=AutoScalingGroupName,Value=$autoScalingGroup" --evaluation-periods 2 --alarm-actions $scaledownarn