#!/usr/bin/env perl
use File::Basename;
use CheckSpelling::Apply;

my $dirname = dirname(dirname(__FILE__));

CheckSpelling::Apply::main("$dirname/apply.pl", $CheckSpelling::Apply::bash_script, @ARGV);
