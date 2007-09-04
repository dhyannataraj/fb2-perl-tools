# Philippe Verdret 1998-1999
use strict;
package RTF::TEXT::Converter;

use RTF::Control;
@RTF::TEXT::Converter::ISA = qw(RTF::Control);

use constant TRACE => 0;
use constant LIST_TRACE => 0;
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

###########################################################################
my $N = "\n"; # Pretty-printing

				# you can split on sentences here if you want!!!
				# some output parameters
%do_on_event = 
  (
   'document' => sub {		# Special action
   },
				# Table processing
   'table' => sub {		# end of table
     if ($event eq 'end') {
     } else {
     }
   },
   'row' => sub {		# end of row
     if ($event eq 'end') {
       output "$text$N";
     } else {
				# not defined
     }
   },
   'cell' => sub {		# end of cell
     if ($event eq 'end') {
       output "$text$N";
     } else {
				# not defined
     }
   },
   'par' => sub {		# Default rule: if no entry for a paragraph style
				# Paragraph styles
     return output($text) unless $text =~ /\S/;
     output "$text$N";
   },
  );

###############################################################################
# If you have an &<entity>; in your RTF document and if
# <entity> is a character entity, you'll see "&<entity>;" in the RTF document
# and the corresponding glyphe in the HTML document
# How to give a new definition to a control registered in %do_on_control:
# - method redefinition (could be the purist's solution)
# - $Control::do_on_control{control_word} = sub {}; 
# - when %do_on_control is exported write:
$do_on_control{'ansi'} =	# callcack redefinition
  sub {
    # RTF: \'<hex value>
    # HTML: &#<dec value>;
    my $charset = $_[CONTROL];
    my $charset_file = $_[SELF]->application_dir(__FILE__) . "/$charset";
    open CHAR_MAP, "$charset_file"
      or die "unable to open the '$charset_file': $!";

    my %charset = (		# general rule
		   map({ sprintf("%02x", $_) => "&#$_;" } (0..255)),
				# and some specific defs
		   map({ s/^\s+//; split /\s+/ } (<CHAR_MAP>))
		  );
    *char = sub { 
      output $charset{$_[1]}
    } 
  };

				# symbol processing
				# RTF: \~
				# named chars
				# RTF: \ldblquote, \rdblquote
$symbol{'~'} = '&nbsp;';
$symbol{'tab'} = ' ';
$symbol{'ldblquote'} = '"';
$symbol{'rdblquote'} = '"';
$symbol{'line'} = "\n";
sub symbol {			
  if (defined(my $sym = $symbol{$_[1]}))  {
    output $sym;
  } else {
    output $_[1];		# as it
  }
}

1;
__END__
