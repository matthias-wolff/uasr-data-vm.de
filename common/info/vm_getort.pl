#!/usr/bin/perl
## Unified Approach to Speech Synthesis and Recognition
## - Read ortographic labels from Verbmobil Database
##
## AUTHOR  : Frank Duckhorn
## PACKAGE : uasr/scripts/perl/db
## REVISION: $Revision:302 $
##

## DESCRIPTION:
## This program reads the ortographic partitur of one
## label file from Verbmobil Database. It uses the
## transliteration partitur to insert <PAUSE> words
## at every "." or "," or "?". The converted ortographic
## partitur is written to stdout. This program is used
## by NMG_evaluation.xtp.

## ARGUMENTS:
##   $1: File name of the label file to read

use strict;                                                                     # Use strict parsing

## Global variables                                                             # --------------------------------------
my $lab_file=$ARGV[0];                                                          # Get label file name from arguments
die "No valid lab file: \"$lab_file\"\n" if ! -f $lab_file;                     # No label file found
my $trl_cur_segment="";                                                         # Remember segment begin without end in last line

## Functions ###################################################################

## Convert whole line of transliteration (remove nonspeech tags)
##
## @param trl string
##          one transliteration line to convert
## @return string
##          converted transliteration line
sub convert_trlline {
	my $trl=shift;                                                                # Get transliteration line
	# Remove special sequences from transliteration line:                         # --------------------------------------
	$trl=~s/<\*T>t//g;                                                            # Technischer Abbruch
	$trl=~s/<\*[A-Z]+>//g;                                                        # Fremdsprachenhinweis
	$trl=~s/<[APZ%]>//g;                                                          # Atmen, Sprechpausen, Zögerung, unverständliche Sprachproduktionen
	$trl=~s/<:|:>//g;                                                             # Geräuschüberlagerung
	$trl=~s/(\+|-)\/.*\/(\+|-)//g;                                                # Wiederholung oder False Start
	$trl=~s/<![1-9] [a-zA-Z""' -]+>//g;                                           # Aussprachekommentare
	$trl=~s/<;[\334\366\344\374a-zA-Z0-9""'?.!,:$ %+-]+>//g;                      # Lokale Kommentare
	$trl=lc $trl;                                                                 # Kleinschreibung
	$trl=~s/ +/ /g; $trl=~s/^ +//; $trl=~s/ +$//;                                 # Mehrfache Leerzeichen
	if(""ne$trl_cur_segment) {                                                    # Vorsetzung von Wiederholung oder False Start >>
		$trl_cur_segment="" if $trl=~/$trl_cur_segment(.*)$/;                       #   trl_cur_segment reseten
		$trl=$1;                                                                    #   Alles bis Segmentende entfernen
	}                                                                             # <<
	if($trl=~/(\+\/)/) { $trl_cur_segment='\/\+'; $trl=~s/\+\/.*$//; }            # Wiederholung / Korrektur
	if($trl=~/(-\/)/) { $trl_cur_segment='\/-'; $trl=~s/-\/.*$//; }               # False Start / Neustart
	return $trl;                                                                  # Return converted transliteration
}

## Convert one single translitaration word (remove nonspeech tags)
##
## @param trl string
##          one transliteration word to convert
## @param ort string
##          ortographic representation corresponding to that word
## @return string
##          converted transliteration word
sub convert_trlsingle {
	my $trl=shift;                                                                # Get transliteration word
	my $ort=shift;                                                                # Get ortographic representation
	# Remove special sequences from transliteration word:                         # --------------------------------------
	$trl="" if $trl=~/^<t_>|<_t>$/;                                               # Wortabbruch
	$trl=~s/<@[0-9]+|[0-9]+@>|@[0-9]+|[0-9]+@|//g;                                # Sprecherüberlagerung
	$trl=~s/^[#~*]([a-z""])/$1/g;                                                 # Zahlen, , Neologismen
	$trl=~s/([a-z""'])%$/$1/g;                                                    # Schwer verständlich
	$trl=~s/<([""]ahm?|hm|h[""]as)>//g;                                           # Hästitationen
	$trl=~s/<(schmatzen|schlucken|r[""]auspern|husten|lachen|ger[""]ausch)>//g;   # Nonverbale artikulatorische Geräusche
	$trl=~s/<#(klicken|klingeln|klopfen|mikrobe|mikrowind|rascheln|quietschen|)>//g;# Geräusche und technische Artefakte
	$trl=~s/^_-?|_$|--$//g;                                                       # Artikulatorische Unterbrechung
	$trl=~s/[a-z""-]+=//g;                                                        # Artikulatorischer Abbruch
	$trl=~s/^[,.?]$/<PAUSE>/g;                                                    # Satzzeichen => insert <PAUSE>
	if($trl=~/'$/) { $trl=~s/'$//; $trl=$ort if $ort=~/^$trl/; }                  # Remove "'" at end of word
	if($trl=~/^'/) { $trl=~s/^'//; $trl=$ort if $ort=~/$trl$/; }                  # Remove "'" at begin of word
	return $trl;                                                                  # Return converted transliteration
}

## Main Programm ###############################################################

# Get all partiturs in label file                                               # --------------------------------------
open TP,"<".$lab_file;                                                          # Open label file
my @par=<TP>;                                                                   # Read partiturs in label file
close TP;                                                                       # Close label file

# Get transliterations and ortographic representations from partitur            # --------------------------------------
my @trl=();                                                                     # Transliterations
my @ort=();                                                                     # Ortographic representations
foreach my $parline (@par) {                                                    # Loop over all lines from label file >>
	chomp $parline;                                                               #   Remove new line at end of line
	my @parline=split /[\t ]+/,$parline,3;                                        #   Split line into columns
	$ort[$parline[1]]=$parline[2] if $parline[0] eq "ORT:";                       #   Save ort. repr. if it is one
	$trl[$parline[1]]=$parline[2] if $parline[0] eq "TR2:";                       #   Save translit. if it is one
}                                                                               # <<

# Convert ortographic repr. to text with <PAUSE>                                # --------------------------------------
print "<PAUSE>\n";                                                              # Start with <PAUSE> word
my $pause_first=1;                                                              # Obmit first <PAUSE> (no duplication)
my $pause_last=0;                                                               # Last <PAUSE> done ?
for(my $i=0;$i<@ort;$i++) {                                                     # Loop over all ort. repr. >>
	my $trl=&convert_trlline($trl[$i]);                                           #    Convert whole translit. line
	my $ort=$ort[$i];                                                             #    Get current ort. repr.
	next if $ort eq "";                                                           #    Ort. repr. empty => next word
	my @trl=split / /,$trl;                                                       #    Split translit. at spaces
	my $ort_found=0;                                                              #    Def: No Corresp. translit. word found
	my $pause_before=0;                                                           #    Def: no pause before word
	my $pause_after=0;                                                            #    Def: no pause after word
	foreach my $trl (@trl) {                                                      #    Loop over all translit. words >>
		$trl=&convert_trlsingle($trl,$ort);                                         #       Convert single translit. word
		$ort_found=1 if $trl eq lc $ort;                                            #       If it matches ort. repr. => remember
		next if "<PAUSE>"ne$trl;                                                    #       If the word is not <PAUSE> => next
		$pause_before=1 if !$ort_found;                                             #       If no ort. => insert pause before
		$pause_after=1 if $ort_found;                                               #       Else => insert pause after word
	}                                                                             #    <<
	print "<PAUSE>\n" if $pause_before && !$pause_first && $pause_last;           #    Insert <PAUSE> before word if necessary
	print "$ort\n";                                                               #    Output current ort. repr. of word
	print "<PAUSE>\n" if $pause_after;                                            #    Insert <PAUSE> after word if necessary
	$pause_last=!$pause_after;                                                    #    If <PAUSE> after word => no <PAUSE> at end
	$pause_first=0;                                                               #    First word was done
}                                                                               # <<
print "<PAUSE>\n" if $pause_last;                                               # Insert <PAUSE> at end if necessary

