# DoS attack to FRITZ!OS devices with version < 06.80 using an unauthenticated HTTP(S) request

## Description

The whole problem was discussed in a thread on IPPF: http://www.ip-phone-forum.de/showthread.php?t=290448 (in german language only). 

Coupled with a poll about the decision to prove it with a proof-of-concept for this threat after the vendor fixed it for the first three models from its product line, a description of the problem was published.

BTW ... the votes: 90 members took part, 13 voted for "immediate release of each information" (full disclosure), 61 votes for "release now, there was already enough time to fix it" and 16 votes for the third option "let the vendor decide, when it's time to publish information about the (now patched) threat (if it will ever happen)".

After the public poll was started, the vendor decided to communicate/react again, my previous attempts were (mostly) ignored - as a result, the publication of the PoC files was delayed about 8 weeks due to two requests from vendor.

## How does it work?

A firmware component runs as a singleton, it may be called in an unauthenticated manner and it's possible to provide incomplete information to such a call. 

As a result, an instance of this component will be started and it's waiting for about 40 minutes for further input, blocking any additional request to the same component (/cgi-bin/firmwarecfg), which is responsible for different tasks, from file downloads (support data, settings export) to uploads (settings import) and firmware updates.

Because additional requests to this component will be queued and every associated TCP connection was correct established, each such request results in a "hanging" TCP connection too. 

The number of external connections is limited (I was able to start up to 15 TLS connections here) and that's why any external (TCP based) access may be blocked this way. 

Even all internal TCP connections (needed for GUI or SIP registrar (over TCP) or NAS) may become exhausted in this manner, but their number is higher (~ 180 connections are possible on a 7490 device).

The additional read request (it's my assumption of the basic problem, based on the value "unix_stream_recvmsg" in the "wchan" pseudo file of the started "firmwarecfg" process) will be finished after about 40 minutes due to a timeout. 

Afterwards the next request in the queue will be started ... even over the limited number of TLS connections, the normal function of "firmwarecfg" may be effectively blocked for 10 hours (15 requests * 40 minutes per request) within seconds.

## Fix/Solution

The vendor (AVM) has published new firmware versions for most models still in service. It should be no threat anymore in versions >= 06.80.

## Timeline:

2016-07-02 05:10 - Vendor notified by (encrypted) e-mail to security@avm.de ... shell-based exploit included, together with a detailed description of the problem and the threats (in my opinion) derived from it.

2016-07-04 15:43 - Vendor confirmed receiving the notification, the problem will be investigated by developers.

2016-07-15 02:22 - Vendor contacted again, supplying another proof-of-concept for an attack based on HTML and Javascript code.

2016-08-10 15:29 - Vendor replied to the reward request (enclosed in my 1st message from above) with an own request to estimate the expenses to find this issue; included was a short note (in german "BTW: der Fehler wird mit dem nächsten geplanten Major Release behoben sein.") regarding further handling of the issue.

2016-08-10 17:25 - I replied, that this finding was the result of an extensive, systematic testing to find other vulnerabilities and I'm unable to provide such an estimation.

2016-08-16 19:11 - No further response from vendor, short note to reiterate the case.

2016-08-19 14:32 - Vendor offered an "expense allowance", not a "bug bounty reward" - there was no statement, what's the difference and how the vendor wants to handle the case further; only a request to send an invoice over the offered value was included.

2016-08-19 17:07 - I replied, that I need some time to consider the proposal, but I'd tend to decline it. Meanwhile I was waiting on answers to some questions in my message from 2016-08-10 regarding some additional facts (was it the first notification of this finding, does the vendor agree to my CVSS settings).

2016-09-05 09:19 - Final rejection of the offered allowance due to missing answers and the obscurity of the associated conditions. Request for coordinated disclosure (a notification from vendor *prior* to publication of fixed versions - there are multiple models involved into this finding) and a coordinated approach requesting a CVE number and releasing an advisory/bulletin.

2016-09-06 18:54 - Vendor declined coordinated disclosure and likes to clarify, it was a misunderstanding, that AVM is running a reward program (and that's true, there's no trace of such an offer or even a disclosure policy on their website) and each case will be examined and assessed individually. Fixed versions will never be announced to the finder, there's only a "info.txt" file included with an update describing the fixed vulnerabilities (that was never the case so far, so I'd assume one more misunderstanding regarding my request and my intention). The only offer was a notification, if a fixed version is available the first time as a "labor" version (vendor's "flavour" of beta firmware) and one more notification, if all models still in service were provided a fixed version (that's usually a longer period of time here, something around one year and it was never functioning in the past - you can't know, if AVM simply forgot the message or there are plans (how could you verify this?) to release further fixes for other models and later decisions to cancel such an intent - you can't get a statement from vendor, which models are affected and/or will be fixed).

2016-09-06 23:29 - Vendor notified, that the rejection of a coordinated disclosure leads to switching my own policy for responsible/coordinated disclosure to one, which is close to Google's "Project Zero", granting a 90 days period after the 1st notification until the finding will be published. If the vendor persists in this uncooperative practices, there's no other option. An advisory will be published on 2016-10-01 here.

2016-09-08 12:35 - Requested a CVE number myself, no such action was taken from vendor up until now, as far as I know - the announced 48 hours waiting for a CVE request confirmation from vendor were expired (started 2016-09-05 09:19).

2016-09-08 21:54 - CVE number request denied by mitre.org; starting in 2016 only the products listed under http://cve.mitre.org/cve/data_sources_product_coverage.html will be covered by this organization and AVM's products aren't listed there. The recommendation was to publish the vulnerability without a CVE number.

2016-09-14 10:39 - Vendor notified about the decision from mitre.org - the CVE number request was forwarded on 2016-09-08 13:49 to security@avm.de already.

2016-10-21 09:10 - Vendor sent notification, that the problem was fixed in the current "Labor" branch for the 7490 model (probably sub-version 41670, it was not mentioned with a number).

2017-04-11 02:56 - I've published two files as proof-of-concept ... this was planned on 2017-02-12 already, but it was delayed twice due to a request from vendor. Meanwhile most models may be updated by their owners and the remaining models without a patched version will probably not get a new firmware in the near future - especially for the 6490 model an update is still missing.

2017-04-19 11:00 - I've updated this description a last time and included the link to the german discussion/description ... now this case is about to be closed.
