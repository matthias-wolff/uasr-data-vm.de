#!/usr/bin/perl
## Unified Approach to Speech Synthesis and Recognition
## - Lexicon file generator for Verbmobil Database
##
## AUTHOR  : Frank Duckhorn
## PACKAGE : uasr/scripts/perl/db
## REVISION: $Revision:302 $
##

## DESCRIPTION:
## This program generates for a specific experiment of
## the Verbmobil database lexicons which are requiered
## for NMG_evaluation.xtp. It reads the lexicons of
## Verbmobil database in lexicon/ and generates for every
## file list in flist/ a specific lexicon in lex/.
## To find that words used by the files of a file list 
## all requiered partiture files are also read.

## ARGUMENTS:
##   $1: (optional) Experiment name

use strict;                                                                     # Use strict parsing

## Global variables                                                             # --------------------------------------
my $uasr_home=$ENV{UASR_HOME};                                                  # UASR home directory
my $db="vm";                                                                    # Database name
my $exp=$ARGV[0]; $exp="common" if $exp eq "";                                  # Experiment name
print "VM experiment used: $exp\n";                                             # Protocol

my $defpenalty=0;                                                               # Default word penalty

my $lexicon_dir=&get_dir("lexicon");                                            # VM lexicon directory
my $flist_dir=&get_dir("flists");                                               # File list directory
my $lex_dir=$flist_dir; $lex_dir=~s/\/flists/\/lex/;                            # UASR lexicon directory
my $lab_dir=&get_dir("lab");                                                    # Label directory
my $labmap=&get_dir("info")."/labmap.txt";                                      # VM phonem map file name
my %labmap=();                                                                  # VM phonem map
print "Using VM lexicon directory: \"$lexicon_dir\"\n";                         # Protocol
print "Using file list directory: \"$flist_dir\"\n";                            # Protocol
print "Using UASR lexicon directory: \"$lex_dir\"\n";                           # Protocol
print "Using label file directory: \"$lab_dir\"\n";                             # Protocol
print "Using label map file directory: \"$labmap\"\n";                          # Protocol

## Functions ###################################################################

## Find or create a directory in uasr_home
##
## @param req string
##          base name of requested directory
## @return string
##           Full directory name
sub get_dir {
	my $req=shift;                                                                # Requiered directory name
	my $dire="data/".$db."/".$exp."/".$req;                                       # Dir. name in exp. dir.
	my $dirc="data/".$db."/common/".$req;                                         # Dir. name in common dir.
	return $dire if -d $uasr_home."/".$dire;                                      # Exp. dir. exists => use
	return $dirc if -d $uasr_home."/".$dirc;                                      # Common dir. exists => use
	mkdir $uasr_home."/".$dire;                                                   # Create dir. in exp. dir.
	return $dire;                                                                 # Use created dir.
}

## Map and convert phonem labels from VM format to UASR format
##
## @param _ list of strings
##            list of phonems to convert
## @return string
##           comma seperated list of phonems
sub convert_labels {
	my $out="";                                                                   # Start with empty output
	foreach(@_) {                                                                 # Loop over input list (phonems) >>
		$_=~s/^_//;                                                                 # Remove all "_"
		print STDERR "ERROR: Label \"$_\" not found in label map\n"                 #   If phonem not in map and not "usb"
			if !$labmap{$_} && $_ ne "usb";                                           #   | return error
		$_="#" if $_ eq "usb";                                                      #   Replace "usb" with "#"
		$_=$labmap{$_};                                                             #   Map phoneme according VM map
	}                                                                             # <<
	$out=join ",",@_;                                                             # Combine to csv-string
	return $out;                                                                  # return result
}

## Main Programm ###############################################################

# Create label maping                                                           # --------------------------------------
print "Reading VM phoneme map file\n";                                          # Protocol
open LM,"<".$uasr_home."/".$labmap;                                             # Open phoneme map file
while(<LM>) {                                                                   # Loop over lines in map >>
	chomp $_;                                                                     #   Remove newline at end of line
	next if $_!~/^[\t ]*([a-zA-Z0-9:~%@<>]+)[\t ]+([a-zA-Z0-9:#@.]+)[\t ]*$/;     #   Valid entry with two columns?
	$labmap{$1}=$2;                                                               #   Save to phoneme map
}                                                                               # <<
close LM;                                                                       # Close phoneme map file

# Get lexicon dir                                                               # --------------------------------------
print "Reading directory lexicon\n";                                            # Protocol
opendir FD,$uasr_home."/".$lexicon_dir;                                         # Open VM lexicon directory
my @lexicon_dir=readdir FD;                                                     # Read directory
closedir FD;                                                                    # Close directory

# Read all lexicon files in dir and convert labels                              # --------------------------------------
my %lex=();                                                                     # Global lexicon map (ort. => phoneme repr.)
foreach my $lexicon (@lexicon_dir) {                                            # Loop over all VM lexicon files >>
	next if $lexicon!~/.lex$/;                                                    #   File has wrong extension => next file
	print "Reading lexicon ".$lexicon."\n";                                       #   Protocol
	open FD,"<".$uasr_home."/".$lexicon_dir."/".$lexicon;                         #   Open VM lexicon file
	while(<FD>) {                                                                 #   Loop over lines in file >>
		chomp $_;                                                                   #     Remove newline at end of line
		my @line=split /[\t ]+/,$_;                                                 #     Split columns
		next if @line<2;                                                            #     Less than 2 col. => next line
		my $ort=shift @line;                                                        #     Get ortographic repr. from 1. col.
		$ort=~s/^\'|\'$//g;                                                         #     Remove "'" or "'$" from repr.
		my $lex=&convert_labels(@line);                                             #     Convert phonem repr. from other columns
		$lex="#" if $lex eq "";                                                     #     Use garbage for empty phonem repr.
		$lex{$ort}->{$lex}=1;                                                       #     Enter both repr. in lexicon map
	}                                                                             #   <<
	close FD;                                                                     #   Close lexicon file
}                                                                               # <<

# Get flist dir                                                                 # --------------------------------------
print "Reading directory flist\n";                                              # Protocol
opendir FD,$uasr_home."/".$flist_dir;                                           # Open file list directory
my @flist_dir=readdir FD;                                                       # Read directory
closedir FD;                                                                    # Close directory

# Reading file list                                                             # --------------------------------------
my %flist=();                                                                   # Global file list map (file => file list)
foreach my $flist_file (@flist_dir) {                                           # Loop over all file list files >>
	next if $flist_file!~/^([A-Za-z0-9_-]+).(flst|txt)$/;                         #   File has wrong extension => next file
	my $flist=$1;                                                                 #   Get basename of file list
	print "Reading flist ".$flist."\n";                                           #   Protocol
	open FD,"<".$uasr_home."/".$flist_dir."/".$flist_file;                        #   Open file list file
	while(<FD>) {                                                                 #   Loop over lines in file >>
		chomp $_;                                                                   #     Remove newline at end of line
		next if $_ eq "";                                                           #     Line empty => next line
		$_=~s/^[\t ]+|[\t ]+$//g;                                                   #     Remove free spaces
		$flist{$_}->{$flist}=1;                                                     #     Enter file list under file in map
	}                                                                             #   <<
	close FD;                                                                     #   Close file list file
}                                                                               # <<

# Get lex per file list                                                         # --------------------------------------
my @flist=sort keys %flist;                                                     # Get sorted list of files
my %lexlist=();                                                                 # Global lexicon map (file list => ort. repr.)
for(my $i=0;$i<@flist;$i++) {                                                   # Loop over all files >>
	printf "Reading partitur %6i/%i\n",$i+1,$#flist if ($i+1)%1000==0;            #   Protocol
	my $file=$flist[$i];                                                          #   Get current file
	open FD,"<".$uasr_home."/".$lab_dir."/".$file.".par";                         #   Open partiture file
	while(<FD>) {                                                                 #   Loop over all lines of partiture >>
		chomp $_;                                                                   #     Remove newline at end of line
		next if $_!~/^[\t ]*ORT:/;                                                  #     Search for ort. repr. (otherwise next)
		my @line=split /[\t ]/,$_,3;                                                #     Split columns
		my $ort=$line[2];                                                           #     Get ort. repr. from second column
		foreach my $flist (keys %{$flist{$file}}) {                                 #     Loop over all file list of cur. file >>
			$lexlist{$flist}->{$ort}=1;                                               #       Enter ort. repr. under file list
		}                                                                           #     <<
	}                                                                             #   <<
	close FD;                                                                     #   Close partiture file
}                                                                               # <<

# Create lex directory if necessary                                             # --------------------------------------
mkdir $lex_dir if ! -d $lex_dir;                                                # Create lex dir. if necessary

# Write lex files                                                               # --------------------------------------
foreach my $name (keys %lexlist) {                                              # Loop over all file lists >>
	my %lexn=%{$lexlist{$name}};                                                  #   Get 
	print "Write lexicon lex/".$name.".txt\n";                                    #   Protocol
	open FD,">".$uasr_home."/".$lex_dir."/".$name.".txt";                         #   Open UASR lexicon file
	foreach my $ort (sort keys %lexn) {                                           #   Loop over all ort. repr in file list >>
		my @labels=keys %{$lex{$ort}};                                              #     Get phonem labels
		print STDERR "Word \"$ort\" has ".(@labels+0)." Representations\n"          #     Print error if more than one phonem
			if @labels>1;                                                             #     | sequence exists
		my $kan=join ";",@labels;                                                   #     Join phonem labels sequences
		$kan=~s/;$//;                                                               #     Remove ";" at end of string
		printf FD "%-20s %-20s %i\n",$ort,$kan,$defpenalty;                         #     Write word in lexicon file
	}                                                                             #   <<
	close FD;                                                                     #   Close lexicon file
}                                                                               # <<

