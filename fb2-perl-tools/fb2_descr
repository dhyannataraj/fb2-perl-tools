#!/usr/bin/perl

use fb2::Description::Extend;
use XML::LibXML;
use Encode;
use Getopt::Long qw(HelpMessage VersionMessage);

use strict;
our $VERSION=0.02;

=head1 NAME

fb2_descr - extend description of fb2 file with all possible elements

=head1 SYNOPSIS

B<fb2_descr.pl> extend I<filename.fb2>

=cut


my $Command = shift @ARGV;

do_extend()    if $Command eq 'extend';
HelpMessage()   if ! $Command || $Command eq 'help';

exit;



sub do_extend
{
  my $opts={};
  GetOptions(
    help		=> sub {HelpMessage(); },
    version		=> sub {VersionMessage(); },
#    "keyword|w=s"	=> \$opts->{'keyword'},
#    "use-number|n"	=> \$opts->{'use_number'},
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

  my ($desc) = $doc->getElementsByTagName("description",0);
  fb2::Description::Extend::extend({'description'=>$desc});

#  if (! $changes_flag )
#  {
#    print STDERR "No changes were made\n";
#    return 0  unless $changes_flag;
#  }
  
  if ($file_name)
  {
    _update_file($file_name,$doc);
  } else
  {
    print $doc->toString();
  } 
  
  print STDERR "Description successfully extended\n";

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