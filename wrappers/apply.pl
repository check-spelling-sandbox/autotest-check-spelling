#!/usr/bin/env perl
use CheckSpelling::Apply;

CheckSpelling::Apply::main($0 ne '-' ? $0 : 'apply.pl', $CheckSpelling::Apply::bash_script, @ARGV);
