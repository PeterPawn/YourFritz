# Threats reported to AVM

This folder contains security flaws, I've reported to the vendor.

Some of them are older and I got a bug-bounty reward for my reports - these findings are only listed, not described in detail and
I don't have any influence on publishing detailed information on them.

Some are newer and for a limited time AVM assigned incident numbers to my reports - if I've got such a number, it will be used as
folder name here. The two newest reports (as of 2016-10-21) didn't get such an assignment from AVM.

There were some other known threats (from 06/2013 to 12/2014), which were reported/mentioned during phone calls (in 09/2014 and 12/2014-01/2015) only.

Meanwhile I know (I got this info in 2016 per e-mail), that a "list" was created during some calls in Sept. 2014 and Dec. 2014 to Jan. 2015, which has contained 13 points. But I myself never got any knowledge, which information were it worth to be recorded there.

The command injection via `/etc/init.d/S44-hostname` or the attack using a malformed user name for (denied) FTP login to gain a root shell are examples of these threats. Another one was the existence of the (at this time yet unencrypted) private key used to sign CM certificates with "cmcertgen" in the 6360 firmware (and later in the 6490 firmware too, which I got in Dec. 2014).

They were never reported in written form, so I don't have correct information in my mail archive, when they were reported exactly and they never got an "incident number" ... and so I'll not describe them here in detail.
