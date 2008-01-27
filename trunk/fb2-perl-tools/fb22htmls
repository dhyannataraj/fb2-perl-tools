#!/usr/bin/perl

# Copyright (c) 2004 Dmitry Gribov (GribUser),
#               2008 Nikolay Shaplov
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


use fb2::Convert::Htmls;
use Getopt::Long qw(HelpMessage VersionMessage);
use strict;

our $VERSION = 0.02;

my $xsl_file=$ENV{FB2_PERL_TOOLS};
$xsl_file.="/" if $xsl_file && $xsl_file =~ /[^\/]$/;
$xsl_file.="XSL/fb22htmls.xsl";


my $Mute=0;
my $SectionSize=30000;
my $MinSectionSize=20000;
my $OutFileName = '';

#=============================================================
if (! @ARGV) { print "
FB2 to HTMLs convertor v$VERSION
Usage:

fb22html  [-options] <inputfile.fb2>

  Options available
   --mute		  Do not print progress messages.
   --partsize=<number>	  Set part size (default is $SectionSize)
   --minsize=<number>  	  Set minimum part size (default is $MinSectionSize)
   --outfile=<file_name>  Base name for output htmls (default is infputfile stripped of .fb2 or .xml extentions)

  outfile name will be used to create new files.
  outfile_<page#>.html files will be created

";exit 0;}
#=============================================================


GetOptions ( help=>sub {HelpMessage(); },
             version=>sub {VersionMessage(); },
             "mute" => \$Mute,
             'partsize=i' => \$SectionSize,
             'minsize=i'=> \$MinSectionSize,
	     'outfile=s'=> \$OutFileName
	    );
my $FileToParce = shift @ARGV;

if (!$OutFileName)
{
  $OutFileName = $FileToParce;
  $OutFileName =~ s/\.xml|\.fb2$//i;
}

fb2::Convert::Htmls::Kolbasim($FileToParce,$xsl_file,$OutFileName,$SectionSize,$MinSectionSize,$Mute);
