#!/usr/bin/env -S perl -T -w -Ilib

use strict;
use warnings;
use utf8;

use Test::More;
use Capture::Tiny ':all';

plan tests => 32;
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
    return CheckSpelling::LoadEnv::print_var_val('hello', 'world');
};
is($stdout, q<export INPUT_HELLO='world';
>, 'print_var_val out');
is($stderr, '', 'print_var_val err');
is(@result, 1, 'print_var_val result');

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
is($stdout, '', 'expect_array out');
is($stderr, '', 'expect_array err');
is(join (',', %{$result[0]}), '1,2', 'expect_array result');

($stdout, $stderr, @result) = capture {
    return CheckSpelling::LoadEnv::expect_map(\'hello', 'bad map');
};
is($stdout, '', 'bad expect_array out');
is($stderr, q<'bad map' should be a map (unsupported-configuration)
>, 'bad expect_array err');
is(%{$result[0]}, 0, 'bad expect_array result');

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
