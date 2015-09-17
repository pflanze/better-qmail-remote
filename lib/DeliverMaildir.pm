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

sub deliver_wholemail_maildir ($$;$) {
    #my $wholemail= $_[0]; # string
    my $maildir= $_[1];
    my $maybe_origpath= $_[2];

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
