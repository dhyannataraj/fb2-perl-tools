package cleanFB2;
#Подчистка Fb2
#<?xml version="1.0" encoding="utf-8"?>

use XML::Parser;
use XML::LibXML;
use Encode;
use utf8;
#
#use Math::Random;

%encodings=(
	'ru'=>'windows-1251',
	'rus'=>'windows-1251',
	'en'=>'windows-1252',
	'eng'=>'windows-1251',
	'urk'=>'windows-1251',
	'bel'=>'windows-1251',
	'fra'=>'iso-8859-1',
	'fre'=>'iso-8859-1',
	'fr'=>'iso-8859-1',
	'de'=>'iso-8859-1',
	'deu'=>'iso-8859-1',
	'ger'=>'iso-8859-1',
	'ara'=>'utf-8',
	'cze'=>'iso-8859-2',
	'cs'=>'iso-8859-2',
	'ces'=>'iso-8859-2',
	'est'=>'iso-8859-2',
	'et'=>'iso-8859-2',
	'fin'=>'iso-8859-1',
	'fi'=>'iso-8859-1',
	'ita'=>'iso-8859-1',
	'slk'=>'iso-8859-2',
	'slo'=>'iso-8859-2',
	'sl'=>'iso-8859-2',
	'swe'=>'iso-8859-1',
	'sv'=>'iso-8859-1'
);
my %oldjenres=(
	Action=>'literature_adv',
	Adventure=>'literature_adv',
	Biography=>'biography',
	Business=>'business',
	Children=>'child_9',
	Classics=>'literature_classics',
	Computer=>'computers',
	Detective=>'thriller_mystery',
	Dictionary=>'ref_dict',
	Encyclopaedia=>'ref_encyclopedia',
	Espionage=>'thriller_mystery',
	Fantasy=>'romance_fantasy',
	Folklore=>'nonfiction_folklor',
	Home=>'home_garden',
	Health=>'health',
	History=>'history_world',
	Hobby=>'home_crafts',
	Horror=>'horror',
	Humor=>'entert_humor',
	Linguistics=>'science',
	Law=>'nonfiction_law',
	Memoir=>'biography',
	Mystery=>'mystery',
	Nature=>'outdoors_outdoor_recreation',
	Poetry=>'literature_poetry',
	Politics=>'nonfiction_politics',
	Religion=>'religion',
	'Религия'=>'religion',
	Romance=>'romance',
	SF=>'romance_sf',
	Science=>'science',
	Sex=>'health_sex',
	Shakespeare=>'literature_poetry',
	Sports=>'sport',
	Education=>'nonfiction_edu',
	Theater=>'performance',
	Thriller=>'thriller',
	Travel=>'travel',
	Western=>'literature_western',
	Unknown=>'romance_sf'
);
my %LangFixes=(
	'deu'=>'de',
	'rus'=>'ru',
	'eng'=>'en'
);
my %escapes=(
  '&'	=> '&amp;',
  '<'	=> '&lt;',
  '>'	=> '&gt;',
  '"'	=> '&quot;',
  "'"	=> '&apos;'
);
my %escapesLite=(
  '&'	=> '&amp;',
  '<'	=> '&lt;',
  '>'	=> '&gt;',
  '"'	=> '&quot;',
  "'"	=> '&apos;'
);

sub GenerateDocInfo{
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $Date=($year+1900)."-$mon-$mday";
	my $RandID='';
	for (Math::Random::random_uniform(40,65,90)){
		$RandID.=chr($_);
	}
	return qq{<document-info><author><nickname>fb.robot</nickname></author>
<program-used>FictionBook.lib cleanup robot</program-used>
<date value="$Date">$Date</date>
<id>$RandID</id>
<version>1.0</version>
</document-info>};
}
sub RandChar{
	return chr(Math::Random::random_uniform(1,97,122));
}
sub CleanupFB2{
	my $FileToParce=shift;
	my $BookLang;
	my $HadDocInfo;
	my %IDsToFix;

	my %ImgLinks;
	my %NotesLinks;
	my %RealImages;
	my %RealNotes;
	
	print "Cleaning the file up...\n$FileToParce\n";
	my $CleanupParser=new XML::Parser(Handlers => {
	  Start => sub {
	    my $expat=shift;
	    $elem=shift;
			my %Params=@_;
			my %CleanParams;
			for (keys(%Params)){
				my $t=$_;
				$t=~s/.*:(.*)/$1/;
				$CleanParams{$t}=$Params{$_};
			}
			$I++;
			print "Cleaning up element #$I\r";

			if ($elem eq "image"){
				$ImgLinks{$CleanParams{'href'}}=1;
			}
			if ($elem eq "a" && lc($Params{'type'}) eq 'note'){
				$NotesLinks{$CleanParams{'href'}}=1;
			}

			if ($elem eq "binary"){
				my $NewID=lc($Params{'id'});
				if ($Params{'content-type'}=~/image\/(jpeg|png)/i){
					my $BinaryType=$1;
					if (!($NewID=~/\.jpe?g\Z/ && $BinaryType eq 'jpeg') &&
							!($NewID=~/\.png\Z/ && $BinaryType eq 'png')){
						$NewID.=lc(".$BinaryType");
					}
				} elsif ($Params{'content-type'}=~/image\/gif/i) {
					$!=18;
					die "GIF image found!";
				}
				$NewID=~s/[^\w\d_\.]/&RandChar/gei;
				$CurBInaryID=$Params{'id'};
				$IDsToFix{$Params{'id'}}=$NewID unless $NewID eq $Params{'id'};
				$RealImages{$NewID}=1;
			}else{
				if ($elem eq "body"){
					$InNotesBody=($elem eq 'body' && $Params{'name'}=~/\Anotes\Z/)?1:0;
				} elsif ($elem eq "section" && $InNotesBody && $Params{'id'}){
					$RealNotes{$Params{'id'}}=1;
				}
				$CurBInaryID=undef;
			}

			if (!$BookLang && $elem =~ /(src-lang|translator|sequence)/){
				if ($XMLBody=~/[А-Яа-я]/){
					$BookLang='ru';
				} else {
					 $BookLang='en' if $XMLBody=~/\A[\w<>,\.\/\\"'\s]/;
				}
				print "\nlang added ($BookLang)!\n";
				$XMLBody.="<lang>$BookLang</lang>";
			}

			$XMLBody.="<$elem";
			for (keys(%Params)){
				$XMLBody.=" $_=\"".stripSpace(xmlescape($Params{$_}))."\"";
			}
			$XMLBody.=">";

			# For "block" elements we will remove leading spaces
			$FirstChars=1 unless $elem=~/(a|style|strong|emphasis)/;

			# If we're in the header, we will preserve all text
			# if we're in body(-like) element - we remove all text in non-text
			# elements (see above)
			$InHead = 1 if $elem eq 'description';
			$InHead = 0 if $elem eq 'annotation';
			$InLang=1 if $elem eq 'lang';
			$InSRCLang=1 if $elem eq 'src-lang';
			$InJenre=1 if $elem eq 'genre';
			
			# Remember, where we are
			unshift(@Elems,$elem);
		},
		Char  => sub {
			my $XText=$_[1];
			$XText=~s/[\r\n\t]/ /g;
			# Leading spaces
			$XText=~s/^\s+// if $FirstChars;
			# We store data only if it's a text container (in header too)
			$XText=~s/\s+// if (defined($CurBInaryID));
			if ($InJenre && $oldjenres{$XText}){
				$XText=$oldjenres{$XText}
			}
			$FirstChars=0;
			if ($XText && ($InLang || $InSRCLang)){
				$XText=lc($XText);
				if ($LangFixes{$XText}){$XText=$LangFixes{$XText};print "Lang changed to: $XText\n"}
			}
			$BookLang.=$XText if $InLang;
			$XMLBody.=xmlescapeLite($XText) if ($InHead or $Elems[0]=~/\A(v|p|subtitle|td|text-author|a|style|strong|emphasis|binary)\Z/);
	  },
		End => sub {
#			if ($_[1] eq 'description'){
#				print $XMLBody;
#			}
			$InHead = 0 if $_[1] eq 'description';
			$InHead = 1 if $_[1] eq 'annotation';
			$InLang=0 if $_[1] eq 'lang';
			$InJenre=0 if $_[1] eq 'genre';
			$InSRCLang=0 if $_[1] eq 'src-lang';
			$HadDocInfo=1 if $_[1] eq 'document-info';

			if (($_[1] eq 'title-info') && !$BookLang){
				$XMLBody.="<lang>ru</lang>" if $XMLBody=~/[А-Яа-я]/;
				$BookLang='ru';
			}

			if (!$HadDocInfo && $_[1] eq 'description'){
				$XMLBody.=&GenerateDocInfo();
				print "\nNew document info generated!\n";
			}

			$XMLBody=~s/\s\Z//;
			$XMLBody.="</".$_[1].">";
			$XMLBody.="\n" if $_[1] eq 'p';
			shift(@Elems);
		}
	});
	# ok, let's get it ower with now - all clean and binary collected
	$CleanupParser->parsefile($FileToParce);
	$CleanupParser=undef;
	print "\nPerforming image ID's fix...\n" unless $Mute;
	for (keys(%IDsToFix)){
		print "'$_'->'$IDsToFix{$_}'\n";
		$XMLBody=~s/(['"])(#)?$_['"]/$1$2$IDsToFix{$_}$1/g;
	}
	print "Performing final text cleanup...\n" unless $Mute;

	# finall cleanup
	
	$XMLBody=~s/\A\s+//;
	print "step 1\n";
	$XMLBody=~s/\s+\Z//;
	print "step 2\n";
	$XMLBody=~s/(\s)\s+/$1/g;
	print "step 3\n";
	$XMLBody=~s/([pv])>\s+/$1>/g;
	print "step 4\n";
	$XMLBody=~s/[-—–]{2,}/–/g;
	print "step 5\n";
	$XMLBody=~s/(p[^>]*>)[-—]/$1–/g;
	print "step 6\n";
	$XMLBody=~s/(p[^>]*>)– /$1–\&#160;/g;
	print "step 7\n";
	$XMLBody=~s/[-—](\s)/–$1/g;
	print "step 8\n";
	$XMLBody=~s/<\/p>/<\/p>\n/g;
	print "step 9\n";
	if ($BookLang eq 'ru'){
		while ($XMLBody=~s/>([^>]*?([\(\s"]))?"([^\"<]+?)([^\s"\(<])"/>$1«$3$4»/g){}
		print "step 10\n";
		while ($XMLBody=~s/>([^>]*?)«([^»<]*?)«([^»<]*?)»/>$1«$2„$3“/g){};
		print "step 11\n";
	  $XMLBody=~s/([\.,!\?;]) –/$1\&#160;–/g;
		print "step 12\n";
	}
#	$XMLBody=~s/–/—/g;


	$BookLang=~s/\s+//;
	$BookLang=lc($BookLang);
	print "Checking internal links...\n";
	$!=13;
	for (keys(%ImgLinks)){
		die "External '$_' image linked - error" if !/\A#/;
	}
	$!=14;
	for (keys(%NotesLinks)){
		die "External note '$_' linked - error" if !/\A#/;
	}
	for (keys(%ImgLinks)){
		my $Item=$_;
		$Item=~s/\A#//;
		if ($IDsToFix{$Item}){
			delete $ImgLinks{$_};
			$ImgLinks{'#'.$IDsToFix{$Item}}=1;
		}
	}

	$!=15;
	my @ImgWrong;
	for (keys(%ImgLinks)){
		s/\A#//;
		push(@ImgWrong,$_) if !$RealImages{$_};
	}
	die "Image links points to inexistent ID!\n".join("\n",@ImgWrong) if @ImgWrong;
	
	$!=16;
	my @NotesWrong;
	for (keys(%NotesLinks)){
		s/\A#//;
		push(@NotesWrong,$_) if !$RealNotes{$_};
	}
	die "Notes point to inexistent section ID!\n".join("\n",@NotesWrong) if @NotesWrong;

	$!=17;
	my @ImgWrong;
	for (keys(%RealImages)){
		push(@ImgWrong,$_) if !$ImgLinks{'#'.$_};
	}
	die "Unused images 'detected!\n".join("\n",@ImgWrong) if @ImgWrong;
	$!=0;

	print "Lang: $BookLang\n";
	if ($encodings{$BookLang}){
		print "language primary encoding found: <$encodings{$BookLang}>, saving in selected encoding...\n";
	} else {
		print "using default UTF-8 encoding for this language, saving in selected encoding...\n";
		$encodings{$BookLang}='utf-8';
	}
	$dom = $parser = XML::LibXML->new();
	$doc = $parser->parse_string($XMLBody);
	$doc->setEncoding($encodings{$BookLang});
	open (FILETOUPDATE, ">$FileToParce") or die "error opening resulf file!\n$!";
	print FILETOUPDATE $doc->toString(0) or die "error writing XML to file!\$!";
	close FILETOUPDATE;
}
sub xmlescapeLite {
	$b=shift;
  $_=$b;
  s/([&<>])/$escapesLite{$1}/gs;
  $_;
}


sub xmlescape {
	$b=shift;
  $_=$b;
  s/([&<>'"])/$escapes{$1}/gs;
  $_;
}

sub stripSpace{
	$_=shift;
	s/\A\s*(.*?)\s*\Z/$1/;
	return $_;
}
1;