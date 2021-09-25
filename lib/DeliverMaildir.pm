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

DeliverMaildir

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package DeliverMaildir;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(deliver_wholemail_maildir deliver_file_maildir);
@EXPORT_OK=qw(hostname genfilename);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Chj::xperlfunc ":all";
use Chj::xsysopen 'xsysopen_excl';
use Chj::xopen 'xopen_read';
use POSIX 'EEXIST';

sub hostname {
    my $hn= xopen_read("/proc/sys/kernel/hostname")->xcontent;
    chomp $hn;
    $hn=~ m{^(\w+)\z} or die "invalid hostname? '$hn'";
    $1
}

sub genfilename {
    my ($hn, $i)=@_;
    # 1439893504.18412.servi:2,S
    # XX is int ok? necessary?
    int(time).".".$$.($i ? "_$i" : "").".".$hn
}

# (adapted COPY from deliver_wholemail_maildir)
sub deliver_file_maildir ($$;$) {
    my ($path, $maildir, $maybe_hn)=@_;
    my $hn= $maybe_hn // hostname;

    my $filename= basename ($path);

    for my $i (0..100) {
	#warn "trying $filename";##
	my $path2= $maildir."/new/".$filename;
	if (eval {
	    xlinkunlink ($path, $path2);
	    1
	}) {
	    return $path2
	} else {
	    if ($! == EEXIST) {
		$filename= genfilename $hn, $i;
		# redo
	    } else {
		die $@
	    }
	}
    }
    die "could not deliver mail (move file), ran out of attempts finding a free filename";
}

sub deliver_wholemail_maildir ($$;$$) {
    #my $wholemail= $_[0]; # string
    my $maildir= $_[1];
    my $maybe_origpath= $_[2];
    my $maybe_perms= $_[3];

    my $hn= hostname;
    my $filename= $maybe_origpath ? basename ($maybe_origpath)
      : genfilename $hn, 0;

    for my $i (0..100) {
	#warn "trying $filename";##
	my $path= $maildir."/tmp/".$filename;
	my $out;
	if (eval {
	    $out= xsysopen_excl ($path);
	    1
	}) {
	    $out->xprint($_[0]);
	    $out->xclose;
	    xchmod $maybe_perms, $path
	      if defined $maybe_perms;

	    return deliver_file_maildir $path, $maildir;
	} else {
	    if ($! == EEXIST) {
		$filename= genfilename $hn, $i;
		# redo
	    } else {
		die $@
	    }
	}
    }
    die "could not deliver mail (write string to disk), ran out of attempts finding a free filename";
}

1
