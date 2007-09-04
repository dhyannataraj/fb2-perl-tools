# Philippe Verdret 1998-1999
use strict;
package RTF::HTML::Converter;

use RTF::Control;
@RTF::HTML::Converter::ISA = qw(RTF::Control);

use constant TRACE => 0;
use constant LIST_TRACE => 0;
use constant SHOW_STYLE_NOT_PROCESSED => 0;
use constant SHOW_STYLE => 0;	# insert style name in the output
use constant SHOW_RTF_LINE_NUMBER => 0;

# Symbol exported by the RTF::Ouptut module:
# %info: informations of the {\info ...}
# %par_props: paragraph properties
# $style: name of the current style or pseudo-style
# $event: start and end on the 'document' event
# $text: text associated to the current style
# %symbol: symbol translations
# %do_on_control: routines associated to RTF controls
# %do_on_event: routines associated to events
# output(): a stack oriented output routine (don't use print())

my $START_NEW_PARA = 1;		# some actions to do at the beginning of a new para

###########################################################################
my $N = "\n"; # Pretty-printing
				# some output parameters
my $TITLE_FLAG = 0;
my $LANG = 'en';
my $TABLE_BORDER = 1;

my $CURRENT_LI = 0;		# current list indent
my @LIST_STACK = ();		# stack of opened lists
my %LI_LEVEL = ();		# li -> list level

my %PAR_ALIGN = qw(
		 qc CENTER
		 ql LEFT
		 qr RIGHT
		 qj LEFT
		);
				# here put your style mappings
my %STYLES = ('Normal' => 'p',
	      'Abstract' => 'Blockquote', 
	      'PACSCode' => 'Code',
	      #'AuthGrp' => '', 
	      'Section' => 'H1',
	      'heading 1' => 'H1',
	      'heading 2' => 'H2',
	      'heading 3' => 'H3',
	      'heading 4' => 'H4',
	      'heading 5' => 'H5',
	      'heading 6' => 'H6', 
	      'Code' => 'pre',
	      'par' => 'p',	# default value

	      'Blockquote' => 'p',
	      'Body Text' => 'p',
	     );
				# list names -> level
my %UL_STYLES = ('toc 1' => 1, 
		 'toc 2' => 2,
		 'toc 3' => 3,
		 'toc 4' => 4,
		 'toc 5' => 5,
		);

				# not used
my %UL_TYPES = qw(b7 disk
		  X square
		  Y circle
		 );

my %OL_STYLES = (
		);				
				# not used
my %OL_TYPES = (
		'pncard' => '1', # Cardinal numbering: One, Two, Three
		'pndec' => '1', # Decimal numbering: 1, 2, 3
		'pnucltr' => 'A', # Uppercase alphabetic numbering
		'pnlcltr' => 'a', # lowercase alphabetic numbering
		'pnucrm' =>  'I', # Uppercase roman numbering
		'pnlcrm' =>  'i', # Lowercase roman numbering
	       );

# Список тегов, которые допускают атрибут ALIGN
my %ALIGN_TAGS = map {$_, 1} qw(p h1 h2 h3 h4 h5 h6 table th tr td);


# Список выгруженных файлов, которые еще надо отконвертировать
my %files2convert = ();

my %prev_list_item = ();

# List of footnotes
use vars qw(@footnotes);
# @footnotes = ();

sub new {
  my $receiver = shift;
  my $self = $receiver->SUPER::new(@_);

  $self->accept_options
    ({
      ImageDir => '.',
      ImageUrl => '.',
      ShowInfo => 0,
      ImageDirCreate => 0,
     },
     @_
    );

  $self;
}



my $in_Field = -1;			# nested links are illegal, not used
my $in_Bookmark = -1;			# nested links are illegal, not used
my $was_output_since_char_prop = 0;
%do_on_event = 
  (
   'document' => sub {		# Special action
     if ($event eq 'start') {
       output qq@<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" []>$N<html>$N<head><title>Converted from rtf</title></head><body>$N@;
       %files2convert = ();
     } else {
       my $author = $info{author};
       my $creatim = $info{creatim};
       my $revtim = $info{revtim};

       my $tag;
       while (@LIST_STACK) {
	 $tag = pop @LIST_STACK;
	 output "</$tag>" . $N;
       }

       # Footnotes output
       if (@footnotes) {
	 output "<hr>\n";

	 my $n = 0;
	 for my $ft (@footnotes) {
	   $n++;
#	   print "*** $n: $ft\n";
	   output(sprintf '<p>[<a href="#footnoteret%d" name="footnote%d">%d</a>] %s</p>'."\n", $n, $n, $n, $ft);
	 }
       }

       $style = 'p';

       if ($_[SELF]->{ShowInfo}) {
	 output "<$style><b>Author</b> : $author</$style>\n" if $author;
	 output "<$style><b>Creation date</b>: $creatim</$style>\n" if $creatim;
	 output "<$style><b>Modification date</b>: $revtim</$style>\n" if $revtim;
       }
       output "</body>\n</html>\n";
     }
   },
				# Table processing
   'table' => sub {		# end of table
     if ($event eq 'end') {
       #print STDERR "end of table\n";
       $TABLE_BORDER ? output "<table BORDER>$N$text</table>$N"
	 :
	   output "<table>$N$text</table>$N";
     } else {
       #print STDERR "start of table\n";
       my $end;
       while (@LIST_STACK) {
	 $end .= '</' . pop(@LIST_STACK) . '>' . $N;
       }
       output ($end);
     }
   },
   'row' => sub {		# end of row
     #my $char_props = $_[SELF]->force_char_props('end');
     #output "$N<tr valign='top'>$text$char_props</tr>$N";
     if ($event eq 'end') {
       output "$N<tr valign=top>$N$text$N</tr>$N";
     } else {
				# not defined
     }
   },
   'cell' => sub {		# end of cell
     if ($event eq 'end') {
#       my $char_props = $_[SELF]->force_char_props('end');
       my $char_props = force_char_props('end');
       my $end = '';
       while (@LIST_STACK) {
	 $end .= '</' . pop(@LIST_STACK) . '>' . $N;
       }
       output "<td>$text$char_props$end</td>$N";
     } else {
       # not defined
     }
   },
				# PARAGRAPH STYLES
   #'Normal' => sub {},		# create one entry per style name???
   'par' => sub {		# Default rule: if no entry for a paragraph style
				# Paragraph styles
     #print STDERR "$style\n" if LIST_TRACE;

     return output($text) unless $text =~ /\S/;
     my ($tag_start, $tag_end, $before) = ('','','');

#     if (0) {
#       if ($par_props{list_item}) {
#	 output "<br><br><tt>**** list_item:" . join('|', %{$par_props{list_item}}) . "</tt>";
#       }
#       if ($outlinelevel != -1) {
#	 output "<br><br><tt>**** outlinelevel: $outlinelevel</tt>";
#       }
##       output "<br><br><tt>**** style: $style</tt>";
#     }

     if ($outlinelevel >= 0) {
       $style = sprintf("heading %d", $outlinelevel+1) 
     } else {
       $style = '' if $style =~ '^heading';
     }

     if (defined(my $level = $UL_STYLES{$style})) { # registered list styles
       if ($level > @LIST_STACK) {
	 my $tag;
	 push @LIST_STACK, $tag = 'UL';
	 if (SHOW_STYLE) {
	   $before = "<$tag>[$style]" . $N;
	 } else {
	   $before = "<$tag>" . $N;
	 }
	 $tag_start = $tag_end = 'LI';
       } else {
	 $level = @LIST_STACK - $level;
	 while ($level-- > 0) {
	   $before .= '</' . pop(@LIST_STACK) . '>'. $N;
	 }
	 $tag_start = $tag_end = 'LI';       
       } 
     }

     if ($tag_start eq '') {	# end of list
       while (@LIST_STACK) {
	 $before .= '</' . pop(@LIST_STACK) . '>' . $N;
       }

       ($tag_start, $tag_end, $before) = proc_list_item() unless $tag_start;
       $tag_start = $tag_end = $STYLES{$style} if !$tag_start && (exists $STYLES{$style});
       $tag_start = $tag_end = $STYLES{'par'} unless $tag_start;
       
       #       $tag_start = $tag_end = $STYLES{$style} || do {
       #	 if (SHOW_STYLE_NOT_PROCESSED) {
       #	   use vars qw/%style_not_processed/;
       #				# todo: add count
       #	   unless (exists $style_not_processed{$style}) {
       #	     print STDERR "style not defined '$style'\n" if SHOW_STYLE_NOT_PROCESSED;
       #	     $style_not_processed{$style} = '';
       #	   }
       #	 }
       #	 $STYLES{'par'};
     }

     # Если этот таг допускает атрибут ALIGN
     if (exists $ALIGN_TAGS{lc($tag_start)}) {
       foreach (qw(qj qc ql qr)) { # for some html elements...
	 if ($par_props{$_}) {
	   $tag_start .= " ALIGN=$PAR_ALIGN{$_}";
	   last;
	 }
       }
     }

     $_[SELF]->trace("$tag_start-$tag_end: $text") if TRACE;

     my $char_props = $was_output_since_char_prop ?
       force_char_props('end') : '';
     my $textforoutput = SHOW_RTF_LINE_NUMBER ? 
       "$N$before<$tag_start>[$.]$text$char_props</$tag_end>$N" : 
	 "$N$before<$tag_start>$text$char_props</$tag_end>$N";

     if ($outlinelevel >= 0) {
       while ($textforoutput =~ s/<$tag_start>\s*<([bui])>(.*)<\/\1>\s*<\/$tag_end>/<$tag_start>$2<\/$tag_end>/i) {}
       while ($textforoutput =~ s/<$tag_start>\s*<(\/[bui])>/<$tag_start>/i) {}
     }


     output $textforoutput;

     $START_NEW_PARA = 1;
   },
				# Hypertextuel links
#   'bookmark' => sub {
#     $_[SELF]->trace("bookmark $event $text") if TRACE;
#     if ($event eq 'end') {
#       return if $in_Bookmark--;
#       output("</a>");
#     } else {
#       return if ++$in_Bookmark;
#       output("<a name='$text'>");
#     }
#   },
#   'field' => sub {
#     my $id = $_[0];
#     $_[SELF]->trace("field $event $text") if TRACE;
#     if ($event eq 'end') {
#       return if $in_Field--;
#       output("$text</a>");
#     } else {
#       return if ++$in_Field;
#       output("<a href='#$id'>"); # doesn't work!
#     }
#   },
				# CHAR properties
   'b' => sub {			
     $style = 'b';
     $was_output_since_char_prop = 0;
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'i' => sub {
     $style = 'i';
     $was_output_since_char_prop = 0;
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'ul' => sub {		
     $style = 'u';
     $was_output_since_char_prop = 0;
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'sub' => sub {
     $style = 'sub';
     $was_output_since_char_prop = 0;
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'super' => sub {
     $style = 'sup';
     $was_output_since_char_prop = 0;
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'strike' => sub {
     $style = 'strike';
     $was_output_since_char_prop = 0;
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },

   'plain' => sub {
     my $o = reset_char_props();
     output $o if $was_output_since_char_prop;
     output $o unless $START_NEW_PARA;
     $was_output_since_char_prop = 0;
#     output RTF::Control::force_char_props('', 'end');
   },

   'char_prop_change' => sub {
     $was_output_since_char_prop = 0;
   },
  );

sub do_group_end_char_props{$was_output_since_char_prop}

sub proc_list_item {

  my %pli = %prev_list_item;

  delete($par_props{list_item})
    if $par_props{list_item} && !exists($par_props{list_item}->{level});

  %prev_list_item = $par_props{list_item} ? %{$par_props{list_item}} : ();

  # Если нет level - не считаем элементом списка
  %pli = () if %pli && !exists($pli{level});

  # Не заголовок ли?
  my $hdr = '';
  $hdr = sprintf("H%d", $outlinelevel+1) if $outlinelevel >= 0;

  # Если заголовок - то этот параграф не в списке
  if ($hdr) {
    %prev_list_item = ();
    $par_props{list_item} && delete($par_props{list_item});
  }

  # Вообще не список
  if (!$par_props{list_item} && !(%pli)) {
    return ($hdr, $hdr, '');
  }

  # Список закончился
  if (!$par_props{list_item} && %pli) {
    # Нумерованный или простой
    if ($pli{level} == 11) {
      return ($hdr, $hdr, "</UL>\n");
    } else {
      return ($hdr, $hdr, "</OL>\n");
    }
  }

  # Список начался
  if ($par_props{list_item} && !%pli) {
    # Нумерованный или простой
    if ($par_props{list_item}->{level} == 11) {
      return ('LI', 'LI', "<UL>\n");
    } else {
      return ('LI', 'LI', "<OL>\n");
    }
  }

  # Продолжается тот же список
  if (%pli && $par_props{list_item} && 
      $pli{level} == $par_props{list_item}->{level} 
#      &&
#      $pli{bullet} eq $par_props{list_item}->{bullet}
     ) {
    return ('LI', 'LI', '');
  } else {
    # Изменился тип списка
    my $before = ($pli{level} == 11) ? "</UL>\n" : "</OL>\n";
    $before .= ($par_props{list_item}->{level} == 11) ? "<UL>\n" : "<OL>\n";
    return ('LI', 'LI', $before);
  }
}

###############################################################################
# Could be used in a next release
# manage a minimal context for the tag generation
# gen_tags(EVENT, TAG_NAME, [ATTLIST])
#          EVENT: open|close
# return: a tag start|end
my %cant_nest = map { $_ => 1 } qw(a);
use constant GEN_TAGS_WARNS => 1;
my @element_stack = ();		
my %open_element = ();
sub gen_tags {			# manage a minimal context for tag outputs
  die "bad argument number"  unless (@_ >= 2);
  my ($eve, $tag, $att)  = @_;

  my $result = '';
  if ($eve eq 'open') {
    push @element_stack, $tag; # add a new node
    if ($open_element{$tag}++ and defined $cant_nest{$tag}) {
      #print STDERR "skip open $tag\n";
      $result = '';
    } else {
      $result = '<'. $tag . '>' . $N;
    }
  } else {			# close
    unless (@element_stack) {
      warn "no element to close on the '$tag' tag\n" if GEN_TAGS_WARNS;
      return $result;
    }
    my $opened_elt;
    while (1) {
      $opened_elt = pop @element_stack;
      if (--$open_element{$tag} >= 1 and defined $cant_nest{$tag}) {
	#print STDERR "skip close $opened_elt\n";
      } else {
	$result .= '</' . $opened_elt . '>' . $N;
      }
      last if $tag eq $opened_elt;
      unless (@element_stack) {
	warn "element stack is empty on $tag close\n" if GEN_TAGS_WARNS;
	return $result;
      }
    }
  }
  $result;
}
###############################################################################
# If you have an &<entity>; in your RTF document and if
# <entity> is a character entity, you'll see "&<entity>;" in the RTF document
# and the corresponding glyphe in the HTML document
# How to give a new definition to a control registered in %do_on_control:
# - method redefinition (could be the purist's solution)
# - $Control::do_on_control{control_word} = sub {}; 
# - when %do_on_control is exported write:
$do_on_control{'ansi'} =	# callback redefinition
  sub {
    # RTF: \'<hex value>
    # HTML: &#<dec value>;
    my $charset = $_[CONTROL];
    my $charset_file = $_[SELF]->application_dir() . "/$charset";
    open CHAR_MAP, "$charset_file"
      or die "unable to open the '$charset_file': $!";

    my %charset = (
		   map({ s/^\s+//; split /\s+/ } (<CHAR_MAP>))
		  );
    *char = sub { 
      my $char_props;
      if ($START_NEW_PARA) {
	$char_props = force_char_props('start');
	$START_NEW_PARA = 0;
      } else {
	$char_props = process_char_props('start');
      }
      $was_output_since_char_prop = 1;
      output $char_props . ((exists $charset{$_[1]}) ? $charset{$_[1]} : chr(hex($_[1])));
    };

    *unicodechar = sub {
      my $char_props;
      if ($START_NEW_PARA) {
	$char_props = force_char_props('start');
	$START_NEW_PARA = 0;
      } else {
	$char_props = process_char_props('start');
      }
      $was_output_since_char_prop = 1;
      output $char_props . from_unicode($_[1]);
    };
  };

$do_on_control{'ansicpg'} = sub {
  my $self = $_[SELF];
  my $cpname = 'cp' . $_[ARG];
  
  set_input_charset($cpname) unless $self->{StrictInputCharset};
};


				# symbol processing
				# RTF: \~
				# named chars
				# RTF: \ldblquote, \rdblquote
$symbol{'~'} = '&nbsp;';
$symbol{'tab'} = ' '; #'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
$symbol{'ldblquote'} = '&laquo;';
$symbol{'rdblquote'} = '&raquo;';
$symbol{'line'} = '<br>';
sub symbol {			
  my $char_props;
  if ($START_NEW_PARA) {	
    $char_props = force_char_props('start');
    $START_NEW_PARA = 0;
  } else {
    $char_props = process_char_props('start');
  }
  $was_output_since_char_prop = 1;
  if (defined(my $sym = $symbol{$_[1]}))  {
    output $char_props . $sym;
  } else {
    output $char_props . $_[1];		# as it
  }
}
				# Text
				# certainly do the same thing with the char() method
sub text {			# parser callback redefinition
  my $text = $_[1];
  my $char_props = '';
  if ($START_NEW_PARA) {	
    $char_props = force_char_props('start');
    $START_NEW_PARA = 0;
  } else {
    $char_props = process_char_props('start');
  }
  $text =~ s/&/&amp;/g;	
  $text =~ s/</&lt;/g;	
  $text =~ s/>/&gt;/g;	
  $was_output_since_char_prop = 1;
  if (defined $char_props) { 
    output("$char_props$text");
  } else {
    output("$text");
  }
}


###############################################################
# Image processing

# Накопленные за время обработки картинки данные
my %pict_props = ();

my %control2suffix =
  (
   emfblip =>        ['emf', 'png'],
   pmmetafile =>     ['wmf', 'png'],
   wmetafile =>      ['wmf', 'png'],

   dibitmap =>       ['bmp', 'png'],
   wbitmap =>        ['bmp', 'png'],

   shppict =>        undef,
   nonshppict =>     undef,
   macpict =>        undef,
   pngblip =>        undef,
   jpegblip =>       undef,
#   pngblip =>        ['png', 'png'],
#   jpegblip =>       ['jpg', 'jpg'],
  );

while (my ($k, $v) = each %control2suffix) {
  if (defined $v) {
    $do_on_control{$k} = \&registered_pict_type;
  } else {
    $do_on_control{$k} = \&unregistered_pict_type;
  }
}

for my $cntrl (qw/picw pich picwgoal pichgoal/) {
  $do_on_control{$cntrl} = sub {
    $pict_props{$_[CONTROL]} = $_[ARG];
  }
}

sub registered_pict_type {
  $pict_props{suffix} = $control2suffix{$_[CONTROL]}->[0];
  $pict_props{dstsuffix} = $control2suffix{$_[CONTROL]}->[1];
  $pict_props{picttype} = $_[CONTROL];
  $pict_props{picttypearg} = $_[ARG];
}

sub unregistered_pict_type {
#  die "Not supported pict type '$_[CONTROL]'";
}

sub output_metafile {
  my ($fname, $data, $dirmode, $bindata) = @_;

	$data = unpack("H*"  , $data) if $bindata;

  use File::Basename;
  my $picdir = dirname($fname);

  unless (-d $picdir) {
    die "No dir for pictures: $picdir" unless $dirmode;
    $dirmode = oct($dirmode) if $dirmode =~ /^0/;
    my $u = umask;
    umask 0;
    mkdir $picdir, $dirmode or die "Cannot create dir: $picdir";
    umask $u;
  }

  open F, "> $fname" or die "Cannot open '$fname' for writting picture";
  binmode F;

  # Сформировать заголовок placeable метафайла
  my @hdrdata = ('d7cdc69a', 0, 1, 1, $pict_props{picwgoal}, $pict_props{pichgoal}, 
		 1440, 0);
      
  my $o = pack("H8H4SSSSSiS", @hdrdata);
  my @words = unpack("SSSSSSSSSS", $o);
  my $crc = 0;
  for my $word (@words) {
    $crc ^= $word;
  }
  my $hdr = pack("H8H4SSSSSiS", @hdrdata, $crc);

  print F $hdr;

  # Подправить заголовок стандартного метафайла
  print F pack("H*", substr($data, 0, 12));
  print F pack("L", length($data)/4);
  print F pack("H*", substr($data, 20));

  close F;
}

my $fnumber = 0;

sub binary {
  $pict_props{bindata} = $_[1];
}

$do_on_event{pict} = sub {
  if ($event eq 'end') {
    return unless $pict_props{suffix};

    my $tmpname = sprintf("%d-%d", $$, $fnumber++);
    my $fname = 
      sprintf("%s/%s.%s", $_[SELF]->{ImageDir}, $tmpname, $pict_props{suffix});
    my $imageurl = 
      sprintf("%s/%s.%s", $_[SELF]->{ImageUrl}, $tmpname, $pict_props{dstsuffix});
    if ($pict_props{suffix} ne $pict_props{dstsuffix}) {
      #      $files2convert{$fname} = [$pict_props{suffix}, $pict_props{dstsuffix}];
      $files2convert{$fname} = $fname;
      $files2convert{$fname} =~ s/$pict_props{suffix}$/$pict_props{dstsuffix}/;
    }

    # Дальше - только вывод картинок
    return if $_[SELF]->{ImageDir} eq 'NONE';
    output "$N<img src=\"$imageurl\" alt=\"IMAGE\">$N";

    # Проверка на обрабатываемые пока типы картинок
#    if ($pict_props{picttype} eq 'wmetafile' && $pict_props{picttypearg} == 8) {
    if ($pict_props{picttype} eq 'wmetafile') {
      output_metafile($fname,
											$pict_props{bindata} || $text,
											$_[SELF]->{ImageDirCreate},
											$pict_props{bindata} ? 1 : 0
										 );

    } else {
      # Это по видимому неверно...
#      die "Unknown type of picture... ";
      
    }


  } else {
    %pict_props = ();
  }
};

sub files2convert {
  %files2convert
}

my $savetext;

$do_on_event{footnote} = sub {
  if ($event eq 'start') {
    $savetext = $text;
    $text = '';
    push_output();
    push_output();
    $START_NEW_PARA = 1;
  } else {
    $text .= pop_output();
    $text .= pop_output();

    if ($text =~ /\S/s) {
      push @footnotes, $text;
      my $n = scalar(@footnotes);
      output(sprintf ' [<a name="footnoteret%d" href="#footnote%d">%d</a>]', $n, $n, $n);
    }

    $START_NEW_PARA = 0;
    $text = $savetext;
  }
};

$do_on_control{chftn} = sub{output(' ')};


1;
