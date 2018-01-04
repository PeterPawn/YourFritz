#! /bin/false
##########################################################
#                                                        #
# This file contains the definitions of name parts for   #
# the files needed to sign and/or verify a signature of  #
# a firmware image (as libfwsign.so would do).           #
#                                                        #
# You may even set the name components from environment  #
# variables - e.g. setting the name_prefix like this:    #
#                                                        #
# name_prefix="$HOME/signing_key"                        #
#                                                        #
# would set the location and a different name prefix     #
# at the same time.                                      #
#                                                        #
# This file is used with multiple scripts in the context #
# of image signing, please be aware, that changes here   #
# may affect more than one script.                       #
#                                                        #
##########################################################
#                                                        #
# this is the prefix to locate and name the files        #
# related to our RSA key                                 #
#                                                        #
##########################################################
name_prefix="${name_prefix:-$HOME/image_signing}"
##########################################################
#                                                        #
# the extension of the private key file - PEM format,    #
# encrypted with aes-128                                 #
#                                                        #
##########################################################
private_extension="key"
##########################################################
#                                                        #
# the extension of the separate public key file in       #
# standard PEM format                                    #
#                                                        #
##########################################################
public_extension="pem"
##########################################################
#                                                        #
# the extensionb of the public key file in AVM's own     #
# format with the modulus and exponent without any       # 
# further text in two consecutive lines as hexadecimal   #
# text                                                   #
#                                                        #
##########################################################
avm_extension="asc"
##########################################################
#                                                        #
# the extension of a file to be used as an additional    #
# entropy source for "openssl genrsa" ... it will be     #
# create while generating the signing key, if it's not   #
# present - but this is done as 16 x 16 byte blocks      #
# from /dev/random and this may be very time consuming   #
# so you should consider to create it yourself           #
#                                                        #
##########################################################
seed_extension="rnd"
##########################################################
#                                                        #
# end of file                                            #
#                                                        #
##########################################################
