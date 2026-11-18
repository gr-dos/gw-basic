# GW-BASIC for GR-DOS (docs/DESIGN.md).
#
# Needs Perl 5.42 as `perl` on PATH, plus a C compiler, make, git, curl and
# xz to fetch and build GR-DOS's pinned JWasm and Open Watcom into
# build/tools.
#
#   make                 prepare the tree, assemble every module, write docs/symbols.md
#   make check           check upstream/, and that docs/symbols.md is current and
#                        agrees with a trial link

SRC      := build/src
OBJ      := build/analysis
TOOLS    := build/tools.env
JWFLAGS  := -q -Zm -Zj -fpc

.PHONY: all prepare analysis symbols check check-upstream check-symbols clean

all: symbols

$(TOOLS): scripts/fetch-grdos scripts/fetch-jwasm scripts/fetch-watcom
	mkdir -p $(@D)
	jwasm=$$(scripts/fetch-jwasm) && watcom=$$(scripts/fetch-watcom) \
	  && printf 'JWASM=%s\nWATCOM=%s\nexport WATCOM\n' "$$jwasm" "$$watcom" > $@

prepare: $(SRC)/PREPARE.LOG

$(SRC)/PREPARE.LOG: scripts/prepare-tree $(wildcard upstream/*)
	scripts/prepare-tree $(SRC)

# Assemble every module of the prepared tree. Not a build of GWBASIC.EXE:
# the OEM layer does not exist yet, so the objects are only analysed.
analysis: $(OBJ)/.stamp

$(OBJ)/.stamp: $(SRC)/PREPARE.LOG $(TOOLS)
	rm -rf $(OBJ)
	mkdir -p $(OBJ)
	. ./$(TOOLS) && cd $(SRC) && for f in *.ASM; do \
	  "$$JWASM" $(JWFLAGS) -Fo$(CURDIR)/$(OBJ)/$${f%.ASM}.OBJ $$f || exit 1; \
	done
	touch $@

symbols: docs/symbols.md

docs/symbols.md: $(OBJ)/.stamp scripts/symbol-report
	scripts/symbol-report $(SRC) $(OBJ) > $@.tmp
	mv $@.tmp $@

check: check-upstream check-symbols

check-upstream:
	scripts/check-upstream

# docs/symbols.md must be what the current tree produces, and must list
# exactly the symbols wlink reports as undefined when it links every module.
check-symbols: $(OBJ)/.stamp $(TOOLS)
	scripts/symbol-report $(SRC) $(OBJ) > build/symbols.md
	diff -u docs/symbols.md build/symbols.md
	. ./$(TOOLS) && cd $(OBJ) && { \
	  echo 'format dos'; echo 'name TRIAL.EXE'; echo 'option quiet, dosseg'; \
	  for f in *.OBJ; do echo "file $$f"; done; \
	} > trial.lnk && { "$$WATCOM/binl64/wlink" @trial.lnk > trial.out 2>&1 || true; }
	sed -n 's/.*E2028: \([^ ]*\) is an undefined reference.*/\1/p' $(OBJ)/trial.out \
	  | sort -u > build/link-undefined.txt
	sed -n 's/^| `\([^`]*\)` |.*/\1/p' docs/symbols.md | sort -u > build/report-undefined.txt
	diff -u build/report-undefined.txt build/link-undefined.txt
	@echo "docs/symbols.md is current and matches the trial link ($$(wc -l < build/link-undefined.txt) symbols)"

clean:
	rm -rf $(SRC) $(OBJ) build/symbols.md build/*-undefined.txt
