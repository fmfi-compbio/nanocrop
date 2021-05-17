#/bin/bash

echo "Terminating monitoring tool-chain..."

pid_file="/tmp/nanocrop_pid_list.txt"
job_file="/tmp/nanocrop_job_queue.txt"
job_file_tmp="/tmp/nanocrop_job_queue.txt.tmp"

if [ -f "$pid_file" ];
then
	source $pid_file
else
	echo -e "No active tool-chain found!\nExiting..."
	exit 1
fi

kill -9 $watchdog_pid
kill -9 $(ps -f | grep "inotifywait -qme create,moved_to $watched_dir --format %f" | head -n 1 | tr -s " " | cut -d' ' -f2)
kill -9 $job_processor_pid

if [ ! -z "$rampart_pid" ];
then
	kill -9 $rampart_pid
fi

rm $pid_file
rm $job_file

if [ -f "$job_file_tmp" ];
then
	rm $job_file_tmp
fi

echo "DONE! Bye!"
exit 0
