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

lxc-ls -f

}






# case/select statement which shows options to user

select TASK in 'Deploy LXC Containers' 'Destroy All LXC Containers' 'List All Running Containers'
do
	case $REPLY in 
                  1) TASK=deploy-containers;;
		  2) TASK=kill-all;;
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
