#!/usr/bin/perl -w

use strict; use warnings FATAL => 'uninitialized';

use Test::More;
use File::Temp qw(tempdir);

use SigningDomain qw(read_hosted_domains dkim_signing_domain);

my $dir= tempdir(CLEANUP => 1);
sub write_file {
    my ($name, $content)= @_;
    open my $fh, '>', "$dir/$name" or die "$name: $!";
    print $fh $content or die $!;
    close $fh or die $!;
}
write_file "virtualdomains", <<'END';
example.com:example.com
Example.ORG:example.org
.sub.example.net:example.net
single@example.info:single-user
END
write_file "locals", "localhost\nmx.example.com\n";

my $hosted= read_hosted_domains $dir;
my $me= 'mx.example.com';

sub mail {
    my (@header)= @_;
    join("", map { "$_\n" } @header) . "\nbody\n"
}

sub domain_for {
    my ($label, $mail, $expect)= @_;
    my ($domain, $reason)= dkim_signing_domain($mail, $hosted, $me);
    is($domain, $expect, "$label ($reason)");
}

# which domains are ours
domain_for "hosted From domain",
  mail('From: Someone <someone@example.com>'), 'example.com';
domain_for "hosted, case and trailing dot ignored",
  mail('From: someone@EXAMPLE.org.'), 'example.org';
domain_for "subdomain of a wildcard entry",
  mail('From: someone@host.sub.example.net'), 'host.sub.example.net';
domain_for "locals",
  mail('From: root@mx.example.com'), 'mx.example.com';
domain_for "foreign From domain",
  mail('From: someone@example.biz'), undef;
domain_for "a single-address entry does not make the domain ours",
  mail('From: other@example.info'), undef;
domain_for "parent of a wildcard entry is not ours",
  mail('From: someone@example.net'), undef;
domain_for "From without a domain",
  mail('From: someone'), undef;
domain_for "two From addresses",
  mail('From: a@example.com, b@example.com'), undef;
domain_for "two From headers",
  mail('From: a@example.com', 'From: b@example.com'), undef;
domain_for "folded From header",
  mail('From: "A long',
       '  name" <someone@example.com>'), 'example.com';

# where the mail came from
domain_for "submitted by an authenticated user",
  mail("Authentication-Results: $me; auth=pass (PLAIN) smtp.auth=u\@example.com",
       'From: u@example.com'), 'example.com';
domain_for "received from outside, DMARC pass for the From domain",
  mail("Authentication-Results: $me; auth=none; spf=pass smtp.mailfrom=example.com;",
       "  dmarc=pass (p=reject) d=example.com",
       'From: u@example.com'), 'example.com';
domain_for "received from outside, header.from property",
  mail("Authentication-Results: $me; auth=none; dmarc=pass header.from=example.com",
       'From: u@example.com'), 'example.com';
domain_for "received from outside, DMARC fail for the From domain (forgery)",
  mail("Authentication-Results: $me; auth=none; dmarc=fail (p=none) d=example.com",
       'From: u@example.com'), undef;
domain_for "received from outside, no DMARC result",
  mail("Authentication-Results: $me; auth=none; spf=pass smtp.mailfrom=example.com",
       'From: u@example.com'), undef;
domain_for "received from outside, From changed after receipt (list)",
  mail("Authentication-Results: $me; auth=none; dmarc=pass (p=reject) d=example.biz",
       'From: "Poster via list" <list@example.com>'), 'example.com';
domain_for "received from outside, foreign From domain",
  mail("Authentication-Results: $me; auth=none; dmarc=pass d=example.biz",
       'From: poster@example.biz'), undef;
domain_for "another authserv-id's header is not ours",
  mail("Authentication-Results: mx.example.biz; auth=pass smtp.auth=x",
       "Authentication-Results: $me; auth=none; dmarc=fail d=example.com",
       'From: u@example.com'), undef;
domain_for "only the topmost header of ours counts",
  mail("Authentication-Results: $me; auth=none; dmarc=fail d=example.com",
       "Authentication-Results: $me; auth=pass smtp.auth=u\@example.com",
       'From: u@example.com'), undef;
domain_for "authserv-id with a comment and a version",
  mail("Authentication-Results: $me (our smtpd) 1; auth=none; dmarc=fail d=example.com",
       'From: u@example.com'), undef;

done_testing;
