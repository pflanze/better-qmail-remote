# Better-qmail-remote

This is a wrapper around qmail-remote that currently does the
following jobs:

 - DKIM signing
 - hashcash if the `hashcash` tool is installed
 - avoid sending backscatter, by delivering bounces for mails with
   high-ish spamassassin scores locally

It being a wrapper written in Perl (with tainting checks on) means
that there is no need to patch Qmail, i.e. it works with the `qmail`
package from Debian (which is actually
[netqmail](http://www.qmailwiki.org/Netqmail)) and there should be
less risk of opening a security hole.

It is a reworked version of the [dkim script from
qmailtoaster](http://qmailtoaster.com/dkim.tgz). I'm running it on
some small systems, where the overhead of running a Perl wrapper is
irrelevant and where I can also easily afford to run hashcash.

This, together with using [qpsmtpd](https://smtpd.github.io/qpsmtpd/)
in place of qmail-smtpd, should be enough to make Qmail work
acceptably/well in a modern setting. (The only things missing are
encryption and delay notifications. Also, you'll want to set up SPF,
perhaps you're interested in using
[tinydns-scm](https://github.com/pflanze/tinydns-scm) for this
purpose--ah, I haven't published that yet. Feel free to
[email](http://christianjaeger.ch/contact) me.)


## Installation

This is for Debian(-derived) systems, you will have to install
packages differently on other systems and may need to use different
paths.

Check out the source code:

    cd /opt
    git clone https://github.com/pflanze/better-qmail-remote.git
    cd better-qmail-remote

Check out the latest release (unless you want the latest changes and fixes):

    v=`git tag -l | grep '^v' | sort |tail -1`
    # to check the signature
    gpg --recv-key 0FA5B21104EDB072
    git tag -v "$v"
    # check it out as a branch
    git checkout -b "$v" "$v"

Get the submodules:

    git submodule init && git submodule update

Optional: run the tests in the functional-perl submodule (although the
kind of test most likely to fail is rather unlikely to be relevant for
better-qmail-remote):

    cd functional-perl
    ./test.pl
    # NOTE: 't/csvstreams' is known to fail, no problem for this project.

Install dependencies:

    apt-get install libmail-dkim-perl  # or: cpan -i Mail::DKIM

Install hashcash if you'd like to use it (it will automatically be
used when accessible from $PATH):

    apt-get install hashcash

To use the backscatter avoidance feature (for an explanation what this
is, see the section below): decide on a group name for users who will
check the captured bounces, then set up the Maildirs using:

    /opt/better-qmail-remote/setup-debounce yourgroupname

If you want to use the XML configuration feature for DKIM keys: read
the contents of the file `install.sh`. Don't just run it, it will be
out of date. NOTE: this has not been tested since making the changes
to the original script. TODO: update or merge/drop install.sh.

Activate the wrapper:

    # on Debian:
    dpkg-divert --local --divert /usr/sbin/qmail-remote.orig --rename /usr/sbin/qmail-remote
    # otherwise just `mv /usr/sbin/qmail-remote{,.orig}`, but you'll 
    # have to do it again after package upgrades.
    ln -s /opt/better-qmail-remote/qmail-remote /usr/sbin/


## Backscatter avoidance

Neither Qmail's own qmail-smtpd nor
[qpsmtpd](https://smtpd.github.io/qpsmtpd/) check for the existence of
an email account for the given address in an incoming mail (no
surprise since local delivery can happen in ways that are configured
outside the scope of these programs). Qmail hence sends a bounce if
the email later turns out to be undeliverable. This is rather bad if
the mail is a spam, since now innocent third parties (whose email
address was misused for sending out the spam) are getting the
bounce. This might lead to your server's future deliveries being
penalized.

Better-qmail-remote checks whether the outgoing email is a bounce, and
if so, looks for an existing 'X-Spam-Status' header (as it was added
by spamassassin when it arrived through e.g. qpsmtpd), and if the
score is high-ish (currently hard coded in
[qmail-remote](qmail-remote), "if ($spamscore >= 2.5)"), delivers
locally instead, currently directly into a Maildir (the path of which
is defined in [lib/Spambounce_config.pm](lib/Spambounce_config.pm)).

There's a tool included, `debounce`, that is meant to be run
periodically (manually) and which then iterates over the mails in this
Maildir, asking for each mail whether it's spam or ham, and uses that
information to train spamassassin on the original incoming mail. For
the actual training, it calls program names 'spam' and 'ham' with the
path as only argument. You need to provide scripts with these names,
reachable through $PATH. See the examples in [examples/](examples/).

To set up the backscatter trap, the Maildir at
`/var/qmail/Maildir_spambounce` needs to be created (currently the
path is hard-coded in
[lib/Spambounce_config.pm](lib/Spambounce_config.pm); please tell if
and how you would like to have it changeable). This is done by running
the `setup-debounce` script as root.

The scripts `bounce-original` and `doublebounce-original` simply
extract the original incoming mail from a (double) bounce. They are
provided as utilities for special circumstances.


## XML config file structure

The original [dkim script from
qmailtoaster](http://qmailtoaster.com/dkim.tgz) had code to read an
XML file that configures the DKIM keys to be used. I have left this
code in, but am not using it myself (instead I'm going with the
default values, which I have changed slightly), so it's
untested. Here's some principles I gleaned from it before realizing
that I don't need it:

 - missing settings will be merged from the global-node

 - domain-entry will also match its subdomains

 - create empty domain-node to omit signing (or specify "none" as id)

        <dkimsign>
          <!-- per default sign all mails using dkim -->
          <global algorithm="rsa-sha256" domain="/var/qmail/control/me" keyfile="/var/qmail/control/dkim/global.key" method="simple" selector="beta">
            <types id="dkim" />
          </global>

          <!-- use dkim + domainkey for example.com -->
          <example.com selector="beta2">
            <types id="dkim" />
            <types id="domainkey" method="nofws" />
          </example.com>

          <!-- no signing for example2.com -->
          <example2.com />
        </dkimsign>


## spf-forward script

Also included is a script `spf-forward` that can be used as a
replacement for Qmail's `forward` program, but does sender rewriting
so that SPF checks don't break.

Its usage is: `spf-forward newsender_pre newsender_post address(es)`,
for example use with a line in a .qmail (see `man dot-qmail`) file
like this:

     |/opt/better-qmail-remote/spf-forward forwarder- @example.com youremailaddressat@gmail.com

A mail with `Return-Path: <foo@bar.com>` will now be forwarded with a
new sender, `Return-Path: <forwarder-foo=bar.com@example.com>`

Note that this doesn't follow generic
[SRS](https://en.wikipedia.org/wiki/Sender_Rewriting_Scheme) schemes:
there's no code to handle bounces. The assumption is that you set up a
`.qmail-forwarder-default` file that will forward bounces to an
admin. It's then that admin's responsibility to figure out the new
target address, or to inform the original sender of the mail about the
failure (and remove the forwarding).


## Links

Possibly useful links:

* [Qmailwiki](http://www.qmailwiki.org/Main_Page)
* [Life with qmail](http://www.lifewithqmail.org/lwq.html)
* [qmail.org](http://www.qmail.org/top.html) (is this not maintained anymore?)
* [indimail](http://www.indimail.org/) ([discussion group](http://groups.google.com/group/indimail))
* [fehcom.de](http://www.fehcom.de/qmail/qmail.html), most active current maintainer of Qmail?
* [eQmail](https://blog.dyndn.es/doku.php?id=blog:2014:10:18_eqmail_1.08)

Mailing lists:

* qmail@list.cr.yp.to, [on gmane](http://news.gmane.org/gmane.mail.qmail.general)
