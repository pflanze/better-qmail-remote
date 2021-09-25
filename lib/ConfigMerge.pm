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

ConfigMerge

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package ConfigMerge;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(config_merge);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

# merge config hashes. arrays and scalars will be copied.
sub config_merge {
    my ($left, $right) = @_;
    for my $rkey (keys(%$right)) {
	my $rtype = ref($right->{$rkey}) eq 'HASH' ? 'HASH'
	    : ref($right->{$rkey}) eq 'ARRAY' ? 'ARRAY'
	    : defined($right->{$rkey}) ? 'SCALAR'
	    : '';
	my $ltype = ref($left->{$rkey}) eq 'HASH' ? 'HASH'
	    : ref($left->{$rkey}) eq 'ARRAY' ? 'ARRAY'
	    : defined($left->{$rkey}) ? 'SCALAR'
	    : '';
	if ($rtype ne 'HASH' || $ltype ne 'HASH') {
	    $left->{$rkey} = $right->{$rkey};
	} else {
	    config_merge($left->{$rkey}, $right->{$rkey});
	}
    }
    return;
}


1
