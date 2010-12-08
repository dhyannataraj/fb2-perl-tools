#!/usr/bin/perl

use strict;
use fb2::Footnotes;
use XML::LibXML;
use Encode;
use Getopt::Long qw(HelpMessage VersionMessage);
our $VERSION=0.02;

=head1 NAME

fb2_notes - manipulate footnotes in the fb2 e-book

=head1 SYNOPSIS

B<fb2_notes> B<convert> [B<-k>=I<keyword>] [B<-n>=[I<1>|I<0>]] I<filename.fb2>

B<fb2_notes> B<convert> <I<src_file.fb2> >I<dst_file.fb2>

B<fb2_notes> B<renumber> <I<src_file.fb2> >I<dst_file.fb2>

=head1 DESCRIPTION

This utility allows to convert specifically formated comments info fb2 footnotes

=head1 COMMANDS

=over 4

=item B<convert>

Converts XML comments that starts with B<keyword> into fb2 e-book footnotes. If B<use-number> is set to 1
then number after B<keyword> will be used as a number of footnote. All other text of a comment will
be saved as a text of the footnote

=over 8

=item B<-k> I<keyword_value>

=item B<--keyword>=I<keyword_value>



All XML comments that starts with I<keyword_value> will be
converted into fb2 e-book footnotes. Default value is 'NOTE'.

=item B<-n> [I<1>|I<0>]

=item B<--use-number>=[I<1>|I<0>]

If B<use-number> is set to 1, than a number after B<keyword> will be used as a number of footnote. 
Default value is 1.

=back


=item B<renumber>

Reorder footnotes according to the order of the footnotes links in main body. Footnote's title and link's text
are changed to the index number of each footnote in a new list. Footnote ids are remain unchanged.

=back

=head1 EXAMPLES

=item B<convert>

=over 4

B<$ cat some_book.fb2>
 ...
 <p>Some text here<!--NOTE112 Here is a text of a footnote--> Some more text</p>
 ...
 
B<$ fb2_notes convert some_book.fb2>
 
B<$ cat some_book.fb2>
 ...
 <p>Some text here<a xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="#note112" type="note">[112]</a> 
    Some more text</p>
 ...
 </body>
 <body type="note">
   <section id="note112">
     <title><p>112</p></title>
     <p>Here is a text of a footnote</p>
   </section>
 </body>
			      
=back			      

=head1 SEE ALSO

http://sourceforge.net/projects/fb2-perl-tools - fb2-perl-tools project page

http://www.fictionbook.org/index.php/Eng:FictionBook - fb2 community (site is mostly in Russian)
 
=head1 AUTHOR

Swami Dhyan Nataraj (Nikolay Shaplov) <N@Shaplov.ru>

=head1 VERSION

0.02

=head1 COPYRIGHT AND LICENSE

Copyright 2007,2010 by Swami Dhyan Nataraj (Nikolay Shaplov)

This library is free software; you can redistribute it and/or modify
it under the terms of the General Public License (GPL).  For
more information, see http://www.fsf.org/licenses/gpl.txt

=cut

my $Command = shift @ARGV;

do_convert()	if $Command eq 'convert';
do_renumber()	if $Command eq 'renumber';
HelpMessage()	if ! $Command || $Command eq 'help';


exit;


sub do_convert
{
  my $opts={};
  GetOptions(
    help		=> sub {HelpMessage(); },
    version		=> sub {VersionMessage(); },
    "keyword|w=s"	=> \$opts->{'keyword'},
    "use-number|n"	=> \$opts->{'use_number'},
  );
  
  my $file_name = $ARGV[0];
  
  my $doc;
  
  if ($file_name)
  {
    $doc = _parse_file($file_name);    
  } else
  {
    $doc = _parse_stdin();
  }
  
  my $changes_flag = fb2::Footnotes::ConvertFromComments($doc,{
								"Keyword" => $opts->{'keyword'}, 
								"UseNumber"=>$opts->{'use_number'}
							      });
  if (! $changes_flag )
  {
    print STDERR "No changes were made\n";
    return 0  unless $changes_flag;
  }
  
  if ($file_name)
  {
    _update_file($file_name,$doc);
  } else
  {
    print $doc->toString();
  } 
  
  print STDERR "Comments successfully converted\n";
}


sub do_renumber
{
  my $opts={};
  GetOptions(
    help		=> sub {HelpMessage(); },
    version		=> sub {VersionMessage(); },
    "keyword|w=s"	=> \$opts->{'keyword'},
    "use-number|n"	=> \$opts->{'use_number'},
  );
  
  my $file_name = $ARGV[0];
  
  my $doc;
  
  if ($file_name)
  {
    $doc = _parse_file($file_name);    
  } else
  {
    $doc = _parse_stdin();
  }
  my $changes_flag = fb2::Footnotes::RenumberFootnotes($doc);
  print $doc->toString();
}

sub _parse_file
{
  my $file_name=shift;
  my $parser = XML::LibXML->new();

  my $doc = $parser->parse_file($file_name);
  return $doc;
}

sub _parse_stdin
{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_fh(\*STDIN);
  return $doc;
}

sub _update_file
{
  my $file_name = shift;
  my $doc = shift;
  
  my $backup = $file_name . "~";
  unlink $backup;
  rename $file_name, $backup or die("Cannot make backup copy: $!");
   my $encoding=$doc->encoding();
  # This call of Encode::decode fixes problem in XML::DOM which do not
  # mark entire output utf8 correctly.
  my $data = decode("utf8",$doc->toString);
  open DST,">:encoding($encoding)",$file_name;
  print DST $data;
  close DST;
}
