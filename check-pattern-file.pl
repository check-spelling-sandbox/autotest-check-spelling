#!/usr/bin/env perl

use CheckSpelling::CheckPattern;

my $file = $ENV{file};
open WARNINGS, ">>:encoding(UTF-8)", $ENV{early_warnings};
$extension = '.orig';
LINE: while (<>) {
  if ($ARGV ne $oldargv) {
    if ($extension !~ /\*/) {
      $backup = $ARGV . $extension;
    }
    else {
      ($backup = $extension) =~ s/\*/$ARGV/g;
    }
    rename($ARGV, $backup);
    open(ARGVOUT, ">$ARGV");
    select(ARGVOUT);
    $oldargv = $ARGV;
  }

  my ($line, $warning) = CheckSpelling::CheckPattern::process_line($_);
  print "$line\n";
  if ($warning) {
    print WARNINGS "$file:$.:$warning";
  }
}
select(STDOUT);

close(WARNINGS);
