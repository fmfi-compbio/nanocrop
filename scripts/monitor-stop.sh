#/bin/bash

echo "Terminating monitoring tool-chain..."
pid_file="/tmp/nanocrop_pid_list.txt"

if [ -f "$pid_file" ];
then
	source $pid_file
else
	echo -e "No active tool-chain found!\nExiting..."
	exit 1
fi

kill -9 $watchdog_pid
kill -9 $(ps -f | grep "inotifywait -qme create,moved_to /tmp/reads --format %f" | head -n 1 | tr -s " " | cut -d' ' -f2)
kill -9 $job_processor_pid

if [ ! -z "$rampart_pid" ];
then
	kill -9 $rampart_pid
fi

rm $pid_file
rm /tmp/nanocrop_job_queue.txt

echo "DONE! Bye!"
