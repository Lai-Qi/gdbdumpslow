# gdbdumpslow
Usage: perl gdbdumpslow.pl [ OPTS... ] [ LOGS... ] or ./gdbdumpslow.pl [ OPTS... ] [ LOGS... ]

Parse and summarize the GoldenDB CN slow query log. Options include:

- `--verbose` : Verbose output.
- `--debug` : Debug mode.
- `--help` : Display this help text.

### Options
- `-v` : Verbose output.
- `-d` : Debug mode.
- `-s ORDER` : Sort by the specified ORDER (at, ap, ag, af, c, t, p, g, f), 'at' is default.
  - `at`: Average query time.
  - `ap`: Average ParserSQLTime time.
  - `ag`: Average GetGTIDTime time.
  - `af`: Average FreeGtidTime time.
  - `c`: Count.
  - `t`: Query time.
  - `p`: Parse SQL time.
  - `g`: GetGTIDTime.
  - `f`: FreeGtidTime.
- `-r` : Reverse the sort order (largest last instead of first).
- `-t NUM` : Show only the top NUM queries.
- `-a` : Do not abstract all numbers to N and strings to 'S'.
- `-n NUM` : Abstract numbers with at least NUM digits within names.
- `-g PATTERN` : Grep only statements that include the specified PATTERN.
