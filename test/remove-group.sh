#!/bin/bash


# displaying groups detected on hosts file
echo "These are the host groups detected on the hosts file:"
echo
cat file |grep "\["
echo
read -p "What group needs to be removed? (just the name, without brackets): " RM_GROUP
read -p "The group $RM_GROUP will be removed. Are sure? <yes/no>: " ANSWER

if [ "$ANSWER" == yes ]; then 
	echo "Removing group $RM_GROUP ..."
	    rm -f delete.hosts.tmp
	    echo "$RM_GROUP" >> delete.hosts.tmp
            awk "/\[$RM_GROUP\]/,/^$/" file | sed '1d; $d; s/^ *//' >> delete.hosts.tmp
	
        # the for statement bellow will remove all occurrences that match 
        for i in $(cat delete.hosts.tmp); do sed -i "/$i/d" ./file; done
	
        # removing blank lines and recreating the file
	    cat -s file >> new-file
	    rm -f file && mv new-file file
	    rm -f delete.hosts.tmp
            echo "Done."

elif [ "$ANSWER" == no ]; then 
       echo "No worries, exiting.."

else 
      echo "Invalid Option. Exiting!"
      exit 1
fi
