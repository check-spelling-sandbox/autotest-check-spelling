#!/usr/bin/env perl
use 5.022;
use CheckSpelling::LoadEnv;

my $parsed_inputs = CheckSpelling::LoadEnv::parse_inputs();

my %inputs = %{$parsed_inputs->{'inputs'}};
for my $var (sort keys %inputs) {
    CheckSpelling::LoadEnv::print_var_val($var, $inputs{$var});
}
