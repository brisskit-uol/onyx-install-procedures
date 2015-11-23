#!/usr/bin/perl
################################################################
#
# BrisskitDAGbuilder.pl
#
# This script reads in a tab separated file as input and outputs XML (refined-metadata.xml) in a format that can be loaded into i2b2 with Jeff's scripts
#
# Usage: treebuilderBrisskit.pl [input filename] [code source] [OPTIONAL: nominal ontology root]
#
# All underscores in the "nominal ontology root" string will be converted to spaces
#
# Problems encountered with BioPortal web services are written to error.log
#
# While we can detect that there is no hierarchy service for an ontology we can not detect if the hierarchy service is correct.  For example, we know that there can be a problem with the SNOMED DAG after looking at the output, but this is not recorded in the log.
#
#################################################################

use strict;
use warnings;
use WebService::Simple;
use WebService::Simple::Parser::XML::Simple;
use XML::Simple;
use Data::Dumper;
use XML::Writer;
use IO::File;
use Tree::DAG_Node;
use POSIX qw/strftime/;

####################################################################
#	Varibles to set
#
# infile e.g. RFcode_file.txt
my $infile = $ARGV[0];
#
# source of codes e.g. onyx - this is the container name for the i2b2 xml
my $codesource = $ARGV[1];
#
# output file e.g. RobsOBO.obo
my $outputxmlfile = IO::File->new(">refined-metadata.xml");
#
# error log filename
my $errlog = "error.log";
#
# the root for any "unknown" terms
my $unknownroot="Nominal Ontology";
$unknownroot = $ARGV[2] if defined $ARGV[2];
$unknownroot =~ s/ /_/g;
#
# xmlns:omr variable for the i2b2 xml
my $xmlns_omr="http://brisskit.org/xml/onyxmetadata-refined/v1.0/omr";
#
# OBO outputfile - temporary!
my $outputfile="refined-metadata.obo";
#
#####################################################################
if (@ARGV<2){
	print "usage: treebuilderBrisskit.pl [input filename] [code source] [OPTIONAL: nominal ontology root]\n";
	exit;
}
my %allpathshash;
my %ontologyidsHoH;
my %unknownstrings;
my %rootnode;
my %fullpathhash;
my %bioportaltermhash;
my %treerootlabels;
my %pathmap=();
my %suppliedid2codes;
my %suppliedid2types;
my %labelstypes;
my %labelscodes;
my $errorstring='';

# date and time for the logs
my $timestamp = strftime('%d:%m:%Y %H:%M',localtime); ## outputs 17-12-2008 10:08

#### create a new DAG root #####
my $root = Tree::DAG_Node->new();
$root->name($codesource);
my $address=$root->address;
$pathmap{$codesource}=$address;
##################################

############ 1: Read in the tab file of codes #####################
open FILE, "<$infile" or die $!;
while (my $text = <FILE>) { 
	chomp $text;
	#$text =~ s/\r\n/\n/g;
	$text =~ m/(.+)\t(.+)\t(.+)\t(.+)\t(.+)/;
	my $idtype=$1; 
	my $code=$2;
	my $toplabel=$3;
	my $codefori2b2=$4;
	my $type=$5;
	
	$suppliedid2codes{$code}=$codefori2b2 unless exists $suppliedid2codes{$code};
	
	$suppliedid2types{$code}=$type unless exists $suppliedid2types{$code};	
	
	if ($idtype eq 'UNKNOWN'){
		# take the last value and put in the code and type hashes 
		$code =~ m/\.([\w\-]+)$/;
		my $lastterm=$1;
		$labelstypes{$lastterm}=$type;
		#replace a period with a pipe - Onyx does not like pipes!
		$code =~ s/\./|/g;
		
		# add 2 bangs and the code to the end of the string
		$code = $code."!!$codefori2b2";
		
		# RELATIVES_CVA_TREATMENT|PNA!!CBO:534543535 => 1
		$unknownstrings{$code}=1;
	}
	else{
		# 1353 => 59978006 => SNOMED-CT
		#	   => 82302008 => SNOMED-CT
		# 1516 => I00-I99.9	=> ICD10
		$ontologyidsHoH{$idtype}->{$code}=$toplabel;
	}
}
close(FILE); 

############ 2: Deal with the bioportal terms #####################

# Loop through the bio portal ontologies
for my $currentvirtualid ( keys %ontologyidsHoH ) {
	# find if the given ontology id matches that in BioPortal
	eval{
		# Use BioPortal webservice to get the latest version id and name for the ontology
		my $currentversionidandname_ref=getversionid($currentvirtualid);
		my %currentversionidandname = %$currentversionidandname_ref;
		my $ontologyrootterm=$currentversionidandname{'name'};
		$ontologyrootterm =~ s/ /_/g;
		my $currentversionid=$currentversionidandname{'id'};
		# 1353 => SNOMED Clinical Terms
		$treerootlabels{$currentvirtualid}=$ontologyrootterm unless exists $treerootlabels{$currentvirtualid};
		# find if there are hierarchy services for this ontology
		my $result = restexists($currentvirtualid);
		# if hierarchy services exist then use them!
		if ($result eq 'yes'){
			# make a hash of all the ids for this virtual ontology id
			my %currentids=();
			for my $id ( keys %{ $ontologyidsHoH{$currentvirtualid} } ) {
     			$currentids{$id}=1;
			}	
			my $currentids_ref=\%currentids;
			# Get labels and paths for the bioportal terms
			my $labelpathhash_ref=bioportalpathsandlabels($currentvirtualid,$currentversionid,$currentids_ref,$ontologyrootterm);
#			my %hash = %$labelpathhash_ref;
			# form the paths of all terms and subterms for the ontology strings
			makepaths($ontologyrootterm,$labelpathhash_ref,'\|','[\w\s\-_\+\(\)\/<>\,:\.]+');
			addtoDAG($ontologyrootterm,$labelpathhash_ref);
		}
		# no hierarchy services so simply list the terms under the created ontology root
		else{
			# add the lack of hierarchy services to the log
			my $logstring="No BioPortal hierarchy service found for ". $ontologyrootterm ." (BioPortal virtual ontology ID: ".$currentvirtualid.") [ ".$timestamp." ]";
			addtolog("user",$logstring);
			my %orphanpaths=();
			# get term details for the submitted codes
			for my $id ( keys %{ $ontologyidsHoH{$currentvirtualid} } ) {
				# if an error is returned record the problem in the log file
				eval {
					my $gettermname=gettermdetails($currentversionid, $id);
					$orphanpaths{$gettermname}=$gettermname;
					# hash of labels to codesfori2b2
					$labelscodes{$id}=$suppliedid2codes{$id} unless exists $labelscodes{$id};
					# hash of labels to types
					$labelstypes{$id}=$suppliedid2types{$id} unless exists $labelstypes{$id};
				};
				if ($@) {
     				my $logstring="No term with the submitted ID of \"". $id ."\" could be found in the latest version of ". $ontologyrootterm ." (BioPortal ontology ID: ".$currentversionid.") [ ".$timestamp." ]";
     				addtolog("user",$logstring);
     			}     			
			}
			my $orphanpaths_ref=\%orphanpaths;
			makepaths($ontologyrootterm,$orphanpaths_ref,'\|','[\w\s\-_\+\(\)\/<>\,:\.]+');
			addtoDAG($ontologyrootterm,$orphanpaths_ref);				
		}
	};
	if ($@) {
     	my $logstring="No ontology was found with the virtual ID of ". $currentvirtualid ." [ ".$timestamp." ]";
     	addtolog("user",$logstring);
     }
}


############ 3: Deal with the unknown terms #####################
# set the root term for any unknown concepts
$treerootlabels{'UNKNOWN'}=$unknownroot unless exists $treerootlabels{'UNKNOWN'};

if (keys( %unknownstrings ) >= 1){
	my $unknownstrings_ref=\%unknownstrings;
	my $unknownrootterm = $treerootlabels{'UNKNOWN'};

	# form the paths of all terms and subterms for the unknown strings
	makepaths($unknownrootterm,$unknownstrings_ref,'\|','[\w\d\-!:\.]+');

	addtoDAG($unknownrootterm,$unknownstrings_ref);
	
	# set the root term for any unknown concepts
	$treerootlabels{'UNKNOWN'}=$unknownroot unless exists $treerootlabels{'UNKNOWN'};
}


############ 4: Write the obo file #####################
# Note: this is left from BioDAG Builder - maybe not needed for BRISSkit?

open FILEOUT, ">$outputfile" or die $!; 
print FILEOUT "format-version: 1.2 \n";
print FILEOUT "date: $timestamp \n";
print FILEOUT "saved-by: BRISSkit DAG Builder \n";
print FILEOUT "auto-generated-by: BRISSkit DAG Builder \n\n";
for my $userspecifiedtreename ( keys %treerootlabels ) {
	my $treeheading = $treerootlabels{$userspecifiedtreename};
	my $treeheadingwithspaces = $treeheading;
	$treeheadingwithspaces =~ s/_/ /g;
	print FILEOUT "[Term]\nid: $treeheading\nname: $treeheadingwithspaces\n\n";
}
# print the unknown and ontology rooots
for my $key ( sort keys %rootnode ) {
 	my $nodename= $key;
 	my $root= $rootnode{$nodename};
 	my $labelwithspaces=$nodename;
 	$labelwithspaces =~ s/_/ /g;
 	print FILEOUT "[Term]\nid: $nodename\nname: $labelwithspaces\nis_a: $root\n\n";
} 
# print all sub-root terms
foreach my $paths ( sort keys %allpathshash ) {
	foreach ( @{$allpathshash{$paths}} ) {
 		my $value = $_;
 		my $labelwithspaces=$value;
 		$labelwithspaces =~ s/_/ /g;
 		my $idstring=$paths."|".$value;
 		my $oboterm='';
		$oboterm ="[Term]\nid: " .$idstring."\nname: " .$labelwithspaces."\nis_a: " .$paths."\n\n";
		print FILEOUT $oboterm;
	}
}
close FILEOUT;

############ 5A: optionals (bug testing) ###################
# Note: remove from production code

# 1. generate a diagram of the DAG - only useful if the tree is small!
# my $diagram = $root->draw_ascii_tree;
# print map "$_\n", @$diagram;

# 2. dump all names in an indented list - this is the list used to make the XML
#print $root->dump_names;

# 3. for bug testing mainly - generates the label path and DAG address relationship e.g  BrissKitOntology|SNOMED-CT = 0:0
# for my $key ( sort keys %pathmap ) {
#	my $value = $pathmap{$key};
#	print "$key = $value \n";
#}

############ 5B: write the XML using the indented list option ##################

my $writer = XML::Writer->new(OUTPUT => $outputxmlfile, DATA_MODE => 1, DATA_INDENT => 1);
$writer->xmlDecl("UTF-8");
$writer->startTag("omr:container", "xmlns:omr" => $xmlns_omr,"name"=> $codesource);

my $currentpath='';
my @lines = $root->dump_names;
my $lineslength= @lines;
for (my $i = 0; $i < $lineslength; $i++) {
	# get the current node name
	my $value =$lines[$i];
	# match the indentation
	$value =~ m/^(\s*)/;
	my $valueindent=$1;
	# get the length of the indentation
	my $indentlength = length($valueindent);
	# remove quotes and whitespace from the name
	chomp($value);
	$value=~s/'//g;
	$value=~s/^\s*//;

	# get the name for the next node
	my $nextvalue = $lines[$i+1];
	# set the next vale name to nothing if not defined i.e. the last name in the list
	$nextvalue = '' unless defined $nextvalue;
	# match the indentation
	$nextvalue =~ m/^(\s*)/;
	my $nextvalueindent=$1;
	# get the length of the indentation
	my $nextvalueindentlength = length($nextvalueindent);
	
	# if the next value has less indentation - then current name is a variable (terminal node)
	if ($nextvalueindentlength < $indentlength){
		# if the value contains a CBO code then separate from the label
		if ($value =~ m/!!/){
			$value =~ m/(.+)!!(.+)/;
			my $cleanvalue=$1;
			my $code=$2;
			$writer->startTag("omr:variable", "name"=>"$cleanvalue", "code"=>"$code", "type"=>"$labelstypes{$cleanvalue}");
		}
		else{
			$writer->startTag("omr:variable", "name"=>"$value", "code"=>"$labelscodes{$value}", "type"=>"$labelstypes{$value}");
		}
		$writer->endTag("omr:variable");
		
		# difference between the indentation
		my $indentdifference=$indentlength-$nextvalueindentlength;
				
		# for every difference of 2 indents end the folder element and remove the end label from the path
		for (my $i = 0; $i < $indentdifference; $i = $i+2) {
				
			$writer->endTag("omr:folder");
		 		
			# remove the node from the current path
			$currentpath=updatepath($currentpath,"-");
		 }
	}
	
	# if the next element is at the same level then see if it is a terminal node
	elsif ($nextvalueindentlength == $indentlength){
		# add the node to the current path
		$currentpath=updatepath($currentpath,$value);
		# get the address for the current path
		my $addressstring = $pathmap{$currentpath};
		#see if node is terminal node
		my $node = $root->address($addressstring);
		my @descnames = map {$_->name} $node->descendants;
		my $descnamessize = @descnames;
		
		# no descendants so a variable
		if ($descnamessize == 0){ 
			# if the value contains a CBO code then separate from the label
			if ($value =~ m/!!/){
				$value =~ m/(.+)!!(.+)/;
				my $cleanvalue=$1;
				my $code=$2;
				$writer->startTag("omr:variable", "name"=>"$cleanvalue", "code"=>"$code", "type"=>"$labelstypes{$cleanvalue}");
			}
			else{
				$writer->startTag("omr:variable", "name"=>"$value", "code"=>"$labelscodes{$value}", "type"=>"$labelstypes{$value}");
			}
			$writer->endTag("omr:variable");
			
			# remove the node label from the current path
			$currentpath=updatepath($currentpath,"-");
		}
		
		# there are descendents so this is a folder
		else {
			# if this folder value matches an original code
			if (exists $labelscodes{$value}){
				$writer->startTag("omr:folder", "name"=>"$value", "code"=>"$labelscodes{$value}");
			}
			else{			
				$writer->startTag("omr:folder", "name"=>"$value");
			}
		}
	}
	
	# if next level has more indentation then this node is a folder
	else {
		# if this folder value matches an original code
		if (exists $labelscodes{$value}){
			$writer->startTag("omr:folder", "name"=>"$value", "code"=>"$labelscodes{$value}");
		}
		else{			
			$writer->startTag("omr:folder", "name"=>"$value");
		}
		# add the node to the current path
		$currentpath=updatepath($currentpath,$value);
	}
}
$writer->endTag("omr:container");
$writer->end();
$outputxmlfile->close();

# print the error log if it exists
if ($errorstring ne ''){
	open ERROROUT, ">$errlog" or die $!; 
	print ERROROUT "$errorstring";
	close ERROROUT;
}

# Final print statement
#print "Success! \n";

################# Sub routines ########################

# returns a hash containing the version id and official name of the ontology
sub getversionid{
	my($vontologyid) = @_;
	# REST ontology service - get latest version of an ontology id 
	my $xs = XML::Simple->new( KeyAttr => [], ForceArray => ['success','classBean'] );
	my $ontologymetadata = WebService::Simple->new(
   	base_url => "http://rest.bioontology.org/bioportal/virtual/ontology/$vontologyid",
    param    => { apikey => "6d7d7db8-698c-4a56-9792-107217b3965c", },
    response_parser => WebService::Simple::Parser::XML::Simple->new( xs => $xs ),
	);
	my %idandnamehash=();
	my $result_ontid = $ontologymetadata->get();
	my $output_ontid = $result_ontid->parse_response;
	my $ontologyid=$output_ontid->{data}->{ontologyBean}->{id};
	my $ontologyname=$output_ontid->{data}->{ontologyBean}->{displayLabel};
	$idandnamehash{'id'}=$ontologyid;
	$idandnamehash{'name'}=$ontologyname;
	return \%idandnamehash;
}	

# returns answer to whether hierarchy services exist for this ontology
sub restexists{
	my($vontologyid) = @_;
	# REST ontology service - get latest version of an ontology id 
	my $xs = XML::Simple->new( KeyAttr => [], ForceArray => ['success'] );
	my $ontologymetadata = WebService::Simple->new(
   	base_url => "http://rest.bioontology.org/obs/ontologies",
    param    => { apikey => "6d7d7db8-698c-4a56-9792-107217b3965c", },
    response_parser => WebService::Simple::Parser::XML::Simple->new( xs => $xs ),
	);
	my $result_list = $ontologymetadata->get();
	my $output_list= $result_list->parse_response;
	my $ontologyid=$output_list->{data}->{list}->{ontologyBean};
	my $numberofontologyid = @$ontologyid;
	for (my $i=0; $i<$numberofontologyid; $i++){
  		my $individualid=$output_list->{data}->{list}->{ontologyBean}->[$i]->{virtualOntologyId}; 		
  		if ($individualid eq $vontologyid){
  			my $individualstatus=$output_list->{data}->{list}->{ontologyBean}->[$i]->{status};
  			if ($individualstatus eq '28'){
  				return "yes";
  			}
  			else{
  				return "no";
  			}
  		}				
  	}
	return "no";
}

# get the labels for bioportal terms and all terms to the root
sub bioportalpathsandlabels{
	my($vontologyid,$ontversionid,$uniqueids,$specifiedontologyrootterm) = @_;
	my %labelpathhash;
	# REST rootpath service - for a term get the paths to root in the latest version of the ontology- uses the virtual id
	my $xs = XML::Simple->new( KeyAttr => [], ForceArray => ['success','classBean'] );
	my $bioportal = WebService::Simple->new(
   		base_url => "http://rest.bioontology.org/bioportal/virtual/rootpath/$vontologyid/",
    	param    => { delim => "|", apikey => "6d7d7db8-698c-4a56-9792-107217b3965c", },
    	response_parser => WebService::Simple::Parser::XML::Simple->new( xs => $xs ),
	);
	# go through the list of given ids for the bioportal terms
	for my $key ( keys %{$uniqueids} ) {
		my $suppliedtermid=$key;	
		eval{
			# get the label for the term in question
  			my $getsuppliedtermname=gettermdetails($ontversionid, $suppliedtermid);
  					
			$bioportaltermhash{$suppliedtermid}=$getsuppliedtermname unless exists $bioportaltermhash{$suppliedtermid};
		
			# hash of labels to codesfori2b2
			$labelscodes{$getsuppliedtermname}=$suppliedid2codes{$suppliedtermid};
		
			# hash of labels to types
			$labelstypes{$getsuppliedtermname}=$suppliedid2types{$suppliedtermid};
		
			# get the paths from root to the term in question
  			my $result = $bioportal->get( $suppliedtermid, {} );
  			my $output = $result->parse_response;
  		
  			# find if there is a path
  			my $thereisapath=$output->{data}->{list}->{classBean};
  		
  			# there is a path - therefore find all parents
  			if (defined($thereisapath)){
        		for my $classbean ( @{$output->{data}->{list}->{classBean}} ) {
        			# parent path - raw output from the service call.  String of ids seperated by pipes
       				my $parentpath = $classbean->{relations}->{entry}->{string}->[1];       	
        			chomp($parentpath);
					my @array = split /\|/,$parentpath;
           			# reverse the array so we start with the immediate parent
           			my @reversedarray= reverse(@array);
           			my $string=0;
           			$string=@array;
           
           			# if 97289008|297464000|297477009|297484001
        			if ($string >1){
           				my $labelpath=$getsuppliedtermname;
           				foreach my $singletermcode (@reversedarray){
           					if (exists $bioportaltermhash{$singletermcode}){
        						$labelpath=$bioportaltermhash{$singletermcode}."|".$labelpath;
         					}
         					# haven't already seen this term, so need to find label using REST services
        					else{
        						eval{
  									my $gettermname=gettermdetails($ontversionid, $singletermcode);	
  									$labelpath=$gettermname."|".$labelpath;
  									$bioportaltermhash{$singletermcode}=$gettermname;
  								};
  								if ($@) {
     								my $logstring="No parent term with the ID of \"". $singletermcode ."\" could be found in ". $specifiedontologyrootterm ." (BioPortal virtual ontology ID: ".$vontologyid.")";
     								addtolog("user",$logstring);
     							}	
  							}
           				}
           				$labelpathhash{$labelpath}=$getsuppliedtermname;
					}
           
            		# if 97289008 - then only one parent
        			else{
           				# if term=>label already exists then use the hash - put in to speed things up!
        				if (exists $bioportaltermhash{$parentpath}){
        					my $labelpath=$bioportaltermhash{$parentpath}."|".$getsuppliedtermname;
        					$labelpathhash{$labelpath}=$getsuppliedtermname;
         				}
         				# haven't already seen this term, so need to find label using REST services
        				else{
        					eval{
        						# get the label for the term in question
  								my $gettermname=gettermdetails($ontversionid, $parentpath);	
  								my $labelpath=$gettermname.'|'.$getsuppliedtermname;
  								$bioportaltermhash{$parentpath}=$gettermname;
  								$labelpathhash{$labelpath}=$getsuppliedtermname;	
  							};
  							if ($@) {
     							my $logstring="No parent term with the ID of \"". $parentpath ."\" could be found in ". $specifiedontologyrootterm ." (BioPortal virtual ontology ID: ".$vontologyid.")";
 	  							addtolog("user",$logstring);
     						}				
  						}
        			}
				}
			}
			# $thereisapath is not defined - therefore this is a root term
			else{
        		my $labelpath=$getsuppliedtermname;
  				$labelpathhash{$labelpath}=$getsuppliedtermname;  						
        	}
		};
       	if ($@) {
     		my $logstring="No term with the submitted ID of \"". $suppliedtermid ."\" could be found in the latest version of ". $specifiedontologyrootterm ." (BioPortal ontology ID: ".$ontversionid.")";
     		addtolog("user",$logstring);
     	}
	}
	return \%labelpathhash
}
     
# stripped down version of the main treebuilder.pl script - just returns label NOT synonyms, definition etc
sub gettermdetails{
	my($ontversionid,$searchtermid) = @_;
	# REST term service - for a term get the label amongst other things - uses the latest ontology version id
	my $xs2 = XML::Simple->new( KeyAttr => [], ForceArray => ['success'] );
	my $termname = WebService::Simple->new(
   		base_url => "http://rest.bioontology.org/bioportal/concepts/$ontversionid",
    	param    => { apikey => "6d7d7db8-698c-4a56-9792-107217b3965c", },
    	response_parser => WebService::Simple::Parser::XML::Simple->new( xs => $xs2 ),
    	debug => 0,
	);
	my $result_termlabel = $termname->get({ conceptid => $searchtermid });
	my $output_termlabel = $result_termlabel->parse_response;
  	my $suppliedtermlabel=$output_termlabel->{data}->{classBean}->{label};
	return $suppliedtermlabel;
}   
     
# standardise the paths - add paths to %allpathshash and root terms to %rootnode
sub makepaths{
	my($currentrootterm,$hash_ref,$delimiter,$pattern) = @_;
	my %labelpathhash = %{$hash_ref};
	for my $key ( sort keys %{$hash_ref} ) {
 		my $value=$labelpathhash{$key};
 		if ($key =~ /$delimiter/){
 	 		my $keytocut=$key;
 	 		$keytocut =~ s/ /_/g;
 			while ($keytocut =~ /$delimiter/){
 				if ($keytocut =~ /^$pattern$delimiter$pattern$/){
 					$keytocut =~ m/^($pattern)$delimiter($pattern)$/;
 					my $root=$1;
 					my $secondterm=$2;
 					if (exists $fullpathhash{$keytocut}){
 						$keytocut =~ s/$delimiter($pattern)$//;
 					}
 					else{
 						$fullpathhash{$keytocut}=1;
 						$keytocut =~ s/$delimiter($pattern)$//;
 						$rootnode{$root}=$currentrootterm;
 						push@{$allpathshash{$keytocut}},"$secondterm";
 					}
 				}
 				else{ 			 			
 					$keytocut =~ m/$delimiter($pattern)$/;
 					my $singlelabel = $1;
 					if (exists $fullpathhash{$keytocut}){
 						$keytocut =~ s/$delimiter($pattern)$//;
 					}
 					else{
 						$fullpathhash{$keytocut}=1;
 						$keytocut =~ s/$delimiter($pattern)$//;
 						push@{$allpathshash{$keytocut}},"$singlelabel";
 					}	
 				}
 			}
 		}
 		# deal with no delimeter - root node was submitted
 		else {
 			$value =~ s/ /_/g;
 			$rootnode{$value}=$currentrootterm;
 		}
 	}
}

#  generate the DAG in memory
sub addtoDAG{
	my($rootlabel,$labelpathhash_ref,$delimiter) = @_;
	my %labelpathhash = %{$labelpathhash_ref};
	# generate the topnode for the ontology e.g. 'SNOMED-CT'
	my $topnode = Tree::DAG_Node->new({
					name => $rootlabel,
					mother => $root,
				});
	# get address for topnode
	my $address=$topnode->address;
	# start the path	
	my $pathstart=$codesource."|".$rootlabel;
	# add address to the pathmap hash
	$pathmap{$pathstart}=$address;
	# go through the hash and create an array of the full path
	for my $key ( sort keys %labelpathhash ) {
 		my $parent = $topnode;
 		my $fullpath=$key;
 		my @tmparray = split /\|/,$fullpath;
 		my $tmparraysize=@tmparray;
		my $path=$pathstart;
		my $parentname=$rootlabel;		
		# for each label starting from nearest root
		for (my $i = 0; $i < $tmparraysize; $i++)  {
			my $currentname=$tmparray[$i];
			# update the path to reflect where we are
			$path=$path."|".$currentname;
			# if we have seen this path before
			if (exists $pathmap{$path}){
				# get the current node object using the address for the current path 
				my $currentnode = $root->address($pathmap{$path});
				# change parent to the current node
				$parent = $currentnode;
			}
			else{
				# write the current node
				my $node = Tree::DAG_Node->new({
					name => $currentname,
					mother => $parent,
				});
				# get address for new node
				my $address=$node->address;
				# add address to the pathmap hash
				$pathmap{$path}=$address;
				# change parent to the current node
				$parent = $node;
			}
		}
	}
}

# keep track of the current term path
sub updatepath{
	my($currentpath,$status) = @_;
	my $path='';
	# if removing a label
	if ($status eq '-'){
		my @array = split /\|/,$currentpath;
		pop(@array);
		my $arraysize=@array;
		for (my $i=0; $i<$arraysize; $i++){
			# if first element then don't add the pipe at the start
			if ($i == 0){
				$path = $array[0];
			}
			else{
				$path = $path."|".$array[$i];
			}
		}
		$currentpath=$path;
	}
	# add a pipe and label to the path unless it is namespace
	else{
		if ($status eq $codesource){
			$currentpath=$status;
		}
		else {
			$currentpath=$currentpath."|".$status
		}
	}
	return $currentpath;
}

# add string to the error log
sub addtolog{
	my($logtype,$logstring) = @_;
	if ($logtype eq 'user'){
		open LOGOUT, ">>$errlog" or die $!; 
		print LOGOUT $logstring."\n";
		close LOGOUT;	
	}
	return;
}
