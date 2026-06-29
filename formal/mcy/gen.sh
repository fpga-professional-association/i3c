#!/usr/bin/env bash
# gen.sh <module> <size> <file1.sv> [file2.sv ...]   (<module> = top)
set -e
MOD="$1"; SIZE="$2"; shift 2; FILES="$@"
D="$(cd "$(dirname "$0")" && pwd)/$MOD"
RTL="$(cd "$(dirname "$0")/../../rtl" && pwd)"
rm -rf "$D"; mkdir -p "$D"; cd "$D"
READS=""; FLIST=""
for f in $FILES; do cp "$RTL/$f" .; READS="$READS $f"; FLIST="$FLIST$f\n"; done
cat > config.mcy <<CFG
[options]
size $SIZE
tags COVERED UNCOVERED

[script]
read -formal -sv -I. $READS
prep -top $MOD

[files]
$(printf "$FLIST")
[logic]
if result("test_fm") == "FAIL":
    tag("COVERED")
else:
    tag("UNCOVERED")

[report]
n = tags("COVERED") + tags("UNCOVERED")
if n:
    print("Mutation coverage: %.1f%% (%d killed / %d total)" % (100.0*tags("COVERED")/n, tags("COVERED"), n))

[test test_fm]
expect PASS FAIL
run bash \$PRJDIR/test_fm.sh
CFG
cat > test_fm.sby <<SBY
[options]
mode bmc
depth 20
expect pass,fail

[engines]
smtbmc boolector

[script]
read_rtlil mutated.il

[files]
mutated.il
SBY
cat > test_fm.sh <<'SH'
#!/bin/bash
exec 2>&1
set -ex
bash $SCRIPTS/create_mutated.sh -o mutated.il
ln -s ../../test_fm.sby .
sby -f test_fm.sby
gawk "{ print 1, \$1; }" test_fm/status >> output.txt
exit 0
SH
echo "generated $D"
