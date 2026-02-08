#!/usr/bin/env -S perl -Ilib

use CheckSpelling::SpellingCollator;

CheckSpelling::SpellingCollator::collate_expect(@ARGV);
