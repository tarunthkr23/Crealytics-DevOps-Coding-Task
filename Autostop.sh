+#!/bin/bash
 +#set environmentInternal to 1 if the script is to be run from an ec2 instance within the same vpc as the instances with tags. This will make the script work based on internal ips(ideally).
 +environmentInternal=0
 +if [[ $environmentInternal -eq 0 ]]
 +then
 +    ipAddr="PublicIpAddress"
 +else
 +    ipAddr="PrivateIpAddress"
 +fi
 +#Tweak min value to terminate instances for different cpu loads. 
 +minVal=1;
 +#The script checks for all users except the admin user logged in, since running the script on an instance would make it log in.
 +adminUser="ubuntu"
 +if [[ ! $# -eq 2 ]]
 +then
 +    echo "2 params required"
 +    exit
 +fi
 +set -e
 +tag=$1
 +currentTimeStamp=`date +%s`
 +duration=$(( $2 * 60 ))
 +startingTimeStamp=$(( $currentTimeStamp - $duration ))
 +echo $duration
 +period=$(( ($2 + 60 - 1) / 60 * 60 ))
 +period=$duration
 +aws ec2 describe-instances --filters "Name=tag-key,Values=$tag"  | sed 's/ *//g' | grep -oP '(?<="InstanceId":").*?(?=")' | while read instance
 +do
 +    echo $instance
 +    echo "aws cloudwatch get-metric-statistics --metric-name CPUUtilization --start-time $startingTimeStamp --end-time $currentTimeStamp --period $period --namespace AWS/EC2 --statistics Maximum --dimensions Name=InstanceId,Value=$instance |  sed 's/ *//g' | grep -oP '(?<=\"Maximum\":).*?(?=,)'"
 +    cpuLoad=`aws cloudwatch get-metric-statistics --metric-name CPUUtilization --start-time $startingTimeStamp --end-time $currentTimeStamp --period $period --namespace AWS/EC2 --statistics Maximum --dimensions Name=InstanceId,Value=$instance |  sed 's/ *//g' | grep -oP '(?<="Maximum":).*?(?=,)'`
 +    echo $cpuLoad;
 +if [[ `echo "$cpuLoad < $minVal" | bc -l` -eq 1 ]]
 +then
 +    echo "terminalte $instance"
 +    
 +     publicIp=`aws ec2 describe-instances --instance-ids $instance | sed 's/ *//g' | grep -oP '(?<="'$ipAddr'":").*?(?=")' | head -n 1`
 +     echo $publicIp
 +     count=`ssh -i MyKeyPair.pem -o StrictHostKeyChecking=no $adminUser@$publicIp "who  | grep -v $adminUser | wc -l"`
 +     if [[ $count -eq 0 ]]
 +     then
 +         echo "TERMINATING $instance"
 +         echo $publicIp
 +         aws ec2 terminate-instances --instance-ids $instance
 +     fi
 +fi
 +done