#!/usr/bin/perl

use strict;
use XML::LibXML;


my @inline_elsments=('a', 'book-name', 'book-title', 'city', 'code', 'custom-info', 'date',   
'email', 'emphasis', 'first-name', 'genre', 'home-page', 'id', 'isbn', 'image', 'keywords', 'lang', 'last-name', 
'middle-name', 'nickname', 'p', 'part', 'program-used', 'publish-info', 'publisher', 'sequence', 'src-lang', 'src-ocr', 
'src-url', 'strikethrough', 'strong', 'sub', 'subtitle', 'sup', 'text-author', 'title', 'translator', 'v', 'version', 
'year');
my %inline_elements_hash=();

foreach (@inline_elsments)
{
  $inline_elements_hash{$_}=1;
}

my $FileName= $ARGV[0];  
my $parser = XML::LibXML->new();
my $root = $parser->parse_file($FileName)->getDocumentElement();

normalize_branch($root);
print $root->toString();

sub normalize_branch
{
  my $branch = shift;
  my $level = shift;
  foreach ($branch->getChildNodes())
  {
    normalize_text_node($_) if ($_->nodeType() == XML_TEXT_NODE);
  }
  my @children=$branch->getChildNodes();
  if (! $inline_elements_hash{$branch->nodeName()} )
  {
    my $count=1;
    foreach my $node (@children)
    {
      if( !(($branch->nodeName() eq 'section') && ($count==1) && ($node->nodeName() eq 'title') ))
      {
        my $new_node=$branch->getOwnerDocument()->createTextNode("\n  ".$level);
        $branch->insertBefore ($new_node,$node);
      }
      $count++;
    }
    my $new_node=$branch->getOwnerDocument()->createTextNode("\n".$level);
    $branch->insertBefore ($new_node,undef); # adding as last node
  }
  foreach (@children)
  {
    normalize_branch($_,$level."  ") if ($_->nodeType() == XML_ELEMENT_NODE);
  }
}
  
sub normalize_text_node
{
  my $text_node=shift;
  return 0 if ( $text_node->nodeType() != XML_TEXT_NODE );
  my $text=$text_node->getData();
  $text=~s/\s+/ /g;
  $text=~s/^ //g;
  $text=~s/ $//g;
  if ($text eq '')
  {
    $text_node->getParentNode()->removeChild($text_node);
  } else
  {
    $text_node->setData($text);
  }
}
  
