/*
 * Licensed under GPLv2 
 * Copyright (C) 2014-2015, Peter Haemmerlein (opensource@peh-consulting.de)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program, please look for the file COPYING.
 */

#ifndef PRIVATEKEYPASSWORD_H

#define PRIVATEKEYPASSWORD_H

// error codes to identify the cause of unexpected results

typedef enum {
	// no error
	PRIVATEKEYPASSWORD_ERROR_NOERROR = 0,
	// error allocating a dynamic memory area
	PRIVATEKEYPASSWORD_ERROR_NOMEMORY = 1,
	// proxy binary not found or not accessible or not executable
	PRIVATEKEYPASSWORD_ERROR_NOPASSWORD = 2,
	// proxy binary not found or not accessible or not executable
	PRIVATEKEYPASSWORD_ERROR_NOPROXY = 3,
	// error executing proxy binary, but preconditions were met
	PRIVATEKEYPASSWORD_ERROR_PROXYERROR = 4,
	// error calling dynamic loader functions
	PRIVATEKEYPASSWORD_ERROR_DLERROR = 5,
	// unexpected length of password, it has to be VENDOR_PASSWORD_SIZE
	PRIVATEKEYPASSWORD_ERROR_UNEXPLEN = 6,
	// too many unsuccessfully attempts to get the password
	PRIVATEKEYPASSWORD_ERROR_TOOMANYTRIES = 7
// to be continued
} privateKeyPassword_error_t;

// call methods enumeration to select the way to determine the password

typedef enum {
	// use dynamic loader functions to load vendor's library
	PRIVATEKEYPASSWORD_METHOD_DL = 0,
	// use a proxy process and call our proxy binary
	PRIVATEKEYPASSWORD_METHOD_PROXY = 1
} privateKeyPassword_method_t;

// the external interface functions

// static char *getStaticPrivateKeyPassword(void)
//
// - returns the pointer to a static string containing the password
// - the returned string is empty in case of any error
// - call getPrivateKeyPassword_Error() to get an error code explaining the
//   reason for the latest error
char *getStaticPrivateKeyPassword(void);

// char *getPrivateKeyPassword(void)
//
// - returns the pointer to a dynamically allocated buffer containing
//   the password string (incl. trailing '\0' character) 
// - the returned value is NULL in case of any error
// - the caller is responsible to free the buffer, if the pointer isn't NULL
// - call getPrivateKeyPassword_Error() to get an error code explaining the
//   reason for the latest error
char *getPrivateKeyPassword(void);

// privateKeyPassword_error_t getPrivateKeyPassword_Error(void)
// 
// - return the latest error code for any call of this library
// - the returned value is cleared after this call
privateKeyPassword_error_t getPrivateKeyPassword_Error(void);

// void getPrivateKeyPassword_setMethod(privateKeyPassword_method_t method)
//
// - set the method used to get the password
// - calling vendor's function directly isn't supported from statically linked
//   binaries and will result in a SIGSEGV while doing dlopen() calls
// - the alternative way (calling a proxy binary) has other disadvantages like
//   an additional dependency and a higher 'costs' starting another process
void getPrivateKeyPassword_setMethod(privateKeyPassword_method_t method);

// int getPrivateKeyPassword_OpenSSL_Callback()
//
// - an additional function with the needed interface for OpenSSL password
//   callbacks
int getPrivateKeyPassword_OpenSSL_Callback(char *buf, int size, int rwflag, void * userdata);

// int getPrivateKeyPassword_WithBuffer(char *buf, size_t size)
//
// - an additional function with the needed interface to be compatible with
//   the library from er13
int getPrivateKeyPassword_WithBuffer(char *buf, size_t size);

#endif
