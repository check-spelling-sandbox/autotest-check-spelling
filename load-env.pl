#!/usr/bin/env perl
use 5.022;
use CheckSpelling::LoadEnv;

my $parsed_inputs = CheckSpelling::LoadEnv::parse_inputs();

my %input_map = %{$parsed_inputs->{'input_map'}};
for my $var (sort keys %input_map) {
    next if $var eq 'INTERNAL_STATE_DIRECTORY' && $input_map{$var} eq '';
    CheckSpelling::LoadEnv::print_var_val($var, $input_map{$var});
}
