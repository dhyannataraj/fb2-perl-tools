#!/usr/bin/perl

use strict;
use XML::DOM;
use Getopt::Long qw(HelpMessage VersionMessage);
use File::MMagic;
use MIME::Base64 qw(encode_base64);
use Encode;
our $VERSION=0.01;

=head1 NAME

fb2images.pl - manipulate embedded images in the FictionBook file

=head1 SYNOPSIS

B<fb2images.pl> B<--list> I<filename.fb2>

B<fb2images.pl> B<--add> I<filename.png> B<--remove> I<image.id> I<filename.fb2>

=head1 DESCRIPTION

This utility allows to add new images into FB2 file, remove images and
list them.

Several operations can be performed during one operation.
First, utility adds all images to add, then removes ones to remove and
then lists images.

Input image names are used as E<lt>binaryE<gt> element ids.

=head1 BUGS

Utility doesn't check if image reference presents  in the file, and is
unable to add references.  

To update image one have to remove it first and add then, and these
operations cannot be combined into one call.

There is no option to extract image into  file or stdout

=head1 AUTHOR

Nikolay Shaplov <shaplov@sf.net>

=cut

my $flags={};
my $opts={};
  GetOptions (help=>sub {HelpMessage(); },
  				version=>sub {VersionMessage(); },
              "list|l" => \$opts->{'list'},
              "add|a=s@"=> \$opts->{'add'},
	      "remove|r=s@"=>\$opts->{'remove'}
             ) or exit(1);
  $opts->{'list'}=1 if @ARGV && ! %{$opts};
  my $FileName= $ARGV[0];
 
  my $parser = new XML::DOM::Parser;
  my $doc = $parser->parsefile ($FileName);
  
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
	my $encoding=$doc->getXMLDecl()->getEncoding();
	# This call of Encode::decode fixes problem in XML::DOM which do not
	# mark entire output utf8 correctly.
	my $data = decode("utf8",$doc->toString);
	open DST,">:encoding($encoding)",$FileName;
    print DST $data;
	close DST;
  }

  $doc->dispose; # Avoid memory leaks - cleanup circular references
  
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
    my $id=$_->getAttributes()->getNamedItem('id');
    if ($id)
    {
      $id=$id->getNodeValue();
      @list= (@list,$id);
    }
  }
  return \@list
}

sub getUsedIdList
{
  my $doc=shift;
  my @list=();
  
  foreach ($doc->getDocumentElement()->getElementsByTagName('*' ,1) )
  {
    my $id=$_->getAttributes()->getNamedItem('id');
    if ($id)
    {
      $id=$id->getNodeValue();
      @list= (@list,$id);
    }
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
    foreach ($root->getElementsByTagName('binary' ,0))
    {
      if ($_->getAttribute('id') eq $ImageName)
      {
        $root->removeChild($_);
	print "Done\n";
	$flag=0;
        $flags->{'changed'}=1;
      }
    }
    print "Not Found!\n" if $flag;
  }
}
