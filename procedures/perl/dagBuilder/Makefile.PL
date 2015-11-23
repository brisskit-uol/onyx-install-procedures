#make file for Brisskit DAG builder script

use inc::Module::Install;

name     'BrisskitDAGbuilder';
author   q{"Tim Beck" <"tb143@le.ac.uk">};
include  'Module::AutoInstall';

license  'perl';
version  '1.00';
requires 'Test::Builder';
requires 'XML::Parser::PerlSAX';
requires 'WebService::Simple';
requires 'WebService::Simple::Parser::XML::Simple';
requires 'XML::Simple';
requires 'XML::Writer';
requires 'IO::File';
requires 'Tree::DAG_Node';


auto_install();

WriteAll;