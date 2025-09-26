#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;

use Cwd qw();
use Test::More;
use File::Temp qw/ tempfile tempdir /;
use Capture::Tiny ':all';

plan tests => 4;
use_ok('CheckSpelling::GitSources');

is(CheckSpelling::GitSources::github_repo(
    'https://github.com/some/thing.git'), 'some/thing');
is(CheckSpelling::GitSources::github_repo(
    'git@github.com:some/thing'), 'some/thing');
is(CheckSpelling::GitSources::github_repo(
    '../some/thing'), '');
