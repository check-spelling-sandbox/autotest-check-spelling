#!/usr/bin/env -S perl

use CheckSpelling::SpellingCollator;

CheckSpelling::SpellingCollator::collate_expect(@ARGV);
