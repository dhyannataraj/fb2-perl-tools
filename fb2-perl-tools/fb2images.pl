#!/usr/bin/perl

use strict;
use XML::LibXML;
use Getopt::Long qw(HelpMessage VersionMessage);
use File::MMagic;
use MIME::Base64 qw(encode_base64);
use Encode;
our $VERSION=0.02;

=head1 NAME

fb2images.pl - manipulate embedded images in the FictionBook file

=head1 SYNOPSIS

B<fb2images.pl> [B<--extract> I<image.id>] [B<--remove> I<image.id>] [B<--add> I<filename.png>] [B<--list>] I<filename.fb2>

=head1 DESCRIPTION

This utility allows to add new images into FB2 file, remove images, extract images and
list them.

Several operations can be performed during one operation.
First, utility extracts images, then removes ones to remove,
then adds all images to add and then lists images.

Input image names are used as E<lt>binaryE<gt> element ids.

=head1 BUGS

Utility doesn't check if image reference presents in the file, and is
unable to add references.

=head1 VERSION

0.02

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2011 by Swami Dhyan Nataraj (Nikolay Shaplov)

This library is free software; you can redistribute it and/or modify
it under the terms of the General Public License (GPL).  For
more information, see http://www.fsf.org/licenses/gpl.txt

=cut

my $flags={};
my $opts={};
  GetOptions (help=>sub {HelpMessage(); },
                                  version=>sub {VersionMessage(); },
              "list|l" => \$opts->{'list'},
              "extract|x=s@" => \$opts->{'extract'},
              "add|a=s@"=> \$opts->{'add'},
              "remove|r=s@"=>\$opts->{'remove'}
             ) or exit(1);
  $opts->{'list'}=1 if @ARGV && ! %{$opts};
  my $FileName= $ARGV[0];

  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_file($FileName);

  if ( $opts->{'extract'} )
  {
    ExtractImages($doc,$opts,$flags);
  }
  if ( $opts->{'add'} )
  {
    AddImages($doc,$opts,$flags);
  }
  if ( $opts->{'remove'} )
  {
    RemoveImages($doc,$opts,$flags);
  }
  if ($opts->{'list'})
  {
    printImageList(getImageList($doc));
  }

  if ($flags->{'changed'})
  {
        my $backup = $FileName . "~";
        unlink $backup;
        rename $FileName, $backup or warn("Cannot make backup copy: $!");
        my $data = $doc->toString;
        open DST,">",$FileName;

        print DST $data;
        close DST;
  }

sub printImageList
{
  my $List=shift;
  foreach (@{$List})
  {
    print "$_\n";
  }
}

sub getImageList
{
  my $doc=shift;
  my @list=();

  foreach ($doc->getDocumentElement()->getElementsByTagName('binary' ,0) )
  {
    my $id=$_->getAttribute('id');
    push @list,$id  if ($id)
  }
  return \@list
}

sub getUsedIdList
{
  my $doc=shift;
  my @list=();

  foreach ($doc->getDocumentElement()->getElementsByTagName('*' ,1) )
  {
    my $id=$_->getAttribute('id');
    push @list,$id if $id
  }
  return \@list
}

sub AddImages
{
  my $doc = shift;
  my $opts = shift;
  my $flags = shift;

  foreach (@{$opts->{'add'}})
  {
    my $flag=1;
    my $ImageName=$_;
    print "Adding image $_ ...\n";
    foreach (@{getImageList($doc)})
    {
      if ($_ eq $ImageName)
      {
        print STDERR "Image $ImageName already exist in $FileName\n";
        $flag=0;
        last;
      }
    }
    if ($flag)
    {
      foreach (@{getUsedIdList($doc)})
      {
        if ($_ eq $ImageName)
        {
          print STDERR "Object $ImageName already exist in $FileName\n";
          $flag=0;
          last;
        }
      }
    }
    if ($flag)
    {
      my $mm= new File::MMagic;
      my $MimeType=  $mm->checktype_filename($ImageName);
      open(FILE, $ImageName) or die "$!";
      local($/) = undef;
      my $Encoded= encode_base64(<FILE>);
      close (FILE);
      my $NewNode = $doc->createElement('binary');
      $NewNode->setAttribute ('id', $ImageName);
      $NewNode->setAttribute ('content-type',$MimeType);
      $NewNode->appendChild($doc->createTextNode("\n".$Encoded));
      $doc->getDocumentElement()->appendChild($NewNode);
      $doc->getDocumentElement()->appendChild($doc->createTextNode("\n"));
      $flags->{'changed'}=1;
    }
  }
}

sub RemoveImages
{
  my $doc = shift;
  my $opts = shift;
  my $flags = shift;

  my $root=$doc->getDocumentElement();
  foreach (@{$opts->{'remove'}})
  {
    my $ImageName=$_;
    print "Removing image '$_'... ";
    my $flag=1;
    foreach my $binary ($root->getElementsByTagName('binary' ,0))
    {
      if ($binary->getAttribute('id') eq $ImageName)
      {
        while (1)
        {
          my $prev = $binary->getPreviousSibling();
          last until defined($prev);
          last until ($prev->nodeType() == XML_TEXT_NODE && $prev->getData() =~ /^\s*$/ );
          $root->removeChild($prev);
        }
        $root->removeChild($binary);
        print "Done\n";
        $flag=0;
        $flags->{'changed'}=1;
      }
    }
    print "Not Found!\n" if $flag;
  }
}

sub getText
{
  my ($elem) = @_;
  my $text = '';
  for my $node ($elem->getChildNodes())
  {
    if ($node->nodeType() == XML_ELEMENT_NODE)
    {
      $text .= getText($node);
    }
    elsif ($node->nodeType() == XML_TEXT_NODE)
    {
      $text .= $node->getData();
    }
  }
  return $text;
}

sub ExtractImages
{
  my ($doc,$opts,$flags) = @_;

  my $root=$doc->getDocumentElement();
  foreach my $ImageName (@{$opts->{'extract'}})
  {
    print "Extracting image '$ImageName'... ";
    my $flag=1;
    foreach my $binary ($root->getElementsByTagName('binary' ,0))
    {
      if ($binary->getAttribute('id') eq $ImageName)
      {
        my $data = MIME::Base64::decode_base64( getText( $binary ) );
        open(FILE, '>', $ImageName) or die "$!";
        print FILE $data;
        close (FILE);
        print "Done\n";
        $flag=0;
        last;
      }
    }
    print "Not Found!\n" if $flag;
  }
}
