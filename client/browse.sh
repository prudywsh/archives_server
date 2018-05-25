# name parameters
host=$1
port=$2
archive_name=$3
archive_root=$4

# if the server responded with an error code, display message and leave here 
if [[ $archive_root == "-1" ]];
then
	echo "can't find the requested archive on the server"
	exit 1
fi

current_location="/"

fetch_location(){
	# send the request and reopen netcat to  
	# see the server's response
	echo "browsels $archive_name $1" > client_in.txt
	nc $host $port < client_in.txt
	sleep 1s
	nc $host $port > client_out.txt
}

# check if the dir exists in the archive
# return 0 (no) or 1 (yes)
directory_exists(){
	echo "direxists $archive_name $1" > client_in.txt
	nc $host $port < client_in.txt
	sleep 1s
	nc $host $port > client_out.txt
}

cmd=""
while [[ $cmd != "exit" ]];
do
	cmd_parts=( $cmd )
	if [[ ${cmd_parts[0]} == "pwd" ]];
	then
		echo $current_location
	elif [[ ${cmd_parts[0]} =~ "ls" ]];
	then
		fetch_location "$archive_root$current_location${cmd_parts[1]}"
		# format and display the response
		str=""
		while read line 
		do 
			if [[ $line =~ ^.+d.+ ]];
			then
				# it's a dir
				str+="$(echo $line | cut -d " " -f 1)/ "
			else
				# it's a file
				str+="$(echo $line | cut -d " " -f 1)"
				# check if executable
				if [[ $line =~ .*[r\-][w\-][x].* ]];
				then
					str+="*"
				fi
				str+=" "
			fi
		done < client_out.txt
		echo $str
	elif [[ ${cmd_parts[0]} =~ "cd" ]];
	then
		# check that there is a second parameter (where to go)
		if [[ ${#cmd_parts[@]} -lt 2 ]];
		then
			echo "cd: missing operand" >&2
			echo "cd: you must provide the destination" >&2
		else
			if [[ ${cmd_parts[1]} == "/" ]];
			then
				current_location="/"
			elif [[ ${cmd_parts[1]} == ".." ]]
			then
				current_location=$(dirname $current_location)
			else
				# check if the resulting dir exists in the archive
				directory_exists "$archive_root$current_location${cmd_parts[1]}"
				exists=$(cat client_out.txt)
				if [[ $exists == "1" ]];
				then
					current_location="$current_location${cmd_parts[1]}/"
				else
					echo "cd: invalid operand" >&2
					echo "cd: you must provide a valid the destination" >&2
				fi
			fi			
		fi
	fi
	read -p "vsh@$host:$port {$archive_name} $current_location :> " cmd
done