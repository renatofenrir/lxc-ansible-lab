#!/bin/bash

read -p "What group needs to be removed? " RM_GROUP
read -p "The group $RM_GROUP will be removed. Are sure? <yes/no>: " ANSWER

if [ "$ANSWER" == yes ]; then 
	echo "Removing group $RM_GROUP ..."
	echo "$RM_GROUP" >> delete.hosts.tmp
        awk "/\[$RM_GROUP\]/,/^$/" file | sed '1d; $d; s/^ *//' >> delete.hosts.tmp
	for i in $(cat delete.hosts.tmp); do sed -i "/$i/d" ./file; done
	# removing last blank line for better readability..
	sed -i '$ d' file
	echo "Done."

elif [ "$ANSWER" == no ]; then 
       echo "No worries, exiting.."

else 
      echo "Invalid Option. Exiting!"
      exit 1
fi
