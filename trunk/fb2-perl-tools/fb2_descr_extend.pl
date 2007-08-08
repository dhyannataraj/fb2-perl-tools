#!/usr/bin/perl

use fb2::Description::Extend;
use XML::DOM;
use Encode;
use strict;
our $VERSION=0.01;

=head1 NAME

fb2_descr_extend.pl - extend description of fb2 file with all possible elements

=head1 SYNOPSIS

B<fix_descr.pl>  I<filename.fb2>

=cut

my $file_name = $ARGV[0];

my $parser = new XML::DOM::Parser;

my $doc = $parser->parsefile($file_name);
my $root = $doc->getDocumentElement();


my ($desc) = $root->getElementsByTagName("description",0);

fb2::Description::Extend::extend({'description'=>$desc});


my $backup = $file_name . "~";
unlink $backup;
rename $file_name, $backup or warn("Cannot make backup copy: $!");
my $encoding=$doc->getXMLDecl()->getEncoding();

# This call of Encode::decode fixes problem in XML::DOM which do not
# mark entire output utf8 correctly.
my $data = decode("utf8",$doc->toString);
open DST,">:encoding($encoding)",$file_name;
print DST $data;
close DST;

print "All OK\n";