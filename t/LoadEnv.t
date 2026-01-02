#!/usr/bin/env -S perl -T -w -Ilib

use strict;
use warnings;
use utf8;

use Test::More;
use Capture::Tiny ':all';

plan tests => 21;
use_ok('CheckSpelling::LoadEnv');

{
    my ($k, $v) = CheckSpelling::LoadEnv::escape_var_val("test", "case");
    is($k, 'TEST', 'basic key');
    is($v, 'case', 'basic value');

    ($k, $v) = CheckSpelling::LoadEnv::escape_var_val("test-ing", q<ev"c$a's\\e
me>);
    is($k, 'TEST_ING', 'dashed key');
    is($v, q<ev"c\$a'"'"'s\e>."\n".'me', 'evil value');
}

my ($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::print_var_val('HELLO', 'world');
};
is($stdout, q<export INPUT_HELLO='world';
>, 'proper print_var_val out');
is($stderr, '', 'proper print_var_val err');
is(@result, 1, 'proper print_var_val result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::print_var_val('hello', 'world');
};
is($stdout, '', 'improper print_var_val out');
is($stderr, "Found improperly folded key in inputs 'hello'\n", 'improper print_var_val err');
is(@result, 0, 'improper print_var_val result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::print_var_val('HELLO', '');
};
is($stdout, '', 'empty print_var_val out');
is($stderr, '', 'empty print_var_val err');
is(@result, 0, 'empty print_var_val result');

my $json = '{"hello":"world"}';
open my $fh, '<', \$json;
my $parsed = CheckSpelling::LoadEnv::parse_config_file($fh);
is($parsed->{'hello'}, 'world', 'parse config file');

my $not_json = '';
open $fh, '<', \$not_json;
my $ref = CheckSpelling::LoadEnv::parse_config_file($fh);
is(ref $ref, 'HASH', 'parse_config_file fallback is ref');
is(keys %{$ref}, 0, 'parse_config_file fallback has no entries');

$ENV{INPUTS} = '{"hello":"world", "ignore-pattern":""}';
$ENV{action_yml} = 'action.yml';
my $parsed_input = CheckSpelling::LoadEnv::parse_inputs();
my %parsed_inputs = %{$parsed_input};
my $inputs = $parsed_inputs{'inputs'};

is($inputs->{'IGNORE_PATTERN'}, '', 'ignore pattern (empty value should suppress fallback)');

like($inputs->{'DICTIONARY_URL'}, qr{https://}, 'dictionary url');
like((join ", ", (sort keys %{$inputs})), qr{CHECK_EXTRA_DICTIONARIES.*, HELLO, .*WARNINGS}, 'input_map');
is(CheckSpelling::LoadEnv::get_json_config_path($parsed_input), '.github/actions/spelling/config.json', 'json_config_path');
