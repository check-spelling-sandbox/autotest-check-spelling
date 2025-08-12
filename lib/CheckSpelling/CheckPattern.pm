#! -*-perl-*-

package CheckSpelling::CheckPattern;

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
    $err =~ s{^.*? in regex; marked by <-- HERE in m/(.*) <-- HERE.*$}{$1};
    my $start = $+[1] - $-[1];
    my $end = $start + 1;
    return ("^\$\n", "$start ... $end, Warning - Bad regex: $@ (bad-regex)\n");
}

1;
