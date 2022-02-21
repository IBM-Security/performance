#!/bin/sh

#set -x
#./create_fetch_javacore_cust.sh
#
#Usage:
#This script is used to capture the Javacores from the IGI VA server for performance analysis.
#
# Created on 08/01/2019
#
#Creators:
#	Anup R Kunwar (anup.kunwar1@ibm.com), 
#	Dave Bachmann (bachmann@us.ibm.com),
#	Nnaemeka Emejulu (eemejulu@us.ibm.com)
#	Diane Flemming (dianefl@us.ibm.com)
#
################### Assiging values 0 to the following variables ################################
#
rm -f javacorelist.txt list_javacore.txt success.txt failure.txt

function usage() {
printf "\nUsage: $0 -s hostname -u admin -p password -d /some/directory [-j (broker or ib)] -t 60 -l 2 \n"
printf "        -s      (Required) Hostname for the server where IGI VA is running \n"
printf "        -u      (Required) Username to Login in to IGIVA \n"
printf "        -p      (Required) Password for the Username above \n"
printf "        -d      (Required) directory where the javacores will be saved \n"
printf "	-j	(Optional) If not provided will collect IGI Application javacore. broker to collect broker javacore, and ib to collect both IGI and broker application javacore. \n"
printf "        -t      (Required) Time interval in seconds for each javacores to be collected For eg: -t 60 (seconds) \n"
printf "        -l      (Required) Number of Javacores to be collected \n"
printf "        -h      help \n\n"
}
hostname=""
username=""
password=""
interval=""
limit=""
snap_dir=""
date_str=$(/bin/date +"%Y%m%d%H%M")
#
################### Applying the getopts to take the value from the user ################################
#
while getopts ":s:u:p:d:j:t:l:h" opt; do 
	case "${opt}" in
		s) 
			hostname=$OPTARG ;;
		u)
            		username=$OPTARG ;;
        	p)
            		password=$OPTARG ;;
		d)
			snap_dir=$OPTARG ;;
		j)
			core=$OPTARG ;;
		t)
			interval=$OPTARG ;;
		l)
			limit=$OPTARG ;;
		[?])
			usage
			exit 1;;
		h)
			usage
            exit 1 ;;
	esac

done
shift "$((OPTIND-1))"
#
###################### Checking if the correct arguement is passed for the script to run ##########
#
if [ X$hostname == "X" ] || [ X$username == "X" ] || [ X$password == "X" ] || [ X$snap_dir == "X" ] || [ X$interval == "X" ] || [ X$limit == "X" ]
then
	usage
exit
#
#Verfying if the IGIVA server is active by pinging it
#
	else
	curl -s -k --user $username:$password --header "Content-Type:application/json" -H "Accept: application/json" https://$hostname:9443/widgets/server | tr '{}' '\012' | grep "identitygovernance" | grep -q "started"
	if [ $? == 0 ]; then
		printf "\nIGI is running so continuing to capture Javacores \n"
	else
		printf "\nIGI WAS Unreachable, Please make sure that the host is running and IGI server is started \n"
		printf "\nExiting... \n\n"
        	exit
	fi
fi
sleep 1
#
###################### Verifying if value for -j (core is provided) #################################
#
if [ -z "$core" ]
then
    	printf "\nThe value for -j is not provided so collecting javacore for IGI Application only. \n"
	printf " If you want to collect javacore for broker application or both IGI and broker Applications, use the following: \n"
	printf "	-j broker (to collect broker application javacore. \n"
	printf "	-j ib (to collect javacore for both IGI and application. \n"
elif [ "$core" = "broker" ]
then
        printf "\nCollecting javacore for Broker Application \n"
elif [ "$core" = "ib" ]
then
        printf "\nCollecting javacore for both IGI, and Broker Applications \n"
else
        printf "\nApplication not defined with -j. Provide one of the following \n"
        printf "	-j broker (To capture javacore for Broker Application \n"
        printf "	-j ib (To capture javacore for both IGI and Broker Application \n"
        exit
fi
#
################ Providing some additional information about the results. #########################
#
printf "\nPlease note the following information: \n"
printf "\nJavacores will be downloaded to $results_dir \n"
printf "\nScript will now run in the background....\n\n"
#
################ The following portion of the script will run in the background  ##############################
#

function igi (){
curl -s -k --user $username:$password  -H "Accept: application/json" --data '{generate_core_dump: "false", generate_heap_dump: "false", server_name: "igi"}' POST https://$hostname:9443/v1/dmp_mgmt
}

function broker (){
curl -s -k --user $username:$password  -H "Accept: application/json" --data '{generate_core_dump: "false", generate_heap_dump: "false", server_name: "broker"}' POST https://$hostname:9443/v1/dmp_mgmt
}

{
while [[ $limit -gt 0 ]]
	do
	(
	if [ -z "$core" ]
	then
		igi
	elif [ $core == broker ]
	then
		broker 
	elif [ $core == ib ]
	then
		igi
		broker
	fi
	)
	sleep $interval
	(( limit-- ))
done

#
####################### Checking to see if the directory exists, if not create 1 #######################
#
results_dir=$snap_dir/javacore_$date_str
if [[ ! -d $results_dir ]]
then
        mkdir -p $results_dir
fi
#
####################### Getting the list of javacore from the host machine ##############################
#
curl -s -k --user $username:$password -H "Accept: application/json" https://$hostname:9443/dmp_mgmt > list_javacore.txt
#
###################### Grepping the javacore name from the file ################################
#
grep -o 'javacore[^"]*' list_javacore.txt | sort -u > javacorelist.txt
#
##################### Assigning filename variable with the saved text file ###################
#
touch success.txt
touch failure.txt
filename='javacorelist.txt'
#
#################### Downloading the javacore from the IGI VA ###############################
#
n=1
while read line
        do
        curl -s -k --user $username:$password https://$hostname:9443/dmp_mgmt/download?$line | gunzip > $results_dir/$line
        if [ $? == 0 ]
        then
            echo $line >> success.txt
        else
            echo $line >> failure.txt
        fi
        
        n=$(( n+1))
done < $filename
#
##################### Removing the javacores created in the server ######################################
#
filename='success.txt'
n=1
while read line
        do
        curl -s -k --user $username:$password -H "Accept: application/json" -X DELETE https://$hostname:9443/dmp_mgmt/$line
        n=$(( n+1))
        done < $filename
#
##################### Removing the created text files ######################################
#
if [[ -s failure.txt ]]
then
    echo "There was an error downloading the following javacores. Please download these manually:"
    cat failure.txt
fi ;

rm -f javacorelist.txt list_javacore.txt success.txt
exit
}&
