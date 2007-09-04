# Sonovision-Itep, Philippe Verdret 1998-1999
# An event-driven RTF parser

require 5.004;
use strict;
package RTF::Parser;

$RTF::Parser::VERSION = "1.07";
use RTF::Config;
use File::Basename;

use constant PARSER_TRACE => 0;
sub backtrace { 
  require Carp;
  Carp::confess;			
}
$SIG{'INT'} = \&backtrace if PARSER_TRACE;
$SIG{__DIE__} = \&backtrace if PARSER_TRACE;
 
# Parser::Generic
sub parse_stream {
  my $self = shift;
  my $stream = shift;
  my $reader = shift;		# eg: parse_stream(\*FH, \&read)
  my $buffer = '';

  unless (defined $stream) {
    die "file not defined";
  }
  $self->{Filename} = '';
  local(*F) = $stream;
  no strict 'refs';
  unless (defined (fileno $stream)) {
    $self->{Filename} = $stream;     # Assume $stream is a filename
    open(F, $stream) or die "Can't open '$stream' ($!)";
  }
  binmode(F);
  $self->{Filehandle} = \*F;
  $self->{Eof} = 0;
  $self->{Buffer} = \$buffer;
  $self->{If_data_needed} = ref $reader eq 'SUB' ? 
    $reader :
      sub {			# The default reader
	if ($buffer .= <F>) {
	  1;
	} else {
	  $self->{Eof} = 1;
	  0;
	}
      };
  local *if_data_needed = $self->{If_data_needed};
				# Now parse the stream
  $self->if_data_needed() or die "unexpected end of data";
  $self->parse();
  close(F) if $self->{Filename} ne '';
  $self;
}
sub parse_string {
  my $self = shift;
  my $buffer = $_[0];

  $self->{Filehandle} = '';
  $self->{Filename} = '';
  $self->{Eof} = 0;
  $self->{If_data_needed} = sub { 0 };
  local *if_data_needed = $self->{If_data_needed};
  $self->{Buffer} = \$buffer;
  $self->parse();
  $self;
}
sub parse_array {
  my $self = shift;
  my $inarr = $_[0];
  my $buffer = '';

  die "Not array ref on 'parse_array'\n" unless ref $inarr eq 'ARRAY';

  $self->{Filehandle} = '';
  $self->{Filename} = '';
  $self->{Eof} = 0;
  $self->{If_data_needed} = sub {
    if (@$inarr) {
      $buffer .= shift @$inarr;
      1;
    } else {
      $self->{Eof} = 1;
      0;
    }
  };
  local *if_data_needed = $self->{If_data_needed};
  $self->{Buffer} = \$buffer;
  $self->parse();
  $self;
}
sub new {
  my $receiver = shift;		# or something like this
  my $class = (ref $receiver or $receiver);
  my $self = bless {
		    Buffer => '', # internal buffer
		    Eof => 0,	# 1 if EOF, not used
		    EOR => '',	# end of record regex
		    Filename => '', # filename
		    Filehandle => '',	#
		    Line => 0,	# not used
		   }, $class;
  $self;
}

sub line { $_[1] ? $_[0]->{Line} = $_[1] : $_[0]->{Line} } 
sub filename { $_[1] ? $_[0]->{Filename} = $_[1] : $_[0]->{Filename} } 
sub buffer { $_[1] ? $_[0]->{Buffer} = $_[1] : $_[0]->{Buffer} } 
sub eof { $_[1] ? $_[0]->{Eof} = $_[1] : $_[0]->{Eof} } 
sub eor { $_[1] ? $_[0]->{EOR} = $_[1] : $_[0]->{EOR} } 

sub error {			# not used
  my($self, $message) = @_;
  my $atline = $.;
  my $infile = $self->{Filename};
}
#################################################################################
# interface must change if you want to write: $self->$1($1, $2);
# $self->$control($control, $arg, 'start');
# I'll certainly redefine this in a next release
my $DO_ON_CONTROL = \%RTF::Control::do_on_control; # default
sub control_definition {
  my $self = shift;
  if (@_) {
    if (ref $_[0]) {
      $DO_ON_CONTROL = shift;
    } else {
      die "argument of control_definition() method must be an HASHREF";
    }
  } else {
    $DO_ON_CONTROL;
  }
}
{ package RTF::Action;		
  use RTF::Config;

  use vars qw($AUTOLOAD);
  my $default = $LOG_FILE ?	# or define a __DEFAULT__ action in %do_on_control
    sub { $RTF::Control::not_processed{$_[1]}++ } : 
      sub {};
  my $sub;

  sub AUTOLOAD {
    #my $self = $_[0];
    #print STDERR "definition of the '$AUTOLOAD' sub\n";

    $AUTOLOAD =~ s/^.*:://;	
    no strict 'refs';
    if (defined ($sub = $DO_ON_CONTROL->{"$AUTOLOAD"})) {
      # Generate on the fly a new method and call it
      #*{"$AUTOLOAD"} = $sub; &{"$AUTOLOAD"}(@_); 
      # in the OOP style: *{"$AUTOLOAD"} = $sub; $self->$AUTOLOAD(@_);
      #goto &{*{"$AUTOLOAD"} = $sub}; 
    } else {
      #goto &{*{"$AUTOLOAD"} = $default};	
      $sub = $default;
    }
    *$AUTOLOAD = $sub; 
    goto &$sub; 
  }
}
sub DESTROY {}
#################################################################################
				# parser's API
sub parse_start {}
sub parse_end {}
sub group_start {}
sub group_end {}
sub text {}
sub char {}
sub unicodechar {}
sub symbol {}
sub bitmap {}
sub binary {}			

#################################################################################
				# Parser
# RTF Specification
# The delimiter marks the end of the RTF control word, and can
# be one of the following:
# 1. a space. In this case, the space is part of the control word
# 2. a digit or an hyphen, ...
# 3. any character other than a letter or a digit
# 
my $CONTROL_WORD = '[a-zA-Z]{1,32}'; # or '[a-z]+';
my $CONTROL_ARG = '(?:\d+|-\d+)'; # argument of control words, or: '-?\d+';
my $END_OF_CONTROL = '(?:[ ]|(?=[^a-z0-9]))'; 
my $CONTROL_SYMBOLS = q![-_~:|{}*\'\\\\]!; # Symbols (Special characters)
my $DESTINATION = '[*]';	
my $UNICODECHAR = '-?[0-9]{2,4}';
				# Another possibility: (?:[^\\\\{}]+|\\\\.)+
				# the following accepts the null string:
my $DESTINATION_CONTENT = '[^\\\\{}]*(?:\\\\.[^\\\\{}]*)*'; 
my $HEXA = q![0-9abcdef][0-9abcdef]!;
my $PLAINTEXT = '[^{}\\\\\n\r]+'; 
my $BITMAP_START = '\\\\{bm(?:[clr]|cwd) '; # Ex.: \{bmcwd 
my $BITMAP_END = q!\\\\}!;
my $BITMAP_FILE = '(?:[^\\\\{}]+|\\\\[^{}])+'; 

sub parse {
  my $self = shift;
  my $buffer = $self->{Buffer};
  my $guard = 0;
  
  my $wasunicodechar = 0;
  
  $$buffer =~ s/[\n\r]//gso;
  $self->parse_start();		# Action before parsing
  while (1) {
    $$buffer =~ s/^\\u($UNICODECHAR)(\\\'$HEXA|$END_OF_CONTROL.|$)//o and do {
      my $lim = $2;
      $self->unicodechar($1);
      $wasunicodechar = $lim !~ /\\\'$HEXA/;
      next;
    };
    $$buffer =~ s/^\\($CONTROL_WORD)($CONTROL_ARG)?($END_OF_CONTROL|\Z)//o and do {
      my ($control, $arg) = ($1, $2);
      $arg = '' unless defined($arg);
      no strict 'refs';		
      &{"RTF::Action::$control"}($self, $control, $arg, 'start');
      next;
    };
    $$buffer =~ s/^($PLAINTEXT)//o and do {
      $self->text($1);
      next;
    };
    $$buffer =~ s/^\{\\$DESTINATION\\(($CONTROL_WORD)($CONTROL_ARG)?)($END_OF_CONTROL|\Z)//o and do { 
      # RTF Specification: "discard all text up to and including the closing brace"
      # Example:  {\*\controlWord ... }
      # '\*' is an escaping mechanism

      if (defined $DO_ON_CONTROL->{$2}) { # if it's a registered control then don't skip
	$$buffer = "\{\\$1" . $$buffer;
      } else {			# skip!
	my $level = 1;
	my($control, $arg) = ($2, $3);
	my $content = "\{\\*\\$1";
	$self->{Start} = $.;		# could be used by the error() method
	while (1) {
	  $$buffer =~ s/^\{// and do {
	    $content .= "\{";
	    ++$level;
	    next;
	  };
	  $$buffer =~ s/^\}// and do { # 
	    $content .= "\}";
	    --$level > 0 ? next : last;
	  };
	  $$buffer =~ s/^($DESTINATION_CONTENT)//o and do {
	    if ($1 ne '') {
	      $content .= $1;
	      next;
	    }
	  };
	  if ($$buffer eq '') {
	    $self->if_data_needed() 
	      or die "unexpected end of data: unable to find end of destination"; 
	  } else {
	    die "unable to analyze '$$buffer' in destination";
	  }
	}
	no strict 'refs';		
	$arg = '' unless defined($arg);
	&{"RTF::Action::*$control"}($self, '*' . "$control", $arg, $content);
      }
      next;
    };
    $$buffer =~ s/^\{(?!\\[*])// and do { # can't be a destination
      $self->group_start();
      next;
    };
    $$buffer =~ s/^\}// and do {		# 
      $self->group_end();
      next;
    };
    $$buffer =~ s/^$BITMAP_START//o and do { # bitmap filename
      my $filename;
      do {
	$$buffer =~ s/^($BITMAP_FILE)//o;
	$filename .= $1;
	
	if ($$buffer eq '') {
	  $self->if_data_needed()  or die "unexpected end of data"; 
	}

      } until ($$buffer =~ s/^$BITMAP_END//o);
      $self->bitmap($filename);
      next;
    };
    $$buffer =~ s/^\\\'($HEXA)//o and do {
      if ($wasunicodechar) {
	$wasunicodechar = 0;
      } else {
	$self->char($1);	
      }
      next;
    };
    $$buffer =~ s/^\\($CONTROL_SYMBOLS)//o and do {
      $self->symbol($1);
      next;
    };
    $$buffer =~ s/^[\n\r]+$//;
    if ($self->if_data_needed()) {
      $$buffer =~ s/[\n\r]//gso;
      next;
    }

    # can't goes there, except one time at EOF
    last if $guard++ > 0;	
  }
				# could be in parse_end()
  if ($$buffer ne '') {  
    my $data = substr($$buffer, 0, 100);
    die "unanalized data: '$data ...' at line $. file $self->{Filename}\n";  
  }
				# 
  $self->parse_end();		# Action after
  $self;
}
sub read {			# by line
  my $self = $_[0];
  my $FH = $self->{Filehandle};
  if (${$self->{Buffer}} .= <$FH>) {
    1;
  } else {
    $self->{Eof} = 1;
    0;
  }
}
use constant READ_BIN => 0;
sub read_bin {
  my $self = shift;
  my $length = shift;
  print STDERR "need to read $length chars\n" if READ_BIN;
  my $bufref = $self->{Buffer};
  my $fh = $self->{Filehandle};
  my $binary = $$bufref . $self->{Strimmed};
  my $toread = $length - length($binary);
  print STDERR "data to read: $toread\n" if READ_BIN;
  if ($toread > 0) {
    my $n = CORE::read($fh, $binary, $toread, length($binary));
    print STDERR "binary data: $n chars\n" if READ_BIN;
    unless ($toread == $n) {
      die "unable to read binary data\n";
    }
  } else {
    $binary = substr($$bufref, 0, $length);
    substr($$bufref, 0, $length) = '';
  }
  $self->binary($binary);	# and call the binary() method
}
1;
__END__


