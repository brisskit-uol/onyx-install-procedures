#make file for onyxOntologyExtract script

use inc::Module::Install;

name     'OnyxOntologyExtract';
author   q{"Rob Free" <"rcf8@le.ac.uk">};
include 'Module::AutoInstall';

license  'perl';
version '1.00';
requires 'Archive::Extract';
requires 'File::Basename';
requires 'File::Path';;
requires 'XML::Simple';
requires 'Data::Stag';
requires 'FindBin';
requires 'Log::Log4perl';
requires 'Digest::MD5';
requires 'Getopt::Euclid';
test_requires  'Test::More';

auto_install();

WriteAll;

