#!/usr/bin/env perl
while (<>) {
  if (/^(\s*)steps:/) {
    $depth = $1;
    $mode = 1;
  } elsif (/^(\s*)concurrency:/) {
    $depth = $1;
    $mode = 2;
    $_ = "";
  } elsif ($mode == 2 && /^$depth\s/) {
    $_ = "";
  } elsif ($mode == 2 && /^(\s+)\w.*:/) {
    $mode = 0;
  } elsif ($mode == 1 && /^(\s*)-/) {
    print qq<$1- uses: actions/checkout\@v4\n$1  with:\n$1    repository: $ENV{repo}\n>;
    $mode = 0;
  }
  s/^(name: .*)/$1 ($ENV{repo})/;
  s/^(\s*cancel-in-progress:).*/$1 false/;
  s/(^\s+checkout:) true/$1 false/;
  print;
}
