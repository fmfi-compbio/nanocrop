#/bin/bash

if [ "$1" == "-h" ] || [ $# -ne 2 ]
then
cat << EOF

Simple directory watchdog. Triggers deepnano-blitz basecaller when new .fast5 batch file is available.

Usage: basecall_continuous_reads [-h] [INPUT_DIRECTORY] [OUTPUT_DIRECTORY]

INPUT_DIRECTORY		Directory being watched for .fast5 files creation.
OUTPUT_DIRECTORY	Output directory for basecalled reads.

Basecaller configuration: 
Script does not implement any basecaller configuration. Please edit its parameters manually.

EOF
exit
fi

inotifywait -qme create,moved_to $1 --format "%f" |
       	while read filename; do
		filename=`echo $filename | cut -d '.' -f1`
		deepnano2_caller.py --output $2/$filename.fastq.tmp --reads $1/$filename.fast5 --output-format fastq --network-type 48 --beam-size 5
		mv $2/$filename.fastq.tmp $2/$filename.fastq
	done
