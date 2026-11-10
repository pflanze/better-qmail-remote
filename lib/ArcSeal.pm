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

ArcSeal - ARC seal (RFC 8617) a message we are sending on

=head1 SYNOPSIS

    use ArcSeal qw(read_arc_config arc_seal);
    if (my $arc= read_arc_config "/var/qmail/control/arc") {
        my ($headers, $reason)= arc_seal($mailbuf, $arc, $authserv_id);
        # $headers: [ ARC-Seal, ARC-Message-Signature,
        #             ARC-Authentication-Results ], or undef
    }

=head1 DESCRIPTION

When we forward a message, or send it on to a mailing list, SPF and
often DKIM fail at the receiving end, and with them DMARC. An ARC set
records the authentication results our smtpd got on receipt (from our
Authentication-Results header) and signs them, so the receiver can take
them into account.

The key is the first `*.key` file in the given directory (normally
/var/qmail/control/arc); its file name without `.key` is the selector,
and `$selector.domain.txt` holds the signing domain (d=). The domain
doesn't have to be the From domain: it identifies us as the sealer.

The chain validation result (cv=) is taken from an `arc=` result in our
Authentication-Results header, so our smtpd needs to verify incoming ARC
chains. Without one, a message without ARC headers is sealed with
cv=none, and a message that already has ARC headers isn't sealed.

=cut


package ArcSeal;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(read_arc_config arc_seal);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

sub _first_line {
    my ($path)= @_;
    open my $fh, '<', $path or return undef;
    my $line= <$fh>;
    return undef unless defined $line;
    $line=~ s/^\s+|\s+\z//g;
    length($line) ? $line : undef
}

# Returns { keyfile, selector, domain }, or undef if there is no key.
# Dies if there is a key but no domain for it.
sub read_arc_config {
    my ($arcdir)= @_;
    my ($keyfile)= sort glob "$arcdir/*.key" or return undef;
    my ($selector)= $keyfile=~ m{([^/]+)\.key\z}s;
    my $domain= _first_line("$arcdir/$selector.domain.txt")
	// die "ARC key $keyfile has no $arcdir/$selector.domain.txt\n";
    +{ keyfile=> $keyfile, selector=> $selector, domain=> $domain }
}

# Returns ($headers, $reason): the ARC set to prepend to the message, as
# header fields with LF line endings and no final newline, or undef and
# why the message wasn't sealed.
sub arc_seal {
    my ($mailbuf, $arc, $authserv_id)= @_;
    require Mail::DKIM::ARC::Signer;
    my $signer= Mail::DKIM::ARC::Signer->new(
	Algorithm => 'rsa-sha256',
	Chain     => 'ar',
	Domain    => $$arc{domain},
	SrvId     => lc $authserv_id,
	Selector  => $$arc{selector},
	KeyFile   => $$arc{keyfile},
    );
    for my $line (split /(?<=\n)/, $mailbuf) {
	$line=~ s/\r?\n\z//;
	$signer->PRINT("$line\015\012");
    }
    $signer->CLOSE;
    my $result= $signer->result // '';
    return (undef, "not sealed: " . ($signer->result_detail || $result))
	unless $result eq 'sealed';
    my @headers= map { (my $h= $_)=~ s/\015\012/\012/g; $h } $signer->as_strings;
    (\@headers, "sealed")
}


1
