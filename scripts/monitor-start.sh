#/bin/bash

function monitor_input_directory {
	inotifywait -qme create,moved_to $input_dir --format "%f" | grep '.fast5$' --line-buffered |
       	while read filename; do
			flock $job_queue -c "echo -n \"$input_dir/$filename \" >> $job_queue" 
	done
}

function process_job_queue {
	while true; do
		if [ -s "$job_queue" ];
		then
			flock $job_queue -c "cat $job_queue > $job_queue.tmp; > $job_queue"
			filename=$(basename $(cat $job_queue.tmp | cut -d '.' -f1))
			deepnano2_caller.py --output $output_dir/$filename.fastq.tmp 					\
					    --reads $(cat $job_queue.tmp) --threads $cpu_cores 				\
					    --output-format $output_format --network-type $network_type			\
					    --beam-size $beam_size --beam-cut-threshold $beam_cut_threshold		\
					    2> /dev/null
			mv $output_dir/$filename.fastq.tmp $output_dir/$filename.fastq
		else
			sleep 10
		fi
	done
}

# Print help
if [ "$1" == "-h" ] || [ $# -ne 1 ];
then
cat << EOF
Nanocrop v0.1
Simple monitoring tool-chain. Triggers deepnano-blitz basecaller when new fast5 batch files are available.
Passes basecalled sequences to RAMPART visualizing tool.

Usage: monitor-start.sh [-h] [CONFIG_FILE]

CONFIG_FILE		Path to nanocrop configuration file.

If successful, tool-chain is initialized and running in the background. 
In order to terminate monitoring tool-chain at any time execute monitoring-stop.sh.

Report issues at <matej.fedor.mf@gmail.com>.
EOF
exit
fi

# Perform initial configuration
echo -e "Nanocrop v0.1\nSetting up environment...\n"
config_file=$1
config_path=$(dirname $config_file)

if [ -f "$config_file" ]; 
then
	source $config_file
else
	echo -e "ERROR: Configuration file does NOT exist!\nExiting..."
	exit 1
fi

if [ ! -d "$seq_dir" ] && [ -z "$input_dir" ];
then
	echo -e "ERROR: Directory containing sequencing runs \"$seq_dir\" does NOT exist!\nExiting..."
	exit 1
fi

if [ ! -d "$input_dir" ] && [ ! -z "$input_dir" ];
then
	echo -e "ERROR: Basecaller input directory \"$input_dir\" does NOT exist!\nExiting..."
	exit 1
fi

if ([ ! -d "$config_path/$protocol_dir" ] || [ -z "$protocol_dir" ]) && [ -z "$protocol_conf_dir" ];
then
	echo -e "ERROR: Directory containing RAMPART protocols \"$config_path/$protocol_dir\" does NOT exist or is NOT set!\nExiting..."
	exit 1
fi

if [ ! -d "$config_path/$protocol_conf_dir" ];
then
	echo -e "ERROR: RAMPART protocol \"$config_path/$protocol_conf_dir\" does NOT exist!\nExiting..."
	exit 1
fi

if [ ! -d "$output_dir" ];
then
	echo -e "ERROR: Basecaller output directory \"$output_dir\" does NOT exist!\nExiting..."
	exit 1
fi

if [ ! -d "$config_path/$annotations_dir" ];
then
	echo -e "ERROR: Annotations directory \"$annotations_dir\" does NOT exist!\nExiting..."
	exit 1
fi

echo -e "CPU cores used for basecalling: $cpu_cores\n"

if [ -z "$protocol_conf_dir" ];
then
	protocol_choices=$(ls -t1 $config_path/$protocol_dir | head -n 4 | cat -n)
	echo "Select a RAMPART protocol (showing 4 latest entries):"
	echo "$protocol_choices"
	echo -n "Select a number or type the protocol name [1, 2, 3, 4]: "

	read protocol
	while [ "$protocol" = "" ]; do
		echo -n "Select a number or type the protocol name [1, 2, 3, 4]: "
		read protocol
	done

	if [ $protocol -le 4 ] 2> /dev/null;
	then
		protocol_conf_dir=$(realpath -e $config_path/$protocol_dir/$(echo "$protocol_choices" | head -n $protocol | tail -n 1 | cut -f2))
	else
		if [ ! -d "$config_path/$protocol_dir/$protocol" ];
       		then
            		echo -e "RAMPART protocol directory \"$config_path/$protocol_dir/$protocol\" does NOT exist!\nExiting..."
            		exit 1
        	fi

		protocol_conf_dir=$(realpath -e $config_path/$protocol_dir/$protocol)
    	fi
	
	echo -e "Setting RAMPART protocol $protocol_conf_dir\n"
fi

if [ -z "$annotations_dir" ];
then
	annotations_dir=$config_path/../annotations/
	echo -e "Setting RAMPART annotations directory $annotations_dir\n"
fi

if [ -z "$input_dir" ];
then
	run_choices=$(ls -t1 $seq_dir | head -n 4 | cat -n)
	echo "Select a sequencing run to monitor (showing 4 latest entries):"
	echo "$run_choices"
	echo -n "Select a number or type the sequencing run name [1, 2, 3, 4]: "

	read seq_run_dir
	while [ "$seq_run_dir" = "" ]; do
		echo -n "Select a number or type the sequencing run name [1, 2, 3, 4]: "
		read seq_run_dir
	done

	if [ $seq_run_dir -le 4 ] 2> /dev/null;
	then
		seq_run_dir=$(echo "$run_choices" | head -n $seq_run_dir | tail -n 1 | cut -f2)
	else
		if [ ! -d "$seq_dir/$seq_run_dir" ];
		then
			echo -e "Sequencing run directory \"$seq_dir/$seq_run_dir\" does NOT exist!\nExiting..."
			exit 1
		fi
	fi

	echo -e "\nLooking for fast5 files in $(realpath -e $seq_dir/$seq_run_dir)"
	filename=$(find $seq_dir/$seq_run_dir -name "*.fast5" | head -n 1)
	if [ ! -z "$filename" ];
	then
		input_dir=$(dirname $filename)
	else
		echo -e "Could NOT find any fast5 files.\nWaiting for fast5 files to be generated..."
		input_dir=$(inotifywait -qre create,moved_to $seq_dir/$seq_run_dir --exclude "[^.][^f][^a][^s][^t][^5]$" | cut -d' ' -f1)
	fi

	echo -e "Setting $input_dir as input directory for fast5 files.\n"
fi

# Initialize job queue and monitoring tool-chain
echo -e "Initializing..."

pid_list="/tmp/nanocrop_pid_list.txt"
job_queue="/tmp/nanocrop_job_queue.txt"

touch $pid_list $job_queue

exec 200> $job_queue
flock -x 200 

echo "Starting input directory watchdog..."
monitor_input_directory &
echo "watchdog_pid=$!" > $pid_list
echo "watched_dir=$input_dir" >> $pid_list

if [ ! -z "$(ls -A "$input_dir")" ];
then
	for filename in "$input_dir/"*.fast5; do
		echo -n "$filename " >> $job_queue
	done
fi

flock -u 200
exec 200>&-

echo "Activating basecaller..."
process_job_queue &
echo "job_processor_pid=$!" >> $pid_list

echo -e "Starting RAMPART...\n"
location=$(pwd)
cd $protocol_conf_dir/run
rampart --protocol ../protocol --basecalledPath $output_dir --annotatedPath $location/$annotations_dir > /dev/null &
rampart_pid=$!

sleep 1
if [ -z "$(ps -p $rampart_pid -o pid=)" ];
then
	echo -e "RAMPART terminated with error.\nTerminating tool-chain..."
	echo "rampart_pid=" >> $pid_list
	$(dirname $location/$0)/monitor-stop.sh
	exit 1
else
	echo "rampart_pid=$!" >> $pid_list
fi

echo "Monitoring tool-chain is initialized SUCCESSFULLY!"
echo "Connect to RAMPART on 'http://localhost:3000'."
echo -e "Use 'monitor-stop.sh' to terminate monitoring when experiment is over. Bye!\n"
exit 0
