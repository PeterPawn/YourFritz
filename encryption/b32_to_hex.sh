#! /bin/sh
. ${YF_SCRIPT_DIR:-.}/yf_helpers
while read length enc_length encoded; do
	hex=$(echo -n "$encoded" | base32.py decode | yf_bin2hex)
	echo -e "$length\t$(( ${#hex} / 2 ))\t$hex"
done 
