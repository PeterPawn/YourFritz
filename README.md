# YourFritz

The final target of this project is to provide a really dynamic package management for SOHO/consumer IADs built by 
well-known vendor (at least known in Germany) AVM from Berlin.

These devices integrate various functions into a single device and - even due to grant-aided sales over some bigger 
providers in Germany - they're used widely in many (non-professional) installations in Germany (some sources speak
about a market share of 50-60 percent here), Austria and Switzerland. 

Maybe there's a little active community using FRITZ!Box devices in Australia too ... sometimes you may find some
(mostly older) bulletin board conversations from this country regarding AVM routers.

The firmware for these devices is built on-top of Linux with many proprietary components. AVM states, they would 
publish a package with the open source files used to build their system, but since they switched to kernel version
3.10.73, these source packages are very incomplete (at least I think, they are ... I'm unable to compile a running
kernel from these sources and I'm not the only one with such problems).

This repository contains (yet) some smaller shell scripts and files supporting their use ... it's growing and each
new script is created with the intention to support the future target - they are the building blocks, which will 
be put together sometime in the future to form a single integrated solution.

Currently I'm the only one working on this project, any fellows are very welcome. 

The modfs project is a spin-off from this (earlier) project, it's a solution to change the firmware supplied by the
vendor on the FRITZ!Box device itself without the needs to use an own Linux installation with a complete toolchain 
built by the Freetz project. It's only a command line based solution, created from some proof-of-concept shell 
scripts, but it got some attention since it's a really simple solution to customize the stock firmware for your
own needs. Because it may be used to create incremental changes and it contains a "boot manager" solution to switch
a FRITZ!Box router between two different systems, each installed in its own partitions in the NAND flash of modern
devices, there's little or no risk to damage the router and even the risk to be forced to recover such a device is
practically non-existant.

Why should anybody need such a solution?

Because most users of FRITZ!OS devices are missing only an OpenVPN server/client and a SSH server for secure access
to the command shell of the devices, these packages are (according to my experiences in the support forum for the 
Freetz project from the IPPF BBS - www.ip-phone-forum.de) the most used extensions to the stock firmware and a 
solution providing these additions as modular packages could save many people from the needs to make further
changes to their devices, as the use of a "full-blown" Freetz image would do. Meanwhile the extensive changes made
by the vendor to the GUI of the devices (it's now a "responsive design" :-)) renders some important Freetz packages
useless and while Freetz is a really big solution, changing many aspects of the system and containing an own GUI
(even if it's rather old and - meanwhile - unsecure compared with the stock firmware), some users want only smaller
changes and prefer a solution, which can make them more "under the hood" without interferences with the original
firmware.

It's not possible to implement the final solution in one fell swoop ... but the building blocks are growing step
by step and meanwhile I think, we should be able to test the first integrated version during this year.
