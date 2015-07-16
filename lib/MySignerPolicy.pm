# Copyright (C) 2007 Manuel Mausz (manuel@mausz.at)
# Copyright (C) 2015 Christian Jaeger (ch at christianjaeger ch)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later
# version.
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

MySignerPolicy

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package MySignerPolicy;

use strict; use warnings FATAL => 'uninitialized';

use Mail::DKIM::SignerPolicy;
use Mail::DKIM::Signature;
use Mail::DKIM::DkSignature;
use Carp;
use ConfigMerge qw(config_merge);

sub new {
    my ($class,$args)=@_;
    bless $args, $class
}

sub config { shift->{config} }


sub apply {
    my ($self, $signer) = @_;
    my $domain = undef;
    $domain = lc($signer->message_sender->host)
	if (defined($signer->message_sender));

    # merge configs
    while ($domain) {
	if (defined($self->config->{$domain})) {
	    $self->config->{'global'}->{'types'} = undef;
	    ConfigMerge::merge($self->config->{'global'}, $self->config->{$domain});
	    last;
	}
	(undef, $domain) = split(/\./, $domain, 2);
    }

    my $conf = $self->config->{'global'};
    return 0
	if (!defined($conf->{'types'}) || defined($conf->{'types'}->{'none'}));

    # set key file
    $signer->key_file($conf->{'keyfile'});

    # parse (signature) domain
    if (substr($conf->{'domain'}, 0, 1) eq '/') {
	open(FH, '<', $conf->{'domain'})
	    or croak('Unable to open domain-file: '.$!);
	my $newdom = (split(/ /, <FH>))[0];
	close(FH);
	croak("Unable to read domain-file. Maybe empty file.")
	    if (!$newdom);
	chomp($newdom);
	$conf->{'domain'} = $newdom;
    }

    # generate signatures
    my $sigdone = 0;
    for my $type (keys(%{$conf->{'types'}})) {
	my $sigconf = $conf->{'types'}->{$type};

	if ($type eq 'dkim') {
	    $signer->add_signature(
		new Mail::DKIM::Signature(
		    Algorithm  => $sigconf->{'algorithm'}  || $conf->{'algorithm'} || $signer->algorithm,
		    Method     => $sigconf->{'method'}     || $conf->{'method'}    || $signer->method,
		    Headers    => $sigconf->{'headers'}    || $conf->{'headers'}   || $signer->headers,
		    Domain     => $sigconf->{'domain'}     || $conf->{'domain'}    || $signer->domain,
		    Selector   => $sigconf->{'selector'}   || $conf->{'selector'}  || $signer->selector,
		    Query      => $sigconf->{'query'}      || $conf->{'query'},
		    Identity   => $sigconf->{'identity'}   || $conf->{'identity'},
		    Expiration => $sigconf->{'expiration'} || $conf->{'expiration'}
		)
		);
	    $sigdone = 1;
	}
	elsif ($type eq 'domainkey') {
	    $signer->add_signature(
		new Mail::DKIM::DkSignature(
		    Algorithm  => 'rsa-sha1', # only rsa-sha1 supported
		    Method     => $sigconf->{'method'}   || $conf->{'method'}   || $signer->method,
		    Headers    => $sigconf->{'selector'} || $conf->{'headers'}  || $signer->headers,
		    Domain     => $sigconf->{'domain'}   || $conf->{'domain'}   || $signer->domain,
		    Selector   => $sigconf->{'selector'} || $conf->{'selector'} || $signer->selector,
		    Query      => $sigconf->{'query'}    || $conf->{'query'}
		)
		);
	    $sigdone = 1;
	}
    }

    return $sigdone;
}


1
