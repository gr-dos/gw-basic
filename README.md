# GW-BASIC

Microsoft's 1983 GW-BASIC interpreter, rebuilt from its MIT-licensed source
for 8086/8088 DOS and packaged for the full GR-DOS distribution
([gr-dos/gr-dos](https://github.com/gr-dos/gr-dos)). Tracked in
[#1](https://github.com/gr-dos/gw-basic/issues/1).

**Status:** milestone M0. The upstream source is vendored and analysed. It
does not produce a `GWBASIC.EXE` yet: the machine-specific OEM layer it needs
([63 routines](docs/symbols.md)) is milestone M1.

- [docs/DESIGN.md](docs/DESIGN.md): goals, build architecture, milestones
- [docs/provenance.md](docs/provenance.md): where the source and tools come from, and what was changed to assemble it
- [docs/symbols.md](docs/symbols.md): the routines the OEM layer must supply

## Building

Needs Perl 5.42 as `perl`, a C compiler, make, git, curl and xz. JWasm and
Open Watcom are fetched and built into `build/tools` at the versions GR-DOS
pins.

```sh
make          # prepare build/src, assemble all 34 modules, write docs/symbols.md
make check    # upstream/ is unmodified; docs/symbols.md is current and agrees with a trial link
```

## License

MIT. `upstream/` is Microsoft's, under its own MIT license; everything else
is this project's. See [NOTICE](NOTICE).
