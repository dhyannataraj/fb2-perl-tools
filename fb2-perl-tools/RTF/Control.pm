# Sonovision-Itep, Philippe Verdret 1998-1999
# 
# Stack machine - must be application independant!
# 
# defined some interesting events for your application
# an application can redefine its own control callbacks if %do_on_control is exported

# todo:
# - output well-formed HTML
# - better list processing
# - process fields and bookmarks

use strict;
require 5.003;
package RTF::Control;
use RTF::Parser;
use RTF::Config;
use RTF::Charsets;		# define names of chars

use File::Basename;
use Exporter;
@RTF::Control::ISA = qw(Exporter RTF::Parser);

				# here is what you can use in your application
use vars qw(
	    %symbol 
	    %info  
	    %do_on_event 
	    %par_props
	    $outlinelevel
	    %do_on_control
	    $style 
	    $newstyle 
	    $event 
	    $text
	   );
###########################################################################
				# Specification of the callback interface
				# so you can easily reorder sub arguments
use constant SELF => 0;		# rtf processor instance 
use constant CONTROL => 1;	# control word
use constant ARG => 2;		# associated argument
use constant EVENT => 3;	# start/end event
use constant TOP => -1;		# access to the TOP element of a stack
###########################################################################
				# symbols to export in the application layer
@RTF::Control::EXPORT = qw(output push_output pop_output
			   %symbol %info %do_on_event
			   %do_on_control
			   %par_props
			   $outlinelevel
			   $style $newstyle $event $text
			   SELF CONTROL ARG EVENT TOP

			   force_char_props
			   process_char_props
			   reset_char_props

			   from_unicode
			 );  

			 
###########################################################################

%do_on_event = ();		# output routines
$style = '';			# current style
$newstyle = '';			# new style if style changing
$event = '';			# start or end
$text = '';			# pending text
%symbol = ();			# symbol translations
%info = ();			# info part of the document
%par_props = ();		# paragraph properties
$outlinelevel = -1;
###########################################################################
				# Automata states, control modes
my $IN_STYLESHEET = 0;		# inside or outside style table
my $IN_FONTTBL = 0;		# inside or outside font table
my $IN_TABLE = 0;
my $IN_PICT = 0;

my %fonttbl;
my %stylesheet;
my %colortbl;
my @par_props_stack = ();	# stack of paragraph properties
my @char_props_stack = ();	# stack of character properties
my @control = ();		# stack of control instructions, rename control_stack
my $stylename = '';
my $cstylename = '';		# previous encountered style
my $cli = 0;			# current line indent value
my $styledef = '';

my $footnote_depth = 0;

###########################################################################
				# Added methods
sub new {
  my $receiver = shift;
  my $self = $receiver->SUPER::new(@_);
  $self->configure(@_);
}


sub accept_options {
  my ($self, $optdef, %arg) = @_;
  die "Bad params for accept options" unless ref($optdef) eq 'HASH';
  my %opts = %$optdef;

  # Проверяем все переданные опции
  while (my ($key, $value) = each %arg) {
    next unless exists $opts{$key};
    $self->{$key} = $value;
    delete $opts{$key};
  }

  # И определим умолчания
  while (my ($key, $value) = each %opts) {
    next unless defined $value;
    $self->{$key} = $value unless exists $self->{$key};
  }
  $self;
}

sub configure { 
  my $self = shift;

  $self->accept_options
    (
     {
      Output => \*STDOUT,
      InputCharset => 'cp1251',  # Какой принять входным если нет ansicpg
      StrictInputCharset => '',  # Если задан - то плевать на InCharset
      OutputCharset => 'utf-8',  # В каком charset-е выводить
      CatdocCharsets => '/usr/local/lib/catdoc',
     },
     @_
    );
  set_top_output_to($self->{Output});
  set_catdoc_libs($self->{CatdocCharsets});
  
  $self;
}



use constant APPLICATION_DIR => 0;
sub application_dir {
  my $class = ref $_[SELF];
  my $file;
  ($file = $class) =~ s|::|/|g;
  $file = $INC{"$file.pm"};
  my $dirname;
  if (-f $file) {		
    $dirname = dirname $file; 
  } else {
    $dirname = dirname '.' . $file; 
  }
  "$dirname"; 				
}


###########################################################################
# Поддержка перекодировок
use Encode;
use vars qw/
  $InCharset 
  $OutCharset
  $CatdocCharsets
  /;

# Где лежат файлы чарсетов
($InCharset, $OutCharset, $CatdocCharsets) = 
  ('', '', '');

sub set_catdoc_libs {$CatdocCharsets = $_[0]}

sub from_unicode {
 return $_[0];
# Этого момента я не понял... Что бы мы не возвращали, все равно все работает правильно :-/
# Разбираться пока леть... Работает же ;-) 
# Шаплов.

#  return "b";
# return ($InMapper->{$_[0]} || '"');
}



sub recode_string {
   my $in_str = shift;
   my $utf8_str = Encode::decode($InCharset,$in_str);
   my $out_str = Encode::encode($OutCharset,$utf8_str,Encode::FB_XMLCREF);
   return $out_str;
}  
###########################################################################
				# Utils
				# output stack management
my @output_stack;
use constant MAX_OUTPUT_STACK_SIZE => 0; # 8 seems a good value
sub dump_stack {
  local($", $\) = ("\n") x 2;
  my $i = @output_stack;
  print STDERR "Stack size: $i";
  print STDERR map { $i-- . " |$_|\n" } reverse @output_stack;
}
my $nul_output_sub = sub {};
my $string_output_sub = sub { $output_stack[TOP] .= $_[0] || ''};
sub output { eval {$output_stack[TOP] .= $_[0]};
             if ($@) {
	       die "Output stack size=".scalar(@output_stack);
	     }   
	    }
sub push_output {  
  if (MAX_OUTPUT_STACK_SIZE) {
    die "max size of output stack exceeded" if @output_stack == MAX_OUTPUT_STACK_SIZE;
  }

  unless (defined($_[0])) {
    local $^W = 0;
    *output = $string_output_sub; 
  } elsif ($_[0] eq 'nul') {
    local $^W = 0;
    *output = $nul_output_sub;
  }

  push @output_stack, '';
}
sub pop_output {  pop @output_stack; }
use constant SET_TOP_OUTPUT_TO_TRACE => 0;
sub set_top_output_to {

  if (fileno $_[0]) {		# set_top_output_to(\*FH)
				# is there a better way to do this?
    my $stream = $_[0];
    print STDERR "stream: ", fileno $_[0], "\n" if SET_TOP_OUTPUT_TO_TRACE;
    local $^W = 0;
    *flush_top_output = sub {
      my $o = ($InCharset eq $OutCharset) ? 
	$output_stack[TOP] : recode_string( $output_stack[TOP]);
      print $stream $o;
      $output_stack[TOP] = ''; 
    };
  } elsif (ref $_[0] eq 'SCALAR') { # set_top_output_to(\$string)
    print STDERR "output to string\n" if SET_TOP_OUTPUT_TO_TRACE;
    my $content_ref = $_[0];
    local $^W = 0;
    *flush_top_output = sub {
      my $o = ($InCharset eq $OutCharset) ? 
	$output_stack[TOP] : recode_string( $output_stack[TOP]);
      $$content_ref .= $o; 
      $output_stack[TOP] = ''; 
    };
  } elsif (ref $_[0] eq 'ARRAY') {
    print STDERR "output to array\n" if SET_TOP_OUTPUT_TO_TRACE;
    my $content_ref = $_[0];
    local $^W = 0;
    *flush_top_output = sub {
      my $o = ($InCharset eq $OutCharset) ? 
	$output_stack[TOP] : recode_string ($output_stack[TOP]);
      push @$content_ref, $o; 
      $output_stack[TOP] = ''; 
    };
  } else {
    warn "unknown output specification: $_[0]\n";
  }

}

# the default prints on the selected output filehandle
sub flush_top_output {
  # Печатать или как есть, или с перекодировкой
  my $o = ($InCharset eq $OutCharset) ? 
    $output_stack[TOP] : recode_string( $output_stack[TOP]);
  print $o;
  $output_stack[TOP] = ''; 
}

#sub print_output_stack {
#  if (@output_stack) {
#    print @output_stack;
#    @output_stack = ();
#  } else {
#    warn "empty \@output_stack\n";
#  }
#}
###########################################################################
				# Trace management
use constant DEBUG => 0;
use constant TRACE => 0;	
use constant STACK_TRACE => 0;	# 
use constant STYLESHEET_TRACE => 0; # If you want to see the stylesheet of the document
use constant STYLE_TRACE => 0; # 
use constant LIST_TRACE => 0;

$| = 1 if TRACE or STACK_TRACE or DEBUG;
sub trace {
  #my(@caller) = (caller(1));
  #my $sub = (@caller)[3];
  #$sub =~ s/.*:://;
  #$sub = sprintf "%-12s", $sub;
  shift if ref $_[0];
  print STDERR "[$.]", ('_' x $#control . "@_\n");
}
$SIG{__DIE__} = sub {
  require Carp;
  Carp::confess;
} if DEBUG;

###########################################################################
				# Some generic routines
use constant DISCARD_CONTENT => 0;
sub discard_content {		
  my($control, $arg, $cevent) = map {defined($_) || ''} ($_[CONTROL], $_[ARG], $_[EVENT]);
  #  trace "($_[CONTROL], $_[ARG], $_[EVENT])" if DISCARD_CONTENT;
  if ($arg eq "0") { 
    pop_output();
    $control[TOP]->{"$_[CONTROL]1"} = 1;
  } elsif ($_[EVENT] eq 'start') { 
    push_output();
    $control[TOP]->{"$_[CONTROL]$arg"} = 1;
  } elsif ($arg eq "1") { # see above
    $cevent = 'start';
    push_output();
  } elsif ($_[EVENT] eq 'end') { # End of discard
    my $string = pop_output();
    if (length $string > 30) {
      $string =~ s/(.{1,10}).*(.{1,10})/$1 ... $2/;
    }
    trace "discard content of \\$control: $string" if DISCARD_CONTENT;
  } else {
    die "($_[CONTROL], $arg, $_[EVENT])" if DISCARD_CONTENT;
  }
}

sub do_on_info {		# 'info' content
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  my $string;
  my $arg = $_[ARG] || '';
  if ($_[EVENT] eq 'start') { 
    push_output();
    $control[TOP]->{"$_[CONTROL]$arg"} = 1;
  } else {
    $string = pop_output();
    $info{"$_[CONTROL]$arg"} = $string;
  }
}
				# SYMBOLS
# default mapping for symbols
# char processed by the parser symbol() callback: - _ ~ : | { } * ' \\
%symbol = qw(
	     | |
	     _ _
	     : :
	     bullet *
	     endash -
	     emdash --
	     ldblquote ``
	     rdblquote ''
	     );
$symbol{rquote} = "\'";
$symbol{lquote} = "\`";
$symbol{'column'} = "\t";
$symbol{'tab'} = "\t";
$symbol{'line'} = "\n";
$symbol{'page'} = "\f";
$symbol{'-'} = '';

sub do_on_symbol { output $symbol{$_[CONTROL]} }
my %symbol_ctrl = map {		# install the do_on_symbol() routine
  if (/^[a-z]+$/) {
    $_ => \&do_on_symbol
  } else {
    'undef' => undef;
  }
} keys %symbol;

###########################################################################################
my %char_props;			# control hash must be declarated before install_callback()
# purpose: associate callbacks to controls
# 1. an hash name that contains the controls
# 2. a callback name
sub install_callback {		# not a method!!!
  my($control, $callback) = ($_[1], $_[2]);
  no strict 'refs';
  unless (%char_props) { # why I can't write %{$control}
    die "'%$control' not defined";
  }
  for (keys %char_props) {
    $do_on_control{$_} = \&{$callback};
  }
}
				# TOGGLES
				# {\<toggle> ...}
				# {\<toggle>0 ...}
###########################################################################
# How to give a general definition?
#my %control_definition = ( # control => [default_value nassociated_callback]
#			  'char_props' => qw(0 do_on_control),
#			 );
my $char_prop_change = 0;
my %current_char_props = %char_props;

sub char_prop_change {
  $char_prop_change = shift;
  if (my $action = $do_on_event{char_prop_change}) {
    ($style, $event) = ('', 'start');
    &$action;
  }
}

sub reset_char_props {
  return if $IN_STYLESHEET or $IN_FONTTBL;
  my $ret = force_char_props('end');

  %char_props = map {
    $_ => 0
  } qw(b i ul sub super strike);

  %current_char_props = %char_props;

  char_prop_change(1);

#  if (defined (my $action = $do_on_event{'reset_char_prop'})) {
#    ($style, $event) = ('', 'start');
#    &$action;
#  }
  $ret;
}
use constant OUTPUT_CHAR_PROPS => 0;
sub char_prop_list {
  if ($_[0] eq 'start') {
    return sort keys %char_props;
  } else {
    return reverse(sort keys %char_props);
  }
}
sub force_char_props {		# force a START/END event
  return '' if $IN_STYLESHEET or $IN_FONTTBL;
  trace "@_" if OUTPUT_CHAR_PROPS;
  $event = $_[0];		# END or START
				# close or open all activated char prorperties
  push_output();
  for my $char_prop (char_prop_list($_[0])) {
    my $value = $char_props{$char_prop};
    next unless $value;
    trace "$event active char props: $char_prop" if OUTPUT_CHAR_PROPS;
    if (defined (my $action = $do_on_event{$char_prop})) {
      ($style, $event) = ($char_prop, $event);
      &$action;
    }
    $current_char_props{$char_prop} = $value;
  }

  char_prop_change(0);
  pop_output();
}
use constant PROCESS_CHAR_PROPS => 0;
sub process_char_props {
  return '' if $IN_STYLESHEET or $IN_FONTTBL;
  return '' unless $char_prop_change;
  my $direction = $_[0];
  push_output();

  for my $char_prop (char_prop_list($direction)) {
    my $value = $char_props{$char_prop};
    my $prop = $current_char_props{$char_prop};
    $prop = defined $prop ? $prop : 0;
    trace "$char_prop $value" if PROCESS_CHAR_PROPS;
    if ($prop != $value) {
      if (defined (my $action = $do_on_event{$char_prop})) {
	$event = $value == 1 ? 'start' : 'end';
	($style, $event) = ($char_prop, $event);
	&$action;
      }
      $current_char_props{$char_prop} = $value;
    }
    trace "$char_prop - $prop - $value" if PROCESS_CHAR_PROPS;
  }

  char_prop_change(0);
  pop_output();
}
use constant DO_ON_CHAR_PROP => 0;
sub do_on_char_prop {		# associated callback
  return if $IN_STYLESHEET or $IN_FONTTBL;
  my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  trace "my(\$control, \$arg, \$cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);" if DO_ON_CHAR_PROP;
  char_prop_change(1);
  if (defined($_[ARG]) and $_[ARG] eq "0") {		# \b0 
    $char_props{$_[CONTROL]} = 0;
  } elsif ($_[EVENT] eq 'start') { # eg. \b or \b1
    $char_props{$_[CONTROL]} = 1; 
  } else {			# 'end'
    warn "statement not reachable";
    $char_props{$_[CONTROL]} = 0;
  }
}

$do_on_control{nosupersub} = sub {
  char_prop_change(1);
  $char_props{super} = $char_props{"sub"} = 0;
};

__PACKAGE__->reset_char_props();
__PACKAGE__->install_callback('char_props', 'do_on_char_prop');
###########################################################################
				# not more used!!!
use constant DO_ON_TOGGLE => 0;
sub do_on_toggle {		# associated callback
  return if $IN_STYLESHEET or $IN_FONTTBL;
  my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  trace "my(\$control, \$arg, \$cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);" if DO_ON_TOGGLE;

  if ($_[ARG] eq "0") {		# \b0, register an START event for this control
    $control[TOP]->{"$_[CONTROL]1"} = 1; # register a start event for this properties
    $cevent = 'end';
  } elsif ($_[EVENT] eq 'start') { # \b or \b1
    $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
  } else {			# $_[EVENT] eq 'end'
    if ($_[ARG] eq "1") {	
      $cevent = 'start';
    } else {			
    }
  }
  trace "(\$style, \$event, \$text) = ($control, $cevent, '')" if DO_ON_TOGGLE;
  if (defined (my $action = $do_on_event{$control})) {
    ($style, $event, $text) = ($control, $cevent, '');
    &$action;
  } 
}
###########################################################################
				# FLAGS
use constant DO_ON_FLAG => 0;
sub do_on_flag {
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  die if $_[ARG];			# no argument by definition
  trace "$_[CONTROL]" if DO_ON_FLAG;
  $par_props{$_[CONTROL]} = 1;
}

use vars qw/%charset/;
my $bullet_item = 'b7'; # will be redefined in a next release!!!

				# Try to find a "RTF/<application>/char_map" file
				# possible values for the control word are: ansi, mac, pc, pca
sub define_charset {
  my $charset = $_[CONTROL];
  eval {			
    no strict 'refs';
    *charset = \%{"$charset"};
  };
  warn $@ if $@;

  my $charset_file = $_[SELF]->application_dir() . "/char_map";
  my $application = ref $_[SELF];
  open CHAR_MAP, "$charset_file"
    or die "unable to open the '$charset_file': $!";

  my ($name, $char, $hexa);
  my %char = map{
    s/^\s+//; 
    next unless /\S/;
    ($name, $char) = split /\s+/; 
    if (!defined($hexa = $charset{$name})) {
      'undef' => undef;
    } else {
      $hexa => $char;
    }
  } (<CHAR_MAP>);
  %charset = %char;		# for a direct translation of hexadecimal values
  warn $@ if $@;
}

my %flag_ctrl =			
  (				
   'ql' => \&do_on_flag,
   'qr' => \&do_on_flag,
   'qc' => \&do_on_flag,
   'qj' => \&do_on_flag,

				# 
   'ansi' => \&define_charset,	# The default
   'mac' => \&define_charset,	# Apple Macintosh
   'pc' => \&define_charset,	# IBM PC code page 437 
   'pca' => \&define_charset,	# IBM PC code page 850
				# 

   #   'pict' => \&discard_content,	#
   'xe'  => \&discard_content,	# index entry
   #'v'  => \&discard_content,	# hidden text
  );

sub do_on_destination {
  trace "currently do nothing";
}
my %destination_ctrl =
  (
  );

sub do_on_value {
  trace "currently do nothing";
}
my %value_ctrl =
  (
  );

my %pn = ();			# paragraph numbering 
my $field_ref = '';		# identifier associated to a field
#trace "define callback for $_[CONTROL]";
%do_on_control = 
  (
   %do_on_control,		
   %flag_ctrl,
   %value_ctrl,
   %symbol_ctrl,
   %destination_ctrl,

   'plain' => sub {
     #unless (@control) {       die "\@control stack is empty";     }
     #output('plain');
     if (defined (my $action = $do_on_event{'plain'})) {
       ($style, $event) = ('', 'start');
       &$action;
     } else {
       reset_char_props();
     }
   },
   'rtf' => sub { # rtfN, N is version number 
     if ($_[EVENT] eq 'start') { 
       push_output('nul');
       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
   },
   'info' => sub {		# {\info {...}}
     if ($_[EVENT] eq 'start') { 
       push_output('nul');
       my $arg = $_[ARG] || '';
       $control[TOP]->{"$_[CONTROL]$arg"} = 1;
     } else {
       pop_output();
     }
   },
				# INFO GROUP
   # Other informations:
   # {\printim\yr1997\mo11\dy3\hr11\min5}
   # {\version3}{\edmins1}{\nofpages3}{\nofwords1278}{\nofchars7287}
   # {\*\company SONOVISION-ITEP}{\vern57443}
   'title' => \&do_on_info,	# destination
   'author' => \&do_on_info,	# destination
   'revtim' => \&do_on_info,	# destination
   'creatim' => \&do_on_info,	# destination, {\creatim\yr1996\mo9\dy18\hr9\min17}
   'yr' => sub { output "$_[ARG]-" }, # value
   'mo' => sub { output "$_[ARG]-" }, # value
   'dy' => sub { output "$_[ARG]-" }, # value
   'hr' => sub { output "$_[ARG]-" }, # value
   'min' => sub { output "$_[ARG]" }, # value

				# binary data
   'bin' => sub { $_[SELF]->read_bin($_[ARG]) }, # value

				# Color table - destination
   'colortbl' => \&discard_content,
				# Font table - destination
   'fonttbl' => sub {
     #     trace "num: $#control control: $_[CONTROL] arg: $_[ARG] event: $_[EVENT]";

     if ($_[EVENT] eq 'start') { 
       $IN_FONTTBL = 1 ;
       push_output('nul');
#       my $arg = '' unless defined $_[ARG];
       $control[TOP]->{$_[CONTROL] . $_[ARG]} = 1;
     } else {
       $IN_FONTTBL = 0 ;
       pop_output();
     }
   },
				# file table - destination
   'filetbl' => sub {
     #trace "$#control $_[CONTROL] $_[ARG] $_[EVENT]";
     if ($_[EVENT] eq 'start') { 
       push_output('nul');
       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
   },

   'f', sub {			
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     # perhaps interesting to provide a contextual
     # definition of this kind of control words
     # eg. in fonttbl call 'fonttbl:f', outside call 'f'
     use constant FONTTBL_TRACE => 0; # if you want to see the fonttbl of the document
     if ($IN_FONTTBL) {
       if ($_[EVENT] eq 'start') {
	 push_output();
	 $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $fontname = pop_output;
	 my $fontdef = "$_[CONTROL]$_[ARG]";
	 if ($fontname =~ s/\s*;$//) {
	   trace "$fontdef => $fontname" if FONTTBL_TRACE;
	   $fonttbl{$fontdef} = $fontname;
	 } else {
	   warn "can't analyze $fontname";
	 }
       }
       return;
     } elsif ($IN_STYLESHEET) {	# eg. \f1 => Normal;
       return if $styledef;	# if you have already encountered an \sn
       $styledef = "$_[CONTROL]$_[ARG]";
       if ($_[EVENT] eq 'start') {
	 #trace "start $_[CONTROL]$_[ARG]" if STYLESHEET;
	 push_output();
	 $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $stylename = pop_output;
	 #trace "end\n $_[CONTROL]" if STYLESHEET;
	 if ($stylename =~ s/\s*;$//) {
	   trace "$styledef => $stylename" if STYLESHEET_TRACE;
	   $stylesheet{$styledef} = $stylename;
	 } else {
	   warn "can't analyze '$stylename' ($styledef; event: $_[EVENT])";
	 }
       }
       $styledef = '';
       return;
     }
     return if $styledef;	# if you have already encountered an \sn
     $styledef = "$_[CONTROL]$_[ARG]";
     $stylename = $stylesheet{"$styledef"};
     trace "$styledef => $stylename" if STYLESHEET_TRACE;
     return unless $stylename;

     if (defined($cstylename) && $cstylename ne $stylename) { # notify a style changing
       if (defined (my $action = $do_on_event{'style_change'})) {
	 ($style, $newstyle) = ($cstylename, $stylename);
	 &$action;
       } 
     }
     $cstylename = $stylename;
     $par_props{'stylename'} = $cstylename; # the current style 
   },
				# 
				# Style processing
				# 
   'stylesheet' => sub {
     trace "stylesheet $#control $_[CONTROL] $_[ARG] $_[EVENT]" if STYLESHEET_TRACE;
     if ($_[EVENT] eq 'start') { 
       $IN_STYLESHEET = 1 ;
       push_output('nul');
       my $arg = $_[ARG] || '';
       $control[TOP]->{"$_[CONTROL]$arg"} = 1;
     } else {
       $IN_STYLESHEET = 0;
       pop_output;
     }
   },
   's', sub {
     my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     $styledef = "$_[CONTROL]$_[ARG]";

     if ($IN_STYLESHEET) {
       if ($_[EVENT] eq 'start') {
	 push_output();
	 $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $stylename = pop_output;
	 warn "empty stylename" and return if $stylename eq '';
	 if ($stylename =~ s/\s*;$//) {
	   trace "$styledef => $stylename|" if STYLESHEET_TRACE;
	   $stylesheet{$styledef} = $stylename;
	   $styledef = '';
	 } else {
	   warn "can't analyze style name: '$stylename'";
	 }
       }
       return;
     }

     $stylename = $stylesheet{"$styledef"};
     #	     trace "cstyle: $cstylename style: $stylename";
     if (defined($cstylename) and $cstylename ne $stylename) {
       if (defined (my $action = $do_on_event{'style_change'})) {
	 ($style, $newstyle) = ($cstylename, $stylename);
	 &$action;
       } 
     }
     $cstylename = $stylename;
     $par_props{'stylename'} = $cstylename; # the current style 
     trace "$styledef => $stylename" if STYLESHEET_TRACE;
   },
				# a very minimal table processing
   'trowd' => sub {		# row start
     use constant TABLE_TRACE => 0;
     #print STDERR "=>Beginning of ROW\n";
     unless ($IN_TABLE) {
       $IN_TABLE = 1;
       if (defined (my $action = $do_on_event{'table'})) {
	 $event = 'start';
	 trace "table $event $text\n" if TABLE_TRACE;
	 &$action;
       } 

       push_output();		# table content
       push_output();		# row  sequence
       push_output();		# cell sequence
       push_output();		# cell content
     }
   },
   'intbl' => sub {
     $par_props{'intbl'} = 1;
     unless ($IN_TABLE) {
       warn "ouverture en catastrophe" if TABLE_TRACE;
       $IN_TABLE = 1;
       if (defined (my $action = $do_on_event{'table'})) {
	 $event = 'start';
	 trace "table $event $text\n" if TABLE_TRACE;
	 &$action;
       } 

       push_output();
       push_output();
       push_output();
       push_output();
     }
   },
   'row' => sub {		# row end
#     $text = pop_output;
#     $text = pop_output . $text;
#     if (defined (my $action = $do_on_event{'cell'})) {
#       $event = 'end';
#       trace "row $event $text\n" if TABLE_TRACE;
#       &$action;
#     } 
     pop_output;
     pop_output;
     $text = pop_output;
     if (defined (my $action = $do_on_event{'row'})) {
       $event = 'end';
       trace "row $event $text\n" if TABLE_TRACE;
       &$action;
     } 
     push_output();
     push_output();
     push_output();
   },
   'cell' => sub {		# end of cell
     trace "process cell content: $text\n" if TABLE_TRACE;
     $text = pop_output;
     if (defined (my $action = $do_on_event{'par'})) {
       ($style, $event,) = ('par', 'end',);
       &$action;
     } else {
       warn "$text";;
     }
     $text = pop_output;
     if (defined (my $action = $do_on_event{'cell'})) {
       $event = 'end';
       trace "cell $event $text\n" if TABLE_TRACE;
       &$action;
     } 
 				# prepare next cell
     push_output();
     push_output();
     trace "\@output_stack in table: ", @output_stack+0 if STACK_TRACE;
   },
   'par' => sub {		# END OF PARAGRAPH
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     trace "($_[CONTROL], $_[ARG], $_[EVENT])" if STYLE_TRACE;
     if ($IN_TABLE and not $par_props{'intbl'}) { # End of Table
       $IN_TABLE = 0;
       my $next_text = pop_output; # next paragraph content
       
#       $text = pop_output;
#       $text = pop_output . "$text";
#       if (defined (my $action = $do_on_event{'cell'})) { # end of cell
#	 $event = 'end';
#	 trace "cell $event $text\n" if TABLE_TRACE;
#	 &$action;
#       } 
#       $text = pop_output;
#       if (defined (my $action = $do_on_event{'row'})) { # end of row
#	 $event = 'end';
#	 trace "row $event $text\n" if TABLE_TRACE;
#	 &$action;
#       } 
       $text = pop_output;
       $text = pop_output;
       $text = pop_output;
       if (defined (my $action = $do_on_event{'table'})) { # end of table
	 $event = 'end';
	 trace "table $event $text\n" if TABLE_TRACE;
	 &$action;
       } 
       push_output();	       
       trace "end of table ($next_text)\n" if TABLE_TRACE;
       output($next_text);
     } else {
       #push_output();	
     }
				# paragraph style
     if (defined($cstylename) and $cstylename ne '') { # end of previous style
       $style = $cstylename;
     } else {
       $cstylename = $style = 'par'; # no better solution
     }
     $par_props{'stylename'} = $cstylename; # the current style 

     if ($par_props{intbl}) {	# paragraph in tbl
       trace "process cell content: $text\n" if TABLE_TRACE;
       if (defined (my $action = $do_on_event{$style})) {
	 ($style, $event, $text) = ($style, 'end', pop_output);
	 &$action;
       } elsif (defined ($action = $do_on_event{'par'})) {
	 #($style, $event, $text) = ('par', 'end', pop_output);
	 ($style, $event, $text) = ($style, 'end', pop_output);
	 &$action;
       } else {
	 warn;
       }
       push_output(); 
     #} elsif (defined (my $action = $do_on_event{'par_styles'})) {
     } elsif (defined (my $action = $do_on_event{$style})) {
       ($style, $event, $text) = ($style, 'end', pop_output);
       &$action;
       flush_top_output();
       push_output(); 
     } elsif (defined ($action = $do_on_event{'par'})) {
       #($style, $event, $text) = ('par', 'end', pop_output);
       ($style, $event, $text) = ($style, 'end', pop_output);
       &$action;
       flush_top_output();
       push_output(); 
     } else {
       trace "no definition for '$style' in %do_on_event\n" if STYLE_TRACE;
       flush_top_output();
       push_output(); 
     }
				# redefine this!!!
     $cli = $par_props{'li'};
     $styledef = '';		
     $par_props{'bullet'} = $par_props{'number'} = $par_props{'tab'} = 0; # 
     $outlinelevel = -1;
   },
				# Resets to default paragraph properties
				# Stop inheritence of paragraph properties
   'pard' => sub {		
				# !!!-> reset_par_props()
     foreach (qw(qj qc ql qr intbl li)) {
       $par_props{$_} = 0;
     }
     foreach (qw(list_item)) {
       $par_props{$_} = '';
     }
   },

   'outlinelevel' => sub {
     $outlinelevel = $_[ARG];
   },
				# ####################
				# Fields and Bookmarks
#    'field' => sub {  		# for a future version
#      use constant FIELD_TRACE => 0;
#      if ($_[EVENT] eq 'start') {
#        push_output();
#        $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
#        $field_ref = '';
#      } else {
#        #trace "$_[CONTROL] content: ", pop_output();
#        if (defined (my $action = $do_on_event{'field'})) {
# 	 ($style, $event, $text) = ($style, 'end', pop_output);
# 	 &$action($field_ref);
#        } 
#      }
#   },

   # don't uncomment!!!
#   'fldrslt' => sub { 
#     return;
#     if ($_[EVENT] eq 'start') {
#       push_output();
#       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
#     } else {
#       #trace "$_[CONTROL] content: ", pop_output();
#       pop_output();
#     }
#   },
   # uncomment!!!
   # eg: {\*\fldinst {\i0  REF version \\* MERGEFORMAT }}
#   '*fldinst' => sub {		# Destination
#     my $string = $_[EVENT];
#     trace "$_[CONTROL] content: $string" if FIELD_TRACE;
#     $string =~ /\b(REF|PAGEREF)\s+(_\w\w\w\d+)/i;
#     $field_ref = $2;
#     # PerlBug???; $_[CONTROL] == $1 - very strange
#     trace "$_[CONTROL] content: $string -> $2" if FIELD_TRACE;
#     trace "$_[1] content: $string -> $2" if FIELD_TRACE;
#     if (defined (my $action = $do_on_event{'field'})) {
#       ($style, $event, $text) = ($style, 'start', '');
#       &$action($field_ref);
#     } 
#   },
#				# Bookmarks
#   '*bkmkstart' => sub {		# destination
#     my $string = $_[EVENT];
#     if (defined (my $action = $do_on_event{'bookmark'})) {
#       $string =~ /(_\w\w\w\d+)/;	# !!!
#       trace "$_[CONTROL] content: $string -> $1" if TRACE;
#       ($style, $event, $text) = ($style, 'start', $1);
#       &$action;
#     } 
#   },
#   '*bkmkend' => sub {		# destination
#     my $string = $_[EVENT];
#     if (defined (my $action = $do_on_event{'bookmark'})) {
#       $string =~ /(_\w\w\w\d+)/;	# !!!
#       ($style, $event, $text) = ($style, 'end', $1);
#       &$action;
#     }
#   },
				# ###########################
   'pn' => sub {  		# Turn on PARAGRAPH NUMBERING
     #trace "($_[CONTROL], $_[ARG], $_[EVENT])" if TRACE;
     if ($_[EVENT] eq 'start') {
       %pn = ();
       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       # I don't like this!!! redesign the parser???
       trace("Level: $pn{level} - Type: $pn{type} - Bullet: $pn{bullet}") if LIST_TRACE;
       $par_props{list_item} = \%pn;
     }
   },
   'pnlvl' => sub {		# Paragraph level $_[ARG] is a level from 1 to 9
     $pn{level} = $_[ARG];
   },
   'pnlvlbody' => sub {		# Paragraph level 10
     $pn{level} = 10;
   },
   'pnlvlblt' => sub {		# Paragraph level 11, processs the 'pntxtb' group
     $pn{level} = 11;		# bullet
   },
  'pntxtb' => sub {
     if ($_[EVENT] eq 'start') { 
       push_output();
       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $pn{'bullet'} = pop_output();
     }
  },
  'pntxta' => sub {
     if ($_[EVENT] eq 'start') { 
       push_output();
       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
  },
				# Numbering Types
   'pncard' => sub {		# Cardinal numbering: One, Two, Three
     $pn{type} = $_[CONTROL];
   },
   'pndec' => sub {		# Decimal numbering: 1, 2, 3
     $pn{type} = $_[CONTROL];
   },
   'pnucltr' => sub {		# Uppercase alphabetic numbering
     $pn{type} = $_[CONTROL];
   },
   'pnlcltr' => sub {		# Lowercase alphabetic numbering
     $pn{type} = $_[CONTROL];
   },
   'pnucrm' => sub {		# Uppercase roman numbering
     $pn{type} = $_[CONTROL];
   },
   'pnlcrm' => sub {		# Lowercase roman numbering
     $pn{type} = $_[CONTROL];
   },
  'pntext' => sub {		# ignore text content
     if ($_[EVENT] eq 'start') { 
       push_output();
       $control[TOP]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
   },
   #'tab' => sub { $par_props{'tab'} = 1 }, # special char

   'li' => sub {		# line indent - value
     use constant LI_TRACE => 0;
     my $indent = $_[ARG];
     $indent =~ s/^-//;
     trace "line indent: $_[ARG] -> $indent" if LI_TRACE;
     $par_props{'li'} = $indent;
   },


   # Picture processing
   'pict' => sub {
     push_output();
     $IN_PICT = 1;
     if (defined (my $action = $do_on_event{pict})) {
       $event = 'start';
       &$action;
     }

   }
  );

$do_on_control{footnote} = sub {
  $footnote_depth = 1;
#  push_output();
  my $action = $do_on_event{footnote};
  $event = 'start';

  &$action if defined $action;
};

###########################################################################
				# Parser callback definitions
use constant GROUP_START_TRACE => 0;
sub group_start {		# on {
  my $self = shift;
  trace "" if GROUP_START_TRACE;
  push @par_props_stack, { %par_props };
  push @char_props_stack, { %char_props };
  push @control, {};		# hash of controls
  $footnote_depth++ if $footnote_depth;
}
use constant GROUP_END_TRACE => 0;
sub do_group_end_char_props{1}
sub group_end {			# on }

				# par properties
  %par_props = %{ pop @par_props_stack };
  $cstylename = $par_props{'stylename'}; # the current style 

				# Char properties
				# process control like \b0
  %char_props = %{ pop @char_props_stack }; 

  # If it ends picture group
  if ($IN_PICT) {
    $IN_PICT = 0;
    $text = pop_output();
    if (defined (my $action = $do_on_event{pict})) {
      $event = 'end';
      &$action;
    }
  } else {
    if ($_[SELF]->do_group_end_char_props()) {
      char_prop_change(1);
      #    output $_[SELF]->process_char_props('end');
      output process_char_props('end');
    } else {
      %current_char_props = %char_props;
    }
  }

  no strict qw/refs/;
  foreach my $control (keys %{pop @control}) { # End Events!
    $control =~ /([^\d]+)(\d+)?/; # eg: b0, b1
    trace "($#control): $1-$2" if GROUP_END_TRACE;
    # sub associated to $1 is already defined in the "Action" package 
    &{"RTF::Action::$1"}($_[SELF], $1, $2, 'end'); 
  }

  # If it ends footnote group
  if ($footnote_depth) {
    $footnote_depth--;
    unless ($footnote_depth) {
#      $text .= pop_output();
      my $action = $do_on_event{footnote};
      $event = 'end';
      &$action if defined $action;
    }
  }
}
use constant TEXT_TRACE => 0;
sub text { 
  trace "$_[1]" if TEXT_TRACE;
  output($_[1]);
}
sub char {			
  if (defined(my $char = $charset{$_[1]}))  {
    #print STDERR "$_[1] => $char\n";
    output "$char";
  } else {
    output "$_[1]"; 
  }
}
sub symbol {			# symbols: \ - _ ~ : | { } * \'
  if (defined(my $sym = $symbol{$_[1]}))  {
    output "$sym";
  } else {
    output "$_[1]";		# as it
  }
}

sub unicodechar {
  output from_unicode(int($_[1]));
}

use constant PARSE_START_END => 0;
sub parse_start {
  my $self = shift;

  # some initializations
  %info = ();
  %fonttbl = ();
  %colortbl = ();
  %stylesheet = ();
  $InCharset = $self->{StrictInputCharset} || $self->{InputCharset};
  $OutCharset = $self->{OutputCharset};
  
#  set_input_charset($self->{StrictInputCharset} || $self->{InputCharset});
#  set_output_charset($self->{OutputCharset});
#  make_direct_map();
  push_output();
  if (defined (my $action = $do_on_event{'document'})) {
    $event = 'start';
    &$action;
  }
  flush_top_output();	
  push_output();
}
sub parse_end {
  my $self = shift;
  my $action = '';
  trace "parseEnd \@output_stack: ", @output_stack+0 if STACK_TRACE;

  if (defined ($action = $do_on_event{'document'})) {
    ($style, $event, $text) = ($cstylename, 'end', '');
    &$action;
  } 
  flush_top_output();		# @output_stack == 2;
}
use vars qw(%not_processed);
END {
  if (@control) {
    trace "END{} - Control stack not empty [size: ", @control+0, "]: ";
    foreach my $hash (@control) {
      while (my($key, $value) = each %$hash) {
	trace "$key => $value";
      }
    }
  }
  if ($LOG_FILE) {
    select STDERR;
    unless (open LOG, "> $LOG_FILE") {
      print qq^$::BASENAME: unable to output data to "$LOG_FILE"$::EOM^;
      return 0;
    }
    select LOG;
    my($key, $value) = ('','');
    while (my($key, $value) = each %not_processed) {
      printf LOG "%-20s\t%3d\n", "$key", "$value";
    }
    close LOG;
    print STDERR qq^See Informations in the "$LOG_FILE" file\n^;
  }
}
1;
__END__
