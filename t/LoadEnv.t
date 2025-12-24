#!/usr/bin/env -S perl -T -w -Ilib

use strict;
use warnings;
use utf8;

use Test::More;
use Capture::Tiny ':all';

plan tests => 39;
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
    return CheckSpelling::LoadEnv::expect_array('', 'empty');
};
is($stdout, '', 'empty expect_array out');
is($stderr, '', 'empty expect_array err');
is(@{$result[0]}, 0, 'empty expect_array result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::expect_array([1, 2], 'series');
};
is($stdout, '', 'expect_array out');
is($stderr, '', 'expect_array err');
is(join (',', @{$result[0]}), '1,2', 'expect_array result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::expect_array(\'hello', 'world');
};
is($stdout, '', 'bad expect_array out');
is($stderr, q<'world' should be an array (unsupported-configuration)
>, 'bad expect_array err');
is(@{$result[0]}, 0, 'bad expect_array result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::expect_map('', 'empty');
};
is($stdout, '', 'empty expect_map out');
is($stderr, '', 'empty expect_map err');
is(%{$result[0]}, 0, 'empty expect_map result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::expect_map({ 1 => 2}, 'map');
};
is($stdout, '', 'expect_map out');
is($stderr, '', 'expect_map err');
is(join (',', %{$result[0]}), '1,2', 'expect_map result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::expect_map(\'hello', 'bad map');
};
is($stdout, '', 'bad expect_map out');
is($stderr, q<'bad map' should be a map (unsupported-configuration)
>, 'bad expect_map err');
is(%{$result[0]}, 0, 'bad expect_map result');

my %mapped = CheckSpelling::LoadEnv::array_to_map([1,2]);
is($mapped{1}, 1, 'array_to_map index 1');
is($mapped{2}, 1, 'array_to_map index 2');
is(scalar keys %mapped, 2, 'array_to_map length');

my $json = '{"hello":"world"}';
open my $fh, '<', \$json;
my $parsed = CheckSpelling::LoadEnv::parse_config_file($fh);
is($parsed->{'hello'}, 'world', 'parse config file');

my $not_json = '';
open $fh, '<', \$not_json;
my $ref = CheckSpelling::LoadEnv::parse_config_file($fh);
is(ref $ref, 'HASH', 'parse_config_file fallback is ref');
is(keys %{$ref}, 0, 'parse_config_file fallback has no entries');

$ENV{INPUTS} = '{"hello":"world"}';
$ENV{action_yml} = 'action.yml';
my $load_config_from_key = 'load-config-from';
my $parsed_input = CheckSpelling::LoadEnv::parse_inputs($load_config_from_key);
my %parsed_inputs = %{$parsed_input};
my $maybe_load_inputs_from = $parsed_inputs{'maybe_load_inputs_from'};
my $load_config_from = $parsed_inputs{'load_config_from_key'};
my $input_map = $parsed_inputs{'input_map'};

is($maybe_load_inputs_from, undef, 'maybe_load_inputs_from');
is($load_config_from, $load_config_from_key, 'load_config_from_key');
like((join ", ", (sort keys %{$input_map})), qr{CHECK_EXTRA_DICTIONARIES.*, HELLO, .*WARNINGS}, 'input_map');
is(CheckSpelling::LoadEnv::get_json_config_path($parsed_input), '.github/actions/spelling/config.json', 'json_config_path');
