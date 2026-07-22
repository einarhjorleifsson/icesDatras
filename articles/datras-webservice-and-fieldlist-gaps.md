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

## The webservice itself is incomplete

The DATRAS webservice
(`https://datras.ices.dk/WebServices/DATRASWebService.asmx`) exposes 25
operations in total (checked live, 2026-07-22). ICES is evidently
mid-migration on header naming for at least one record type: `getHLdata`
has a sibling, `getHLdataNewHeaders`, returning the same data under
updated column names. But that’s the *only* such pair – there is no
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
    – this package had translated `Valid_Aphia` to a made-up canonical
    name, `aphia`; the one place ICES’s real header migration touches
    this field (`getHLdataNewHeaders`) still calls it `Valid_Aphia`,
    unchanged.

Items 1-5 predate this session; items 6-7 were found and patched here.

## Steps used to find and confirm each gap

The method was the same each time, and is worth naming as a repeatable
recipe rather than a one-off:

1.  **Fetch real data, compare column names against the field list
    directly.** For each record type, pull a live response and check
    `setdiff(names(response), union(field_list$FieldNameOld, field_list$FieldName))`
    for that `RecordHeader`. Anything left over has no entry at all –
    this is what surfaced the CA `Age` gap, and confirmed it was the
    *only* such gap across HH/HL/CA/FL/LT for the survey/ quarter
    checked.
2.  **Repeat with `new_names = FALSE`** specifically, to localise
    *where* a gap sits. If the raw, untranslated response already uses a
    name absent from the field list’s `FieldNameOld` column, the field
    list’s metadata is wrong or incomplete – not a translation bug in
    this package.
3.  **Where a real “new headers” endpoint exists, cross-check against it
    directly** rather than trusting this package’s own translation as
    ground truth. This is what caught the `aphia`/`Valid_Aphia`
    divergence – without a second, independent source for what ICES
    actually calls a field, a locally-invented name can look correct
    indefinitely.
4.  **Treat every fix found this way as interim, not final.** The field
    list is ICES’s data, not this package’s – a patch here corrects the
    symptom for this package’s users, but the underlying gap still needs
    reporting to ICES Datacenter directly (a different channel to
    whoever maintains the `icesDatras` R package code on GitHub – not
    yet identified as of writing).
