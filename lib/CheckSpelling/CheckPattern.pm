#! -*-perl-*-

package CheckSpelling::CheckPattern;

use CheckSpelling::Util;

sub process_line {
    my ($line) = @_;
    chomp $line;
    return ($line, '') if $line =~ /^#/;
    return ($line, '') unless $line =~ /./;
    my $regex_pattern = qr{^(.*?) in regex; marked by <-- HERE in m/(.*) <-- HERE.*$};
    my $warning;
    local $SIG{__WARN__} = sub {
        $warning = $_[0];
    };
    if (eval {qr/$line/} && ($warning eq '')) {
        return ($line, '');
    }
    $warning = $@ unless $warning;
    $warning =~ s/(.*?)\n.*/$1/m;
    my $err = $warning;
    chomp $err;
    $err =~ s{$regex_pattern}{$2};
    my $code = $1;
    my $start = $+[2] - $-[2];
    my $end = $start + 1;
    my $wrapped = CheckSpelling::Util::wrap_in_backticks($err);
    return ("^\$\n", "$start ... $end, Warning - $code: $wrapped. (bad-regex)\n");
}

1;
