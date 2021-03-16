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
	      qlog
	 );
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

# Can't print log messages right away, even via stderr, since the
# qmail system expects qmail-remote to print protocol stuff first
# only. Delay log message till after the end.
my @log;

sub qexit {
    print @_;
    if (@log) {
	print join("\n", "", "Note:", @log);
    }
    print "\0";
    # Qmail stops copying output after the null byte.
    exit(0);
}

sub qexit_deferral {
    qexit('Z', @_);
}

sub qexit_failure {
    qexit('D', @_);
}

sub qexit_success {
    qexit('K', @_);
}

sub qlog {
    my $msg= join(" ", @_);
    chomp $msg;
    push @log, $msg;
}

1
