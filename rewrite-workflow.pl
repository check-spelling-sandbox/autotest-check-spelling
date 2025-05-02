#!/usr/bin/env perl
my $repo = $ENV{repo};
my $is_spell_check_this = $repo =~ m</spell-check-this>;
my $set_name = 0;

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
    my $indent = $1;
    print qq<$indent- uses: actions/checkout\@v4\n$1  with:\n$1    repository: $repo>;
    my $ignore_non_comment_lines = '$_ = "#\n" unless /^$|^# /';
    my $action_dir = q<$(find .github/actions/ -mindepth 1 -maxdepth 1 -type d -name 'spell*')>;
    if ($is_spell_check_this) {
      my $replacement = '# $1';
      my $code = qq?
    ref: prerelease
- name: enable checking spelling metadata
  shell: bash
  run: |
    : Rewrite spelling metadata
    perl -pi -e 's,(.*\.github/actions/spell),$replacement,' $action_dir/excludes.txt
    find .github/actions/spell* -name '*patterns*' -o -name reject.txt |
      xargs -r perl -pi -e '$ignore_non_comment_lines'
    curl -fsSL https://raw.githubusercontent.com/$ENV{GITHUB_REPOSITORY}/$ENV{GITHUB_REF}/shims/$repo/.github/actions/spelling/allow.txt |
      tee -a "$action_dir/allow.txt" > /dev/null || true
    git diff || true
?;
      $code =~ s/^/$indent/gm;
      print $code;
    } else {
      print "\n";
    }
    $mode = 0;
  }
  $set_name = 1 if s/^(name: .*)/$1 ($repo)/;
  s/^(\s*cancel-in-progress:).*/$1 false/;
  s/(^\s+checkout:) true/$1 false/;
  print;
}
unless ($set_name) {
  print;
  print "name: ? Check Spelling ($repo)\n";
}
