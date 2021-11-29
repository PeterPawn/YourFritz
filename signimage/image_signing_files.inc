#! /bin/false
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later WITH exceptions
#######################################################################################################
#                                                                                                     #
# include file for signimage scripts to define file locations and extension names                     #
#                                                                                                     #
###################################################################################################VER#
#                                                                                                     #
# image_signing_files.inc, version 1.0.1                                                              #
#                                                                                                     #
###################################################################################################CPY#
#                                                                                                     #
# Copyright (C) 2016-2021 P. Haemmerlein (peterpawn@yourfritz.de)                                     #
#                                                                                                     #
###################################################################################################LIC#
#                                                                                                     #
# This project is free software, you can redistribute it and/or modify it under the terms of the GNU  #
# General Public License as published by the Free Software Foundation; either version 2 of the        #
# License, or (at your option) any later version.                                                     #
#                                                                                                     #
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without   #
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      #
# General Public License under http://www.gnu.org/licenses/gpl-2.0.html for more details.             #
#                                                                                                     #
#################################################################################################EMBED#
#                                                                                                     #
# This file contains the definitions of name parts for the files needed to sign and/or verify a       #
# signature of a firmware image (as AVM's libfwsign library would do it).                             #
#                                                                                                     #
# You should consider to overwrite the settings below using environment values, instead to change the #
# contents of this file.                                                                              #
#                                                                                                     #
#################################################################################################EMBED#
#                                                                                                     #
# To relocate all personal files needed for the provided scripts (private and public keys, seeds for  #
# random number generators, etc.) in one single swoop, specify the path and common filename prefix    #
# with a variable named YF_SIGNIMAGE_FILES. The path may be an absolute value or a relative one,      #
# starting from location of the script files from project.                                            #
#                                                                                                     #
# Previous versions used a variable name 'name_prefix' instead, but this name is deprecated now, even #
# if it's still taken into account.                                                                   #
#                                                                                                     #
# If neither of these variables is present, FREETZ_IMAGE_SIGNING_PREFIX is checked next, to retain    #
# backward compatibility with the original Freetz project (https://github.com/Freetz/freetz).         #
#                                                                                                     #
# In the last resort, the default value '$HOME/image_signing' is used and the files are searched in   #
# the home directory of current user (or wherever the variable $HOME points to - this part is taken   #
# from environment anyway).                                                                           #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# this is the prefix to locate and name the files related to the RSA key generated/used for signing   #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# uncomment and change the next assignment to persist different settings, but keep the other checks   #
# intact please                                                                                       #
#                                                                                                     #
#######################################################################################################
#YF_SIGNIMAGE_FILES="<place your own value here>"
#######################################################################################################
#                                                                                                     #
# evaluate possible replacements, if YF_SIGNIMAGE_FILES isn't set yet                                 #
#                                                                                                     #
#######################################################################################################
if [ -z "$YF_SIGNIMAGE_FILES" ]; then
	[ -z "$name_prefix" ] && YF_SIGNIMAGE_FILES="$FREETZ_IMAGE_SIGNING_PREFIX"
	[ -z "$YF_SIGNIMAGE_FILES" ] && YF_SIGNIMAGE_FILES="${YF_SIGNIMAGE_FILES:-$HOME/image_signing}"
fi
#######################################################################################################
#                                                                                                     #
# the extension of private key file - PEM format, encrypted with AES-128 best                         #
#                                                                                                     #
#######################################################################################################
private_extension="key"
#######################################################################################################
#                                                                                                     #
# the extension of public key file in standard PEM format                                             #
#                                                                                                     #
#######################################################################################################
public_extension="pem"
#######################################################################################################
#                                                                                                     #
# the extension of public key file in AVM's own format - a text file with hexadecimal values for      #
# modulus and exponent on separate lines                                                              #
#                                                                                                     #
#######################################################################################################
avm_extension="asc"
#######################################################################################################
#                                                                                                     #
# the extension of a file to be used as an additional source of entropy for "openssl genrsa" ... it   #
# will be created while generating the signing key, if it's not present - but this is done with 16    #
# blocks of each 16 bytes read from /dev/random and this may be very time consuming, especially on    #
# an embedded system like a FRITZ!Box - so you should consider to create it yourself before you try   #
# to generate your own key                                                                            #
#                                                                                                     #
#######################################################################################################
seed_extension="rnd"
#######################################################################################################
#                                                                                                     #
# a list of hash algorithms supported by the scripts - placed into this file to provide an option to  #
# remove or add algorithm names without the needs to change the scripts; please take into account,    #
# that the specified algorithms (at least the one, that's finally used) have be supported by the      #
# openssl binary, too                                                                                 #
#                                                                                                     #
#######################################################################################################
supported_hashes="md5 sha1 sha224 sha256 sha384 sha512 whirlpool"
#######################################################################################################
#                                                                                                     #
# end of file                                                                                         #
#                                                                                                     #
#######################################################################################################
