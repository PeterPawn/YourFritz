# YourFritz Shell Script Library

## Why should I use (or need) it?

If you're working with embedded devices, you're often confronted with a very limited shell environment, where usually a BusyBox binary contains most of the available shell commands and some "bread 'n butter" commands from other environments are not available. One example is the utility ```awk``` (a swiss knife for string processing), which is missing in each FRITZ!OS version from AVM, I've ever seen yet.

Other languages as Python, Perl, Lua or Java/JavaScript are also not supported on many (or the most) devices ... if you don't want each time to compile your own binaries for different platforms, your only option is the one available common language to use - the shell command processor.

On the other hand there are in nearly each shell script some very basic tasks, which are really hard to implement, if you've to use only a POSIX compatible shell syntax, where even a simple 'substring' operation isn't present. The popular 'dash' shell (I didn't really understand, why the world needed yet another shell, but now it exists and you've to take it into account) may be faster than others, but it's really limited to the basic syntax of the POSIX standard and - on many (desktop) systems nowadays - it's the "standard shell", reachable over the symlink from ```/bin/sh```.

If you want to create shell scripts, which can be used on a desktop version of Linux and an embedded system on the same time without modifications and without installation with "autoconfigure" or any other support for different environments (on embedded devices it's rarely present), you've to think carefully, which "she-bang" you include into the file. On an embedded device, most times the ```ash``` applet of a BusyBox will be the default shell (```/bin/sh```) and on a desktop system it may vary, depending on the Linux distribution and user preferences or system settings. Some FreeBSD variants of userland utilities (including OS X from Apple) are another pitfall (e.g. the ```expr``` utility), if you want to support these systems too. In the end you can only rely on the POSIX standard as lingua franca - and then you may use the she-bang ```/bin/sh```.

This leads to a situation, where more than one script contains the same shell code for inline helper functions, while other shell dialects provide a syntax construct, which is easier to use. Some of those helpers are identically, because they are "implemented" with copy & paste, some of them are the union of two or more functions from other sources and others are created only for one special shell script.

To save me from wasting time for such functions again and again (even C&P is time consuming, if you've to search for the best boilerplate first), I've attempted to create a library of such "frequently used functions". This way they're gathered in a well-known place - combined with a simple mechanism to include the needed code into an own script.

The result is the content of this directory ...

## How can I use it?

There are two different approaches, how you may profit from this library - one is to create a special include file for the own shell script at design-time and incorporate it into the own file and the other is a more run-time centered approach, where the functions to include are assembled due to your requirements.

If you want to use the design-time approach, there are some license limitations to consider (beside all the other points of the GPLv2 license agreement, under which this library is licensed to you) ... because the generated include file will not contain any comment line and there will be no other references (to this library) within it, you're obliged to mention the source of the functions, if you want to *publish* your own script using them. If you use it only for your own purposes, this limitation will not apply.

Your key to the library is the script ```yf_helpers```, but you may include a single function yourself with the dot-command (.), if you want to do it without the automatic administration of dependencies between functions. ```yf_helpers``` was designed to be included with this dot-command into your own script and its processing may be controlled by some environment variables.

The most important variable is ```YF_SCRIPT_DIR```, which has to point to the library directory, where ```functions``` is a sub-directory (its name is fixed) containing the functions as single files. If the variable is not set, the current directory (.) is assumed to be this base directory.

The provided functions are divided into subsets to make it possible, to include only the really needed functions - sometimes even the consumed memory of a shell instance is important on an embedded device. A single function may be a member of more than one subset.

The following subset keywords are used:

- base64
  - convert data between a Base64 format and their binary content ... if no ```base64``` command is available, the conversion is done with ```cmp``` command using shell statements; it's slow as a snail, but it's working even without a binary ```base64``` command, which is missing in some (older) FRITZ!OS versions

- convert
  - convert data between different (string) presentations (binary to/from hexadecimal or decimal)

- endian
  - detect the endianess used by the run-time environment

- filesystem
  - some functions with a (what a surprise) filesystem context
- fritzbox

  - functions only useful on a FRITZ!OS based device
- network

  - functions to work with network addresses and devices
- strings
  - string manipulation even with POSIX syntax

If you want to include one or more single function(s) with automatic dependency resolving, you may specify their names with the variable ```YF_SCRIPT_FUNCTIONS```, before you include the ```yf_helpers``` script. If you want only the functions from one or more of the subsets mentioned above, you may select these subsets with the variable ```YF_SCRIPT_SUBSETS```.

The selected functions (and any other function, they're depending from) are automatically included into the current shell instance using the dot-command (any comment lines will be ignored by the shell itself), if you do not specify a variable ```YF_SCRIPT_GENERATE_FILE```. If it exists, it has to contain the name of a file, where the assembled functions are stored; this file will be overwritten without any warning, if it exists already. The output file is piped through a ```sed``` instance, which removes all comment lines (but only whole lines starting with a hash-tag, no - rarely used anyway - comments after a valid statement) - please remember the license limitations for this file.

You may use another variable to automatically store the resulting include file, if the directory with the script is writable for your account. If the variable ```YF_SCRIPT_SAVE``` is set to ```1```, the include file will be saved as ```$0.yf_scriptlib``` (if write fails, the functions aren't included) and you can try to use this file next time, if you include something like this into your script:

```shell
if [ -f "$0.yf_scriptlib" ]; then
        . $0.yf_scriptlib
else
        YF_SCRIPT_FUNCTIONS="..."
        YF_SCRIPT_SAVE=1
        . "$YF_SCRIPT_DIR/yf_helpers"
fi
```

There are some verifications done by ```yf_helpers```, that are not meaningful for the generated include file, if it's not built for the system, where ```yf_helpers``` was running. The ```yf_helpers``` script itself needs the following POSIX compatible utilities to operate:

- cmp
- expr (only the POSIX compatible syntax is used, not the GNU extensions)
- find
- printf
- sed
- sort (this is emulated with a really, really slow bubble sort implementation in shell code, if it's missing)
- uniq (will be emulated with ```read``` and a shell loop (for pre-sorted data), if it's missing)
- wc

While assembling the library functions, additional commands needed by the included functions are checked - any missing command will be mentioned with a warning message on STDERR ... but the library will be assembled in any case, because it's not sure, that you later will invoke a function, which really needs such a missing command.

If you want to see some details regarding the processing of ```yf_helpers```, you may set the variable ```YF_HELPERS_DEBUG``` to a value of ```1``` - then it will output some informational messages on STDERR.

Some simple examples, how to use the library at run-time:

```shell
export YF_SCRIPT_DIR=$HOME/scriptlib # it's also a good idea to put this into your own shell profile, if you use the library on a regular basis
YF_SCRIPT_FUNCTIONS="yf_pack yf_bin2hex" # provide only these functions (and all the others on which they are dependent)
. $HOME/scriptlib/yf_helpers # include the main file
```

```shell
export YF_SCRIPT_DIR=$HOME/scriptlib
YF_SCRIPT_SUBSETS="fritzbox" # provide only FRITZ!OS related functions (and again all the others on which they are dependent)
. $HOME/scriptlib/yf_helpers
```

```shell
export YF_SCRIPT_DIR=$HOME/scriptlib
. $HOME/scriptlib/yf_helpers # include the whole library
```

```shell
export YF_SCRIPT_DIR=$HOME/scriptlib
YF_SCRIPT_GENERATE_FILE=/tmp/my_scriptlib.txt # write the assembled functions to the specified file
YF_SCRIPT_SUBSETS="strings" # provide only string related functions
. $HOME/scriptlib/yf_helpers # create the file, but do not include it into the current instance
. $YF_SCRIPT_GENERATE_FILE # include the file as a whole, it may be re-used this way without repeated generation by other scripts

```

If you want to use the library at design-time, you may run the commands from the last example above in a shell instance and copy the generated file for further use.

## Additional files provided in the library directory

Sometimes I write shell code for special purposes in a manner, that it may be re-used ... but it's not designed to be a part of the functions. Such files will be stored in the same directory as ```yf_helpers```, but they are not intended to be a part of the library ... it's only the intent to store them in a location, where my "search and find, before you may use copy and paste" problem mentioned above is not taking place. At the time of this writing, the "multipart_form" script is the only one here - but there will be others in the near future.

Their purposes will be documented here only with a short description, look into their headers to get a exhaustive description:

- multipart_form
  - create the payload of a multipart-form HTTP request from shell code
  - the BusyBox applet ```wget``` lacks support for POST requests and they have to be emulated with the applet ```nc``` and a self-made request body
