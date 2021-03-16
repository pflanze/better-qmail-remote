#
# Copyright 2015 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

Spamscore

=head1 SYNOPSIS

=head1 DESCRIPTION

*Very* ad-hoc hacky parser of whole-mail string to spamassassin
spamscore value.

=cut


package Spamscore;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(perhaps_wholemail_spamscore
	   wholemail_spamscore
	   perhaps_wholemail_doublebounce
	   perhaps_wholemail_bounce
	   perhaps_wholemail_spamscore_bounce
	 );
@EXPORT_OK=qw(
           xcontentref
           mailstring_xhead
           mailheadstring_perhaps_headerfirstline
           );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use Date::Parse;  # always load, to avoid surprises, ok?
use Chj::IO::Command;  # is always loaded by HashCash.pm anyway


sub xcontentref {
    my ($path)=@_;
    require Chj::xopen; import Chj::xopen 'xopen_read';
    my $in= xopen_read ($path);
    my $res= $in->xcontentref;
    $in->xclose;
    $res
}

my $NL= qr/(?:\015?\012)/;

sub mailstring_xhead ($) {
    #my ($str)=@_;
    my ($head)= $_[0]=~ /^(.*?)(?:$NL{2}|$)/s
        or die "can't parse head";
    $head
}

sub mailheadstring_perhaps_headerfirstline ($$) {
    my ($head,$headername)=@_;
    $head=~ /(?:^|$NL)$headername:(.*?)(?:$NL|\z)/i
}


sub mailheadstring_perhaps_received_unixtime {
    my ($head)= @_;
    if (my ($rcvd)= mailheadstring_perhaps_headerfirstline($head, "Received")) {
	if (my ($timestr)= $rcvd=~ /^\s*\(qmail.*?\);\s*(.*)/) {
	    my $t= Date::Parse::str2time $timestr;
	    if (defined $t) {
		$t
	    } else {
		warn "got invalid date string from qmail??: '$timestr'";
		()
	    }
	} else {
	    warn "expected Received value from qmail, got: '$rcvd'";
	    ()
	}
    } else {
	# warn "missing 'Received' header"--no, newly generated
	# messages don't have one.
	()
    }
}

sub perhaps_mailheadstring_spamscore ($) {
    my ($head)= @_;
    if (my ($score)= $head=~ /${NL}X-Spam-Status:.*score=(\S+)/) {
	$score
    } else {
	()
    }
}

sub perhaps_wholemail_spamscore ($) {
    my $head= mailstring_xhead $_[0];
    perhaps_mailheadstring_spamscore $head
}

sub wholemail_spamscore {
    # "Take spam score from header if present and recently delivered;
    #  from `spamcheck` script instead otherwise. If spamcheck fails,
    #  return nothing."
    my $head= mailstring_xhead $_[0];

    if (my ($received_t)= mailheadstring_perhaps_received_unixtime $head) {
	if (abs(time - $received_t) < 30) {
	    # There probably was no time to manually tag mail
	    # (probably this is an auto-forwarding), thus assume that
	    # the score didn't change.
	    if (my ($spamscore)= perhaps_mailheadstring_spamscore $head) {
		return $spamscore;
	    }
	}
    }
    # Fall back to running spamcheck and parsing *its* output.
    my $res;
    eval {
	$res= do {
	    require Chj::xtmpfile;
	    my $t= Chj::xtmpfile::xtmpfile ("/tmp/better-qmail-remote_");
	    $t->xprint($_[0]);
	    $t->xclose;
	    my $path= $t->path;
	    my $in= Chj::IO::Command->new_sender("spamcheck", $path);
	    my $str= $in->xcontent;
	    $in->xxfinish; # must exit 0 in either case
	    if (my ($newscore)= perhaps_wholemail_spamscore $str) {
		$newscore
	    } else {
		warn "'spamcheck' script did not print an X-Spam-Status header";
		# Visibly but safely break: assume it's spam (thus diverted to local).
		10
	    }
	};
	1
    } || do {
	warn "$0: wholemail_spamscore: exception: $@";
	()
    }
}

sub perhaps_wholemail_doublebounce ($) {
    # returns 2 parts: ($to_me,$return_and_orig)
    $_[0]=~ /^(.*?)$NL$NL---\ Below\ this\ line\ is\ the\ original\ bounce\.?\ *$NL$NL
	     (.*)
	    /sx
}

sub perhaps_wholemail_bounce ($) {
    # returns 2 parts: ($return,$orig)
    $_[0]=~ /^(.*?)$NL$NL---\ Below\ this\ line\ is\ a\ copy\ of\ the\ message\.?\ *$NL$NL
	     (.*)
	    /sx
}


sub perhaps_wholemail_spamscore_bounce ($) {
    if (my ($return,$orig)= perhaps_wholemail_bounce $_[0]) {
	perhaps_wholemail_spamscore $orig
    } else {
	()
    }
}


1
