#! -*-perl-*-

package CheckSpelling::CheckPattern;

use CheckSpelling::Util;

sub process_line {
    my ($file, $text, $line) = @_;
    chomp $text;
    return ($text, '') if $text =~ /^#/;
    return ($text, '') unless $text =~ /./;
    if (eval {qr/$text/}) {
        return ($text, '')
    }
    $@ =~ s/(.*?)\n.*/$1/m;
    my $err = $@;
    chomp $err;
    $err =~ s{^(.*?) in regex; marked by <-- HERE in m/(.*) <-- HERE.*$}{$2};
    my $code = $1;
    my $start = $+[2] - $-[2];
    my $end = $start + 1;
    my $wrapped = CheckSpelling::Util::wrap_in_backticks($err);
    return ("^\$\n", "$file:$line:$start ... $end, Warning - $code: $wrapped. (bad-regex)\n");
}

1;
