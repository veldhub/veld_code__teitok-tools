use Getopt::Long;
use Data::Dumper;
use POSIX qw(strftime);
use File::Find;
use LWP::Simple;
use LWP::UserAgent;
use JSON;
use XML::LibXML;
use Encode;

# Pars# Convert the known TEITOK differences to "pure" TEI/P5

$scriptname = $0;

GetOptions ( ## Command line options
            'debug' => \$debug, # debugging mode
            'verbose' => \$verbose, # debugging mode
            'help' => \$help, # debugging mode
            'longid' => \$longid, # write tok_id= in the misc column
            'file=s' => \$filename, # input file name
            'posatt=s' => \$posatt, # name to use for pos
            'pos=s' => \$posatt, # XPOS tag
            'form=s' => \$wform, # form to use as word
            'output=s' => \$output, # output file name
            'outfolder=s' => \$outfolder, # Originals folder
            'tagmapping=s' => \$tagmapping, # XPOS tag
            'training' => \$training, # write back to original file or put in new file
            );

$\ = "\n"; $, = "\t";

$parser = XML::LibXML->new(); 

if ( !$filename ) { $filename = shift; };

if ( $help ) {
	print "Usage: perl teitok2conllu.pl [options] filename

Options:
	--verbose	verbose output
	--debug		debugging mode
	--file		filename to convert
	--output	conllu file to write to
	--pos=s		XML attribute to use for @xpos
	--form=s	TEITOK inherited form to use as @form
	";
	exit;

};

if ( !$posatt ) { $posatt = "pos"; };
if ( !$wform ) { 
	$wform = "pform"; 
} else {
	# We need an inheritance from the settings
	$doc = "";
	$setfile = "Resources/settings.xml"; 
	if ( $verbose ) { print "Reading settings from $setfile for inheritance from $wform	"; };
	eval {
		$setxml = $parser->load_xml(location => $setfile);
	};
	if ( $setxml ) { foreach $node ( $setxml->findnodes("//xmlfile/pattributes/forms/item") ) {
		$from = $node->getAttribute("key");
		$to = $node->getAttribute("inherit");
		$inherit{$from} = $to;
	};};
	if ( !$inherit{'form'} ) { $inherit{'form'} = "pform"; };
};
if ( $debug ) { while ( ( $key, $val ) = each ( %inherit ) ) { print "Inherit: $key => $val"; }; };

if ( $tagmapping && -e $tagmapping ) {
	open FILE, $tagmapping;
	binmode(FILE, ":utf8");
	while ( <FILE> ) {
		chop;
		( $xpos, $upos, $feats ) = split ( "\t" );
		$xpos2upos{$xpos} = $upos;
		$xpos2feats{$xpos} = $feats;
	};
	close FILE;
};

$parser = XML::LibXML->new(); $doc = "";
eval {
	$doc = $parser->load_xml(location => $filename);
};
if ( !$doc ) { print "Invalid XML in $filename"; exit; };

if ( !$output ) { 
	( $output = $filename ) =~ s/\.xml/.conllu/; 
	if ( $outfolder ) { 
		$output =~ s/.*\//$outfolder\//;
	};
} else {
	( $ofldr = $output ) =~ s/[^\/]+$//;
	if ( $debug ) { print "Creating $ofldr when needed"; };
	`mkdir -p $ofldr`;
};

if ( !$doc->findnodes("//tok") ) {
	print "Error: cannot convert untokenized files to CoNNL-U";
	exit;
};

print "Writing converted file to $output\n";
open OUTFILE, ">$output";
binmode(OUTFILE, ":utf8");

# Convert <dtok> to <tok> (to be dealt with later)
$scnt = 1;

$docid = $filename; $docid =~ s/.*\///; $docid =~ s/\.xml//;

print OUTFILE "# newdoc id = $docid";
$sents = $doc->findnodes("//s");
if ( !scalar $sents ) { $sents = $doc->findnodes("//u"); };
if ( $sents ) { 
	if ( $verbose ) { print "With sentences"; };
	$sntcnt = 0;
	foreach $snt ( @{$sents} ) {
		$sentid = $snt->getAttribute('id');
		if ( !$sentid ) { 
			$sentid = "[$sntcnt]"; 
			if ( $verbose ) { print "Unnumbered sentence $sentid"; };
		}; 
		$sntcnt++;
		@toks =  $snt->findnodes(".//tok");
		if ( ! scalar @toks ) { 
			if ( $verbose ) { print "Skipping empty sentence $sentid"; };
			next; 
		};
		$senttxt = $snt->textContent;
		$senttxt =~ s/\s/ /g; $senttext =~ s/ +/ /g;
		print OUTFILE "# sent_id = $docid\_$sentid";
		print OUTFILE "# text = $senttxt";
		undef(%toknrs); # Undef to avoid sentence-crossing links

		# Check for loops
		$tree = $parser->load_xml(string => "<s/>");
		undef(%nodes); undef($rootid); undef($unrootid); undef($root);
		foreach $tok ( @toks ) {
			$tokid =  $tok->getAttribute("id");
			$nodes{$tokid} = $tree->createElement("tok");
			if ( $tok->getAttribute("deprel")."" eq "root" ) {
				if  ( !$rootid ) { $rootid = $tokid; };
			} elsif ( !$tok->getAttribute("head") || $tok->getAttribute("head")."" eq ""  ) {
				$unrootid = $tokid;
			};
		}; if ( !$rootid ) { $rootid = $unrootid; };
		if ( !$rootid ) { 
			if ( $verbose ) { print "No root element found in $sentid"; };
		};
				
		foreach $tok ( @toks ) {
			$tokid =  $tok->getAttribute("id")."";
			$headid =  $tok->getAttribute("head")."";
			$deprel =  $tok->getAttribute("deprel")."";
			if ( $rootid && $tokid ne $rootid && $deprel eq "root" ) {
				if  ( $verbose ) { print "Linked or secondary marked as root in $sentid/$tokid (renaming to dep)"; };
				$tok->setAttribute("deprel", "dep"); # We should not keep multiple roots
			};
			if ( $headid ) { 
				if ( !$nodes{$headid} ) { 
					if ( $verbose ) { print "Reference to non-existing node in $sentid: $tokid -> $headidc"; };
					$tok->setAttribute("head", $rootid);
					$nodes{$rootid}->addChild($nodes{$tokid});
				} elsif ( $nodes{$headid}->findnodes(".//ancestor::tok[\@id=\"$tokid\"]") ) { 
					if ( $verbose ) { print "Circular dependency in $sentid: $tokid -> $headid (reattaching to $rootid)"; };
					$tok->setAttribute("head", $rootid);
					$nodes{$rootid}->addChild($nodes{$tokid});
				} else { eval {
					$nodes{$headid}->addChild($nodes{$tokid});
				}; };
				if ( !$nodes{$tokid}->parentNode ) { 
					if ( $verbose ) { print "Failed to attach $tokid in $sentid to $headid (reattaching to $rootid)"; };
					$tok->setAttribute("head", $rootid);
					$nodes{$rootid}->addChild($nodes{$tokid});
				};
			} else {
				if ( $tokid ne $rootid ) { 
					if  ( $verbose ) { print "Multiple roots in $sentid: $rootid and $tokid (reattaching to $rootid)"; };
					$tok->setAttribute("head", $rootid);
					$tok->setAttribute("deprel", "dep"); # We should not keep multiple roots
				};
				$tree->firstChild->addChild($nodes{$tokid});
			};
			$sentlines .= parsetok($tok);
		};
		print OUTFILE putheads($sentlines); 
		$sentlines = "";
		$toknr = 0;
	};
} else {
	if ( $verbose ) { print "Without sentences"; };
	$snum = 1;
	print OUTFILE "# sent_id = $docid\_s-".$snum++;
	foreach $tok ( $doc->findnodes("//tok") ) {
		if ( $newsent ) { 
			print OUTFILE "# sent_id s-".$snum++; 
			print OUTFILE "# text = $senttxt";
			print OUTFILE putheads($sentlines);
			$sentlines = ""; $senttxt = "";
			$toknr = 0;
		};
		$newsent = 0;
		$tokxml = parsetok($tok); $sentlines .= $tokxml; 
		@tmp = split("\t", $tokxml); 
		$senttxt .= $tmp[1]; if ( $tmp[9] !~ /Space/ ) { $senttxt .= " "; };
		if ( $tmp[1] =~ /^[.!?]$/ ) { 
			$newsent = 1;
		};
		$num++;
	};
	if ( $sentlines ) {
		print OUTFILE "# sent_id s-".$snum++; 
		print OUTFILE "# text = $senttxt";
		print OUTFILE putheads($sentlines);
		$sentlines = ""; $senttxt = "";
		$toknr = 0;
	};
};
print OUTFILE "\n";
close OUTFLE;

sub putheads($txt) {
	$txt = @_[0];

	while ( ( $key, $val) = each ( %toknrs ) ) {
		$txt =~ s/{#$key}/$val/g;
	};
	if ( $txt =~ /root/ ) {
		$txt =~ s/{#_}/0/g;
	} else {
		$txt =~ s/{#_}/_/g;
	};
	$txt =~ s/{#[^{}]+}/0/g; # Remove heads that did not get placed (no longer restricted to TEITOK numbering w-xxx or d-xxx)
	
	if ( $training ) { 
		# Remove all 0's that are not root when training
		$txt =~ s/^([^\t]+\t[^\t]+\t[^\t]+\t[^\t]+\t[^\t]+\t[^\t]+)\t0\t(?!root).*/\1\t0root/g;
	};
	
	return $txt;
};

sub parsetok($tk) {
	$tk = @_[0];

	$toklinenr = "";
	if ( !$tk->findnodes("./dtok") ) {
		$toknr++; 
		$toklinenr = $toknr;
		$tokid = $tk->getAttribute('id').'';
		$toknrs{$tokid} = $toknr;
		$word = calcform($tk, $wform);
		$word =~ s/\s+$//gsm;
		$word =~ s/&#039;/''/g;
		$lemma = getAttVal($tk, 'lemma');
		$upos = getAttVal($tk, 'upos');
		$xpos = getAttVal($tk, $posatt);
		$feats = getAttVal($tk, 'feats');
		$head = getAttVal($tk, 'head');
		$deprel = getAttVal($tk, 'deprel');
		$deps = getAttVal($tk, 'deps');
		$misc = getAttVal($tk, 'misc');

		if ( $deprel eq '_' && $training ) { $deprel = "dep"; }; # We always need a deprel for training the parser

		if ( $misc eq '_' ) { $misc = ""; };
		if ( $misc ) { $misc = $misc."|"; };
		if ( $longid ) { 
			$misc .= $tokid; 
		} else {
			$misc .= "tok_id=".$tokid; 
		};
		
		# fallback
		if ( $word eq '' ) { $word = "_"; };
		if ( $misc eq '' ) { $misc = "_"; };
		
		undef($tkp); $tmp = $tk;
		if ( !$tk->nextSibling() ) { while ( $tmp->parentNode() &&  $tmp->parentNode()->getName() ne 's' ) { $tkp = $tmp->parentNode(); $tmp = $tkp; }; };
		if ( $tk->nextSibling() && $tk->nextSibling()->getName() eq "tok" ) { $misc .= "|SpaceAfter=No"; 
		} elsif ( $tkp && $tkp->nextSibling() && $tkp->nextSibling()->getName() eq "tok" ) { $misc .= "|SpaceAfter=No"; };

		$tokline = "\t$word\t$lemma\t$upos\t$xpos\t$feats\t{#$head}\t$deprel\t$deps\t$misc\n";
	} else {
		$tokfirst = $toknr+1;
		$word = calcform($tk, $wform);
		$word =~ s/\s+$//gsm;
		$tokid = $tk->getAttribute('id').'';
		$misc = $tk->getAttribute('misc');
		if ( $misc ) { $misc = $misc."|"; };
		if ( $longid ) { 
			$misc .= $tokid; 
		} else {
			$misc .= "tok_id=".$tokid; 
		};

		if ( $word eq '' ) { $word = "_"; };
		if ( $misc eq '' ) { $misc = ""; };

		undef($tkp); $tmp = $tk;
		if ( !$tk->nextSibling() ) { while ( $tmp->parentNode() &&  $tmp->parentNode()->getName() ne 's' ) { $tkp = $tmp->parentNode(); $tmp = $tkp; }; };
		if ( $tk->nextSibling() && $tk->nextSibling()->getName() eq "tok" ) { $misc .= "|SpaceAfter=No"; 
		} elsif ( $tkp && $tkp->nextSibling() && $tkp->nextSibling()->getName() eq "tok" ) { $misc = "SpaceAfter=No"; };
		$tokline = "\t$word\t_\t_\t_\t_\t_\t_\t_\t$misc\n";
	};
	

	$dtoklines = "";
	foreach $dtk ( $tk->findnodes("./dtok") ) {
		$toknr++;
		$tokid = $dtk->getAttribute('id').'';
		$toknrs{$tokid} = $toknr;
		$word = calcform($dtk, $wform);
		$lemma = getAttVal($dtk, 'lemma');
		$upos = getAttVal($dtk, 'upos');
		$xpos = getAttVal($dtk, $posatt);
		$feats = getAttVal($dtk, 'feats');
		$head = getAttVal($dtk, 'head');
		$deprel = getAttVal($dtk, 'deprel');
		$deps = getAttVal($dtk, 'deps');
		$misc = getAttVal($dtk, 'misc');

		if ( $deprel eq '_' && $training ) { $deprel = "dep"; }; # We always need a deprel for training the parser

		if ( $misc ) { $misc = $misc."|"; };
		$misc .= $tokid;

		# fallback
		if ( $word eq '' ) { $word = "_"; };
		if ( $misc eq '' ) { $misc = "_"; };
		
		$dtoklines .= "$toknr\t$word\t$lemma\t$upos\t$xpos\t$feats\t{#$head}\t$deprel\t$deps\t$misc\n";
	};
	if ( $toklinenr eq "" ) {
		$toklinenr = "$tokfirst-$toknr";
	};
	
	return "$toklinenr$tokline$dtoklines"; 
	
};

sub getAttVal ($node, $att ) {
	( $node, $att ) = @_;
	$val = $node->getAttribute($att);
	$val =~ s/^\s+|\s+$//g;
	$val =~ s/\t| //g;
	$val =~ s/ +/ /g;
	
	if ( !$val ) { $val = "_"; };
	
	return $val;
};

sub calcform ( $node, $form ) {
	( $node, $form ) = @_;
	if ( !$node ) { return; };
	
	if ( $form eq 'pform' ) {
		$value = $node->toString;
		$value =~ s/<[^>]*>//g;
		return $value;
		# return $node->textContent;
	} elsif ( $node->getAttribute($form) ) {
		return $node->getAttribute($form);
	} elsif ( $inherit{$form} ) {
		return calcform($node, $inherit{$form});
	} else {
		return "_";
	};
};