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


create-hosts-file () {

local LIST=$(lxc-ls -f | grep -v NAME | cut -c37-47)
local NUM=$(lxc-ls -f | grep -v NAME | wc -l)

echo "Adding all the $NUM containers to a hosts file on the current directory ----> $PWD"
echo "[all]" >> hosts

for i in $LIST
do
   echo $i >> hosts
done

}




# add user input validation..

remove-target-container () {

read -p "Please, enter the name of the lxc container you need to kill: " LXC_NAME

lxc-destroy --name $LXC_NAME --force
echo "Container $LXC_NAME killed."

}



# case/select statement which shows options to user

select TASK in 'Deploy LXC Containers' 'Destroy All LXC Containers' 'List All Running Containers' 'Create hosts file' 'List All Running Containers' 'Remove Target Container'
do
	case $REPLY in 
                  1) TASK=deploy-containers;;
		  2) TASK=kill-all;;
                  3) TASK=list-running-containers;;
                  4) TASK=create-hosts-file;;
                  5) TASK=list-running-containers;;
                  6) TASK=remove-target-container;;
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
