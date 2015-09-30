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

Spambounce_config -- config for anti-backscatter feature

=head1 SYNOPSIS

 use Spambounce_config qw(maildir_spambounce_path);
 my $maildirbasepath=  maildir_spambounce_path;

 use Spambounce_config ":maildir_path_vars";
 # get:
 $maildir_in
 $maildir_orig
 $maildir_spam
 $maildir_ham

=head1 DESCRIPTION


=cut


package Spambounce_config;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@vars=qw(
 $maildir_in
 $maildir_orig
 $maildir_spam
 $maildir_ham
);
@EXPORT_OK=(qw(maildir_spambounce_path),@vars);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK],
	      maildir_path_vars=> \@vars,
	     );

use strict; use warnings FATAL => 'uninitialized';

our $maildir_in= '/var/qmail/Maildir_spambounce';
our $maildir_orig= '/var/qmail/Maildir_spambounce/.orig';
our $maildir_spam= '/var/qmail/Maildir_spambounce/.Spam';
our $maildir_ham= '/var/qmail/Maildir_spambounce/.Ham';

sub maildir_spambounce_path () {
    $maildir_in
}

1
