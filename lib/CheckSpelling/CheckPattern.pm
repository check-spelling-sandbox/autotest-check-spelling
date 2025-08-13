#! -*-perl-*-

package CheckSpelling::CheckPattern;

use CheckSpelling::Util;

sub process_line {
    my ($line) = @_;
    chomp $line;
    return ($line, '') if $line =~ /^#/;
    return ($line, '') unless $line =~ /./;
    if (eval {qr/$line/}) {
        return ($line, '')
    }
    $@ =~ s/(.*?)\n.*/$1/m;
    my $err = $@;
    chomp $err;
    $err =~ s{^(.*?) in regex; marked by <-- HERE in m/(.*) <-- HERE.*$}{$2};
    my $code = $1;
    my $start = $+[2] - $-[2];
    my $end = $start + 1;
    my $wrapped = CheckSpelling::Util::wrap_in_backticks($err);
    return ("^\$\n", "$start ... $end, Warning - $code: $wrapped. (bad-regex)\n");
}

1;
