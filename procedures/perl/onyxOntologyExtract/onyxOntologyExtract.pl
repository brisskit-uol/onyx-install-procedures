#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);
use XML::Simple;
use Data::Stag qw(:all);
use FindBin;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
use Digest::MD5 qw(md5_hex);
use Getopt::Euclid qw( :minimal_keys );
my $DEBUG = 1;

my $input = $ARGV{input}
  || die
"Please provide an input ZIP archive file OR a directory containing ZIP archive files";
my $output_path = $ARGV{output} || die "Please provide an output directory";

my @files = ();
-e $input or die "$input file or directory does not exist";
if ( -d $input ) {
	INFO "Input '$input' is a directory";
	@files = glob( $input . "/*.zip" );
	INFO "Files to be processed:" . join( "\n", @files );
}
else {
	@files = ($input);
}

my %ont_data = get_ont_data_from_file("$FindBin::Bin/ontologies.xml");

my $temp_path = get_temp_path();

#open output file to print extracted codes to
if (!$ARGV{s}) {
open CODE_FILE, ">", $temp_path . "/code_file.txt";

INFO
  "Open temporary code file at $temp_path/code_file.txt";
}
foreach my $archive_file (@files) {
	my $unarchive_path = extract_onyx_archive( $archive_file, $temp_path );
	my $sep_file;
	if ($ARGV{s}) {
		$sep_file = basename($archive_file);
		$sep_file=~s/\..+$//;
		open CODE_FILE, ">", $temp_path . "/$sep_file.txt";
		INFO
	  "Open temporary code file at $temp_path/$sep_file.txt";
	}
	
	
	
	#read and parse questionnaire.xml file into Data::Stag
	my $qxml_file = $unarchive_path . "/questionnaire.xml";
	-e $qxml_file or die "$qxml_file file does not exist";
		
	my $qxml      = Data::Stag->parse($qxml_file) or die "Unable to parse $qxml_file";

	#get questionnaire name
	my @questionnaires = $qxml->findnode('questionnaire');
	my $questionnaire  = $questionnaires[0];
	my $quest_name     = $questionnaire->get('@')->get('name');
	
	

	#find all section elements
	my @sections = $qxml->findnode('section');
	my $line_no  = 0;
	foreach my $section (@sections) {
		my $sect_name = $section->get('@')->get('name');

		#find all category elements
		my @questions = $section->findnode('question');
		my %prev_codes;

		#loop through each question, pulling out the categories
		foreach my $question (@questions) {
			my @categories = $question->findnode('category');
			my $qname      = $question->get('@')->get('name');
			my $qtype      = $question->get('@')->get('type') || "BOOLEAN";

		   #loop through each category element and pull out the 'name' attribute
			foreach my $cat (@categories) {
				my $cat_name    = $cat->get('@')->get('name');
				my $extract_val = $cat_name;
				my $openansdef  = $cat->get('openAnswerDefinition');

				my $datatype = "BOOLEAN";

				my $spath;

				if ($openansdef) {
					$datatype    = $openansdef->get('@')->get('dataType');
					$extract_val = $openansdef->get('@')->get('name');
				}

				my ( $bioportal_id, $code, $field, $ont_desc, $i2b2_code ) =
				  determine_bioportal_info($extract_val);

				if ($openansdef) {
					$spath =
					    $qname . "."
					  . $cat_name . "."
					  . ( $field || $extract_val );
				}
				else {
					$spath = $qname . "." . ( $field || $extract_val );
				}

				my $md5_qpath = md5_hex($spath);

#if there is an ontology code and it hasn't been seen before, print it to the output file
#otherwise print the question category question and name
				if ( $bioportal_id && $code ) {
					if ( !$prev_codes{$code} ) {
						print CODE_FILE
"$bioportal_id\t$code\t$ont_desc\t$i2b2_code\t$datatype\n";

						$prev_codes{$code} =
						  1;    #mark this code as previously seen
						$cat_name = $field;
					}
				}

				$md5_qpath = $i2b2_code ? $i2b2_code : "CBO:$md5_qpath";
				print CODE_FILE "UNKNOWN\t$sect_name.$spath\t"
				  . $quest_name
				  . "\t$md5_qpath\t$datatype\n";
			}
		}
	}
	if ($ARGV{s}) {
		close CODE_FILE;
		INFO "Copy temporary file $temp_path/$quest_name.txt to output path ".$ARGV{output};
		system "cp $temp_path/$sep_file.txt ".$ARGV{output};
	}
}

#close output file
if (!$ARGV{s}) {
	close CODE_FILE;
	INFO "Copy temporary file $temp_path/code_file.txt to output path ".$ARGV{output};
	system "cp $temp_path/code_file.txt ".$ARGV{output};
}
exit 0;

sub determine_bioportal_info {
	my ($cat_name) = @_;

#use regex to pull the code from the category name (look for two characters, a possible third character, then at least one number, followed by anything at the end of the name)
	$cat_name =~ /^(.+)__([A-Z]{2}[A-Z]*\d+.+)$/;
	my ( $field, $ont_and_code ) = ( $1, $2 );

	#extract the two letter prefix followed by anything
	return if !$ont_and_code;
	$ont_and_code =~ /^([A-Z]{2})(.+)?$/;
	my ( $ont, $code ) = ( $1, $2 );

	#use the ont prefix to get information from the ontology config
	my $ont_item     = $ont_data{$ont};
	my $bioportal_id = $ont_item->{bioportal_id};
	my $desc         = $ont_item->{description};
	my $find         = $ont_item->{find};
	my $replace      = $ont_item->{replace};
	my $onyx_prefix  = $ont_item->{onyx_prefix};
	my $add_prefix   = $ont_item->{add_prefix};
	( $find && $replace )
	  and $code =~ s/$find/$replace/
	  ;    #do and search/replace operations required (e.g. substitute _ for .)
	my $i2b2_code = $ont . ":" . $code;
	$add_prefix
	  and $code = $add_prefix
	  . $code;    #add an additional prefix to the code if one is specified
	return ( $bioportal_id, $code, $field, $desc, $i2b2_code );
}

sub get_ont_data_from_file {
	my ($ont_file) = @_;

	#parse the ontology.xml config file
	my $ont_xml    = Data::Stag->parse($ont_file);
	my @ontologies = $ont_xml->findnode('ontology');

	#get the pertinent information for each ontology and place in a hash
	foreach my $o (@ontologies) {
		my $oattrs   = $o->get('@');
		my $ont_item = {
			add_prefix   => $oattrs->get('add_prefix'),
			bioportal_id => $oattrs->get('bioportal_id'),
			description  => $oattrs->get('description'),
			find         => $oattrs->get('find'),
			replace      => $oattrs->get('replace'),
		};
		$ont_data{ $oattrs->get('onyx_prefix') } = $ont_item;
	}
	return %ont_data;
}

sub get_temp_path {
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
	  localtime(time);
	my $work_dir = sprintf "%4d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1,
	  $mday, $hour, $min, $sec;
	my $output_path = "$FindBin::Bin/temp/$work_dir"
	  ;    #output location based on the ZIP file name
	  make_path($output_path);
	return $output_path;
}

sub extract_onyx_archive {
	my ( $zip_file, $temp_path ) = @_;
	my ( $name, $path, $suffix ) = fileparse($zip_file);
	$name =~ s/\..+//;
	$output_path = $temp_path . "/$name";

	#make path to output extracted zip to
	make_path($output_path);
	INFO "Extract file $zip_file => $output_path\n";

	#extract zip file to path
	system "unzip $zip_file -d $output_path";
	return $output_path;
}

__END__


=head1 NAME

  onyxOntologyExtract.pl

=head1 VERSION

  0.1

=head1 DESCRIPTION

  Takes an Onyx questionnaire definition ZIP file or a directory containing a number of such files, with specifically encoded BioPortal Ontology terms
  Result is a 'code_list.txt' tab-delimited file or files containing just a list of extracted ontology terms.

=head1 USAGE

  [ignored, usage line is built by Getopt::Euclid from interface-description below]

=head1 REQUIRED ARGUMENTS

=over


=item <input>

  Input ZIP archive file OR a directory containing ZIP archive files

=item -o[utput] <output>

  Output directory (will be created if it does not exist) for code_file.txt

=back

=head1 OPTIONS

=over

=item -s[eparate]

  Create separate output files for each input archive file.

=item --version

=item --usage

=item --help

=item --man

  Print the usual program information

=back

=head1 AUTHOR

  Rob Free <rcfree@gmail.com>>

=head1 BUGS

  None known, but please report any to the author

=cut

