#!/usr/bin/env perl
use 5.022;
use CheckSpelling::LoadEnv;

my $parsed_inputs = CheckSpelling::LoadEnv::parse_inputs();

my %inputs = %{$parsed_inputs->{'inputs'}};
for my $var (sort keys %inputs) {
    next if $var eq 'INTERNAL_STATE_DIRECTORY' && $inputs{$var} eq '';
    CheckSpelling::LoadEnv::print_var_val($var, $inputs{$var});
}
