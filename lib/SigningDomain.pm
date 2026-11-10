# Copyright (C) 2026 yitzhaq
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=head1 NAME

SigningDomain - decide which domain, if any, to DKIM sign a message for

=head1 SYNOPSIS

    use SigningDomain qw(read_hosted_domains dkim_signing_domain);
    my $hosted= read_hosted_domains "/var/qmail/control";
    my ($domain, $reason)=
        dkim_signing_domain($mailbuf, $hosted, $authserv_id);
    # $domain is undef if the message should not be signed

=head1 DESCRIPTION

A DKIM signature only helps DMARC if its domain is the domain of the
From header, and we should only sign for domains we host. So a message
is signed for its From domain if that domain is listed in
control/virtualdomains or control/locals.

Mail that came in from outside and is now being sent on (forwarded,
or sent to a mailing list) carries the Authentication-Results header
our smtpd added on receipt. If its From domain is one of ours, it is
only signed if that header recorded a DMARC pass for that domain (it
really is our mail), or recorded a DMARC result for another domain (the
From header was changed after receipt, as mailing list managers do to
avoid DMARC failures). Otherwise it could be a forgery of one of our
domains, and signing it would make it look genuine. Mail submitted by
an authenticated user (auth=pass) or generated locally (no header of
ours) is signed.

This relies on the smtpd renaming incoming Authentication-Results
headers that claim our authserv-id, as RFC 8601 requires.

=cut


package SigningDomain;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(read_hosted_domains header_fields from_domain our_auth_results
	      received_from_outside dkim_signing_domain);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Mail::Address;
use Mail::AuthenticationResults::Parser;

sub _lines {
    my ($path)= @_;
    open my $fh, '<', $path or return ();
    map { s/^\s+|\s+\z//g; length($_) ? $_ : () } <$fh>
}

# Returns { exact => { domain => 1 }, wildcard => { parent => 1 } }:
# the domains in control/virtualdomains ("domain:prepend", or
# ".parent:prepend" for all subdomains of parent; single addresses,
# "user@domain:prepend", are not whole domains and are skipped) and
# control/locals.
sub read_hosted_domains {
    my ($controldir)= @_;
    my %exact; my %wildcard;
    for (_lines("$controldir/virtualdomains")) {
	my ($d)= /^([^:]*):/ or next;
	next if $d=~ /\@/ or !length $d;
	$d= lc $d;
	if ($d=~ s/^\.//) {
	    $wildcard{$d}= 1;
	} else {
	    $exact{$d}= 1;
	}
    }
    $exact{lc $_}= 1 for _lines("$controldir/locals");
    +{ exact=> \%exact, wildcard=> \%wildcard }
}

sub is_hosted {
    my ($domain, $hosted)= @_;
    return 1 if $hosted->{exact}{$domain};
    my $d= $domain;
    while ($d=~ s/^[^.]*\.//) {
	return 1 if $hosted->{wildcard}{$d};
    }
    0
}

# The header fields of a message (up to the first empty line), unfolded,
# as a list of [ lowercase name, value ].
sub header_fields {
    my ($mailbuf)= @_;
    my ($head)= $mailbuf=~ /\A(.*?)(?:\r?\n\r?\n|\z)/s;
    my @fields;
    for my $line (split /\r?\n/, $head) {
	if ($line=~ /^[ \t]/ and @fields) {
	    $fields[-1][1].= "\n$line";
	} elsif (my ($name, $value)= $line=~ /^([^:\s]+)[ \t]*:(.*)\z/s) {
	    push @fields, [lc $name, $value];
	}
    }
    @fields
}

# The domain of the From header, lowercase, or undef unless there is
# exactly one From header with exactly one address.
sub from_domain {
    my ($fields)= @_;
    my @from= map { $$_[1] } grep { $$_[0] eq 'from' } @$fields;
    return undef unless @from == 1;
    my @addr= Mail::Address->parse($from[0]);
    return undef unless @addr == 1;
    my $host= $addr[0]->host;
    return undef unless defined $host and length $host;
    $host= lc $host;
    $host=~ s/\.\z//;
    $host
}

# The topmost Authentication-Results header with our authserv-id (the
# one our smtpd added on receipt), as { method => [ entry, .. ] } where
# each entry is { result => .., props => { name => value } }, or undef.
sub our_auth_results {
    my ($fields, $authserv_id)= @_;
    for my $field (@$fields) {
	next unless $$field[0] eq 'authentication-results';
	my $ar= eval {
	    Mail::AuthenticationResults::Parser->new->parse($$field[1])
	} or next;
	next unless lc($ar->value->value) eq lc $authserv_id;
	my %results;
	for my $entry (@{$ar->children}) {
	    next unless $entry->isa('Mail::AuthenticationResults::Header::Entry');
	    my %props= map { (lc($_->key) => $_->value) }
		grep { $_->isa('Mail::AuthenticationResults::Header::SubEntry') }
		@{$entry->children};
	    push @{$results{lc $entry->key}},
		+{ result=> lc($entry->value), props=> \%props };
	}
	return \%results;
    }
    undef
}

# Whether the message came in from outside: it has our header (added
# by our smtpd on receipt), and that doesn't record auth=pass. Takes
# the result of our_auth_results.
sub received_from_outside {
    my ($ar)= @_;
    $ar and !grep { $$_{result} eq 'pass' } @{$$ar{auth} || []}
}

# Returns ($domain, $reason): the domain to sign for, or undef and why not.
sub dkim_signing_domain {
    my ($mailbuf, $hosted, $authserv_id)= @_;
    my @fields= header_fields $mailbuf;
    my $from= from_domain \@fields;
    return (undef, "no single From address")
	unless defined $from;
    return (undef, "From domain $from is not hosted here")
	unless is_hosted $from, $hosted;

    my $ar= our_auth_results \@fields, $authserv_id;
    # no header of ours: locally generated
    return ($from, "locally generated") unless $ar;
    return ($from, "submitted with auth=pass")
	unless received_from_outside $ar;

    # came in from outside
    my ($dmarc)= @{$$ar{dmarc} || []};
    return (undef, "received from outside without a DMARC result")
	unless $dmarc;
    my $d= lc($$dmarc{props}{'header.from'} // $$dmarc{props}{d} // '');
    $d=~ s/\.\z//;
    return ($from, "received with dmarc=pass for $from")
	if $d eq $from and $$dmarc{result} eq 'pass';
    return ($from, "From changed after receipt (DMARC was for $d)")
	if length $d and $d ne $from;
    (undef, "received from outside with dmarc=$$dmarc{result} for $from")
}


1
