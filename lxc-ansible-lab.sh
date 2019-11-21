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


read -p "Are you sure? This action will remove ALL running/stopped containers! <yes/no> " ANSWER

if [ "$ANSWER" == yes ]; then

   for container in $RUNNING_CONTAINERS; do
      echo "Destroying $container..."
      lxc-autostart --kill --all
      lxc-destroy --name $container --force
   done

   echo "Removing hosts file, since we don't have containers anymore.."
   rm -f hosts
   echo "hosts file removed."
   echo "Now you can start fresh :)"
   echo "done."
   exit 0

elif [ "$ANSWER" == no ]; then
   echo 
   echo "Ok, quitting now.."
   echo "Done."
   exit 0

else 
   echo 
   echo "Invalid Choice!"
   exit 1
fi


}


# function to create lxc containers based on user input

deploy-containers () {

COUNTER=0


check-ssh
read -p 'How many containers do you want to spin-up: ' AMOUNT
read -p 'Please provide the container kind: ' KIND
read -p 'Please provide a nice name for the containers: ' NAME
read -p 'Enter the name of the group: ' GROUP

while [  $COUNTER -lt "$AMOUNT" ]; do
    echo $COUNTER containers started
    lxc-create -t $KIND -n "$NAME"-"$COUNTER" && lxc-start -n "$NAME"-"$COUNTER" && echo "$NAME"-"$COUNTER" >> container.list
    let COUNTER=COUNTER+1 
done

sleep 5
create-hosts-file-and-group

}


# list all running LXC Containers

list-all-containers () {


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
    read -p "An existing hosts file was detected. Do you still want to create a new one? This might cause issues for the next playbook executions.. <yes/no>: " answer
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


# This function will create the hosts file as usual BUT will assign the new containers
# to a new group. This is meant to prevent problems when it comes to SSH KeyPair deployment,
# because a new mechanism to deploy SSH Keys for individual groups is going to be implemented.

create-hosts-file-and-group () {

#local NUM=$(lxc-ls -f | grep -v NAME | wc -l)

echo "Adding the $GROUP group to a hosts file on the current directory --> $PWD"
echo "[$GROUP]" >> hosts


for i in $(cat container.list)
do
     lxc-info $i |grep -v Link | grep ip -i | cut -c17- >> hosts.tmp.$GROUP
done

echo "" >> hosts.tmp.$GROUP
cat hosts.tmp.$GROUP >> hosts
sleep 3
rm hosts.tmp.$GROUP
rm container.list

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
echo Please, check the following:
echo ""
echo "Group(s) from the hosts file:"
cat hosts |grep '\['
echo ""
read -p 'Please, supply SSH user from remote containers: ' USRKEY
read -p 'Type in what group would you like to deploy SSH Keys to: ' GRPKEY
echo "Great, now supply authentication details..."
ansible-playbook deploy-authorized.yml -i hosts -u $USRKEY --limit $GRPKEY -k --ask-become-pass

# example: ansible-playbook deploy-authorized.yml -i hosts -u ubuntu --limit 'debian-group' -k --ask-become-pass

}



# The function 'stop-start-container-group' after being called within the case statement responsible for
# the menu bellow, after receiveing the user input will finally call right afterwards the function 
# 'group-start-stop-execute'. This one will start or stop the previously selected container group using 
# the ansible hosts file as main argument.


group-start-stop-execute () {


# displaying ip addresses of the containers fromt the selected group:
awk "/\[$GROUP\]/,/^$/" hosts | sed '1d; $d; s/^ *//'

echo ""

lxc-ls -f |grep $GROUP | awk -F' ' '{ print $1 }' | grep -v NAME >> group-to-handle.tmp


if [ "$ACTION" == stop ]; then

        for container in $(cat group-to-handle.tmp)
        do
           lxc-stop $container
           echo "Stopped container $container"
        done
        echo ""

elif [ "$ACTION" == start ]; then

        for container in $(cat group-to-handle.tmp)
        do
           lxc-start $container
           echo "Started container $container"
        done
        echo ""
else
        echo "Invalid Action!"
        exit 1
fi


}


stop-start-container-group () {

clear

echo ""
echo "Group(s) found within current hosts file:"
echo ""
cat hosts |grep '\['
echo ""



read -p "What would you like me to do? <start/stop> " ACTION
read -p "Ok, which group would you like me to $ACTION: " GROUP

if [ "$ACTION" == stop ]; then
   echo ""
   echo "Great, stopping the hosts from $GROUP group.."
   echo ""
   group-start-stop-execute

elif [ "$ACTION" == start ]; then
   echo ""
   echo "Great, starting the hosts from $GROUP group.."
   echo ""
   group-start-stop-execute

else
        echo "Invalid Action! [Options: start/stop]"
        echo "Exiting.."
        exit 1
fi


# removing temp file
rm -f group-to-handle.tmp
echo ""
echo "--------------------------------------------------------------------------"
echo "Now please check the updated status of $GROUP container group bellow:"
echo "--------------------------------------------------------------------------"
echo ""

lxc-ls -f |grep $GROUP

echo 
echo "Done!"
echo ""

}



#remove-container-group () {
#}





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

select TASK in 'Deploy LXC Containers' 'Destroy All LXC Containers' 'List All Containers' 'Create hosts file' 'Remove Target Container' 'Deploy Public Key To Ansible Targets' 'Start Stopped Containers' 'Stop/Start group of Containers' 'Remove Group of Containers'

do
	case $REPLY in 
                  1) TASK=deploy-containers;;
		  2) TASK=kill-all;;
                  3) TASK=list-all-containers;;
                  4) TASK=check-hosts-file;;
                  5) TASK=remove-target-container;;
                  6) TASK=deploy-keys;;
		  7) TASK=start-all-containers;;
		  8) TASK=stop-start-container-group;;
		  9) TASK=remove-container-group;;
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
