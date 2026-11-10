#!/usr/bin/perl -w

use strict; use warnings FATAL => 'uninitialized';

use Test::More;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use Crypt::OpenSSL::RSA;
use Mail::DKIM::ARC::Verifier;

use ArcSeal qw(read_arc_config arc_seal);
use SigningDomain qw(header_fields our_auth_results received_from_outside);

my $keyfile= "test/qmail-control-dkim/foo.key";

# the public key, as published in DNS, for the verifier
my $pub= do {
    open my $fh, '<', $keyfile or die "$keyfile: $!";
    local $/;
    my $rsa= Crypt::OpenSSL::RSA->new_private_key(<$fh>);
    (my $p= $rsa->get_public_key_x509_string)=~ s/-----[^-]+-----|\s//g;
    $p
};
no warnings 'redefine';
*Mail::DKIM::DNS::query= sub {
    my ($name, $type)= @_;
    $@= '';
    return bless { data=> "v=DKIM1; k=rsa; p=$pub" }, 'FakeDNS::Record'
	if $type eq 'TXT' and lc $name eq 'arc._domainkey.example.com';
    $@= 'NXDOMAIN';
    return;
};
use warnings 'redefine';

# configuration
my $dir= tempdir(CLEANUP => 1);
is(read_arc_config($dir), undef, "no key: ARC not configured");
copy $keyfile, "$dir/arc.key" or die $!;
ok(!eval { read_arc_config($dir); 1 }, "key without a domain file: error");
open my $fh, '>', "$dir/arc.domain.txt" or die $!;
print $fh "example.com\n"; close $fh;
my $arc= read_arc_config($dir);
is_deeply($arc, { keyfile=> "$dir/arc.key", selector=> 'arc',
		  domain=> 'example.com' }, "configuration");

my $me= 'mx.example.com';
my $message= <<"END";
Authentication-Results: $me; auth=none; spf=pass smtp.mailfrom=example.org;
  dkim=pass header.i=\@example.org; dmarc=pass (p=reject) d=example.org
From: Someone <someone\@example.org>
To: list\@example.com
Subject: test
Message-ID: <arc-test\@example.org>

body
END

sub verify {
    my ($mail)= @_;
    my $v= Mail::DKIM::ARC::Verifier->new;
    for my $line (split /(?<=\n)/, $mail) {
	$line=~ s/\r?\n\z//;
	$v->PRINT("$line\015\012");
    }
    $v->CLOSE;
    $v->result
}

ok(received_from_outside(our_auth_results([header_fields $message], $me)),
   "message came in from outside");

# first hop
my ($headers, $reason)= arc_seal($message, $arc, $me);
ok($headers, "sealed ($reason)");
is_deeply([ map { /^([^:]+):/ } @{$headers || []} ],
	  [qw(ARC-Seal ARC-Message-Signature ARC-Authentication-Results)],
	  "ARC set header names");
like($$headers[0], qr/\bi=1;.*\bcv=none;/s, "ARC-Seal i=1, cv=none");
like($$headers[2], qr/^ARC-Authentication-Results: i=1; \Q$me\E;.*\bdmarc=pass\b/s,
     "our results copied into ARC-Authentication-Results");
unlike(join("", @$headers), qr/\r/, "LF line endings");
my $sealed= join("", map { "$_\n" } @$headers) . $message;
is(verify($sealed), 'pass', "the verifier accepts the ARC set");
(my $tampered= $sealed)=~ s/\nbody\n/\nchanged body\n/;
is(verify($tampered), 'fail', "but not with a changed body");

# second hop, whose smtpd didn't verify the chain: not sealed
my $me2= 'mx.example.net';
my $hop2= "Authentication-Results: $me2; auth=none; spf=fail smtp.mailfrom=example.org\n"
    . $sealed;
($headers, $reason)= arc_seal($hop2, $arc, $me2);
is($headers, undef, "existing chain without an arc= result: not sealed ($reason)");

# second hop, whose smtpd did: sealed with its result
$hop2= "Authentication-Results: $me2; auth=none; arc=pass; spf=fail smtp.mailfrom=example.org\n"
    . $sealed;
($headers, $reason)= arc_seal($hop2, $arc, $me2);
ok($headers, "existing chain with arc=pass: sealed ($reason)");
like($$headers[0] // '', qr/\bi=2;.*\bcv=pass;/s, "ARC-Seal i=2, cv=pass");
is(verify(join("", map { "$_\n" } @{$headers || []}) . $hop2), 'pass',
   "the verifier accepts the chain of two");

# a chain that failed validation here is sealed with cv=fail (RFC 8617,
# section 5.1.2), and then not sealed again (section 5.1, step 2)
my $failed_hop= "Authentication-Results: $me2; auth=none; arc=fail; spf=fail smtp.mailfrom=example.org\n"
    . $sealed;
($headers, $reason)= arc_seal($failed_hop, $arc, $me2);
like($$headers[0] // '', qr/\bi=2;.*\bcv=fail;/s, "arc=fail: sealed with cv=fail ($reason)");
my $me3= 'mx.example.org';
my $hop3= "Authentication-Results: $me3; auth=none; arc=fail\n"
    . join("", map { "$_\n" } @{$headers || []}) . $failed_hop;
($headers, $reason)= arc_seal($hop3, $arc, $me3);
is($headers, undef, "most recent seal has cv=fail: not sealed ($reason)");

# DKIM signatures are covered by the ARC-Message-Signature (section 4.1.2)
my $signed= "DKIM-Signature: v=1; a=rsa-sha256; d=example.org; s=x; h=from;\n"
    . "  bh=x; b=x\n" . $message;
($headers, $reason)= arc_seal($signed, $arc, $me);
my ($h)= ($$headers[1] // '')=~ /\bh=([^;]*)/;
like(($h // '')=~ s/\s+//gr, qr/(^|:)dkim-signature(:|$)/i,
     "ARC-Message-Signature covers DKIM-Signature");
unlike(($h // '')=~ s/\s+//gr, qr/authentication-results|arc-/i,
       "but not Authentication-Results or ARC header fields");
is(verify(join("", map { "$_\n" } @{$headers || []}) . $signed), 'pass',
   "and verifies");
(my $dkim_changed= join("", map { "$_\n" } @{$headers || []}) . $signed)
    =~ s/bh=x; b=x/bh=y; b=y/;
is(verify($dkim_changed), 'fail', "but not once the DKIM-Signature is changed");

# without our header
($headers, $reason)= arc_seal("From: someone\@example.org\n\nbody\n", $arc, $me);
is($headers, undef, "no header of ours: not sealed ($reason)");

done_testing;

package FakeDNS::Record;
sub type    { 'TXT' }
sub txtdata { $_[0]{data} }
