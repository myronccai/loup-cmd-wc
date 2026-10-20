#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY
#
# The cases run in a temporary directory holding the fixture files made
# below, so error messages show short names.

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    want stderr: $want_err"
        sed 's/^/    got stderr:  /' "$TMP/err" | head -5
    fi
}

cd "$TMP" || exit 1
printf 'one two\nthree\n' > small
printf 'a\nb\nc' > abc
printf 'caf\303\251 \343\200\200na\303\257ve\n' > utf
printf 'x\377y \001\n' > binary
printf 'ab\tc\n\344\270\255\346\226\207\346\226\207\n' > wide
head -c 123456 /dev/zero | tr '\0' 'z' > big
: > empty
mkdir dir

# Counts and their order
check "default"            0 $' 2  3 14 small\n'                     small
check "-l"                 0 $'2 small\n'                            -l small
check "-w"                 0 $'3 small\n'                            -w small
check "-c"                 0 $'14 small\n'                           -c small
check "-m UTF-8"           0 $'12 utf\n'                             -m utf
check "-c UTF-8"           0 $'16 utf\n'                             -c utf
check "-w with U+3000"     0 $'2 utf\n'                              -w utf
check "all counts, GNU order" 0 $' 1  2 12 16 12 utf\n'              -Lcmwl utf
check "bad bytes"          0 $'1 2 5 6 binary\n'                     -lwmc binary
check "-L tabs and wide"   0 $'9 wide\n'                             -L wide
check "--words --lines"    0 $' 2  3 small\n'                          --words --lines small
check "--max abbreviation" 0 $'9 wide\n'                             --max wide
check "no final newline"   0 $'2 3 5 abc\n'                          abc
check "empty file"         0 $'0 0 0 empty\n'                        empty

# Column width and names
check "two files, total"   0 $' 2  3 14 small\n 2  3  5 abc\n 4  6 19 total\n'  small abc
check "width from sizes"   0 $'     0      1 123456 big\n     2      3     14 small\n     2      4 123470 total\n' big small
check "one count, one file" 0 $'0 big\n'                             -l big
IN=small check "stdin, no name" 0 $' 2  3 14\n'
printf 'one two\nthree\n' | "$BIN" > "$TMP/piped"
printf '      2       3      14\n' > "$TMP/want-pipe"
if cmp -s "$TMP/want-pipe" "$TMP/piped"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: pipe is width 7"; fi
IN=small check "dash names stdin" 0 $' 2  3 14 -\n 2  3  5 abc\n 4  6 19 total\n' - abc
check "--total=always"     0 $'2 3 5 abc\n2 3 5 total\n'             --total=always abc
check "--total=only"       0 $'4 6 19\n'                             --total=only small abc
check "--total=never"      0 $' 2  3 14 small\n 2  3  5 abc\n'       --total=never small abc
check "--tot=al"           0 $'2 3 5 abc\n2 3 5 total\n'             --tot=al abc
check "options after files" 0 $'2 small\n'                           small -l
check "-- ends options"    0 $'2 small\n'                            -l -- small

# Errors
check "missing file"       1 $' 2  3 14 small\n 2  3 14 total\n'    missing small
check_err "missing message" 1 'wc: missing: No such file or directory' missing small
check "directory"          1 $'      0       0       0 dir\n      2       3      14 small\n      2       3      14 total\n' dir small
check_err "directory message" 1 'wc: dir: Is a directory'            dir small
check_err "invalid option" 1 $'wc: invalid option -- \'x\'\nTry \'wc --help\' for more information.' -x
check_err "bad --total"    1 $'wc: invalid argument \'x\' for \'--total\'\nValid arguments are:\n  - \'auto\'\n  - \'always\'\n  - \'only\'\n  - \'never\'\nTry \'wc --help\' for more information.' --total=x
check_err "--total needs a value" 1 $'wc: option \'--total\' requires an argument\nTry \'wc --help\' for more information.' --total
check_err "flag with a value" 1 $'wc: option \'--lines\' doesn\'t allow an argument\nTry \'wc --help\' for more information.' --lines=1

# Help and version
check "version"            0 $'wc (loup-cmd-wc) 0.1.0\n'             --version
"$BIN" --help > "$TMP/help"
if head -1 "$TMP/help" | grep -q '^Usage: wc \[OPTION\]... \[FILE\]...$'; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: help"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
