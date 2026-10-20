# Requirements: wc

## Introduction

`wc` counts the newlines, words, characters and bytes in files, and the
width of their longest line. This repository recreates GNU coreutils `wc` in
Loup, with UTF-8 character and display-width rules, the `total` line and
GNU's column alignment. It is the fifth command in the loup-cmd series.

## Requirements

### Requirement 1: Counts

**User Story:** As a shell user, I want the size of a text in lines, words,
characters and bytes so that I can measure files and command output.

#### Acceptance Criteria

1. WHEN wc is run without count options, THE program SHALL print the newline,
   word and byte counts of each operand, in that order.
2. WHEN any of `-l`, `-w`, `-m`, `-c`, `-L` (or their long forms) is given,
   THE program SHALL print only the selected counts, always in the order
   newlines, words, characters, bytes, maximum line width.
3. THE program SHALL count newline bytes as lines, and every byte as a byte.
4. THE program SHALL count each well-formed UTF-8 character as a character
   (as glibc decodes them: overlong forms and surrogates are not characters)
   and not count bytes that are not part of one.
5. THE program SHALL count as a word each maximal run of characters that are
   not white space, where white space is what glibc's `iswspace` accepts in
   a UTF-8 locale plus the no-break spaces U+00A0, U+2007, U+202F and U+2060;
   bytes that are not characters are part of words.
6. WHEN `-L` is given, THE program SHALL print the largest display width of a
   line: TAB advances to the next multiple of 8, CR and FF start a new line,
   and each character adds its display width (0 for controls and combining
   marks, 2 for wide East Asian characters and emoji).

### Requirement 2: Output format

**User Story:** As a shell user, I want aligned columns and a total so that
the output is easy to read and to parse.

#### Acceptance Criteria

1. THE program SHALL right-align every count in a column whose width is the
   number of digits of the summed sizes of the regular-file inputs, at least
   7 when an input is not a regular file (a pipe, a directory), and 1 when
   exactly one count of one input is printed.
2. THE program SHALL follow the counts with a space and the operand's name,
   except for standard input read without operands.
3. WHEN there is more than one operand, THE program SHALL print a `total`
   line; `--total=auto|always|only|never` SHALL control this as in GNU wc
   (`only` prints just the totals, without a name, in width 1).

### Requirement 3: Command line and errors

**User Story:** As a shell user, I want GNU's option syntax and messages so
that wc fits into existing scripts.

#### Acceptance Criteria

1. THE program SHALL accept combined short options (`-lw`), options after
   operands, `--`, `-` for standard input, and long options abbreviated to a
   unique prefix; `--total` values may be abbreviated as well.
2. WHEN an option is unknown, ambiguous, lacks its argument or has one it
   does not take, or a `--total` value is not valid, THE program SHALL print
   GNU's message and `Try 'wc --help' for more information.` and exit with
   status 1.
3. WHEN an operand does not exist, THE program SHALL print
   `wc: NAME: No such file or directory`; WHEN it is a directory, SHALL print
   a line of zero counts for it and then `wc: NAME: Is a directory`; in both
   cases continue and exit with status 1.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or the version line and exit with status 0.
