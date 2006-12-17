#!/usr/bin/perl

use strict;
use XML::DOM;
use Getopt::Long;
use File::MMagic;
use MIME::Base64 qw(encode_base64);
 
my $flags={};
my $opts={};
  GetOptions ("lits|l" => \$opts->{'list'},
              "add|a=s@"=> \$opts->{'add'},
	      "remove|r=s@"=>\$opts->{'remove'}
             );

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
    open SRC,$FileName;
    open DST,">$FileName~";
    local($/) = undef;
    print DST <SRC>;
    close SRC;
    close DST;
    $doc->printToFile ($FileName);	 
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
