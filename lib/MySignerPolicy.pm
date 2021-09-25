# Copyright (C) 2007 Manuel Mausz (manuel@mausz.at)
# Copyright (C) 2015-2021 Christian Jaeger (ch at christianjaeger ch)
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

sub new {
    my ($class, $config, $maybe_debugprint)=@_;
    bless { config=> $config,
	    maybe_debugprint=> $maybe_debugprint }, $class
}

sub debug {
    my $self=shift;
    if (my $pr= $self->{maybe_debugprint}) {
	my @args= map {
	    if (ref $_) {
		require Data::Dumper;
		local $Data::Dumper::Sortkeys=1;
		Data::Dumper::Dumper($_)
	    } else {
		$_
	    }
	} @_;
	$pr->(@args)
    }
}

sub config { shift->{config} }


sub apply {
    my ($self, $signer) = @_;
    my $host= $signer->message_sender->host;
    my $domain = $host && lc $host;

    $self->debug("apply config", $self->config);

    # merge configs
    while ($domain) {
	if (exists $self->config->{$domain}) {
	    $self->config->{'global'}->{'types'} = undef;
	    ConfigMerge::merge($self->config->{'global'}, $self->config->{$domain});
	    last;
	}
	(undef, $domain) = split(/\./, $domain, 2);
    }

    my $sigdone = 0;
    for my $selector (sort keys %{$self->config}) {
	my $conf = $self->config->{$selector};
	next # XX or report an error?
	  if (!exists($conf->{'types'})
	      ||
	      (exists($conf->{'types'}->{'none'}) and defined($conf->{'types'}->{'none'})));

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
	for my $type (keys(%{$conf->{'types'}})) {
	    my $sigconf = $conf->{'types'}->{$type};

	    my $get= sub {
		my ($key)=@_;
		my $fallback= exists $conf->{$key} ? $conf->{$key} : undef;
		exists $sigconf->{$key} ? ($sigconf->{$key} || $fallback) : $fallback
	    };
	    my $getm= sub {
		my ($key)=@_;
		&$get($key) || $signer->$key
	    };

	    if ($type eq 'dkim') {
		$signer->add_signature(
		    new Mail::DKIM::Signature(
			Algorithm  => &$getm('algorithm'),
			Method     => &$getm('method'),
			Headers    => &$getm('headers'),
			Domain     => &$getm('domain'),
			Selector   => &$getm('selector'),
			Query      => &$get('query'),
			Identity   => &$get('identity'),
			Expiration => &$get('expiration'),
		    )
		    );
		$sigdone = 1;
	    }
	    elsif ($type eq 'domainkey') {
		$signer->add_signature(
		    new Mail::DKIM::DkSignature(
			Algorithm  => 'rsa-sha1', # only rsa-sha1 supported
			Method     => &$getm('method'),
			Headers    => &$getm('selector'),
			Domain     => &$getm('domain'),
			Selector   => &$getm('selector'),
			Query      => &$get('query')
		    )
		    );
		$sigdone = 1;
	    }
	}
    }
    return $sigdone;
}


1
