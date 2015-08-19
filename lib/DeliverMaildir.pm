#
# Copyright 2015 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

DeliverMaildir

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package DeliverMaildir;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(deliver_wholemail_maildir);
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
    $hn
}

sub genfilename {
    my ($hn, $i)=@_;
    # 1439893504.18412.servi:2,S
    int(time).".".$$.($i ? "_$i" : "").".".$hn
}

sub deliver_wholemail_maildir ($$) {
    #my $wholemail= $_[0];
    my $maildir= $_[1];

    my $hn= hostname;
  TRY: {
	for my $i (0..10) {
	    # XX is int ok? necessary?
	    my $filename= genfilename $hn, $i;
	    warn "trying $filename";##
	    my $path= $maildir."/tmp/".$filename;
	    my $out;
	    if (eval {
		$out= xsysopen_excl ($path);
		1
	    }) {
		$out->xprint($_[0]);
		$out->xclose;

		# oh wow: now do the same circus again!!!!
	      TRY2: {
		    for my $i (0..10) {
			# XX is int ok? necessary?
			my $filename= genfilename $hn, $i;
			warn "trying $filename";##
			my $path2= $maildir."/new/".$filename;
			if (eval {
			    xlinkunlink ($path, $path2);
			    1
			}) {
			    return $path2
			    #last TRY2;
			} else {
			    if ($! == EEXIST) {
				# redo
			    } else {
				die $@
			    }
			}
		    }
		    die "could not deliver mail, ran out of attempts finding a free filename";
		}
		#last TRY;
	    } else {
		if ($! == EEXIST) {
		    # redo
		} else {
		    die $@
		}
	    }
	}
	die "could not deliver mail, ran out of attempts finding a free filename";
    }
}

1
