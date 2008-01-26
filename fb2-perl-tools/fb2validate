#!/usr/bin/perl

use strict;
use XML::LibXML;
use Getopt::Long qw(HelpMessage VersionMessage);
our $VERSION=0.01;

=head1 NAME

fb2validate - Checks if the file is a valid fb2-book

=head1 SYNOPSIS

B<fb2validate> I<filename.fb2>

=head1 DESCRIPTION

This utility allows to check if the file is a valid fb2-book.

If the check were successful it will print "This book is a valid fb2-book" message, 
otherwise you will get list of wrong xml-elements.

=head1 BUGS

fb2validate does not show line numbers of wrong elements. To get error messages with line numbers it is better 
to use B<xmllint> utility:

xmllint --noout --schema SCHEMA2.1/FictionBook2.1.xsd I<file_name>

=head1 AUTHOR

Nikolay Shaplov <n@shaplov.ru>

=head1 VERSION

0.01

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Nikolay Shaplov

This library is free software; you can redistribute it and/or modify
it under the terms of the General Public License (GPL).  For
more information, see http://www.fsf.org/licenses/gpl.txt

=cut

my $opts={};
GetOptions(
	help                => sub {HelpMessage(); },
	version             => sub {VersionMessage(); },
	    #    "keyword|w=s"      => \$opts->{'keyword'},
#    "use-number|n"     => \$opts->{'use_number'},
	  );

my $file_name = $ARGV[0];
my $doc;
		  
if ($file_name)
{
  $doc = _parse_file($file_name);
} else
{
  $doc = _parse_stdin();
}
				    
my $xmlschema = XML::LibXML::Schema->new( location =>'XSD/FB2.1/FictionBook2.1.xsd');
$xmlschema->validate($doc);
 
print "This book is a valid fb2-book\n";	


sub _parse_file
{
  my $file_name=shift;
  my $parser = XML::LibXML->new();
    
  my $doc = $parser->parse_file($file_name);
  return $doc;
}
	
sub _parse_stdin
{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_fh(\*STDIN);
  return $doc;
}
	      