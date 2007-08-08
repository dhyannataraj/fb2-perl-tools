package fb2::Footnotes;

our $VERSION=0.01;

use strict;
use XML::LibXML;

=head1 NAME

fb2::Footnotes - manipulates footnotes in fb2 e-book

=head1 SYNOPSIS

  use fb2::Footnotes;
  use XML::LibXML;
  
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_file($ARGV[0]);
  
  fb2::Footnotes::ConvertFromComments($doc,{Keyword => 'NOTE', UseNumber => 1});

=head1 DESCRIPTION

fb2::Footnotes provides a set of functions for manipulating footnotes in fb2 e-book. 

=head1 METHODS

The following methods are provided in this module.

=cut

=head2 ConvertFromComments

  fb2::Footnotes::ConvertFromComments($document,{Option1 => 'Value1', Option2 => 'Value2'});
  
Converts specially formated comments to fb2 footnotes. Returns 1 if convertation were successful, and 0 if no changes were
made.
  
I<$document> - Fb2 e-book stored as an XML::LibXML Document object

=over 4 

=item B<Options>

I<Keyword> - All the comments that begins with the keyword will be converted into footnotes. The default value is 'NOTE';

I<UseNumber> - If this option is true, B<ConvertFromComments> will take a number after Keyword as a number of footnote. 
Default value is 1;

=back
			  

=cut

sub ConvertFromComments
{
  my $doc = shift;
  my $opt = shift || {};
  
  $opt->{'Keyword'}='NOTE' unless $opt->{'Keyword'};
  $opt->{'UseNumber'}=1 unless $opt->{'UseNumber'};
  
  my $keyword = $opt->{'Keyword'};
  my $use_number = $opt->{'UseNumber'};
  
  my $root = $doc->getDocumentElement();
  my $changes_flag = 0;
  
  
  my @NodeList=();
  foreach ('p','v','subtitle','th', 'td','text-author')
  {
    my @l = $doc->getElementsByTagName($_);
    
    @NodeList=(@NodeList,@l);
  }
  
  foreach (@NodeList)
  {
    foreach ($_->childNodes)
    {
      if ($_->nodeType == XML_COMMENT_NODE)
      {
        my $node=$_;
        if ( $node->data()=~/^\s*$keyword(.*)/ )
	{
	  my $text=$1;
	  my $number = int(rand(10000));
	  if ($use_number && ($text=~/^(\d+)\s+(.*)$/) )
	  {
	    $text = $2;
	    $number = $1;
	  }
	  Add({'doc'=>$doc, 'Number' => $number, 'Text' => $text, 'InsertBefore' => $node });
	  $node->parentNode->removeChild($node);
	  $changes_flag = 1;
	}        
      }
    }  
  }  
  return($changes_flag);
}

=head2 Add

  fb2::Footnotes::Add($document,{Option1 => 'Value1', Option2 => 'Value2'});  
  
  Adds a new footnote to a fb2 document.
  
I<$document> - Fb2 e-book stored as an XML::LibXML Document object

=over 4 

=item B<Options>

I<Text> - Text of a new footnote 

I<Number> - Number of a new footnote

I<InsertBefore> - XML::LibXML Node object. An <A href> link to a new footnote will be inserted
before that node

=back


=cut

sub Add
{
  my $opt = shift || {};
  
  my $doc = $opt->{'doc'};
  my $number = $opt->{'Number'};
  my $text = $opt->{'Text'};
  my $insert_before = $opt->{'InsertBefore'};
  
  
  my $note_body=undef;
  
  my ($book) = $doc->getElementsByTagName('FictionBook');
  die "Cant find FictionBook element" unless $book;
  
  
  foreach ($doc->getElementsByTagName('body'))
  {
    my $node = $_;
    foreach ($node->attributes())
    {
       if ( ($_->nodeName eq 'type') && ($_->value eq 'note')) 
      {
        # It's assumed that there is only one note-body in the book
	$note_body  = $node;
      }
    }
  }  
  if (! $note_body)
  {
    $note_body = $doc->createElement('body');
    $note_body->setAttribute('type','note');
    $book->appendChild($doc->createTextNode('  '));
    $book->appendChild($note_body);
    $book->appendChild($doc->createTextNode("\n"));
  }  
  
  my $section_node = $doc->createElement('section');
  $section_node->setAttribute('id',"note$number");
  
  # Create Title
  my $p_node = $doc->createElement('p');
  $p_node->appendChild($doc->createTextNode($number));
  my $title_node = $doc->createElement('title');
  $title_node->appendChild($p_node);
  
  # Append Title  
  $section_node->appendChild($doc->createTextNode("\n      "));
  $section_node->appendChild($title_node);
  
  # Create p 
  $p_node = $doc->createElement('p');
  $p_node->appendChild($doc->createTextNode($text));
  
  # Append p 
  $section_node->appendChild($doc->createTextNode("\n      "));
  $section_node->appendChild($p_node);
  $section_node->appendChild($doc->createTextNode("\n    "));
  
  
  $note_body->appendChild($doc->createTextNode("\n    "));
  $note_body->appendChild($section_node);
  $note_body->appendChild($doc->createTextNode("\n  "));
  
  ### Now will create <a href> tag and insert it...
  
  my $xlink_namespace=undef;
  
  foreach ($book->attributes())
  {
    # print $_->nodeName,"  ",$_->value,"\n";
    
    if ($_->value=~/^http:\/\/www.w3.org\/1999\/xlink$/)
    {
      if ($_->nodeName=~/^.*\:(.*)$/)
      {
        $xlink_namespace=$1;
      }
    }
  }
  
#  print "NameSpace = $xlink_namespace \n";
  
  my $a_node = $doc->createElement('a');
  
  if ($xlink_namespace)
  {
    $a_node->setAttribute("$xlink_namespace:href" ,"#note$number" );
  } else
  {
    $a_node->setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href' ,"#note$number" );
  } 
  $a_node->setAttribute('type','note');
  $a_node->appendChild($doc->createTextNode("[$number]"));
  
  
  $note_body->appendChild($a_node);  
  $insert_before->parentNode->insertBefore($a_node,$insert_before);
  
  
#  print $note_body->toString, "\n" if $note_body;
}


1;

=head1 EXAMPLES

=head2 ConvertFromComments

  fb2::Footnotes::ConvertFromComments($doc, {Keyword => 'NOTE', UseNumber => 1});
  fb2::Footnotes::ConvertFromComments($doc);
  
Both will transform fb2 document from

 <p>Some text here <!--NOTE112 Here is a text of a footnote--> Some more text</p>

into

 <p>Some text here <a xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="#note112" type="note">[112]</a>
    Some more text</p>
 ...	
 </body>
 <body type="note">
   <section id="note112">
     <title><p>112</p></title>
     <p>Here is a text of a footnote</p>
   </section>
 </body>


=head2 Add

 fb2::Footnotes::Add($doc,{Text => "Foot note text", Number => 4, InsertBefore => $some_node });  

=head1 SEE ALSO

http://sourceforge.net/projects/fb2-perl-tools - fb2-perl-tools project page

http://www.fictionbook.org/index.php/Eng:FictionBook - fb2 community (site is mostly in Russian)
 
=head1 AUTHOR

Nikolay Shaplov <N@Shaplov.ru>

=head1 VERSION

0.01

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Nikolay Shaplov

This library is free software; you can redistribute it and/or modify
it under the terms of the General Public License (GPL).  For
more information, see http://www.fsf.org/licenses/gpl.txt

=cut


