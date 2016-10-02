#! /bin/sh
#######################################################################################################
#                                                                                                     #
# unpack LZMA compressed FRITZ!OS kernel                                                              #
#                                                                                                     #
# - external shell implementation of arch/mips/boot/compressed/decompress.c                           #
# - it's a complementary script to 'dump_kernel_config.sh', this one may be used on a kernel MTD      #
#   partition (or an image of it), so it's possible to extract the configuration area even from an    #
#   inactive system - the first step to do this, is to unpack the compressed kernel                   #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# Copyright (C) 2016 P.Hämmerlein (peterpawn@yourfritz.de)                                            #
#                                                                                                     #
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU  #
# General Public License as published by the Free Software Foundation; either version 2 of the        # 
# License, or (at your option) any later version.                                                     #
#                                                                                                     #
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without   #
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      #
# General Public License under http://www.gnu.org/licenses/gpl-2.0.html for more details.             #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# The compressed kernel is expected on STDIN, the uncompressed version is written to STDOUT.          #
#                                                                                                     #
# It has to be possible to store the STDIN content to a temporary file, 'cause multiple commands have #
# to access the input stream.                                                                         #
#                                                                                                     #
# A MIPS kernel image is decompressed to the address, which can be found at offset 0x08, all          #
# addresses and all length values are always in "little endian" and have to be converted, if we're    #
# running on a BE based platform.                                                                     #
#                                                                                                     #
# The LZMA header                                                                                     #
#                                                                                                     #
# struct lzma_header {                                                                                #
#     uint8_t pos;                                                                                    #
#     uint32_t dict_size;                                                                             #
#     uint64_t dst_size;                                                                              #
# } __attribute__ ((packed)) ;                                                                        #
#                                                                                                     #
# is partially located at offset 0x1C in the kernel image, but 'dst_size' can be found as uint32_t at #
# offset 0x14 in our image. The value at offset 0x10 contains the length of the compressed stream.    #
#                                                                                                     #
# The "normal" LZMA file format consists of this header, followed be the compressed stream, as a      #
# short check reveals:                                                                                #
#                                                                                                     #
# $ echo "" | lzma | hexdump -C                                                                       #
# 00000000  5d 00 00 80 00 ff ff ff  ff ff ff ff ff 00 05 41  |]..............A|                      #
# 00000010  fb ff ff ff e0 00 00 00                           |........|                              #
# 00000018                                                                                            #
#                                                                                                     #
# So we have to copy this header followed by the compressed data (starting from offset 0x24 in our    #
# image) into a temporary file to decompress it with 'lzma -d'. The length of the uncompressed stream #
# is only needed, if decompression is done to a memory buffer, but we provide it anyway to prevent an #
# 'unexpected end of input' from 'lzma -d'.                                                           #
#                                                                                                     #
# This script needs the 'testvalue' script from here:                                                 #
#                                                                                                     #
# https://github.com/PeterPawn/YourFritz/blob/master/export/testvalue                                 #
#                                                                                                     #
# , if it's not called from a FRITZ!OS installation.                                                  #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# constants                                                                                           #
#                                                                                                     #
#######################################################################################################
uncomplen_offset=20
uncomplen_size=4
complen_offset=16
complen_size=4
lzmahdr_offset=28
lzmahdr_size=5 # usually 0x5D followed by 32 KB dictionary size (0x00008000), both in LE encoding
comp_stream_offset=36
#######################################################################################################
#                                                                                                     #
# subfunctions                                                                                        #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# read 8, 16 or 32 bit values from the specified file                                                 #
#                                                                                                     #
# - this will not handle unexpected EOF while reading the file                                        #
#                                                                                                     #
#######################################################################################################
__read_value()
{
	local file="$1" type=$2 offset=$3
	
	while [ $type -gt 0 ]; do
		dd if=$file bs=1 skip=$(( offset + type - 1 )) count=1 2>/dev/null
		type=$(( type - 1 ))
	done
}
#######################################################################################################
#                                                                                                     #
# read 8, 16 or 32 bit values from the specified file, values are stored as 'little endian'           #
#                                                                                                     #
# - this will not handle unexpected EOF while reading the file                                        #
#                                                                                                     #
#######################################################################################################
__get_value()
{
	local file="$1" type=$2 offset=$3 rd i=0 v=0 s
	local s=$(( type * 8 ))
	
	rd=$(__read_value $file $type $offset | base64 | sed -e 's/+/_/g')
	while [ ${#rd} -gt $i -a $s -gt 0 ]; do
		b=$(( $(expr index "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_/" "${rd:$i:1}") - 1 ))
		[ ${rd:$i:1} == = ] && break
		if [ $s -gt 6 ]; then
			v=$(( v << 6 ))
			s=$(( s - 6 ))
		else
			v=$(( v << s ))
			b=$(( b >> 4 ))
		fi
		v=$(( v + b ))
		i=$(( i + 1 ))
	done
	printf "%u" $v
}
#######################################################################################################
#                                                                                                     #
# assure redirected STDIN descriptor                                                                  #
#                                                                                                     #
#######################################################################################################
if [ -t 0 ]; then
	printf "Kernel image to unpack is expected on STDIN.\n" 1>&2
	exit 1
fi
#######################################################################################################
#                                                                                                     #
# assure redirected STDOUT descriptor                                                                 #
#                                                                                                     #
#######################################################################################################
if [ -t 0 ]; then
	printf "Unpacked kernel image is written to STDOUT, redirect it to a file.\n" 1>&2
	exit 1
fi
#######################################################################################################
#                                                                                                     #
# save STDIN to a temporary file and prepare clean exit                                               #
#                                                                                                     #
#######################################################################################################
tf=/tmp/$(date +%s)_$$.kernel
rm $tf 2>/dev/null
trap "rm $tf 2>/dev/null" EXIT HUP INT
cat - >$tf
#######################################################################################################
#                                                                                                     #
# get length from compressed kernel image                                                             #
#                                                                                                     #
#######################################################################################################
uncomplen=$(__get_value $tf $uncomplen_size $uncomplen_offset)
complen=$(__get_value $tf $complen_size $complen_offset)
copylen1=$(( complen / comp_stream_offset )) # so we can use skip=1 to start at the stream
copylen2=$(( complen % comp_stream_offset )) # the remaining bytes to copy
copyoffset2=$(( ( copylen1 + 1 ) * comp_stream_offset )) # start of remaining copy
( dd if=$tf bs=1 skip=$lzmahdr_offset count=$lzmahdr_size 2>/dev/null; \
  dd if=$tf bs=$uncomplen_size skip=$(( uncomplen_offset / uncomplen_size )) count=1 2>/dev/null; \
  printf "\x00\x00\x00\x00"; \
  dd if=$tf bs=$comp_stream_offset skip=1 count=$copylen1 2>/dev/null; \
  dd if=$tf bs=1 skip=$copyoffset2 count=$copylen2 2>/dev/null ) | \
lzma -d
#######################################################################################################
#                                                                                                     #
# end of script                                                                                       #
#                                                                                                     #
#######################################################################################################
exit $?
