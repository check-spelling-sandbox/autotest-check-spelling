#!/usr/bin/env -S perl -T

use warnings;
use CheckSpelling::SpellingCollator;

binmode STDOUT, ':encoding(UTF-8)';

CheckSpelling::SpellingCollator::main();
