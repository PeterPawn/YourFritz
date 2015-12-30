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

/* 
 *  - that's finally the "vendor's way" to get the "secret" password for the 
 *    private key file
 *
 *  - the vendor owns the needed library interface file(s) to insert dynamic 
 *    library calls at compile/link time, we should do this better with 
 *    dynamic library support functions to be independent from changes here
 *
 *  - so we'll try to locate the "securestore_get" function from "libboxlib.so"
 *    and call it with an appropriate parameter list to obtain the password 
 *    string - if we do not provide a value for the 'mask' parameter (which
 *    leads to XOR with all zeros and therefore does not change the password
 *    string), we do not need to 'deobfuscate' the resulting string
 *
 *  - to provide more flexibility, a method to use a proxy process is added
 *    and based on the assumption, that most callers of this library are
 *    using the OpenSSL libraries, there is an additional function to use
 *    this library immediately as callback routine set up with a call to
 *    'SSL_CTX_set_default_passwd_cb'
 *
 *  - to honor the aspect of weakening the 'security' of private key files
 *    with this library, I want to express it cleary: storing the private key 
 *    on the flash of a FRITZ!Box is *necessary* and you can't work around 
 *    this security threat at all ... so you better do not use the same private
 *    key anywhere else and keep in mind, that the FRITZ!Box key and certificate
 *    (finally the identity of the device) are suspicious anytime
 *
 *  - nevertheless using a secured connection and a consistent identity of the 
 *    FRITZ!Box router is better than using an open connection and many 
 *    different identities for various services, because there's a higher 
 *    probability that the user gets confused while using different keys
 *
 *  - having a solution to use the same private key for different services does
 *    not mean, you're obliged to use the same identity, but you get the 
 *    *chance* to do so
 *
 *  REMARKS:
 *
 *  - either the libboxlib.so implementation is faulty or under uClibc something
 *    else wents wrong (perhaps with pthread_atfork() handlers) => but calling
 *    fork() after dlclose()-ing the vendor's library leads to an invalid call 
 *    to an address, where the library was prior loaded, therefore we load the
 *    library only once (and check this with RTLD_NOLOAD first) and calling 
 *    dlclose() is avoided
 * 
 *  - the dlopen() call fails with a SEGV exception, if the calling binary is 
 *    built with static linking ... we have to use another implementation for
 *    such binaries to work around this problem => use a prior call to
 *    'getPrivateKeyPassword_setMethod' in this case to force proxy usage
 */

#define _GNU_SOURCE

#include <unistd.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <assert.h>
#include "privatekeypassword.h"

#define VENDOR_LIBRARY_FILE		"libboxlib.so"
#define VENDOR_LIBRARY_FUNCTION		"securestore_get"
#define VENDOR_PASSWORD_SIZE		8
#define PROXY_PATH_ENV_VARNAME		"PRIVATEKEYPASSWORD_PROXY"
#define PROXY_PATH_DEFAULT		"/usr/bin/privatekeypassword"
#define MAX_CACHED_PASSWORD_SIZE	31

typedef int (*VENDOR_FUNCTION)(int unknown1, int mask, char * buffer, int unknown2);

#define EXPORTED			__attribute__((__visibility__("default")))

#define setError(err)			__privateKeyPassword_error = PRIVATEKEYPASSWORD_ERROR_##err

#define returnError(err,value)		{ setError(err); return (value); }

// the static variable for our error code, it will be cleared after reading

static privateKeyPassword_error_t __privateKeyPassword_error = PRIVATEKEYPASSWORD_ERROR_NOERROR;

// the static variable for our error code, it will be cleared after reading

static privateKeyPassword_method_t __privateKeyPassword_method = PRIVATEKEYPASSWORD_METHOD_DL;

// the password is cached in a static variable once read, 'cause it's never 
// changed anymore

static char __privateKeyPassword_cache[MAX_CACHED_PASSWORD_SIZE + 1] = { '\0' };

// as long as we got no password, we'll try it over and over again ... one
// solution is an additional counter for unsuccessfully tries with an
// appropriate upper value to avoid useless calls => set MAX_TRIES below to
// use counting (any value > 0 will enable it)

#define MAX_TRIES			5

#if MAX_TRIES > 0
static int __privateKeyPassword_tries = 0;
#endif

// internal helper functions

char *__privateKeyPassword_malloc(const char *source)
{
	int len = strlen(source);
	if (!len) returnError(NOPASSWORD, NULL);
	char *password = malloc(len + 1);
	if (!password) returnError(NOMEMORY, NULL);
	strcpy(password, source);
	returnError(NOERROR, password);
}

int __privateKeyPassword_dynamic(char *buffer)
{
	void *handle = dlopen(VENDOR_LIBRARY_FILE, RTLD_LAZY | RTLD_NOLOAD);
	// call dlopen() without NOLOAD only, if the library isn't loaded 
	// already
	if (!handle) handle = dlopen(VENDOR_LIBRARY_FILE, RTLD_LAZY);
	if (!handle) returnError(DLERROR, 0);
	dlerror();
	VENDOR_FUNCTION function = (VENDOR_FUNCTION) dlsym(handle, VENDOR_LIBRARY_FUNCTION);
	if (dlerror()) returnError(DLERROR, 0);
	// - we call the function without obfuscation and set our mask to 0 to 
	//   prevent 'xor'ing the buffer
	// - if the fourth parameter is really the length of the allocated buffer, it is 
	//   not used this way in 'securestore_get' - any other value than 10 seems to be
	//   an error and the returned 'size' should always be 8 ... that it's a size, what
	//   is returned there, is only an assumption too
	if (VENDOR_PASSWORD_SIZE != (*function)(2, 0, buffer, 10))
	{
		*buffer = '\0';
		returnError(UNEXPLEN, 0);	
	}
	*(buffer + VENDOR_PASSWORD_SIZE) = 0;
	returnError(NOERROR, strlen(buffer));
}

int __privateKeyPassword_proxy(char *buffer)
{
	char *proxy = getenv(PROXY_PATH_ENV_VARNAME);
	if (!proxy) proxy = PROXY_PATH_DEFAULT;
	struct stat proxyStat;
	// file is missing or not accessible
	if (stat(proxy, &proxyStat)) returnError(NOPROXY, 0);
	// file is not executable
	if (!(proxyStat.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH))) returnError(NOPROXY, 0);
	FILE *pipe = popen(proxy, "r");
	// error executing proxy
	if (!pipe) returnError(PROXYERROR, 0);
	// invalid password size - we check the fixed length to avoid surprises
	// and the proxy does not append any characters (not even a newline)
	if (VENDOR_PASSWORD_SIZE == fread(buffer, 1, VENDOR_PASSWORD_SIZE, pipe))
	{
		*(buffer + VENDOR_PASSWORD_SIZE) = '\0';
	}
	else setError(UNEXPLEN);
	pclose(pipe);
	return strlen(buffer);
}

char *__privateKeyPassword_fromCache()
{
	int len = strlen(__privateKeyPassword_cache);
	if (len) returnError(NOERROR, __privateKeyPassword_cache);
#if MAX_TRIES > 0
	if (__privateKeyPassword_tries >= MAX_TRIES) returnError(TOOMANYTRIES, __privateKeyPassword_cache);
	__privateKeyPassword_tries++;
#endif
	len = ( __privateKeyPassword_method == PRIVATEKEYPASSWORD_METHOD_PROXY
		? __privateKeyPassword_proxy(__privateKeyPassword_cache)
		: __privateKeyPassword_dynamic(__privateKeyPassword_cache) );
	// error value is set already
	return __privateKeyPassword_cache;
}

// privateKeyPassword_error_t getPrivateKeyPassword_Error(void)
//
// - get the latest error code from library
// - the error code is reset after reading it once
EXPORTED privateKeyPassword_error_t getPrivateKeyPassword_Error(void)
{
	privateKeyPassword_error_t error = __privateKeyPassword_error;
	__privateKeyPassword_error = PRIVATEKEYPASSWORD_ERROR_NOERROR;
	return error;
}

// static char *getStaticPrivateKeyPassword(void)
//
// - returns the pointer to a static string containing the password
// - the returned string is empty in case of any error
// - call getPrivateKeyPassword_Error() to get an error code explaining the
//   reason for the latest error
EXPORTED char *getStaticPrivateKeyPassword(void)
{
	return __privateKeyPassword_fromCache();
}

// char *getPrivateKeyPassword(void)
//
// - returns the pointer to a dynamically allocated buffer containing
//   the password string (incl. trailing '\0' character)
// - the returned value is NULL in case of any error
// - the caller is responsible to free the buffer, if the pointer isn't NULL
// - call getPrivateKeyPassword_Error() to get an error code explaining the
//   reason for the latest error
EXPORTED char *getPrivateKeyPassword(void)
{
	return __privateKeyPassword_malloc(__privateKeyPassword_fromCache());
}

// void getPrivateKeyPassword_setMethod(privateKeyPassword_method_t method)
//
// - set the method used to get the password
// - calling vendor's function directly isn't supported from statically linked
//   binaries and will result in a SIGSEGV while doing dlopen() calls
// - the alternative way (calling a proxy binary) has other disadvantages like
//   an additional dependency and a higher 'costs' starting another process
EXPORTED void getPrivateKeyPassword_setMethod(privateKeyPassword_method_t method)
{
	assert(method == PRIVATEKEYPASSWORD_METHOD_DL
		|| method == PRIVATEKEYPASSWORD_METHOD_PROXY);
	__privateKeyPassword_method = method;
}

// int getPrivateKeyPassword_OpenSSL_Callback()
//
// - an additional function with the needed interface for OpenSSL password 
//   callbacks
EXPORTED int getPrivateKeyPassword_OpenSSL_Callback(char *buf, int size, int rwflag, void * userdata)
{
	size_t len = 0;

	if (rwflag) return len;		// no password for encoding

	// if userdata pointer is supplied, use the string it's pointing to
	// instead of any other possible passwords, so we can use this pointer
	// to override any automatic password extraction

	char *source = userdata;
	if (!source) source = __privateKeyPassword_fromCache();

	if ((len = strlen(source)))
	{
		if ((size_t) size <= len) len = size;
		strncpy(buf, source, len);
	}

	return len;
}

// int getPrivateKeyPassword_WithBuffer(char *buf, size_t size)
//
// - an additional function with the needed interface to be compatible with
//   the library from er13
EXPORTED int getPrivateKeyPassword_WithBuffer(char *buf, size_t size)
{
	int len = getPrivateKeyPassword_OpenSSL_Callback(buf, size - 1, 0, NULL);
	return (len == 0 ? -1 : len);
}
