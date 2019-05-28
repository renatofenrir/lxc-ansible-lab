#!/bin/bash
# 
# Maintainer: Renato Rodrigues
# E-mail: renato.rod.araujo@gmail.com
# Title: lxc-ansible-lab
# License: MIT
#




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


check-ssh
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

local NUM=$(lxc-ls -f | grep -v NAME | wc -l)

echo "Adding all the $NUM containers to a hosts file on the current directory ----> $PWD"
echo "[all]" >> hosts

for i in $(lxc-ls -f | awk -F' ' '{ print $1 }' | grep -v NAME)
do 
     lxc-info $i |grep -v Link | grep ip -i | cut -c17- >> hosts
done 


}


# This function checks for an existing hosts file. If there's no hosts file, a new one is going to be created.

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



# Starts all stopped LXC containers..

start-all-containers () {

local CONTAINERS=$(lxc-ls -f | awk -F' ' '{ print $1 }' | grep -v NAME)

### grabbing all container names :)

for container in $CONTAINERS; do
   lxc-start $container
   echo $container started.. moving on..
done

}



# This function makes sure that we have ssh key-pair prior to proceeding the script execution.. 

check-ssh () {


if [[ -f ~/.ssh/id_rsa && -f ~/.ssh/id_rsa.pub ]]; then
   echo "SSH Key Pair looks good. Proceeding.."
else
    echo "There is no SSH Key Pair for the user $USER!"
    read -p "Do you want to create a new SSH Key Pair prior to proceeding? <yes/no>: " answer

	if [ "$answer" == yes ]; then
	       echo ""
	       echo "Follow the instructions bellow: "
	       ssh-keygen -t rsa
	       echo ""
	elif [ "$answer" == no ]; then
	       echo "As you wish. But you cannot use Ansible without it! Exiting.."
	       exit 0
	else
	       echo "Invalid Choice"
	       exit 1
	fi
fi


}


# Function to remove a target LXC container.

remove-target-container () {

read -p "Please, enter the name of the lxc container you need to kill: " LXC_NAME

lxc-destroy --name $LXC_NAME --force
echo "Container $LXC_NAME killed."

}


# Function to deploy public keys. Note that the function check-ssh is going to be called prior 
# to ssh key deployment.

deploy-keys () {

check-ssh
echo Deploying public key to ansible targets.. 
echo Please, provide authentication details:
ansible-playbook deploy-authorized.yml -i hosts -u ubuntu -k --ask-become-pass

}


echo ''
echo ''
echo '############################################################################'
echo '#    _                               _ _     _            _       _        #'
echo '#   | |_  _____       __ _ _ __  ___(_) |__ | | ___      | | __ _| |       #'
echo '#   | \ \/ / __|____ / _` | \_ \/ __| | |_ \| |/ _ \_____| |/ _` | |_ \    #'
echo '#   | |>  < (_|_____| (_| | | | \__ \ | |_) | |  __/_____| | (_| | |_) |   #'
echo '#   |_/_/\_\___|     \__,_|_| |_|___/_|_.__/|_|\___|     |_|\__,_|_.__/    #'
echo '#                                                                          #'
echo '############################################################################'
echo 'Created by renatofenrir'
echo ''
echo ''

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
