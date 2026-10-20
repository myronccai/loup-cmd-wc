# loup-cmd-wc

GNU `wc` recreated in [Loup](https://code-craft.ai/references/loup): count
the newlines, words, characters and bytes of files and the display width of
their longest line, with GNU's column alignment and `total` line.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                       # native binary: build/wc
make ci                          # check, unit tests, build, end-to-end tests
make run ARGS="-lw README.md"    # run from source with loup run
```

```text
$ build/wc fox.txt
 3  9 45 fox.txt
$ build/wc -l fox.txt numbers.txt
   3 fox.txt
1000 numbers.txt
1003 total
$ build/wc -mc words.txt
15 23 words.txt
$ build/wc -L words.txt
10 words.txt
$ build/wc --total=only fox.txt numbers.txt
1003 1009 3938
$ printf 'a b\n' | build/wc
      1       2       4
$ build/wc fox.txt missing.txt; echo "exit $?"
 3  9 45 fox.txt
wc: missing.txt: No such file or directory
 3  9 45 total
exit 1
$ build/wc --version
wc (loup-cmd-wc) 0.1.0
```

`words.txt` holds `café naïve` and `日本語`: 15 characters in 23 bytes, and
the second line is 6 columns wide, the first 10.

With no FILE, or when FILE is `-`, wc reads standard input. Without options
it prints lines, words and bytes. The counts always appear in the order
below, whatever the order of the options.

| Option | Meaning |
|---|---|
| `-l`, `--lines` | newline count |
| `-w`, `--words` | word count: runs of characters that are not white space |
| `-m`, `--chars` | character count (UTF-8 characters; stray bytes are not characters) |
| `-c`, `--bytes` | byte count |
| `-L`, `--max-line-length` | display width of the widest line (TAB stops of 8, wide characters 2 columns, combining marks 0) |
| `--total=WHEN` | `auto` (more than one file), `always`, `only` (just the totals, no name), `never` |

Columns are right-aligned to the number of digits of the files' total size,
at least 7 wide when an input is a pipe or a directory, and not padded when
there is one count of one input, as in GNU wc. Short options combine (`-lw`),
options may follow file names, `--` ends the options, and long options and
`--total` values may be shortened to any unique prefix (`--max`,
`--tot=al`).

Exit status: `0` on success; `1` if any operand could not be read or the
command line was invalid.

## Differences from GNU wc

- Each input is read whole (Loup 1.26.0 has no streaming reads), so an
  endless input never finishes, and memory grows with the input.
- Characters, words and widths always follow UTF-8 (as GNU wc does in a
  UTF-8 locale such as `en_US.UTF-8` or `C.UTF-8`); GNU wc follows the
  locale and in the plain C locale counts every byte as a character.
- Display widths come from a table generated from glibc 2.42's `wcwidth()`
  (`tools/gen_widths.py`); a newer glibc may give new characters other
  widths.
- Messages quote like GNU in the C locale (`'x'`, not `‘x’`), and file names
  are printed as they are (GNU quotes a name that contains a newline).
- `--files0-from` is not implemented.
- A file that exists but cannot be read (no read permission) stops the
  native binary with the runtime's message, e.g.
  `IoError: read_text failed on 'secret': Permission denied (os error 13)`,
  and status 1. Missing files and directories are reported as GNU does.
- `--version` prints a single line.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # GNU getopt-style parsing, --total=WHEN
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/counts.loup   # one pass over the bytes: UTF-8, words, widths
source/commands/widths.loup   # display width table (generated)
source/commands/wc.loup       # column width, output lines, totals, errors
tools/gen_widths.py           # regenerates widths.loup from glibc's wcwidth()
tests/*_test.loup             # unit tests (make test)
tests/fixtures/               # files read by the unit tests
tests/e2e.sh                  # end-to-end tests of build/wc (make e2e)
specs/wc/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
