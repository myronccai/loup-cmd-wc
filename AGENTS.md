# AGENTS.md

This repository recreates GNU `wc` in the Loup programming language, as part
of the loup-cmd series of example applications. The program is `host.dual`
Loup built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, match_long(), parse_total(), parse_args()
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_wc, exit status
│   └── commands/
│       ├── counts.loup          # struct Counts, count_data(): UTF-8, words, widths
│       ├── widths.loup          # width_runs(): generated display width table
│       └── wc.loup              # column_width(), format_line(), run_wc()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── fixtures/                # files read by the unit tests
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/wc/                    # requirements.md, design.md, tasks.md
├── tools/gen_widths.py          # regenerates source/commands/widths.loup from glibc
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-lw README.md"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter value"` | tests whose name contains `value` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/wc` |
| Run the binary | `build/wc --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/wc`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/wc --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/wc/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/wc/tasks.md`.

Keep behaviour in pure functions that return values (`count_data` returns a
`Counts`, `format_line` a line) so unit tests can check it; only `run_wc`
prints.

`source/commands/widths.loup` is generated: do not edit it. To refresh it
for a newer Unicode, run `python3 tools/gen_widths.py >
source/commands/widths.loup` on Linux with glibc and the `en_US.UTF-8`
locale, then `make ci`. Unit tests run under Stage0, whose strings must be
valid UTF-8; cases with other bytes belong in `tests/e2e.sh`.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- In the native build a failed `readText`/`readBytes` ends the program
  (status 1) instead of throwing a catchable `IoError`, so check `exists()`
  and `isDir()` first. Write output with `print`: `writeBytes("/dev/stdout")`
  truncates a redirected file. Strings made per byte are never freed, so
  build output from shared pieces and `join("")`.
- `system.text.padStart` and `parseInt` fail to link in a native build; pad
  and parse by hand (see `pad` in `source/commands/wc.loup`).
- Loup strings have no `\v` or `\f` escape: write such bytes as numbers in
  a `bytesFromInts([...])` list in tests.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
