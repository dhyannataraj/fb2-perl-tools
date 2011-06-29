package fb2::Description::Extend;

use strict;
use XML::LibXML;
use XML::LibXML::Common;
our $VERSION=0.02;


=head2 extend

Adds missing elements to fb2 descriprion, to comply with fb2 schema test.

Usage:

fb2::fix::fix_description('option'=>'value, 'option'=>value ...);

Options:

description - ref to a description XML::DOM:Element 

optional - 0/1 add optional elements or not (1 - default)

version - version of fb2 xml schema (2, 2.1, 2.2) 2.1 - default

offset - 

offset_step - 



=cut

sub extend
{
  my $par=shift;
  
  $par->{'version'}       = 2.1  unless defined($par->{'version'});
  $par->{'optional'}      = 1    unless defined($par->{'optional'});
  $par->{'offset'}        = 2    unless defined($par->{'offset'});
  $par->{'offset_step'}   = 2    unless defined($par->{'offset_step'});
  
  my $descr=$par->{'description'};
  
  _extend_description_fill_complex_node($par,$descr);
}

# ##########################
sub _extend_description_fill_node
{
  my $par=shift;
  my $node=shift;
  my $content=shift;
  my $doc=$node->getOwnerDocument;
  
  
  
  if ($content eq '#SPACE#')
  {
    $node->appendChild($doc->createTextNode(' '));
    
  } elsif  ($content =~ /$\#TEXT\#\s*(.*)/ )
  {
  
    my $text = $content;
    $text =~ s/$\#TEXT\#\s*//;
    $node->appendChild($doc->createTextNode($text));
  }
  elsif ($content eq '#PARAGRAPH#')
  {
    my $p=$doc->createElement('p');
    $node->appendChild($p);
    $p->appendChild($doc->createTextNode(' '));

  }
  elsif ($content =~ /$\#DATE\#\s*(.*)/ )
  {
    my $date = $content;
    $date =~ s/$\#DATE\#\s*//;
    my $displ_date=$date;
    if ($date=~/\d{4}-\d{1,2}-\d{1,2}/)
    {
      $date=~/(\d{4})-(\d{1,2})-(\d{1,2})/;
      $displ_date="$3.$2.$1";      
    }
    $node->appendChild($doc->createTextNode($displ_date));
    $node->setAttribute("value",$date);
  }  
  elsif ($content eq '#IMAGE#')
  {
    my $img=$doc->createElement('image');
    $node->appendChild($img);
    $img->setAttribute("xlink:href","");
  }
  elsif ($content eq '#SEQ_ATTRS#')
  {
    $node->setAttribute('name','');
    $node->setAttribute('number','');    
  }
  elsif ($content eq '#COMPLEX#')
  {
    $par->{'offset'}+=$par->{'offset_step'};
    _extend_description_fill_complex_node($par,$node);
    $par->{'offset'}-=$par->{'offset_step'};
  }
  
}

# ##################################

sub _extend_description_fill_complex_node
{
  my $par=shift;
  my $node=shift;
  
  my $name=$node->nodeName();
  my $doc=$node->getOwnerDocument;
  my $children_info=_get_node_children_info($name);

  my %name_to_num=();
  for(my $i=0;$i<=$#$children_info;$i++)
  {
    if ($children_info->[$i]->{'ver'} <= $par->{version})
    {
      $name_to_num{$children_info->[$i]->{'name'}}=$i;
    }
  }
  my $last_processed_child_num=-1;
  
  foreach my $child ($node->getChildNodes)  # Loops all child nodes
  {
    if ($child->nodeType == ELEMENT_NODE())         # When element node is found
    {
      my $num = $name_to_num{$child->nodeName};   # Get it's number in children_info array
      die "Node '".$child->nodeName."' is not allowed inside '".$node->nodeName."'" unless defined $num;
      die "Invalid child node order inside '".$node->nodeName."'" if $num<$last_processed_child_num;
      
      for(my $i=$last_processed_child_num+1;$i<$num;$i++)                           # If there shuld be children between
      {                                                                             # current child and last processed
										    # child, then we insert it there
	if ( ( ( $children_info->[$i]->{'opt'} == 0 ) ||
	       ( $children_info->[$i]->{'opt'} == 1 && $par->{'optional'} == 1 ) ) &&
	     ( $children_info->[$i]->{'ver'} <= $par->{version} ) )
	{
          my $offset_node = $doc->createTextNode("\n".(' ' x $par->{'offset'}));
	  my $new_child   = $doc->createElement($children_info->[$i]->{'name'});
	  my $content     = $children_info->[$i]->{'content'};
	
	  $node->insertBefore($new_child, $child);
	  $node->insertBefore($offset_node, $child);
	  _extend_description_fill_node($par,$new_child,$content);
	}
      }
      
      if ( $children_info->[$num]->{'content'} eq '#COMPLEX#' )   # If exiting node have #COMPLEX# content then
      {                                                           # we should try to refill it. 'cause some child node
        _extend_description_fill_node($par,$child,'#COMPLEX#');      # might be missing there
      }
      
      $last_processed_child_num=$num;
    }
  }
  
  # When we processed all children of the $node then we add childern that should go after last_processed_child
  for(my $i=$last_processed_child_num+1;$i<=$#$children_info;$i++)
  {      
   if ( ( ( $children_info->[$i]->{'opt'} == 0 ) ||
          ( $children_info->[$i]->{'opt'} == 1 && $par->{'optional'} == 1 ) ) &&
        ( $children_info->[$i]->{'ver'} <= $par->{version} ) )
    {
      my $offset_node = $doc->createTextNode("\n".(' ' x $par->{'offset'}));
      my $new_child   = $doc->createElement($children_info->[$i]->{'name'});
      my $content     = $children_info->[$i]->{'content'};
    
      $node->appendChild($offset_node) if $i!=$last_processed_child_num+1;
      $node->appendChild($new_child);
      _extend_description_fill_node($par,$new_child,$content);
    }
  }  
  
  if ($node->getFirstChild && $node->getFirstChild->nodeType == ELEMENT_NODE)  # If first node is element_node
  {                                                                               # then add an offset, for better view
    my $offset_node = $doc->createTextNode("\n".(' ' x $par->{'offset'}));
    $node->insertBefore($offset_node,$node->getFirstChild);
  }
  
  if ($node->getLastChild && $node->getLastChild->nodeType == ELEMENT_NODE)    # If last node is element_node
  {                                                                               # then add an offset, for better view
    my $offset_node = $doc->createTextNode("\n".(' ' x ($par->{'offset'} - $par->{'offset_step'})));
    $node->appendChild($offset_node);
  }
  
  
}

# ############################################

sub _get_node_children_info
{
  my $name = shift;
  if ($name eq 'description')
  {
    return [
	{'name'	=> 'title-info',	'opt'=>0, 'ver'=> 2  , 'content'=>'#COMPLEX#'},
	{'name' => 'src-title-info',	'opt'=>1, 'ver'=> 2.1, 'content'=>'#COMPLEX#'},
	{'name' => 'document-info',	'opt'=>0, 'ver'=> 2  , 'content'=>'#COMPLEX#'},
	{'name' => 'publish-info',	'opt'=>1, 'ver'=> 2  , 'content'=>'#COMPLEX#'},
	{'name' => 'custom-info',	'opt'=>-1,'ver'=> 2  , 'content'=>'#????#'},
	{'name' => 'output',		'opt'=>-1,'ver'=> 2.1, 'content'=>'#????#'},
    ];	
  } elsif  ($name eq 'title-info' || $name eq 'src-title-info')
  {
    return [
	{'name' => 'genre'	,'opt'=>1, 'ver'=> 2, 'content'=>'#SPACE#'},
	{'name' => 'author'	,'opt'=>0, 'ver'=> 2, 'content'=>'#COMPLEX#'},
	{'name' => 'book-title'	,'opt'=>0, 'ver'=> 2, 'content'=>'#SPACE#'},
	{'name' => 'annotation'	,'opt'=>1, 'ver'=> 2, 'content'=>'#PARAGRAPH#'},
	{'name' => 'keywords'	,'opt'=>1, 'ver'=> 2, 'content'=>'#SPACE#'},
	{'name' => 'date'	,'opt'=>1, 'ver'=> 2, 'content'=>'#DATE#'},
	{'name' => 'coverpage'	,'opt'=>1, 'ver'=> 2, 'content'=>'#IMAGE#'},
	{'name' => 'lang'	,'opt'=>0, 'ver'=> 2, 'content'=>'#SPACE#'},
	{'name' => 'src-lang'	,'opt'=>1, 'ver'=> 2, 'content'=>'#SPACE#'},
	{'name' => 'translator'	,'opt'=>1, 'ver'=> 2, 'content'=>'#COMPLEX#'},
	{'name' => 'sequence'	,'opt'=>1, 'ver'=> 2, 'content'=>'#SEQ_ATTRS#'}
    ];
  }  elsif ($name eq 'document-info')
  {
    my $letters_str='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    my @letters=split(//,$letters_str);
    my $id='FB2-PERL-TOOLS';
    for(my $i=0;$i<4;$i++)
    {
      $id.="-";
      for(my $j=0;$j<10;$j++)
      {
        $id.=$letters[int(rand($#letters+1))];
      }
    }
    
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime time;
    $year+=1900;
    $mon=sprintf("%02d",$mon+1);
    $mday=sprintf("%02d",$mday);
    my $date = "$year-$mon-$mday";
    
    return [
	{'name' => 'author'	 , 'opt'=>0, 'ver'=> 2  , 'content'=>'#COMPLEX#'},
	{'name' => 'program-used', 'opt'=>1, 'ver'=> 2  , 'content'=>'#TEXT# http://fb2-perl-tools.sourceforge.net'},
	{'name' => 'date'	 , 'opt'=>0, 'ver'=> 2  , 'content'=>"#DATE# $date"},
	{'name' => 'src-url'	 , 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'src-ocr'	 , 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'id'		 , 'opt'=>0, 'ver'=> 2  , 'content'=>"#TEXT# $id"},
	{'name' => 'version'	 , 'opt'=>0, 'ver'=> 2  , 'content'=>'#TEXT# 1.0'},
	{'name' => 'history'	 , 'opt'=>1, 'ver'=> 2  , 'content'=>'#PARAGRAPH#'},
	{'name' => 'publisher'	 , 'opt'=>1, 'ver'=> 2.2, 'content'=>'#COMPLEX#'},
    ];
  
  } elsif ($name eq 'publish-info')
  {
    return [
	{'name' => 'book-name'	, 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'publisher'	, 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'city' 	, 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'year' 	, 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'isbn' 	, 'opt'=>1, 'ver'=> 2  , 'content'=>'#SPACE#'},
	{'name' => 'sequence'	, 'opt'=>1, 'ver'=> 2  , 'content'=>'#SEQ_ATTRS#'}
    ];
  
  } elsif ($name eq 'author' || $name eq 'translator' || $name eq 'publisher')
  {
    return [
	{'name' => 'first-name'		,'opt'=>0, 'ver'=> 2,  'content'=>'#SPACE#'},
        {'name' => 'middle-name'	,'opt'=>1, 'ver'=> 2,  'content'=>'#SPACE#'},
	{'name' => 'last-name'		,'opt'=>0, 'ver'=> 2,  'content'=>'#SPACE#'},
	{'name' => 'nickname'		,'opt'=>1, 'ver'=> 2,  'content'=>'#SPACE#'},
	{'name' => 'home-page'		,'opt'=>0, 'ver'=> 2,  'content'=>'#SPACE#'},
	{'name' => 'email'		,'opt'=>0, 'ver'=> 2,  'content'=>'#SPACE#'},
	{'name' => 'id'			,'opt'=>0, 'ver'=> 2.2,'content'=>'#SPACE#'},
    ];
  }    
  return [];
}



1;
