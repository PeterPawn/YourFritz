#! /bin/sh
. .update-timestamp.conf
date="$(date +%Y%m%d%H%M)"
for file in $files; do
	sed -e "s|^\($marker=\).*|\1$date|" -i $file
done
printf "Updated timestamp string (%s) to %s\n" "$marker" "$date"


