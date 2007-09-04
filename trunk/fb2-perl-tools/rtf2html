#!/usr/bin/perl -w

# $Id: rtf2html.PL,v 1.8.10.1 2005/07/02 23:41:27 abstract Exp $

=head1 NAME

rtf2html - script to convert Microsoft Rich Text Format files to HTML.

=head1 SYNOPSYS

 rtf2html [options] infile.rtf outfile.html

 rtf2html [options] infile.rtf | some_filter

 cat infile.rtf | rtf2html [options] | some_filter

=head1 DESCRIPTION

This script performs conversion files written in Microsoft RTF format to
HTML. Script can work as filter, converting STDIN to STDOUT, or accepts names of
files as first (input RTF file) and optional second (output HTML file) arguments.

=head2 Text processing options

=over

=item --incharset=charset_name

The name of input documents charset, one of file names in B<tables> directory.
This option is nessesary if charset in input document is absent. Default - cp1251.

=item --strictincharset=charset_name

If this option is present, 'charset_name' accepts as charset of input document,
unconditionally of ansicpg keyword nor --incharset option.

=item --outcharset=charset_name

The name of output charset.

=item --tables=dir_name

Name of directory containing B<catdoc> files. Default - /usr/local/lib/charsets.

=item --test

If this option is specified output HTML file validates with weblint program.

=back

=head2 Image processing options

The script can extract (some) images from RTF file and put them into special
directory. By this extraction images are converting to GIF format.

=over

=item --imgdir=directory_for_images

Image processing performs only if this option is given. Value of option -
name of directory to put extracted images in GIF format.

=item --imgdircreate=mode

In directory imgdir is absent it will be tried to create with mode.

=item --imgurl=url_prefix

Meaning of this option - URL prefix in <IMG ...> tags in output HTML file. Default - '.',
current directory.

=back

=cut

require 5.004;
use strict;

use File::Basename;
use Getopt::Long;

use RTF::HTML::Converter;

use vars qw/
  $srcname
  $dstname

  %par

  $cnv

  %opt
  /;

%par = (
	StrictInputCharset=>'cp1251',
	ImageDir => 'NONE',
	ImageUrl => '.',
	CatdocCharsets => '/cmw/tables'
);


GetOptions(
	   \%opt,

	   qw/
	   incharset=s
	   outcharset=s
	   strictincharset=s
	   tables=s

	   imgdircreate=s
	   imgdir=s
	   imgurl=s
	   imgrmsrc!

	   test
	   /,
) or die "Bad rtf2html options\n";

$opt{imgdir}          and $par{ImageDir}           = $opt{imgdir};
$opt{imgurl}          and $par{ImageUrl}           = $opt{imgurl};
$opt{imgdircreate}    and $par{ImageDirCreate}     = $opt{imgdircreate};


$opt{incharset}       and $par{InputCharset}       = $opt{incharset};
$opt{outcharset}      and $par{OutputCharset}      = $opt{outcharset};
$opt{strictincharset} and $par{StrictInputCharset} = $opt{strictincharset};

$opt{tables} and $par{CatdocCharsets} = $opt{tables};

#if (defined $par{OutputCharset} && !-f "$par{CatdocCharsets}/$par{OutputCharset}.txt") {
#  open F, "$par{CatdocCharsets}/charset.map" or die "$par{CatdocCharsets}/charset.map:$!";
#  while (<F>) {
#    next if /^\s*#/ || /^\s*$/;
#    my ($mime_name,$table_name) = split;
#    $par{OutputCharset}=$table_name if $mime_name eq $par{OutputCharset};
#  }
# }  

# die "Unknown output charset $par{OutputCharset}" if $par{OutputCharset} && ! -f "$par{CatdocCharsets}/$par{OutputCharset}.txt";

unless (defined $ARGV[0]) {
  # stdin -> stdout
  $cnv = new RTF::HTML::Converter(%par);
  $cnv->parse_stream(\*STDIN);

} elsif (!defined $ARGV[1]) {
  # $ARGV[0] -> stdout
  $cnv = new RTF::HTML::Converter(%par);
  $cnv->parse_stream($ARGV[0]);

} else {
  # $ARGV[0] -> $ARGV[1]
  open F, "> $ARGV[1]" or die $!;
  $cnv = new RTF::HTML::Converter(%par, Output => \*F);
  $cnv->parse_stream($ARGV[0]);
  close F;
}


# Преобразование картинок - только если их конвертация поддерживается в текущей
# конфигурации
if ($par{ImageDir} ne 'NONE') {
  my %job = $cnv->files2convert();

  while (my ($from, $to) = each %job) {
    next unless $from =~ /\.wmf$/;
    next unless $to =~ /\.png$/;
    die "No source file $from" unless -f $from;

    # Удаляем dst
    unlink $to;
    die "Dst file $to cannot be deleted before converting" if -f $to;

    system "/usr/bin/convert $from $to";
    die "Error execution /usr/bin/convert: $!\n" if $? >> 8;
    die "Convertion from $from to $to fails\n" unless -f $to;
    unlink $from if $opt{imgrmsrc} || !exists($opt{imgrmsrc});
  }
}

if ($opt{test} && defined($ARGV[1])) {
  my $nw = `weblint -d empty-container $ARGV[1] | wc -l`;
  
  printf 
    "%20s bytes: %7d -> %-6d %5.2f sec  warn: %2d\n", 
    $ARGV[0],
    -s $ARGV[0],
    -s $ARGV[1],
    (times)[0],
    $nw
    ;
}

