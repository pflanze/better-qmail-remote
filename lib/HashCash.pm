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

HashCash

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package HashCash;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(have_hashcash mint_hashcash);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Chj::IO::Command;

sub have_hashcash {
    my $path= `which hashcash`;
    chomp $path;
    length $path ? 1 : 0
}

sub mint_hashcash {
    @_==2 or die "wrong number of arguments";
    my ($bits, $str)=@_;
    die "address contains invalid characters"
      if $str=~ /[\n\r\t:]/s;
    my $in= Chj::IO::Command->new_sender("hashcash", "-b", $bits, "-X", "-Z", "2",
					 "-m", $str);
    my $res= $in->xcontent;
    $in->xxfinish;
    $res
}


1
