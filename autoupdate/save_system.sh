#! /bin/sh
ringbuffer=savesystem
rm /var/.srb_$ringbuffer
nand=/var/media/ftp
logfile() { showshringbuf -i $ringbuffer; }
log() { echo "$*" | logfile; }
save_part()
{
	local dev="$1" content="$2" version="$3" fn rc
	fn=${content}_$version
	cat $dev >$TD/$fn
	rc=$?
	[ $rc -eq 0 ] && log "Successfully saved $dev to $TD/$fn" || log "Error $rc saving $dev to $TD/$fn"
}
if [ "$CONFIG_PRODUKT" == "Fritz_Box_HW213a" ]; then
	core=ARM
	ledon="update_running"
	ledoff="update_no_action"
else
	if [ "$CONFIG_PRODUKT" == "Fritz_Box_HW213x" ]; then
		core=ATOM
		ledon="wlan_starting"
		ledoff="wlan_on"
	else
		log "Unknown hardware revision $CONFIG_PRODUKT"
		exit 1
	fi
fi
TD=$nand/$core
led-ctrl $ledon
log "Waiting for NAND flash to appear ..."
while true; do
	mode=$(sed -n -e "s|^[^ ]* $nand .* \(r.\),.*|\1|p" /proc/mounts)
	[ x"$mode" == x"rw" ] && break
	log "Still waiting until NAND flash storage is mounted read/write"
	sleep 10
done
log "NAND flash is mounted now on $nand"
rm -r $TD
mkdir -p $TD
log "Saving serial flash content:"
logfile </proc/mtd
sed -n -e "s/^\(mtd[0-9]\{1,2\}\): [0-9a-f]* [0-9a-f]* \"\(.*\)\"\$/MTD=\1 NAME=\"\2\"/p" /proc/mtd |
while read line; do
	eval $line
	NAME=$(echo "$NAME" | sed -e "s/[()]//g" -e "s/ /_/")
	cat /dev/$MTD >$TD/${MTD}_$NAME
	log "Copying /dev/$MTD to $TD/${MTD}_$NAME done, rc=$?"
done
log "Saving serial flash done"
log "Saving kernel and filesystem partitions"
mp=/var/tmp/savesystem.mp
mkdir -p $mp
dmesg | grep "/dev/mmcblk.*logical:.*$core" | sed -n -e "s|.*\(/dev/mmcblk.*\) logical: \(.*\)|DEV=\1 CONTENT=\2|p" |
while read line; do
	eval $line
	echo "$CONTENT" | grep -q "_reserved_" && stat="inactive" || stat="active"
	CONTENT=$(echo "$CONTENT" | sed -e "s/_reserved//")
	echo "$CONTENT" | grep -q "filesystem"
	if [ $? -eq 0 ]; then
		mount -t squashfs -o ro $DEV $mp
		rc=$?
		if [ $rc -eq 0 ]; then
			version=$($mp/etc/version --version)
			vdate=$($mp/etc/version --date)
			project=$($mp/etc/version --project)
			umount $mp
			rc=$?
			[ $rc -ne 0 ] && log "Error $rc unmounting $DEV from $mp"
			version=$version${project+-$project}
			log "Device $DEV contains $stat $CONTENT with version $version created at $vdate"
			save_part $DEV $CONTENT $version
		else
			log "Error $rc mounting $DEV to $mp - skip kernel and filesystem partition"
			version="unknown"
		fi
	else
		[ "$version" != "unknown" ] && save_part $DEV $CONTENT $version
	fi
done
rmdir $mp
showshringbuf $ringbuffer >$TD/logfile
rm /var/.srb_$ringbuffer
led-ctrl $ledoff