Timeline:

2016-07-02 05:10 - Vendor notified by (encrypted) e-mail to security@avm.de ... shell-based exploit included, together with a detailed description of the problem and the threats (in my opinion) derived from it.

2016-07-04 15:43 - Vendor confirmed receiving the notification, the problem will be investigated by developers.

2016-07-15 02:22 - Vendor contacted again, supplying another proof-of-concept for an attack based on HTML and Javascript code.

2016-08-10 15:29 - Vendor replied to the reward request (enclosed in my 1st message from above) with an own request to estimate the expenses to find this issue; included was a short note (in german "BTW: der Fehler wird mit dem nächsten geplanten Major Release behoben sein.") regarding further handling of the issue.

2016-08-10 17:25 - I replied, that this finding was the result of an extensive, systematic testing to find other vulnerabilities and I'm unable to provide such an estimation.

2016-08-16 19:11 - No further response from vendor, short note to reiterate the case.

2016-08-19 14:32 - Vendor offered an "expense allowance", not a "bug bounty reward" - there was no statement, what's the difference and how the vendor wants to handle the case further; only a request to send an invoice over the offered value was included.

2016-08-19 17:07 - I replied, that I need some time to consider the proposal, but I'd tend to decline it. Meanwhile I was waiting on answers to some questions in my message from 2016-08-10 regarding some additional facts (was it the first notification of this finding, does the vendor agree to my CVSS settings).

2016-09-05 09:19 - Final rejection of the offered allowance due to missing answers and the obscurity of the associated conditions. Request for coordinated disclosure (a notification from vendor *prior* to publication of fixed versions - there are multiple models involved into this finding) and a coordinated approach requesting a CVE number and releasing an advisory/bulletin.

2016-09-06 18:54 - Vendor declined coordinated disclosure and likes to clarify, it was a misunderstanding, that AVM is running a reward program (and that's true, there's no trace of such an offer or even a disclosure policy on their website) and each case will be examined and assessed individually. Fixed versions will never be announced to the finder, there's only a "info.txt" file included with an update describing the fixed vulnerabilities (that was never the case so far, so I'd assume one more misunderstanding regarding my request and my intention). The only offer was a notification, if a fixed version is available the first time as a "labor" version (vendor's "flavour" of beta firmware) and one more notification, if all models still in service were provided a fixed version (that's usually a longer period of time here, something around one year and it was never functioning in the past - you can't know, if AVM simply forgot the message or there are plans (how could you verify this?) to release further fixes for other models and later decisions to cancel such an intend - you can't get a statement from vendor, which models are affected and/or will be fixed).

2016-09-06 23:29 - Vendor notified, that the rejection of a coordinated disclosure leads to switching my own policy for responsible/coordinated disclosure to one, which is close to Google's "Project Zero", granting a 90 days period after the 1st notification until the finding will be published. If the vendor persists in this uncooperative practices, there's no other option. An advisory will be published on 2016-10-01 here.

2016-09-08 12:35 - Requested a CVE number myself, no such action was taken from vendor up until now, as far as I know - the announced 48 hours waiting for a CVE request confirmation from vendor were expired (started 2016-09-05 09:19).

2016-09-08 21:54 - CVE number request denied by mitre.org; starting in 2016 only the products listed under http://cve.mitre.org/cve/data_sources_product_coverage.html will be covered by this organization and AVM's products aren't listed there. The recommendation was to publish the vulnerability without a CVE number.

2016-09-14 10:39 - Vendor notified about the decision from mitre.org - the CVE number request was forwarded on 2016-09-08 13:49 to security@avm.de already.

2016-10-21 09:10 - Vendor sent notification, that the problem was fixed in the current "Labor" branch for the 7490 model (probably sub-version 41670, it was not mentioned with a number).
