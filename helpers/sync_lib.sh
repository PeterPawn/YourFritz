#! /bin/sh
[ "$1" = do ] && n="" || n="n"
printf "Sync to FB7490 ...\n"
rsync -a${n}P functions/ /ssh/fb7490/var/media/ftp/root/bin/functions/
printf "Sync to modfs repository ...\n"
rsync -a${n}P functions/ ../../modfs/bin/scripts/functions/
printf "creating archive to deploy ...\n"
tar -c -v -f shell_lib.tar yf_helpers functions
