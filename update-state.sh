#!/bin/bash
Q='"'
q="'"
B='```'
b='`'
n="
"
N="$n$n"
strip_lead() {
  perl -ne 's/^\s+(\S)/$1/; print'
}
strip_leading() {
  leading="$1" perl -pe 's/^ {$ENV{leading}}(.)/$1/'
}
strip_blanks() {
  perl -ne 'next unless /./; print'
}
strip_lead_and_blanks() {
  strip_lead | strip_blanks
}
