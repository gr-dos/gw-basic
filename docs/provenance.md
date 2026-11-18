# GW-BASIC — Source Provenance (M0)

**Status:** M0 inventory, living document
**Upstream:** https://github.com/microsoft/GW-BASIC at `edf82c2ebf6bfe099c2054e0ae125c3efe5769c4` (2020-05-21, "Added announcement blog link")

## Vendored source

`upstream/` is an unmodified copy of upstream's whole tree at that commit, made with `git archive`. Its git tree hash, `da3c09bb336705cf166739c8bb50c99e4434f328`, equals upstream's root tree exactly. `scripts/check-upstream` (part of `make check` and CI) fails if that ever changes. `.gitattributes` turns off line-ending conversion for `upstream/`.

Upstream is archived and read-only. Its README says it "will not be modified" and "contains no build scripts, makefiles, or tools required to generate executable binaries".

- **License:** `upstream/LICENSE` is MIT, "Copyright (c) Microsoft Corporation". It covers everything in `upstream/`.
- **This repository's license:** the root `LICENSE` (MIT, Graham Ollis) covers our own scripts, documentation and, from M1, the OEM modules in `src/oem/`. It does not relicense `upstream/`. `NOTICE` lists which license covers what.

## Tree contents

46 files:

| Kind | Files | Notes |
| --- | --- | --- |
| `.ASM` modules | 35 | `MATH1.ASM` and `MATH2.ASM` are two halves of one module, so 34 modules assemble |
| `.H` include files | 3 | `OEM.H` (build switches and 8080-style macros), `BINTRP.H`, `IBMRES.H` |
| Extensionless include files | 2 | `GIO86U` (device I/O definitions), `MSDOSU` (MS-DOS interface definitions) |
| `LICENSE`, `README.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.gitignore` | 6 | Repository files, not source |

The first line of most modules says how they were made: `[ This translation created 10-Feb-83 by Version 4.3 ]`. The code was machine-translated from Microsoft's 8080 BASIC sources (`OEM.H` still defines 8080 instruction macros such as `LDIR` and `DJNZ`) and assembled with Microsoft's own 1983 assembler, not with MASM.

## Encoding and line endings

- **`.ASM` files** use CRLF. All but `DSKCOM.ASM` are padded with NUL bytes to a multiple of 128 bytes, the CP/M record size. Their last line ends in CR without LF, followed by the padding.
- **Overstrike bytes.** `BIMISC.ASM` and `GWMAIN.ASM` contain backspace (`08h`) bytes in comments.
- **`.H`, `GIO86U` and `MSDOSU`** use LF only and end with a `^Z` (`1Ah`).
- All text is otherwise plain 7-bit ASCII. Nothing appears to be damaged or converted to UTF-8.

`scripts/prepare-tree` copies these bytes unchanged except for the rewrites below. It drops the NUL padding only where `MATH1.ASM` joins `MATH2.ASM`.

## Making the source assemble

Upstream does not assemble with any available assembler as published. `scripts/prepare-tree` writes an assemblable copy to `build/src`, applying a short list of named rules. It logs every change to `build/src/PREPARE.LOG` as `FILE(LINE) RULE: old => new`. The script's own documentation explains each rule in full.

| Rule | Changes | What it does |
| --- | --- | --- |
| `rename` | 122 | Symbols named after later instructions or directives (`PUSHF`, `IDIV`, `INT`, `NEG`, `LOOP`, `FDIV`, `FCOMP`, `FADD`, `FSUB`, `FFREE`, `NAME`, `OPTION`, `FOR`, `WHILE`, `GOTO`, `INSTR`) get a trailing `_`, as do the switches `SHORT`, `LENGTH` and `LABEL`. Keyword text in the reserved-word table is untouched |
| `byte-offset` | 100 | `DB OFFSET X` and `MOV DL,OFFSET X` become `LOW (OFFSET X)`: the 1983 assembler truncated silently |
| `forward-equate` | 5 | Assignments that use symbols defined further down (`PWR2PX` in `ADVGRP.ASM`; `CNSLEN`, `FILDEV`, `FILNM`, `FILEXT` in `GWDATA.ASM`) move below those definitions |
| `r-to-r2` | 5 | Reserved-word dispatch `R X` becomes `R2 X,X_` where `X` is renamed, so the token value `$X` keeps its name |
| `movs-cs` | 3 | `MOVS ?CSLAB,WORD PTR ?CSLAB` becomes the explicit `MOVS WORD PTR ES:[DI],WORD PTR CS:[SI]` (same encoding, `2E A5`) |
| `marker-equate` | 1 | An empty marker macro defined with a nested `&endm` in `BINTRP.H` becomes an equate; it is only tested with `IFNDEF` |
| `join-math` | 1 | `MATH.ASM` = `MATH1.ASM` + `MATH2.ASM` |

With these rules, all 34 modules assemble with GR-DOS's JWasm (`-Zm -Zj -fpc`) without errors. One warning remains: `SCNDRV.ASM(2284)` uses the text macro `SCROL2` before it is defined. M1 will check whether that changes the generated code.

The rules are meant to change no generated code, only spelling. That has not been proved yet. M1's MASM reference build and M2's byte comparison are where it gets checked. MASM 5.10 may need its own subset of these rules, or more.

## What is missing: the OEM layer

`make symbols` assembles every module and lists each symbol that some module declares `EXTRN` but no module makes `PUBLIC`. The result is [`symbols.md`](symbols.md): **63 routines, and no data**. `make check` regenerates the report and also links every object with `wlink`. It fails unless the linker's undefined references are exactly the report's 63.

This replaces the rough text scan in the first draft of the design, which counted 219 symbols. The other 156 are defined, but by macros the text scan could not see:

- the reserved-word token values `$PRINT`, ... (`T`, `R` and `R2` in `BINTRP.H` and `IBMRES.H`);
- the error entry points `DERBFM`, ... (`DERMAK` in `BINTRP.H`);
- the RAM variables `CSRX`, `LINLEN`, ... (`R` and `R1` in `GWRAM.ASM`, `ROFFST` in `GIO86U`).

The list includes every routine that TK Chia's README names as reconstructed or stubbed: `SETC`, `MAPXYC`, `INICOM`, `RECCOM`, `SNDCOM`, `STACOM`, `TRMCOM`, `POLLEV`, `RDPEN`, `RDSTIK`, `RDTRIG` and `SNDLPT`.

## Toolchain

Nothing is vendored. `scripts/fetch-grdos` checks out three paths of [gr-dos/gr-dos](https://github.com/gr-dos/gr-dos) at `424fcfef6630ac4e52b71c3b4575522b345e5a6f`. Its scripts then build or download the same tools GR-DOS uses:

| Tool | Version | License |
| --- | --- | --- |
| JWasm | v2.20 at `ac54827ff40b77ecd6e77ed0866a43fc60cd5fe1`, with GR-DOS's 22 patches in `patches/jwasm` | Sybase Open Watcom Public License |
| Open Watcom `wlink` | snapshot `2026-10-01-Build`, sha256-checked | Sybase Open Watcom Public License |

Neither tool ships with GW-BASIC, so their licenses don't affect the release.

## Prior art: TK Chia's restoration

[tkchia/GW-BASIC](https://codeberg.org/tkchia/GW-BASIC) (mirror on GitLab), checked 2026-11-18:

- **Build:** builds `GWBASIC.EXE` and `GWBASICA.EXE` with JWasm, JWlink, AWK (`jwasmify.awk`) and GNU Make, or `GWBASIC.EXE` alone with MASM 5.1A under DOSBox.
- **OEM layer:** `OEM.ASM`, `OEMEV.ASM` and `OEMSND.ASM` are written "mainly from scratch", and it borrows OEM routines such as `SETC` and `MAPXYC` from MS-DOS 1.25's `BASICA.COM`. Serial I/O (`INICOM`, `RECCOM`, `SNDCOM`, `STACOM`, `TRMCOM`) is stubbed. Light pen, joystick, printer and event polling need hardware testing.
- **Releases:** the latest is 20261005 (`GWB26A05.ZIP`), "mostly working".
- **License:** `LICENSE` is Microsoft's MIT notice alone. The README says "All files within this repo are released under the MIT (OSI) License", but nothing names who holds the copyright in the new files. The vendored JWasm and JWlink tarballs carry their own licenses, which we have not checked.

**Decision:** we write our own OEM layer from Microsoft's interface. We use the fork as a technical reference only and copy none of its code, scripts or binaries. `prepare-tree`'s rules were worked out from JWasm's own errors on the upstream source, not from `jwasmify.awk`. If the maintainer later confirms MIT terms for the new files, reusing any of them would be a separate, reviewed change. Nothing waits on the answer.

### Clarification request

**Status: drafted, not yet sent.** Proposed for an issue on the Codeberg repository:

> **Licensing of the new OEM files**
>
> Thank you for restoring GW-BASIC. We are packaging an 8086 GW-BASIC built from Microsoft's MIT-licensed source for GR-DOS (https://github.com/gr-dos/gw-basic). The README says all files in this repository are under the MIT license, but `LICENSE` carries only Microsoft's copyright. Could you confirm that your own new files (for example `OEM.ASM`, `OEMEV.ASM`, `OEMSND.ASM`, `jwasmify.awk` and the makefiles) are offered under the MIT license, and say what copyright line you would like credited? Also, do the routines taken from MS-DOS 1.25's `BASICA.COM` come with any terms beyond the MIT license of the `microsoft/MS-DOS` repository? We are writing our own OEM layer in the meantime, so there is no hurry.

Once it is sent, record the date and link here, and later the answer.
