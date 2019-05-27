#!/bin/bash


# function to kill all lxc containers
# caution: it will kill ALL CONTAINERS DESPITE OF STATE OF EXECUTION!

kill-all () {

LXC=/var/lib/lxc
ROOTFS=rootfs
RUNNING_CONTAINERS="$(lxc-ls)"

for container in $RUNNING_CONTAINERS; do
  echo "Destroying $container..."
  lxc-autostart --kill --all
  lxc-destroy --name $container --force
done
 
}


# function to create lxc containers based on user input

deploy-containers () {

COUNTER=0

read -p 'how many containers do you want to spin-up: ' AMOUNT
read -p 'please provide the container kind: ' KIND
read -p 'and now, please provide a nice name for the containers: ' NAME


while [  $COUNTER -lt "$AMOUNT" ]; do
    echo $COUNTER containers started
    lxc-create -t $KIND -n "$NAME"-"$COUNTER" && lxc-start -n "$NAME"-"$COUNTER"
    let COUNTER=COUNTER+1 
done

}


# list all running LXC Containers

list-running-containers () {


TOTAL=$(lxc-ls -f | grep -v NAME | wc -l)

lxc-ls -f
echo ""
echo "-----------------------------------------------------------"
echo "TOTAL = $TOTAL Containers"
echo ""

}



# Creates a hosts file using the list of all currently running lxc containers.
# Function just in initial stage, still have to add validation structure to first check 
# if actually we have instances up and running before trying to generate a list of hosts.
# Also, I have to check if there's already an existing hosts file in current working directory



create-hosts-file () {

#local LIST=$(lxc-ls -f | grep -v NAME | cut -c36-46)
LIST=$(lxc-ls -f | grep -v NAME | cut -d "-" -f3)
local NUM=$(lxc-ls -f | grep -v NAME | wc -l)

echo "Adding all the $NUM containers to a hosts file on the current directory ----> $PWD"
echo "[all]" >> hosts

for i in $LIST
do
   echo $i >> hosts
done

}



check-hosts-file () {

if [ -f hosts ]
then
    read -p "There is already a hosts file within the current directory. Do you still want to create a new one? <yes/no>: " answer
    if [ "$answer" == yes ]; then
	rm -f hosts
	create-hosts-file
	echo "Great."
    elif [ "$answer" == no ]; then
	echo "OK. Proceeding with the existing hosts file.."
	exit 0
     else
	 echo "Invalid Choice"
	 exit 1
    fi
else
    create-hosts-file
fi

}



start-all-containers () {

local CONTAINERS=$(lxc-ls -f |grep -v NAME | cut -c1-12)

### grabbing all container names :)

for container in $CONTAINERS; do
   lxc-start $container
   echo $container started.. moving on..
done

}



# add user input validation..

remove-target-container () {

read -p "Please, enter the name of the lxc container you need to kill: " LXC_NAME

lxc-destroy --name $LXC_NAME --force
echo "Container $LXC_NAME killed."

}


# function to deploy public keys

deploy-keys () {

echo Deploying public key to ansible targets.. 
echo Please, provide authentication details:
ansible-playbook deploy-authorized.yml -i hosts -u ubuntu -k --ask-become-pass

}


# case/select statement which shows options to user

select TASK in 'Deploy LXC Containers' 'Destroy All LXC Containers' 'List All Running Containers' 'Create hosts file' 'Remove Target Container' 'Deploy Public Key To Ansible Targets' 'Start Stopped Containers'
do
	case $REPLY in 
                  1) TASK=deploy-containers;;
		  2) TASK=kill-all;;
                  3) TASK=list-running-containers;;
                  4) TASK=check-hosts-file;;
                  5) TASK=remove-target-container;;
                  6) TASK=deploy-keys;;
		  7) TASK=start-all-containers;;
        esac

	if [ -n "$TASK" ]
	then
	     clear
	     $TASK
             break
	else
	     echo INVALID CHOICE! && exit 3
        fi
done
