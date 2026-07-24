# DATRAS Webservice and Field-List Gaps

## Why this exists

The [other
article](https://einarhjorleifsson.github.io/icesDatras/articles/recent-fixes.md)
in this pair covers code bugs – places where, given correct input, this
package’s own logic produced a wrong result. This one is about something
upstream of that entirely: real gaps in what the DATRAS webservice
itself provides, and in the field list it publishes to describe its own
data. Neither is fixable by changing this package’s logic; both are
patched here as interim, escapable workarounds – see the
“webserver/schema gap” category in `AGENTS.md` for the general framework
this falls under.

This is written up separately because the two problems are genuinely
different in kind: one is missing behaviour on ICES’s server, the other
is missing or wrong metadata *about* behaviour that already works fine.

**That distinction has a practical consequence worth stating plainly,
since it determines where any of this can actually go.** A genuine
`icesDatras` code bug – the other article’s territory – has somewhere to
be reported: `ices-tools-prod/icesDatras`’s own issue tracker, with a
real maintainer reading it. Nothing in *this* article does. There is no
GitHub repo for “the DATRAS webservice” or “the DATRAS data model” –
these are ICES Datacenter’s own server and database, not a piece of
open-source code with an issue tracker attached. Reporting anything here
means finding the right contact at ICES Datacenter directly (not yet
identified as of writing, see `AGENTS.md`), or raising it with a
relevant ICES Working Group (IBTSWG has been suggested elsewhere for
related data-model questions) – not filing a GitHub issue and waiting
for a response.

## The webservice itself is incomplete

The DATRAS webservice
(`https://datras.ices.dk/WebServices/DATRASWebService.asmx`) exposes 25
operations in total. ICES is evidently mid-migration on header naming
for at least one record type: `getHLdata` has a sibling,
`getHLdataNewHeaders`, returning the same data under updated column
names. But that’s the *only* such pair – there is no
`getHHdataNewHeaders`, `getCAdataNewHeaders`,
`getDatrasFieldListNewHeaders`, or equivalent for FL, LT, Indices, or
either CPUE endpoint. The migration, in other words, is real but only
about 4% rolled out across the service’s surface.

icesDatras itself doesn’t call the one endpoint that does exist in its
new form – every function in this package still uses the old-style
operations, translating names client-side via
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
instead. Cross-checking `getHLdataNewHeaders` directly against that
client-side translation (real NS-IBTS 2022 Q1 data) found 28 of 29
columns agreeing exactly – good validation that the translation approach
is generally sound – and one real mismatch, detailed below.

Separately,
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
has no true server-side equivalent at all: there is no “get catch
weight” operation on the service. The function fabricates one
client-side, fetching HH and HL and summing `CatCatchWgt` per haul in R.
Anyone re-implementing DATRAS access from scratch should know this going
in – it looks like a single endpoint from the outside but isn’t one.

## The field list is incomplete or ambiguous

[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
is the service’s own description of its data: which fields exist per
record type, their old and new names, and their intended type. In
practice it has several distinct kinds of gaps against what the service
actually returns:

1.  **Plain formatting inconsistencies** – `DataFormat` uses `"float"`
    in some rows and `"decimal"` in others for what should be the same
    type; `Year` isn’t consistently marked `"int"`; a couple of FA
    fields have the wrong `DataFormat` or a missing `Description`
    entirely.
2.  **Wrong `FieldNameOld` values** – for three fields LT shares with HH
    (`Platform`, `StationName`, `HaulNumber`), the list’s `FieldNameOld`
    column simply echoes the *new* name instead of the actual old column
    name the service returns with `new_names = FALSE`.
3.  **Missing rows entirely, at record-type scale** – the list covers
    only LT’s ~22 upload-spec fields, but
    [`getLTassessment()`](https://einarhjorleifsson.github.io/icesDatras/reference/getLTassessment.md)
    actually returns on the order of 40 additional HH-style columns
    (coordinates, gear metrics, haul metadata) with no corresponding
    entry at all.
4.  **A whole record type absent** – FL isn’t in the list at all,
    despite
    [`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md)
    returning every HH column plus several FL-specific swept-area ones.
5.  **Server-added columns with no spec entry** – the live database
    appends `DateofCalculation` (HH/HL/CA) and a validated Aphia code
    column to HL/CA responses, neither of which the upload-spec field
    list ever mentions.
6.  **A field matching neither documented name** – CA’s age column comes
    back as `Age`, matching neither the list’s new name
    (`IndividualAge`) nor its documented old name (`AgeRings`) –
    confirmed live, even with `new_names = FALSE`.
7.  **A locally-invented name diverging from ICES’s own real direction**
    – this is not something `ices-tools-prod/icesDatras` (the actual
    upstream repository) ever did: the official field list has no entry
    for this column at all. A local patch in this fork had filled that
    gap by translating `Valid_Aphia` to a made-up canonical name,
    `aphia`. The one place ICES’s real header migration touches this
    field (`getHLdataNewHeaders`) still calls it `Valid_Aphia`,
    unchanged – so the invented name diverged from ICES’s own actual
    direction, not from anything upstream chose.
8.  **Three entire products missing, not just a record type** –
    [`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md),
    [`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md),
    and
    [`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
    have no field-list coverage at all, under any `RecordHeader`. Bigger
    in scope than item 4 (FL is one record type with real coverage in
    this fork’s patch; these three have none) and with a directly
    confirmed consequence:
    [`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)’s
    own `Age_0`..`Age_15` came back as a mix of `integer`/`numeric`
    *within a single response*, not just across separate calls, purely
    from `simplify()`’s data-dependent guessing having nothing to anchor
    it to – exactly the scenario where per-file type drift turns into a
    real, hard-to-debug problem once many files from many calls are
    bound together.

## Discrepancies across tables, not just within one

Everything above is one record type’s own field list being wrong or
incomplete. A related, likely larger issue sits one level up: ICES’s own
data model has inconsistencies *across* HH/HL/CA/FL/LT/Indices/CPUE\* –
in both naming conventions and typing – that a client library has no
business trying to resolve on its own.

A broader, separate investigation comparing several independent
DATRAS-consuming tools directly landed on a useful distinction: HH/HL/CA
are institute *measurements* – interpreting them (units, codes, key
uniqueness, naming) has exactly one right answer, so every downstream
tool solving that independently is waste, not legitimate scientific
difference. Derived products (FL, indices, spread models) are a
different case and can legitimately diverge – that’s normal practice,
not a bug.

Concrete cases bearing directly on this package:

- **Old-name/new-name inconsistency** was named, independently of
  anything in this package, as one of a handful of things every serious
  downstream DATRAS tool ends up re-solving on its own. This package’s
  own field-list hot-fix (documented above) is one instance of that
  pattern, not an isolated case.
- **The same concept, spelled differently depending on which product
  returns it** – distinct from old-name/new-name migration (that’s one
  table’s names changing over time; this is several tables disagreeing
  *right now*). Confirmed live, four cases, all involving item 8’s
  `IDX`/`CPUEL`/`CPUEA` columns against HH/HL/LT’s established names:
  - `Valid_Aphia` (HL/CA) vs. `AphiaID` (Indices/CPUE) – the same WoRMS
    species identifier.
  - `ShootLong` (HH/LT) vs. `ShootLon` (CPUE) – the same shoot
    longitude.
  - `DateofCalculation` (HH/HL/CA/FL/LT) vs. `Cal_DateID` (CPUE) – the
    same recalculation-timestamp concept.
  - `LngtClass` (HL’s own old name) vs. `LngtClas` (CPUE) – the same
    length class.

  Each pair is one keystroke or one naming pattern apart – consistent
  with the derived products (Indices, CPUE) having been built separately
  from the core HH/HL/CA tables, by a different process, without the two
  ever being reconciled. Deliberately left as separate, self-mapped
  entries in this fork’s field-list patch rather than unified locally –
  doing that would be this package quietly deciding they’re identical on
  ICES’s behalf, the same overreach the `aphia` naming mistake (item 7)
  already was once.
- **HL and CA diverge in *both* directions on the same two concepts,
  confirmed live.** Sex: both share the identical old name `Sex`, but
  the new-name convention gives them *different* names – `SpeciesSex`
  (HL) vs. `IndividualSex` (CA). Unlike the item above, this one may not
  be carelessness: HL’s sex is assessed by visual bulk-catch
  examination, CA’s by dissection – genuinely different methods, so the
  shared old name `Sex` may be the misleading part, not the diverging
  new names. Number-at-length runs the opposite way: the new names
  already converge on one shared name, `NumberAtLength`, for both HL and
  CA, but the *old* names are table-prefixed and differ (`HLNoAtLngt`
  vs. `CANoAtLngt`) – mostly harmless once `new_names = TRUE` is used,
  but a trap for anyone working with raw old-style names across both
  tables.
- **The same field name, but a different value encoding, across tables –
  arguably the most dangerous kind, since nothing about the column name
  signals it.** `DateofCalculation` exists, identically named, in
  HH/HL/CA/FL/LT, but the digit order differs: HH’s live values
  (e.g. `20260625`) are `YYYYMMDD`, while FL’s (e.g. `20232303`,
  `20233003`) are only valid at all as `YYYYDDMM` – read as `YYYYMMDD`
  they’d claim months 23 and 30 exist. Confirmed directly against live
  data, not just cited.

All of this is exactly the kind of thing that turns invisible the moment
work stays within one table, one survey, one point in time – and turns
into silent, wrong answers the moment it doesn’t: joining across tables,
comparing across surveys, or building an archive across years are
precisely where a shared name masking two methods, or a diverging name
masking one concept, or an identical name masking two date formats,
actually bites.

None of this is fixable by patching `icesDatras`. A client-side patch
can only ever correct the symptom for this package’s own users – the
actual fix is ICES settling on one answer at the data-model level, which
is a question for a Working Group (IBTSWG has been suggested as the
right venue, since DATRAS already briefed them on related work), not
something a webservice client can resolve for itself.

## icesVocab: a related, currently-unused source of field/vocabulary truth

`icesVocab` – a separate ICES package, not currently consulted by
`icesDatras` for anything – governs the *values* many DATRAS fields are
allowed to take (gear codes, data-type codes, validity flags, and more)
via `getCodeList(code_type, ...)`. Two things about it are relevant
here, both confirmed directly rather than assumed:

- It’s piecemeal in the same way
  [`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
  is:
  [`getCodeList()`](https://rdrr.io/pkg/icesVocab/man/getCodeList.html)
  takes exactly one `code_type` per call with no bulk/“all” option, and
  [`getCodeTypeList()`](https://rdrr.io/pkg/icesVocab/man/getCodeTypeList.html)
  returns type *names* only, not their code values. Even ICES’s own
  official DATSU submission-validation code
  (`icesDatsuQC::runVocabChecks()`) loops the same way internally –
  there’s no bulk shortcut even from the inside.
- Some DATRAS-relevant fields (`HaulVal`, `Gear`, `DataType` among them)
  aren’t registered under any DATRAS-specific grouping in `icesVocab`’s
  own `findCodeType("DATRAS")` helper, so it wouldn’t fully cover this
  package’s fields even if adopted.

Separately: some field *descriptions* – in
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)’s
own `Description` column – appear to be wrong, occasionally with the
hallmarks of a copy-paste from a different field. Noted directly from
working with the data, not yet catalogued case by case here; worth a
dedicated pass at some point, distinct from the naming/typing gaps
above.

## Steps used to find and confirm each gap

The method is the same each time, and reproducible directly – code, not
just a description of it. Each of these runs against real DATRAS data as
shown.

**1. Fetch real data, compare column names against the field list
directly.**

``` r

fl <- getDatrasFieldList()
ca <- getDATRAS("CA", "NS-IBTS", 2022, 1, fix_types = FALSE, new_names = FALSE)

known <- unique(c(fl$FieldNameOld[fl$RecordHeader == "CA"],
                   fl$FieldName[fl$RecordHeader == "CA"]))
setdiff(names(ca), known)
#> [1] "Age"
```

Repeated across HH/HL/CA/FL/LT for the same survey/quarter, `"Age"` in
CA was the *only* column left over with no field-list entry at all –
everything else already had one.

**2. Repeat with `new_names = FALSE` specifically**, to localise *where*
a gap actually sits.

``` r

"Age" %in% names(getDATRAS("CA", "NS-IBTS", 2022, 1, new_names = TRUE))
#> [1] TRUE
"Age" %in% names(getDATRAS("CA", "NS-IBTS", 2022, 1, new_names = FALSE))
#> [1] TRUE
```

Same result either way. If the raw, untranslated response already uses a
name absent from the field list’s `FieldNameOld` column, the field
list’s metadata is what’s wrong – not a translation bug in this package.

**3. Where a real “new headers” endpoint exists, cross-check against it
directly** rather than trusting this package’s own translation as ground
truth.

``` r

url_new <- paste0(
  "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getHLdataNewHeaders",
  "?survey=NS-IBTS&year=2022&quarter=1"
)
new_headers   <- parseDatras(readDatras(url_new))
hl_translated <- getDATRAS("HL", "NS-IBTS", 2022, 1, fix_types = FALSE, new_names = TRUE)

setdiff(names(new_headers), names(hl_translated))
#> [1] "Valid_Aphia"    # ICES's real endpoint still uses this name...
setdiff(names(hl_translated), names(new_headers))
#> [1] "aphia"          # ...but this package had invented a different one
```

Without a second, independent source for what ICES actually calls a
field, a locally-invented name can look correct indefinitely.

**4. Treat every fix found this way as interim, not final.** The field
list is ICES’s data, not this package’s – a patch here corrects the
symptom for this package’s users, but the underlying gap still needs
reporting to ICES Datacenter directly (a different channel to whoever
maintains the `icesDatras` R package code on GitHub – not yet identified
as of writing).
