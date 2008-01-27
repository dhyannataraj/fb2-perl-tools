#!/usr/bin/perl

# Copyright (c) 2004 Dmitry Gribov (GribUser)
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


package fb2::Convert::Htmls;

use XML::Parser;
use XML::LibXSLT;
use XML::LibXML;
use strict;
no warnings;

my $Mute;
my $SectionSize;
my $MinSectionSize;

my @BodyParts;
my $RootAttrs;
my $BookTitle;

sub Kolbasim{
	my $FileToParce=shift;
	my $StyleSheet=shift;
	my $OutFileName=shift;
	$SectionSize=shift;
	$MinSectionSize=shift;
	$Mute=shift;
	($RootAttrs,$BookTitle,@BodyParts)=&SplitBook($FileToParce);
	return TransformParts($StyleSheet,$OutFileName,$RootAttrs,$BookTitle,@BodyParts);
}

sub SplitBook{
	my $FileToParce=shift;
	my $I;
	my $CurDeepness=0;
	my ($CurPart,$InBinary,$InHead);
	my $Description;
	my @BodyAsArray;
	my $PartSize=0;
	my $PartStarted=1;
	my $InSectionTitle=0;
	my $AllowSectionTitle=0;
	my $CanCutHere=1;
	my $SectionTitle;
	my @ContentParts;
	my $InNotesBody;
	my $RootAttrs;
	my $BookTitle;
	my $InBookTitle;
	my $SplitParser=new XML::Parser(Handlers => {
	  Start => sub {
	    my $expat=shift;
	    my $elem=shift;
			my %Params=@_;
			$I++;
			print "Working element #$I\r" unless $Mute;

			$InHead = 1 if $elem eq 'description';
			$InBinary=($elem eq 'description')?1:0;
			$CurPart='' if $elem=~/\Adescription\Z/;
			if ($elem eq 'FictionBook'){
				for (keys(%Params)){
					$RootAttrs.=" $_=\"".xmlescape($Params{$_})."\"" unless $_ eq 'xmlns';
				}
			}
			$InBookTitle=$elem eq 'book-title'?1:0 ;
			unless ($elem eq 'section'){
				if ($elem eq 'title'){
					$Params{'deepness'}=$InNotesBody?5:$CurDeepness;
					$Params{'number'}=scalar @BodyAsArray;
				}
				$CurPart.="<$elem";
				for (keys(%Params)){
					$CurPart.=" $_=\"".xmlescape($Params{$_})."\"";
				}
				$CurPart.=">";
			}else{
				$CurDeepness++;
			}
			$AllowSectionTitle=0 if $elem eq 'poem';
			$InSectionTitle=1 if ($AllowSectionTitle && $elem eq 'title');
			if ($elem=~/\A(title|epigraph|annotation|poem|cite)\Z/){
				$CanCutHere=0;
			}
			if ($elem=~/\A(section|body)\Z/){
#				$CurPart='' unless $InNotesBody;
				$CurPart='' if $elem eq 'body';
				$PartSize=0 if $elem eq 'body';
				$PartStarted=1;
				$AllowSectionTitle=1;
				$SectionTitle='';
				$InNotesBody=1 if ($elem eq 'body' && $Params{'name'}=~/\Anotes\Z/i);
			}
		},
		Char  => sub {
			$PartSize+=length($_[1]);
			$CurPart.=xmlescape($_[1]) unless $InBinary;
			$SectionTitle.=xmlescape($_[1]) if $InSectionTitle;
			$BookTitle.=xmlescape($_[1]) if $InBookTitle;
	  },
		End => sub {
			my $elem=$_[1];
			$CurPart.="</".$_[1].">" unless $elem=~ /(section|body)/;
			if (((!$InHead && $CanCutHere  && $elem eq 'p' && $PartSize>=$SectionSize) ||
				 ($elem eq 'section' && $PartSize>=$MinSectionSize) || $elem eq 'description') && !$InNotesBody || $elem eq 'body') {
				my %t=(
					'parstart'=>$PartStarted,
					'partcontent'=>$CurPart,
					'level'=>$CurDeepness
				);
				push(@BodyAsArray,\%t) unless $CurPart=~/\A\s+\Z/;
				$CurPart='';
				$PartSize=0;
				$PartStarted=0;
				$InHead=0 if $_[1] eq 'description';
			}
			$CurDeepness-- if $_[1] eq 'section';
			if ($elem=~/\A(title|epigraph|annotation|poem|cite)\Z/){
				$CanCutHere=1;
			}
			$AllowSectionTitle=0 if $elem eq 'section';

			if ($elem eq 'p' && $InSectionTitle && $SectionTitle){
				my %t=('title'=>$SectionTitle,'N'=>(scalar @BodyAsArray), 'deep'=>$CurDeepness);
				push (@ContentParts,\%t);
				$InSectionTitle=0;
				$SectionTitle='';
				$AllowSectionTitle=0;
			}
		}
	});

	$SplitParser->parsefile($FileToParce) or die $!;
	$SplitParser=undef;
	for (@ContentParts){
		$BodyAsArray[0]->{'partcontent'}.="<toc-item n=\"".$_->{'N'}."\" deep=\"".$_->{'deep'}."\">".$_->{'title'}."</toc-item>\n";
	}
	return ($RootAttrs,$BookTitle,@BodyAsArray);
}

sub TransformParts{
	my $StyleSheet=shift;
	my $OutFileName=shift;
	my $RootAttrs=shift;
	my $BookTitle=shift;
	my @Parts=@_;
	my $OutFileSHort=$OutFileName;
	$OutFileSHort=~s/\A(.*[\/\\])?([^\/\\]*)\Z/$2/;
	for (my $I=0;$I<@Parts;$I++){
		my $ItemLength=$Parts[$I]->{'title'};
		print "Generating file ${OutFileName}_$I.html...\n" unless $Mute;
		my $Result=TransformXML("<part$RootAttrs>".$Parts[$I]->{'partcontent'}."</part>",
			$StyleSheet,'PageN'=>"'$I'",
			'TotalPages'=>'"'.(@Parts-1).'"',
			'FileName'=>"'$OutFileSHort'",
			'BookTitle'=>"'$BookTitle'");
		open OUTFILE,">${OutFileName}_$I.html";
		print OUTFILE $Result;
		close OUTFILE;
	}
	return scalar(@Parts);
}

sub xmlescape {
	my %escapes=(
	  '&'	=> '&amp;',
	  '<'	=> '&lt;',
	  '>'	=> '&gt;',
	  '"'	=> '&quot;',
	  "'"	=> '&apos;'
	);
	$b=shift;
  $_=$b;
  s/([&<>'"])/$escapes{$1}/gs; #'
  $_;
}

sub TransformXML{
	my $XML=shift;
	my $XSL=shift;
  my $parser = XML::LibXML->new();
  my $xslt = XML::LibXSLT->new();
  my $source = $parser->parse_string($XML);
  my $style_doc = $parser->parse_file($XSL);
  my $stylesheet = $xslt->parse_stylesheet($style_doc);
  my $results = $stylesheet->transform($source,@_);
  $stylesheet->output_string($results);
}
1;