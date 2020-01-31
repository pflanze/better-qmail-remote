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


sub perhaps_wholemail_spamscore ($) {
    #my ($str)=@_;
    my $head= mailstring_xhead $_[0];
    if (my ($score)= $head=~ /${NL}X-Spam-Status:.*score=(\S+)/) {
	$score
    } else {
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
