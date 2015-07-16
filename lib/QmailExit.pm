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

QmailExit

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package QmailExit;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(
	      qexit_deferral
	      qexit_failure
	      qexit_success
	 );
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

sub qexit {
    print @_, "\0";
    exit(0);
}

sub qexit_deferral {
    return qexit('Z', @_);
}

sub qexit_failure {
    return qexit('D', @_);
}

sub qexit_success {
    return qexit('K', @_);
}

1
