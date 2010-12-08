package fb2::Footnotes;

our $VERSION=0.02;

use strict;
use warnings;
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
        if ( $node->data()=~/^\s*$keyword(.*)/s )
	{
	  my $text=$1;
	  my $number = int(rand(10000));
	  if ($use_number && ($text=~/^(\d+)\s+(.*)$/s) )
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

=cut

=head2 RenumberFootnotes

  fb2::Footnotes::RenumberFootnotes($document);

Reorder footnotes in footnotes body according to the order of footnote links in the book's body. Each footnote will get new title according
to it's position in this list; footnote links text will also be changed to each footnote index number. Meanwhile footnote ids are kept unchanged.
If reorder were successful function returns 1, or 0 if something went wrong.

I<$document> - Fb2 e-book stored as an XML::LibXML Document object


=cut
 
sub RenumberFootnotes
{
  my $doc = shift;
  my $root = $doc->getDocumentElement();
  my $note_body = undef;
  
  foreach my $node ($doc->getElementsByTagName('body'))
  {
    foreach ($node->attributes())
    {
       if ( ($_->nodeName eq 'name') && ($_->value eq 'notes')) 
      {
        # It's assumed that there is only one note-body in the book
        if ($note_body)
        {
          warn "More then one footnote body in the document. Refusing renombering footnotes";
          return 0;
        }
	$note_body  = $node;
      }
    }
  }
  if (! $note_body)
  {
    warn ("No footnote body found. No renumbering have been done");
    return 0;
  }
  my %footnotes = ();
  my @lost_foot_notes = ();
  foreach my $section ($note_body->getChildrenByLocalName('*'))
  {
    if ($section->nodeName ne 'section')
    {
      warn "Unexpected node in footnote body:'".$section->nodeName."', aborting";
      return 0;
    }

    my $id = $section->getAttribute('id');
    my $fn_record = {content=>$section, prefix=>[]};
    
    # saving all non-element nodes that goes before each foonnote sections into prefix array in $fn_record
    my $node = $section->previousSibling();
    while ($node)
    {
      if ($node->nodeType != XML_ELEMENT_NODE)
      {
        push @{$fn_record->{prefix}}, $node;
      } else
      {
        $node = undef;
      }
      $node=$node->previousSibling() if $node;
    }
    
    if (! $id) # If we habe no id, we are trying to get footnote title for error message
    {
      # Trying to get title if any
      my $title = "";
      foreach my $title_node ($section->getChildrenByLocalName('title'))
      {
        foreach my $p_node ($title_node->getChildrenByLocalName('*'))
        {
          my $p_content = $p_node->firstChild;
          while ($p_content)
          {
            $title.= $p_content->toString;
            $p_content=$p_content->nextSibling
          }
        }
      }
      warn "Lost footnote (footnote withot id) found in section with title '$title'" if $title;
      warn "Lost footnote (footnote withot id) found in section with no title" unless $title;
      push @lost_foot_notes,$fn_record;
    } else
    {
      $footnotes{$id} = $fn_record;
    }
  }

  # Saving bottom of the footnite body to preserve formatting and comments, if any
  my @bottom = ();
  my $node =  $note_body->lastChild;
  while ($node)
  {
    if ($node->nodeType != XML_ELEMENT_NODE)
    {
      unshift @bottom,$node;
    } else
    {
      $node = undef;
    }
    $node = $node->previousSibling if $node;
  }
  
  my @footnote_links = _recur_find_footnote_link($root);

  
  my $new_note_body = $doc->createElementNS("http://www.gribuser.ru/xml/fictionbook/2.0",'body');
  $new_note_body->setAttribute( 'name','notes');
  
  my $i = 0;
  foreach my $a_node (@footnote_links)
  {
    my $id = $a_node->getAttributeNS('http://www.w3.org/1999/xlink', 'href');;
    if ($id =~s/^\#//)
    {
      unless ($footnotes{$id})
      {
        if (defined($footnotes{$id}))
        {
          warn "Footnote with id='$id' is linked twice or more";
        } else
        {
          warn "Footnote with id='$id' does not exists but linked from the main body";
        }
      } else ## if note exists
      {
        while (@{$footnotes{$id}->{prefix}})
        {
          $new_note_body->appendChild(shift(@{$footnotes{$id}->{prefix}})->cloneNode(1));
        }
        $i++;
        my $new_note = $footnotes{$id}->{content}->cloneNode(1);
        my $insert_after = undef;
        foreach ($new_note->getChildrenByTagName('title'))
        {
          unless (defined $insert_after)
          {
            $insert_after =$_->previousSibling
          } else
          {
            $insert_after = 0;
          }
          $new_note->removeChild($_);
        }
        my $new_note_title = $doc->createElementNS("http://www.gribuser.ru/xml/fictionbook/2.0",'title');
        $new_note_title->addNewChild("http://www.gribuser.ru/xml/fictionbook/2.0",'p')->appendText("[$i]");
      
        if ($insert_after)
        {
           $insert_after->parentNode->insertAfter($new_note_title,$insert_after);
        } else
        {
          $new_note->insertBefore($new_note_title,$new_note->firstChild);
        } 
        $new_note_body->appendChild($new_note);
        $footnotes{$id}=0;
        $a_node->removeChildNodes();
        $a_node->appendText("[$i]");
      }
    }
  }
  foreach (keys %footnotes)
  {
    if ($footnotes{$_})
    {
      push @lost_foot_notes, $footnotes{$_};
      warn "Footnote with id ='$_' does not linked from the main body";
    }
  }
  if (@lost_foot_notes)
  {
    $new_note_body->appendText("\n");
    $new_note_body->appendChild($doc->createComment(' ======== Lost footnotes: footnotes without id, or footnotes not linked from the main body ========'));
    foreach my $lost_fn_rec (@lost_foot_notes)
    {
      while (@{$lost_fn_rec->{prefix}})
      {
        $new_note_body->appendChild(shift(@{$lost_fn_rec->{prefix}})->cloneNode(1));
      }
      $new_note_body->appendChild($lost_fn_rec->{content}->cloneNode(1));
    }
  }
  foreach (@bottom)
  {
    $new_note_body->appendChild($_->cloneNode(1));
  }
  $note_body->parentNode->insertBefore($new_note_body,$note_body);
  $note_body->parentNode->removeChild($note_body);
  
  return 1; # FIXME 1 is retured even if no real changes were made (i.e. when renubering file that were already renumbered
}

sub _recur_find_footnote_link
{
  my $node = shift;
  my @res = ();
  if ( ($node->nodeType == XML_ELEMENT_NODE) && ($node->nodeName eq 'a') && $node->getAttribute('type') && ($node->getAttribute('type') eq 'note'))
  {
    return $node; # in note link found, we do not look futher
  }
  if ( $node->nodeType == XML_ELEMENT_NODE)
  {
    foreach my $n ($node->childNodes)
    {
      push @res, _recur_find_footnote_link($n);
    }
  }
  return @res;
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
       if ( ($_->nodeName eq 'name') && ($_->value eq 'notes')) 
      {
        # It's assumed that there is only one note-body in the book
	$note_body  = $node;
      }
    }
  }
  if (! $note_body)
  {
    $note_body = $doc->createElement('body');
    $note_body->setAttribute('name','notes');
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

Swami Dhyan Nataraj (Nikolay Shaplov) <N@Shaplov.ru>

=head1 VERSION

0.02

=head1 COPYRIGHT AND LICENSE

Copyright 2007,2010 by Swami Dhyan Nataraj (Nikolay Shaplov)

This library is free software; you can redistribute it and/or modify
it under the terms of the General Public License (GPL).  For
more information, see http://www.fsf.org/licenses/gpl.txt

=cut


