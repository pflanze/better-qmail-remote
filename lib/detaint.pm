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

detaint -- local ~copy

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package detaint;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(detaint);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

sub detaint ($) {
    $_[0]=~ /^(.*)\z/s or die "??";
    $1
}

1
