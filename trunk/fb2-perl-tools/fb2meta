#!/usr/bin/perl

our $VERSION=0.02;
use strict;

=head1 NAME

fb2meta - manipulate meta information of FictionBook files collection

=head1 SYNOPSIS

B<fb2meta> B<list> [B<-t>|B<-f>I<pattern>] [I<directory>...]

B<fb2meta> B<export> I<format> [I<directory>...]

B<fb2meta> B<uniq> [-c] I<attribute> [I<directory>...]

B<fb2meta> B<rename> [B<-z>] I<pattern>   [I<directrory>...]

B<fb2meta> B<update> [B<-s>] I<attribute>=I<value>  I<files...>

B<fb2meta> B<fix> I<attribute> I<filename> [I<directory>...]

B<fb2meta> B<find> [B<-0>] I<expression> [I<directory>...]

=cut


sub HELP_MESSAGE {
  print "fb2meta list [-t|-f pattern] [directory...]\n",
  "fb2meta uniq [-c] attribute [directory...]\n",
  "fb2meta rename [-z] pattern [directory...]\n",
  "fb2meta find [-0] expression [directory...]\n",
  "fb2meta update [-s] attribute=value [-s attribute=value...] files..\n",
  "fb2meta fix attribute substtable [directory...]\n";
  exit(1);
}



=head1 DESCRIPTION

B<fb2meta> operates on metainformation of the collection of FictionBook
files. It is able to operate on uncompressed, zip-compressed and
gzip-compressed files.

By default it outputs listing of all supported files in XML format.

If directory is not specified, current one is used. For update command,
which expect list of files, rather than directory, omitting file names
produces an error.

=head1 COMMANDS

=over 4

=item B<list>

Outputs more or less complete metainformation for all FB2 files in given
directory(ies) to stdout.
Following formats of listing are supported

=over 8

=item default

By default XML document with root element B<Library> is produced.
It contains B<book> element for each file found. This element has two
attributes B<href> which contain relative path to file and
optional B<compression>, which can have value B<zip> or B<gzip>. Content
of this element is subset of FictionBook B<title-info> element.

=item B<-t>

This option causes B<fb2meta> to output tab-separated listing which can
be imported into spreadsheet or database. First line contains column
headings. If book have several authors, they are comma-separated.

=item B<-f>I<pattern>

Uses printf-like format to format output. See B<FORMAT STRING> below.

=back

=item B<export>

Export books metadata from all files in given directory(ies) to external collection.

Supported formats:

=over 8

=item B<tellico>

Export to Tellico book collection.

Tellico is a collection manager for KDE (http://www.periapsis.org/tellico/).

=item B<onix>

Export to ONIX format.

ONIX (http://www.editeur.org/onix.html) is an XML format for representing
and communicating book industry product information, primarily for book vendors.

=back

=item B<uniq>

Produces list of unique values of specified attribute from all files in
the given directory(ies) See
B<ATTRIBUTES> below for syntax of attribute specification. If B<-c>
option is specified, than value preceeded by count of occurences.

=item B<rename>

Renames files according to pattern. See B<FORMAT STRING> below for
syntax of pattern string. If B<-z> option is specified, than
for zip-compressed file, filename in the archive is changed as well as
filename of archive itself.

=item B<update>

Updates attributes in the given list of files, setting them to specified
value. If only one I<attribute>=I<value> expression is used, than it can
be specified without additional options. Otherwise it should be
preceeded by B<-s> switch (just like B<-e> in B<sed>(1)).

See B<ATTRIBUTES> below for list of suppoted attributes.

Values for all attributes are treated literally. For B<sequence.num>
attribute special value B<#> is supported, which is expanded to
sequentual number of the processed file. So, you can use command

  fb2meta update -s sequence="Some cool serial" -s sequence.num=# file1 file2 file3

and file1 would be number 1 in this sequence, file2 - number2 etc.

=item B<fix>

Updates given attribute in the directory tree(s) according to file of
search/replace pairs. File should contain two values, separated by colon
on each line - original (as prodiced by appropriate B<uniq> command) and
new. Lines without colon are ignored, so file, produced by B<uniq>
command can be used with minimal editing.

=item B<find>

Produce listing of files, which match given expression.
By default, prints one filename per line. If B<-0> option is specified,
file names are separated by '\0' symbol (suitable for B<xargs -0>).

Expression could contain condition on attributes, combined by AND and OR
operators.

For attributes which has multiple values several expressions which seems
to be mutually exclusive can be specified. For example

  author="Anne McCaffree" and not author="Elisabeth Scarborro"

means "Find the books by Anne McCaffree, which are not coauthored by
Elisabeth Scarrboro".

Note subtle difference in the semanic of not = and != for multi-valued
attributes:

= means "There exist at least one value equal to...". not = is logical
negation of "=" - "There exist no value equal to"

!= means "There exist at least one value not equal to..".

If only first and last name of author are specified, any author with
same first and last name, regardless of middle_name value is considered
matching. Use two spaces between first and last name if you want author
with empty middle name.

Apart from condition, predicate B<exists> I<attribute> can be used for
attributes which are allowed to absent.

=back

=head1 FORMAT STRING

=over 4

=item B<%f>

Original file name

=item B<%A>

Author name (first middle last). If there is multiple authors,
name of one which first mentioned in the file would be used.

=item B<%a>

Author name (first last).


=item B<%t>

Translator name.

=item B<%T>

Title.

=item B<%s>

Sequence name. If book belongs to no sequence, and you use sequence name
as path component (say %a/%s/%T.%x), book would be put on the upper
level along with subdirectories of the sequences.

=item B<%n>

Number in the sequence.

=item B<%x>

File extension. Would be B<.fb2> for uncompressed, B<.fb2.zip> for
zip-compressed and B<.fb2.gz> for gzip-compressed files.

=item B<%l>

Book language (language it would be read on).

=item B<%L>

Book source language (language it was written on).

=item B<%d>

Date of writing. Note that FB2 format allows arbitrary text in this
element, so sorting on this field probably wouldn't yield expected
results.

=item B<%g>

Genre.

=back

=head1 ATTRIBUTES

Commands which require attribute name recognize following attribute
names:

=over 4

=item B<author>

Name of author. Value of this attribute is constrcted from values
of B<first-name>, B<middle-name> and B<last-name> from FB2 B<author>
element, separated by space.  There can be several authors of one book.

=item B<author.last-name>

Last name of author.

=item B<author.first-name>

First name of author.

=item B<author.middle-name>

Middle name of author.

=item B<title>

Value of B<book-title> element.

=item B<sequence>

Value of the B<name> attribute of B<sequence> element.

=item B<sequence.num>

Value of B<num> attribute of B<sequence> element.

=item B<genre>

Genre.

=item B<translator>

Person, who translated book to the B<lang>. Follows same rules as
B<author>.

=item B<lang>

Language of the text in the file. (Language on which book can be read).

=item B<src-lang>

Language on which book was originally written by its author(s).

=item B<date>

Date of writing. Note that authors of past centuries were quite lossy
specifying date of writing. It may be year, year and month or  even
range of years.

=back




=head1 BUGS

Output always goes to STDOUT in the current locale encoding, although
XML declaration for XML listing says UTF-8.

Some options are not implemented yet.

=head1 AUTHOR

Victor Wagner <vitus@wagner.pp.ru>

=cut

use File::Find;
use File::Copy;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Compress::Zlib;
use XML::Parser;
use Data::Dumper;
use Getopt::Std;
use I18N::Langinfo qw(langinfo CODESET);
use vars qw($opt_c $opt_t $opt_f $opt_z);
use XML::Writer;
use Encode;
use Locale::Language;
#
# XML parsing block
#
our($context,$ref,$aref);
our %metainfo;

#
# Clear parsed data from previous file
#
sub parse_init {
   our $context = "";
   our %metainfo = ();
}
#
# Process element start. Accumulate path from root in the $context
# and if path matches some actual metainfo tag, set $ref variable to
# reference of the desired element of %metainfo
#
sub parse_start {
	my ($handle,$element,%attrs) = @_;
	our $context .= "/$element";
	if ($context eq '/FictionBook/description/title-info/book-title') {
		$metainfo{'Title'} = "";
		$ref = \$metainfo{'Title'}
	}
	if ($context eq "/FictionBook/description/title-info/genre") {
	 push @{$metainfo{"genre"}},"";
	 $ref= \$metainfo{"genre"}[$#{$metainfo{"genre"}}];
	}
	if ($context eq "/FictionBook/description/title-info/sequence") {
	 $metainfo{sequence}={$attrs{"name"},$attrs{"number"}};
	}
	if ($context eq "/FictionBook/description/title-info/date"||
	    $context eq "/FictionBook/description/title-info/lang"||
		$context eq "/FictionBook/description/title-info/src-lang") {
		$metainfo{$element} = "";
		$ref =\$metainfo{$element};
	}
	if ($context eq "/FictionBook/description/title-info/author") {
		$aref = {};
		push @{$metainfo{author}},$aref;
	}
	if ($context =~ m!/FictionBook/description/title-info/author/.*!) {
		$aref->{$element} = "";
		$ref = \$aref->{$element};
	}
	if ($context eq "/FictionBook/description/title-info/translator") {
		$aref = {};
		push @{$metainfo{translator}},$aref;
	}
	if ($context =~ m!/FictionBook/description/title-info/translator/.*!) {
		$aref->{$element} = "";
		$ref = \$aref->{$element};
	}

}
#
# Parse characer data. If $ref is defined, store them there, otherwise
# just ignore
#
sub parse_char {
    my ($handle,$string) = @_;
	$string =~ s/\s+/ /g;
	if ($ref) {
		$$ref .=$string;
	}
}
#
# Process end of element - remove last element from path and undefine
# $ref
#
sub parse_end {
	my ($handle,$element) = @_;
	undef $ref;
	$context =~s!/[^/]*$!!;
}
#
# Subroutine reference for procedure to process parsed data, accumulated
# in the %metainfo
#
our $output;
#
# Process read file header - parse XML, fill %metainfo,
# add filename and compression type there, and than call whatever
# is referenced by $output
#

sub process {
  my ($filename,$type,$header) = @_;
  our $filenameencoding;
  my $parser = XML::Parser->new(Handlers=> {Start =>\&parse_start,
  End=>\&parse_end,
  Char =>\&parse_char,
  Init =>\&parse_init,});
  eval {
  $parser->parse($header);
  };
  if ($@) {
  	print STDERR "$filename:$@\n";
	return;
  }
  $metainfo{filename} = decode($filenameencoding,$filename);
  $metainfo{type} = $type;
  $output->();
}
#
# Debugging output routine. Just dump %metainfo with Data::Dumper
#
sub debug_output {
  print Data::Dumper->Dump([\%metainfo],["\%metainfo"]);
}
#
# Output tab-separated data (for -t option)
#

sub tabsep_output {
	print $metainfo{'filename'},"\t",$metainfo{'type'},"\t",
	join(", ",
	  map($_->{'first-name'}." ".$_->{'middle-name'}." ".$_->{'last-name'},
	  	@{$metainfo{'author'}})),"\t",
	  $metainfo{'Title'},"\t",join(", ",@{$metainfo{genre}}),
	  "\t",$metainfo{'date'},"\t",$metainfo{'lang'},"\t",$metainfo{'src-lang'},"\t",($metainfo{sequence}?join("\t",%{$metainfo{sequence}}):""),"\n";

}
#
# Output xml element
#
sub simple_element {
	my ($writer,$element,$content) = @_;
	$writer->startTag($element);
	$writer->characters($content);
	$writer->endTag;
}
our $xmlwriter;

sub xml_output {
	$xmlwriter->startTag("book", "href"=>$metainfo{'filename'},
	 ($metainfo{'type'} ne "fb2"?("compression"=>$metainfo{'type'}):()));
	simple_element($xmlwriter,"book-title",$metainfo{'Title'});
	foreach my $person ("author","translator") {
		foreach my $a (@{$metainfo{$person}}) {
			$xmlwriter->startTag($person) ;
			foreach my $name ("first-name","middle-name","last-name") {
				if (exists $a->{$name}) {
					simple_element($xmlwriter,$name,$a->{$name});
				}
			}
			$xmlwriter->endTag();
		}
	}
	simple_element($xmlwriter,"date",$metainfo{'date'});
	simple_element($xmlwriter,"lang",$metainfo{'lang'});
	simple_element($xmlwriter,"src-lang",$metainfo{'src-lang'});
	foreach my $g (@{$metainfo{genre}}) {
		simple_element($xmlwriter,"genre",$g);
	}
	if (defined $metainfo{sequence}) {
		my ($seqname,$num) = %{$metainfo{sequence}};
		$xmlwriter->emptyTag("sequence","name"=>$seqname,(defined
		$num?("number"=>$num):()));
	}
	$xmlwriter->endTag();
}

our %genres_transfer = ();
sub read_genres {
	my ($lang) = @_;
	my ($genre,$title);
	my $parser = XML::Parser->new(Handlers=> {
		Start => sub {
			my ($handle,$element,%attrs) = @_;
			if ($element eq 'subgenre') {
				$genre = $attrs{'value'};
				$title = undef;
			}
			elsif ($element eq 'genre-descr') {
				$genres_transfer{$genre} = $title = $attrs{'title'} if ($attrs{'lang'} eq $lang);
			}
			elsif ($element eq 'genre-alt') {
				$genres_transfer{$attrs{'value'}} = $title;
			}
		}
	});
	$parser->parsefile('genres_transfer.xml');
}

sub conv_lang {
	return code2language($_[0]) || $_[0];
}

sub format_name1 {
	my $s = $_->{'last-name'};
	if (exists $_->{'first-name'}) {
		$s .= ', '.$_->{'first-name'};
		if (exists $_->{'middle-name'}) {
			$s .= ' '.$_->{'middle-name'};
		}
	}
	return $s;
}
sub tellico_output {
	our %genres_transfer;
	$xmlwriter->startTag('entry');
	simple_element($xmlwriter,'title',$metainfo{'Title'});
	foreach my $person ('author','translator') {
		$xmlwriter->startTag(${person}.'s') ;
		foreach (@{$metainfo{$person}}) {
			simple_element($xmlwriter,$person,format_name1($_));
		}
		$xmlwriter->endTag();
	}
	simple_element($xmlwriter,'date',$metainfo{'date'});
	simple_element($xmlwriter,'language',conv_lang($metainfo{'lang'}));
	simple_element($xmlwriter,'orig_language',conv_lang($metainfo{'src-lang'}));
	$xmlwriter->startTag('genres');
	my @genres = @{$metainfo{'genre'}};
	@genres = keys %{{map { $genres_transfer{$_} || "?$_" => ''} @genres}};
	foreach my $g (@genres) {
		simple_element($xmlwriter,'genre',$g);
	}
	$xmlwriter->endTag();
	if (defined $metainfo{sequence}) {
		my ($seqname,$num) = %{$metainfo{sequence}};
		simple_element($xmlwriter,'series',$seqname);
		if (defined $num) {
			simple_element($xmlwriter,'series_num',$num);
		}
	}
	simple_element($xmlwriter,'url',$metainfo{'filename'});
	$xmlwriter->endTag();
}

sub check_pattern {
	my $specifier = shift;
	if (index("AatTsnxlLdgf%",$specifier)==-1) {
		die ("Invalid format specifier \%$specifier\n");
	};
	return "\%$specifier";
}

sub interpret_pattern {
	our %metainfo;
	my $specifier = shift;
	if ($specifier eq 'A') {
		return join(", ",
	  map($_->{'first-name'}." ".$_->{'middle-name'}." ".$_->{'last-name'},
	  	@{$metainfo{'author'}}))

	} elsif ($specifier eq 'a') {
		return join(", ",
	  map($_->{'first-name'}." ".$_->{'last-name'},
	  	@{$metainfo{'translator'}}))
	} elsif ($specifier eq 't') {
		return join(", ",
	  map($_->{'first-name'}." ".$_->{'middle-name'}." ".$_->{'last-name'},
	  	@{$metainfo{'translator'}}))
	} elsif ($specifier eq 'T') {
		return $metainfo{'Title'};
	} elsif ($specifier eq 's') {
		return join(" ",keys %{$metainfo{sequence}});
	} elsif ($specifier eq 'n') {
		return join(" ",values %{$metainfo{'sequence'}});
	} elsif ($specifier eq 'l') {
		return $metainfo{'lang'};
	} elsif ($specifier eq 'L') {
		return $metainfo{'src-lang'};
	} elsif ($specifier eq 'd') {
		return $metainfo{'date'};
	} elsif ($specifier eq 'x') {
		return '.fb2.zip' if ($metainfo{'type'} eq 'zip');
		return '.fb2.gz' if ($metainfo{'type'} eq 'gzip');
		return '.fb2';
	} elsif ($specifier eq 'g') {
		return join(',',@{$metainfo{'genre'}});
	} elsif ($specifier eq 'f') {
		return $metainfo{'filename'};
 	} elsif ($specifier eq '%') {
		return '%';
	}
}

sub bs_escape {
  my $sym = shift;
  my %escapes = ('n'=>"\n",'r'=>"\r",'b'=>"\b",'a'=>"\a","\\"=>"\\");
  if (exists $escapes{$sym}) {
  	return $escapes{$sym}
  } else {
  	return $sym;
  }
}

sub set_pattern {
	my $pat = shift;
	$pat =~ s/%(.)/check_pattern($1)/ge;
	$pat =~ s/\\(.)/bs_escape($1)/ge;
	our $pattern = $pat;
}

sub format_string {
	our $pattern;
	my $str = $pattern;
	$str =~s/%(.)/interpret_pattern($1)/ge;
	return $str;
}

sub formatted_output {
	print format_string();
}
sub do_list {
	our $encoding;
	getopts("tf:");
	if ($opt_t) {
		print
		join("\t","filename","compr","author(s)","title","genre","date",
		"lang","src-lang","sequence","num"),"\n";
		scan_tree(\&tabsep_output)
	} elsif ($opt_f) {
		set_pattern($opt_f);
		scan_tree(\&formatted_output);
	} else {
		our $xmlwriter = new XML::Writer(OUTPUT=> \*STDOUT,DATA_MODE=>1,
		DATA_INDENT=>2);
		$xmlwriter->xmlDecl($encoding);
		$xmlwriter->startTag("Library");
		scan_tree( \&xml_output);
		$xmlwriter->endTag();
		$xmlwriter->end();
	}
}

sub do_export {
	our $format = shift @ARGV;
	if ($format eq 'tellico') {
		do_export_tellico();
	} elsif ($format eq 'onix') {
		do_export_onix();
	} else {
		die ("Invalid format $format\n");
	}
}

sub do_export_tellico {
	read_genres('en');
	our $encoding;
	our $xmlwriter = new XML::Writer(OUTPUT=> \*STDOUT,DATA_MODE=>1, DATA_INDENT=>2);
	$xmlwriter->xmlDecl($encoding);
	$xmlwriter->startTag('tellico', 'xmlns'=>'http://periapsis.org/tellico/', 'syntaxVersion'=>'9');
	$xmlwriter->startTag('collection', 'title'=>'My Fiction Books', 'type'=>'2');
	$xmlwriter->startTag('fields');
	$xmlwriter->emptyTag('field','flags'=>'8', 'title'=>'Title', 'category'=>'General', 'format'=>'1', 'type'=>'1', 'name'=>'title');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Subtitle', 'category'=>'General', 'format'=>'1', 'type'=>'1', 'name'=>'subtitle');
	$xmlwriter->emptyTag('field','flags'=>'7', 'title'=>'Author', 'category'=>'General', 'format'=>'2', 'type'=>'1', 'name'=>'author');
	$xmlwriter->emptyTag('field','flags'=>'7', 'title'=>'Translator', 'category'=>'General', 'format'=>'2', 'type'=>'1', 'name'=>'translator');
	$xmlwriter->emptyTag('field','flags'=>'2', 'title'=>'Binding', 'category'=>'General', 'allowed'=>'Hardback;Paperback;Trade Paperback;E-Book;Magazine;Journal', 'format'=>'4', 'type'=>'3', 'name'=>'binding');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Purchase Date', 'category'=>'General', 'format'=>'3', 'type'=>'1', 'name'=>'pur_date');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Purchase Price', 'category'=>'General', 'format'=>'4', 'type'=>'1', 'name'=>'pur_price');
	$xmlwriter->emptyTag('field','flags'=>'6', 'title'=>'Publisher', 'category'=>'Publishing', 'format'=>'0', 'type'=>'1', 'name'=>'publisher');
	$xmlwriter->emptyTag('field','flags'=>'4', 'title'=>'Edition', 'category'=>'Publishing', 'format'=>'0', 'type'=>'1', 'name'=>'edition');
	$xmlwriter->emptyTag('field','flags'=>'3', 'title'=>'Copyright Year', 'category'=>'Publishing', 'format'=>'4', 'type'=>'6', 'name'=>'cr_year');
	$xmlwriter->emptyTag('field','flags'=>'2', 'title'=>'Publication Year', 'category'=>'Publishing', 'format'=>'4', 'type'=>'6', 'name'=>'pub_year');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'ISBN#', 'category'=>'Publishing', 'format'=>'4', 'type'=>'1', 'name'=>'isbn', 'description'=>'International Standard Book Number');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'LCCN#', 'category'=>'Publishing', 'format'=>'4', 'type'=>'1', 'name'=>'lccn', 'description'=>'Library of Congress Control Number');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Pages', 'category'=>'Publishing', 'format'=>'4', 'type'=>'6', 'name'=>'pages');
	$xmlwriter->emptyTag('field','flags'=>'7', 'title'=>'Language', 'category'=>'Publishing', 'format'=>'4', 'type'=>'1', 'name'=>'language');
	$xmlwriter->emptyTag('field','flags'=>'7', 'title'=>'Original Language', 'category'=>'Publishing', 'format'=>'4', 'type'=>'1', 'name'=>'orig_language');
	$xmlwriter->emptyTag('field','flags'=>'7', 'title'=>'Genre', 'category'=>'Classification', 'format'=>'4', 'type'=>'1', 'name'=>'genre');
	$xmlwriter->emptyTag('field','flags'=>'7', 'title'=>'Keywords', 'category'=>'Classification', 'format'=>'4', 'type'=>'1', 'name'=>'keyword');
	$xmlwriter->emptyTag('field','flags'=>'6', 'title'=>'Series', 'category'=>'Classification', 'format'=>'4', 'type'=>'1', 'name'=>'series');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Series Number', 'category'=>'Classification', 'format'=>'4', 'type'=>'6', 'name'=>'series_num');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Condition', 'category'=>'Classification', 'allowed'=>'New;Used', 'format'=>'4', 'type'=>'3', 'name'=>'condition');
	$xmlwriter->emptyTag('field','flags'=>'1', 'title'=>'URL', 'category'=>'Personal', 'format'=>'4', 'type'=>'7', 'name'=>'url');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Signed', 'category'=>'Personal', 'format'=>'4', 'type'=>'4', 'name'=>'signed');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Read', 'category'=>'Personal', 'format'=>'4', 'type'=>'4', 'name'=>'read');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Gift', 'category'=>'Personal', 'format'=>'4', 'type'=>'4', 'name'=>'gift');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Loaned', 'category'=>'Personal', 'format'=>'4', 'type'=>'4', 'name'=>'loaned');
	$xmlwriter->startTag('field','flags'=>'2', 'title'=>'Rating', 'category'=>'Personal', 'format'=>'4', 'type'=>'14', 'name'=>'rating');
	$xmlwriter->startTag('prop', 'name'=>'maximum'); $xmlwriter->characters('5'); $xmlwriter->endTag();
	$xmlwriter->startTag('prop', 'name'=>'minimum'); $xmlwriter->characters('1'); $xmlwriter->endTag();
	$xmlwriter->endTag();
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Front Cover', 'category'=>'Front Cover', 'format'=>'4', 'type'=>'10', 'name'=>'cover');
	$xmlwriter->emptyTag('field','flags'=>'0', 'title'=>'Comments', 'category'=>'Comments', 'format'=>'4', 'type'=>'2', 'name'=>'comments');
	$xmlwriter->endTag();
	scan_tree( \&tellico_output);
	$xmlwriter->endTag();
	$xmlwriter->endTag();
	$xmlwriter->end();
}

sub onix_output {
	our $recordReference;
	$xmlwriter->startTag('Product');
	simple_element($xmlwriter,'RecordReference',$recordReference++);
	simple_element($xmlwriter,'NotificationType','03');
# 	simple_element($xmlwriter,'RecordSourceName','fb2meta');
	simple_element($xmlwriter,'ISBN',''); # TODO
	simple_element($xmlwriter,'ProductForm','DG'); # Electronic book text
	simple_element($xmlwriter,'DistinctiveTitle',$metainfo{'Title'});
	foreach (@{$metainfo{'author'}}) {
		$xmlwriter->startTag('Contributor');
		simple_element($xmlwriter,'ContributorRole','A01'); # By (author)
		simple_element($xmlwriter,'PersonName',format_name1($_));
		$xmlwriter->endTag();
	}
	foreach (@{$metainfo{'translator'}}) {
		$xmlwriter->startTag('Contributor');
		simple_element($xmlwriter,'ContributorRole','B06'); #Translated by
		simple_element($xmlwriter,'PersonName',format_name1($_));
		$xmlwriter->endTag();
	}
	simple_element($xmlwriter,'PublisherName',''); # TODO
	$xmlwriter->endTag();
}

sub do_export_onix {
	our $recordReference = 0;
	our $encoding;
	our $xmlwriter = new XML::Writer(OUTPUT=> \*STDOUT,DATA_MODE=>1, DATA_INDENT=>2);
	$xmlwriter->xmlDecl($encoding);
	$xmlwriter->startTag('ONIXMessage');
	$xmlwriter->startTag('Header');
	simple_element($xmlwriter,'SentDate',''); # TODO
# 	simple_element($xmlwriter,'MessageNote','');
	$xmlwriter->endTag();
	scan_tree( \&onix_output);
	$xmlwriter->endTag();
	$xmlwriter->end();
}

#
#  Accumulate author names in the hash instead of outputting
#
our %attrlist;
our $attribute;
sub attrlist_output {
	our $attribute;
	if ($attribute eq 'author' || $attribute eq 'translator') {
		foreach my $a (@{$metainfo{$attribute}}) {
			$attrlist{join("|",$a->{'last-name'},$a->{'first-name'},$a->{'middle-name'})}++;
		}
	} elsif ($attribute eq 'book-title' || $attribute eq 'title') {
		$attrlist{$metainfo{'Title'}}++;
	} elsif ($attribute eq 'genre') {
		foreach my $a (@{$metainfo{$attribute}}) {
			$attrlist{$a}++;
		}
	} elsif ($attribute eq 'sequence') {
		foreach my $a (keys %{$metainfo{'sequence'}}) {
			$attrlist{$a}++;
		}
	} elsif ($attribute eq 'sequence.num') {
		foreach my $a (values %{$metainfo{'sequence'}}) {
			$attrlist{$a} ++;
		}
	} elsif ($attribute =~ /(\w+)\.(\w+)/) {
		foreach my $a (@{$metainfo{$1}}) {
			$attrlist{$a->{$2}} ++;
		}
	} else {
		$attrlist{$metainfo{$attribute}}++;
	}
	progress();
}

sub fix_format {
	our $attribute;
	my $key = shift;
	my ($l,$f,$m);
	if ($attribute eq 'author' || $attribute eq 'translator') {
		($l,$f,$m) = split(/\|/,$key);
		return "$f $m $l";
	} else {
		return $key;
	}
}

sub do_uniq {
	getopts("c");
	select STDERR;
	$|=1;
	select STDOUT;
	our $attribute = shift @ARGV;
	scan_tree(\&attrlist_output);
	print STDERR "\r"," "x78,"\r";
	if ($opt_c) {
		foreach my $key (sort {$attrlist{$a} <=> $attrlist{$b}|| $a cmp $b}
		   keys(%attrlist)) {

		   printf "%5d %s\n",$attrlist{$key},fix_format($key);
		}
	} else {
		foreach my $key (sort keys(%attrlist)) {
			print fix_format($key),"\n";
		}
	}
}


#
# Changes names of specified files accordingly to metainfo
#
sub rename_file {
    my $old_name = $metainfo{'filename'};
    my $new_name = format_string();
    unless (-e "$new_name") {
    move($old_name, $new_name) or die "Can't rename $old_name to $new_name: $!";
    } else {
        print "Can't rename $old_name to $new_name: file already exists!\n";
    }
}

sub do_rename {
	getopts("z");
	our $pattern = shift @ARGV;
    if($opt_z) {
        print "Option -z is not implemented yet!\n";
        exit 1;
    }
    set_pattern($pattern);
    scan_tree(\&rename_file);
}

#
# Accumulates new names made by specified format
#
sub format_rename {

}
#
# Main workhorse of directory traversal.
# Checks compression type, uncompresses file and cuts description tag.
#
sub check_file {
	return unless -f $_;
	my ($f,$magic);
	open $f,"<",$_;
	binmode $f,":bytes";
	read $f,$magic,3;
	my ($data,$type,$i);
	if ($magic eq "\x1f\x8b\x08") {
		seek $f,0,0;
		my $gz = gzopen($f,"r");
		$gz->gzread($data);
		return unless (substr($data,0,5) eq '<?xml');
		return unless (index($data,"<FictionBook")!=-1);
		while (($i = index($data,"</description>"))==-1) {
			my $d2;
			return if $gz->gzread($d2)<=0;
			$data .= $d2;
		}
		close $f;
		$type = "gzip"
	} elsif ($magic eq "PK\03") {
		close $f;
		my $zip = new Archive::Zip($_);
		if (!$zip) {
			print STDERR "\r$_ is broken ZIP archive\n";
			return;
		}
		my ($member) = $zip->members();
		$member->desiredCompressionMethod(COMPRESSION_STORED);
		$member->rewindData();
		my ($bytes,$status) = eval {$member->readChunk(4096);};
        unless (defined($bytes) && ($status == AZ_OK || $status == AZ_STREAM_END)) {
			print STDERR "\r$_ is broken: $@\n";
			$member->endRead();return;
		}
		$data = $$bytes;
		unless (substr($data,0,5) eq '<?xml' &&
		   index($data,"<FictionBook")!=-1) {
		   $member->endRead();
		   return;
		}
		while (($i = index ($data,"</description>"))==-1) {
			if ($status == AZ_STREAM_END) {
				$member->endRead();
				return;
			}
			($bytes,$status) = $member->readChunk(4096);
			if ($status != AZ_OK && $status != AZ_STREAM_END) {
				$member->endRead(); return;
			}
			$data .= $$bytes;
		}
		$member->endRead();
		$type = "zip";
	} elsif ($magic eq "<?x") {
		$type = "fb2";
		$data = $magic;
		while ( ($i = index($data,"</description>"))==-1)  {
			return unless read($f,$data,4096,length($data));
		}
		close $f;
	} else {
		return;
	}
	if ($i) {
	 process($File::Find::name,$type,substr($data,0,$i+length("</description>"))."</FictionBook>");
	}
#	return unless $head = $data =~m!^.*</document-info>!;
#	print "$_ ($type):\n$head\n";
}
sub progress {
	our $count;
	printf STDERR "\r%6d files processed",++$count;
}
#
# Scans tree of files using specified output procedure
#
sub scan_tree {
	our $output = shift;
	if (!@ARGV) {
		unshift @ARGV,".";
	}
	for my $dir (@ARGV) {
		find({no_chdir =>1, wanted=>\&check_file},$dir);
	}
}



#
# Main program
#

sub TBD {
 print STDERR "This functionality is not implemented yet\n";
 exit 1;
}

my %cmds=(
'list'=>\&do_list,
'export'=>\&do_export,
'find'=>\&TBD,
'update'=>\&TBD,
'uniq' => \&do_uniq,
'rename'=>\&do_rename,
'fix'=>\&TBD,
'help'=>\&HELP_MESSAGE
);

use open ":std";
use open ":locale";
our $encoding = lc(langinfo(CODESET));
our $filenameencoding = $ENV{G_FILENAME_ENCODING}||$encoding;

$output = \&tabsep_output;

if (!@ARGV) {
	HELP_MESSAGE();
} else {
	my $command = shift @ARGV;
	if (!exists $cmds{$command}) {
		print STDERR "Unknown command $command\n";
		HELP_MESSAGE();
	}
	$cmds{$command}();
}
