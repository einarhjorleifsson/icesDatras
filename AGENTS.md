# icesDatras — Project Notes

This project is a local clone of the
[icesDatras](https://github.com/ices-tools-prod/icesDatras) R package.
Work here is done via `devtools::load_all()` — do **not** call
[`library(icesDatras)`](https://datras.ices.dk/WebServices/Webservices.aspx).

## Key files modified

- `R/getDatrasFieldList.R` — fetches the ICES DATRAS field list from the
  web service. Contains a hot-fix block (`if(TRUE) { ... }`) that
  corrects upstream errors and fills gaps in the URL response.
- `R/getFlexFile.R` — changed `record = "HH"` to `record = "FL"` in the
  `formatDatras()` call, now that FL entries exist in the field list.

## Hot-fix block: what it does

### 1. Miscellaneous format/description fixes

- `DataFormat == "float"` normalised to `"decimal"` across all records.
- `Year` forced to `"int"` everywhere.
- FA `StationName` forced to `"char"`; FA/LT `HaulNumber` forced to
  `"int"`.

### 2. LT — wrong `FieldNameOld` for three HH-shared fields

The URL echoes the new name instead of the actual old column name that
`getLTassessment(..., new_names = FALSE)` returns:

| FieldName     | FieldNameOld (URL, wrong) | FieldNameOld (correct) |
|---------------|---------------------------|------------------------|
| `Platform`    | `Platform`                | `Ship`                 |
| `StationName` | `StationName`             | `StNo`                 |
| `HaulNumber`  | `HaulNumber`              | `HaulNo`               |

### 3. LT — missing rows for ~40 HH-style columns

The URL only covers the LT upload-spec fields (~22 rows).
[`getLTassessment()`](https://einarhjorleifsson.github.io/icesDatras/reference/getLTassessment.md)
returns many additional columns (coordinates, gear metrics, haul
metadata, etc.) absent from the URL list, so `new_names = TRUE`
translation silently failed for them. The hot-fix appends the correct
`FieldName`/`FieldNameOld` rows for all of these. After the fix,
`new_names = TRUE` vs `new_names = FALSE` correctly translates 22 column
pairs (e.g. `ShootLat` ↔︎ `ShootLatitude`, `StatRec` ↔︎
`StatisticalRectangle`, etc.).

### 4. FL — entirely absent from the URL

[`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md)
returns all HH columns plus FL-specific swept-area columns (`ICESArea`,
`Cal_DoorSpread`, `DSflag`, `Cal_WingSpread`, `WSflag`, `Cal_Distance`,
`DistanceFlag`, `SweptAreaDSKM2`, `SweptAreaWSKM2`, `SweptAreaBWKM2`,
`DateofCalculation`). The URL has no FL entries at all. The hot-fix
builds FL entries by copying the matching HH rows (preserving
`FieldNameOld` and `Description`) and appending the FL-only extras.

### 5. Back-filled Descriptions for LT and FL

After adding LT and FL rows, any row with an empty `Description` is
back-filled from the matching HH row (same `FieldName`).

### 6. DB-added columns not in the upload spec

The ICES database appends extra columns that have no entry in the
upstream field list:

| RecordHeader | FieldName           | FieldNameOld        | DataFormat |
|--------------|---------------------|---------------------|------------|
| HH, HL, CA   | `DateofCalculation` | `DateofCalculation` | `int`      |
| HL, CA       | `aphia`             | `Valid_Aphia`       | `int`      |

`Valid_Aphia` is the DB-validated aphia code; the new canonical name
used here is `aphia`.

### 7. Known remaining gap — CA `Age`

`getDATRAS("CA", ..., new_names = TRUE)` returns a column named `Age`.
The upstream field list has `IndividualAge` (new) / `AgeRings` (old);
icesDatras returns `Age` instead, matching neither. This mismatch is
left unresolved intentionally.

**Update (2026-07-22):** live-verified as the *only* field, across
HH/HL/CA/FL/LT, missing from the (hot-fixed) field list entirely
(checked against NS-IBTS 2022 Q1 real data — see
`einar_dev/ca-age-field-name-gap`). Also: calling with
`new_names = FALSE` *still* returns `Age`, not `AgeRings` — meaning the
raw server response itself uses `Age`, the same pattern as the
already-fixed “LT wrong `FieldNameOld`” case (section 2 above). That’s
evidence this is fixable with a field-list correction (`FieldNameOld`
for CA’s `IndividualAge` row: `AgeRings` → `Age`), not the deeper
[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
renaming surgery originally assumed here — needs confirming on the
branch itself before assuming it’s that simple.

### 8. `getIndices()`/`getCPUELength()`/`getCPUEAge()` have no `RecordHeader` at all

**Found 2026-07-22, reported from another project doing a full survey ×
year × quarter archive.** Unlike HH/HL/CA/FL/LT, these three functions’
own output columns (`AphiaID`, `Species`, `IndexArea`,
`Age_0`..`Age_15`, `ShootLon`, `DateTime`, `Area`, `SubArea`,
`LngtClas`, `CPUE_number_per_hour`, `Cal_DateID`) have **no field-list
entry under any `RecordHeader`** — not a wrong or missing row for an
existing table, the table itself doesn’t exist in the upstream list. All
three functions call `formatDatras()` without a `record` argument, so
every one of these columns fell through to `simplify()`’s data-dependent
type guess.

**Confirmed live, not hypothetical:**
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)’s
own `Age_0`..`Age_15` came back as a mix of `integer`/`numeric` *within
a single response* before this fix — exactly the cross-file type drift a
per-call parquet archive would hit.

**Fixed** by adding self-mapped (`FieldName == FieldNameOld`, no
invented renames) rows under three organisational labels
(`IDX`/`CPUEL`/`CPUEA` — this repo’s own labels, not anything ICES
defines; chosen to match the equivalent labels already used in `obus`’s
own hand-curated dictionary, `obus/data-raw/DATASET_lookup_fields.R`,
which was consulted for the raw field names and `DataFormat`s,
cross-checked against live data before applying — not copied blind).
Verified live: all three functions now show 0 untyped columns, and
`Age_0`..`Age_15` are uniformly `numeric`.

**This is still a quickfix, same as the rest of this hot-fix block** —
the real, permanent answer is ICES’s own field list covering these three
products, not a client-side patch. Full writeup and upstream-facing
framing: `vignettes/articles/datras-webservice-and-fieldlist-gaps.Rmd`.

## Local fixes applied (2026-07-06)

Three bugs were fixed locally in `R/utilities.R` and `R/getDATRAS.R`.
Each has a corresponding upstream issue that should be raised with the
package developer.

### Fix 1 — `-9` sentinel not scrubbed by `fix_types = TRUE` (`R/utilities.R`)

**What was fixed:** `applyDatrasTypeSchema()` now replaces numeric `-9`
/ `-9L` with `NA` for all `int` and `decimal` columns, after type
coercion.

**Why `parseDatras()` alone is insufficient:** `parseDatras()` scrubs
`-9` via string comparison (`x[x == -9] <- NA`), which catches the
string `"-9"` but not `"-9.0"` — a valid decimal representation DATRAS
uses for missing float fields. After `simplify()` converts such strings
to numeric, the `-9.0` value becomes `-9` and passes through
`applyDatrasTypeSchema()` unchanged.

**Upstream issue to raise:** \> **`fix_types = TRUE` does not fully
scrub DATRAS `-9` sentinels** \> \> `applyDatrasTypeSchema()` coerces
column types but never converts the `-9` sentinel to `NA`. \>
`parseDatras()` attempts this via string comparison, but misses decimal
representations such as \> `"-9.0"`. Minimal reproducible example: \> \>
`r > # Simulate what parseDatras + simplify produce for a "-9.0" decimal field: > x <- data.frame(HaulDur = -9) # numeric -9 survived simplify() > applyDatrasTypeSchema(x, record = "HH")$HaulDur > #> [1] -9 # expected NA >`
\> \> Sentinel scrubbing should be applied inside
`applyDatrasTypeSchema()` for `int` and `decimal` \> columns, so that
`fix_types = TRUE` is a reliable single-step clean-up regardless of how
values \> arrive.

------------------------------------------------------------------------

### Fix 2 — `getDATRAS()` returns `FALSE` instead of a zero-row data frame (`R/getDATRAS.R`)

**What was fixed:** The two availability-check early exits (all years
unavailable; all quarters unavailable) now `return(data.frame())` rather
than `return(FALSE)`. Extended to `R/getFlexFile.R` and
`R/getLTassessment.R` (their own early-exit `return(FALSE)`s), to
`R/getIndices.R` (identical pattern), and to `R/getCatchWgt.R` (no
availability checks of its own — it inherits failure from two internal
[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
calls and would otherwise hard-error on column-dependent processing
against an empty result; needed a new
[`is.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)/[`nrow()`](https://rdrr.io/r/base/nrow.html)
guard, not a mechanical substitution).

**Update (2026-07-22, reported from the `obus` side):**
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)
and
[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
have the same underlying problem in a different shape — neither has any
survey/year/quarter validation at all (only a
`checkDatrasWebserviceOK()` reachability check), so an unavailable cell
hits the *`NULL`-propagation* path instead: `parseDatras()` returns
`NULL` on an empty response, and nothing caught it before
`formatDatras()`. Fixed with the same `is.null(out)` guard already used
in
[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md).
All 7 functions now consistently return
[`data.frame()`](https://rdrr.io/r/base/data.frame.html) for an
empty/unavailable result — this is one story for an eventual upstream
ask, not two.

**Upstream issue to raise:** \>
**[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
returns the scalar `FALSE` (or `NULL`) instead of a zero-row data
frame** \> \> There are two distinct paths that produce a non-data-frame
result: \> \> 1. **Early exits** — when
`intersect(years, available_years)` or the quarter availability \> check
is empty, the function messages the user and `return(FALSE)`. \> 2.
**`NULL` propagation** — when the DATRAS web service returns an empty
XML response, \> `parseDatras()` returns `NULL`.
`do.call(rbind, list(NULL))` then propagates `NULL` out \> of
[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
rather than an empty data frame, silently bypassing `formatDatras()`. \>
\> Both paths break idiomatic downstream code: \> \>
`r > out <- getDATRAS("HH", "NS-IBTS", years = 1800, quarters = 1) > nrow(out) # Error: argument is not a data frame (FALSE path) > > # Empty-response path (valid survey/year/quarter but no records uploaded yet): > out <- getDATRAS("HH", "NS-IBTS", years = 2024, quarters = 1) > nrow(out) # Error: argument is not a data frame (NULL path) >`
\> \> Fix the early exits with `return(data.frame())` and add a `NULL`
guard after \> `do.call(rbind, out)`. The same early-exit issue exists
in
[`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md)
and \>
[`getLTassessment()`](https://einarhjorleifsson.github.io/icesDatras/reference/getLTassessment.md),
and the same `NULL`-propagation issue exists in
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md),
\>
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md),
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md),
and
[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
— all seven functions should be \> covered by one comprehensive fix/PR,
not raised piecemeal.

------------------------------------------------------------------------

### Fix 3 — `xsi:nil` attribute leaks into column names (`R/utilities.R`)

**What was fixed:** The `parseDatras()` name-extraction regex was
changed from `(.*?)` (intended lazy but unreliable across regex engines)
to `([^ >]+)[^>]*`, which unambiguously stops the capture at the first
space or `>` and then skips any remaining tag attributes with `[^>]*`.

**Upstream issue to raise:** \> **`parseDatras()` leaks XML attributes
into column names (e.g. `Age_6 xsi:nil="true"`)** \> \> When DATRAS
returns a self-closing null field such as `<Age_6 xsi:nil="true" />`,
line 46 \> of `parseDatras()` expands it to
`<Age_6 xsi:nil="true"> NA </Age_6 xsi:nil="true">`. The \> subsequent
name-extraction regex `gsub(" *<(.*?)>.*", "\\1", ...)` then captures \>
`Age_6 xsi:nil="true"` as the column name rather than `Age_6`: \> \>
`r > # Reproduce the bad name extraction: > gsub(" *<(.*?)>.*", "\\1", ' <Age_6 xsi:nil="true">NA</Age_6>') > #> [1] "Age_6 xsi:nil=\"true\"" # expected "Age_6" >`
\> \> Fix: replace `(.*?)` with `([^ >]+)[^>]*` so tag attributes are
skipped without relying on \> lazy quantifier support: \> \>
`r > gsub(" *<([^ >]+)[^>]*>.*", "\\1", ' <Age_6 xsi:nil="true">NA</Age_6>') > #> [1] "Age_6" >`

------------------------------------------------------------------------

### Fix 4 — a numeric column stays `character("NA")` when it’s entirely missing in one

response, even after Fix 3’s name fix (found from the `obus` side,
2026-07-21; applied here 2026-07-22, `einar_dev/age-na-string-coercion`)

**Distinct from Fix 3.** Fix 3 stops the `xsi:nil` *attribute* leaking
into the column *name*. This is a separate bug in the column’s *value*,
one level deeper — it happens even with Fix 3 already applied, whenever
every value in a numeric column is missing for a given response (a
single-row response —
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
— is the case most likely to trigger it, since there’s no other row’s
real value to pull the column’s inferred type toward numeric).

**Root cause**, both pieces in `R/utilities.R`:

1.  `parseDatras()` line 46 turns a self-closing/empty tag into the
    **literal text** `"NA"`:

    ``` r

    x <- gsub("^ *<(.*?) />$", "<\\1> NA </\\1>", x)
    ```

    Two lines later, `-9` and `""` are explicitly normalized to a real
    `NA`:

    ``` r

    x[x == -9] <- NA
    x[x == ""] <- NA
    ```

    but the `"NA"` string this substitution just created is never
    similarly normalized — it survives as a genuine, non-missing
    character value all the way to `simplify()`.

2.  `simplify()` decides whether a character column can be safely
    converted to numeric by comparing NA counts before and after
    conversion:

    ``` r

    if (is.character(x)) {
      y <- as.numeric(x)
      if (sum(is.na(y)) == sum(is.na(x)))
        x <- y
    }
    ```

    `as.numeric("NA")` correctly yields `NA_real_`, so `sum(is.na(y))`
    counts every row of an all-missing column correctly. But
    `is.na("NA")` is `FALSE` — the character string `"NA"` is a real,
    present value from [`is.na()`](https://rdrr.io/r/base/NA.html)’s
    point of view, not a missing one — so `sum(is.na(x))` is `0` for a
    column made entirely of these converted empty tags. `0 != n`, the
    guard fails, and the whole column is left `character`, with the
    literal text `"NA"` in every cell.

**Reproduce (pre-fix behaviour):**

``` r

d <- getIndices(survey = "NS-IBTS", year = 1965, quarter = 1, species = 126417,
                fix_types = TRUE, new_names = TRUE)
sapply(d[grep("^Age_", names(d))], class)
# before the fix: Age_0-5 numeric/integer (real catch at those ages here); Age_6-15
# character, holding the literal string "NA". After the fix (verified live): all 16
# Age_0..Age_15 columns come back numeric/integer, none character.
```

**Impact:** affects every function going through
`formatDatras(fix_types = TRUE)` whenever a numeric column is entirely
missing in one response —
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
especially, since they return exactly one row per call. Building an
archive from many separate per-call responses (the normal usage pattern
here) means some files get the column as numeric and others as
character, breaking any tool that expects one type per column across
files (DuckDB, Arrow, `bind_rows()` without prior coercion) — this is
exactly how it was found, from the `obus` side, building a per-response
parquet archive of
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
output.

**Fix applied:** in `parseDatras()`, the self-closing-tag expansion now
produces empty content instead of the literal text `"NA"` (the first of
the two options above), so the existing `x[x == ""] <- NA` normalisation
catches it — for every column type, not just numeric ones. Also
confirmed live: declared-character columns (e.g. `StatRec`) had the
identical gap and are now covered too, not just `Age_*`.

**Full writeup with commit-pinned citations against both this fork and
upstream:**
`~/R/Pakkar/obus/dev/upstream_reports/getindices_age_column_type_inconsistency.qmd`.

------------------------------------------------------------------------

## Existing upstream issues already filed (on `ices-tools-prod/icesDatras`, not this fork)

Checked live via the GitHub API, 2026-07-21 — all three still open, all
`einarhjorleifsson`-authored:

| \# | Title | Maps to |
|----|----|----|
| [\#46](https://github.com/ices-tools-prod/icesDatras/issues/46) | “on getCatchWgt” | Not a code bug — a design question about `CatchWgt`/`DataType` interpretation. `obus`’s own `dr_add_n_and_cpue()`/`dr_catch_weight_by_haul()` (in `obus/R/`) already have a principled, coded answer — see “Related project” below — worth a comment, low priority. |
| [\#47](https://github.com/ices-tools-prod/icesDatras/issues/47) | “on getFlexFile” | [`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md) returns no `StNo` — the exact gap `obus`’s `crosswalk_id_from_hh()` exists to work around. Still open, 0 comments. Worth adding: [`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md) have the *same* gap, worse (also missing `Country`). |
| [\#48](https://github.com/ices-tools-prod/icesDatras/issues/48) | “getCPUELength - variable name returned” | Exactly Fix 3 above (the `xsi:nil` name leak) — already has a local fix here. The one existing comment on this issue (by the same user, same day it was filed) already shows [`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)’s `Age_6`..`Age_15` coming back with the same `xsi:nil`-in-name artifact *and* landing as literal `"NA"` strings — that second half is Fix 4 above, not fully recognized as a separate bug until the `obus`-side session that added Fix 4. |

## Contribution workflow (worked out 2026-07-21, from the `obus` side — full version with a

diagram at `~/R/Pakkar/obus/dev/icesdatras_contribution_workflow.qmd`)

Two repos, two different rules:

- **This fork (`einarhjorleifsson/icesDatras`, `origin`)**: full
  control, no pacing needed — push or self-merge freely, any time. What
  `obus` actually depends on
  (`pak::pak("einarhjorleifsson/icesDatras")`, no `@ref`, always current
  `master`).
- **Upstream (`ices-tools-prod/icesDatras`)**: a real maintainer, shared
  with everyone else who depends on the package. “Don’t fire everything
  at once” applies *here*, not to this fork.

The loop, per bug: 1. **Check upstream’s existing issues first**
(including by your own username) before filing anything new — see the
table above; this is what surfaced that \#47/#48 already existed. 2.
File a new upstream issue **before** writing the fix, only if nothing
already covers it — cheap for the maintainer to read, gives them first
right of context (they may already know why, or want a different
approach), and doesn’t block starting the fix here in parallel. 3. Fix
it on a branch here, merge to this fork’s own `master` (self-reviewed PR
or direct push — no CI configured, nothing to wait on). 4.
`pak::pak("einarhjorleifsson/icesDatras")` from `obus` — picks it up
immediately. 5. Close the upstream issue **manually** (merging here does
not auto-close a different repo’s issue) — comment + close, or leave it
for a later actual upstream PR’s “Closes \#N”. 6. Whether/when to also
send fixes as PRs *to* upstream is separate, unhurried, and should be
paced (not fired all at once) — group by **logical fix, not by file**:
Fix 1/Fix 4 are both in `R/utilities.R` but are two unrelated stories
and should stay separate PRs; Fix 2 spans four functions but is one
story (once extended to
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)).

Evidence upstream isn’t glacially slow but has no SLA either (checked
via the GitHub API): zero open PRs right now; recent (2026) PRs merged
within hours to ~2 weeks; a few small past PRs sat ~2 months before a
batch-merge; some plain issues (no PR) have sat open for years
(e.g. #26, filed 2019).

## Code bug vs. data bug vs. webserver/schema gap — a working distinction

Not every wrong-looking result is fixable the same way, or even fixable
*here* at all. This generalizes a scope note that already existed
narrowly for two data-anomaly write-ups on the `obus` side
(`obus/dev/upstream_reports/fl_cal_distance_defect.qmd`,
`norway_58g2_58j3_weight_anomaly.qmd`) into a three-way test, applied
2026-07-22:

- **Code bug** — given the *same* values the DATRAS API already returns
  (`HaulDuration`, `DataType`, `CatCatchWgt`, etc., taken as correct), a
  function’s own arithmetic or logic produces a result that contradicts
  a clear, well-defined convention. Fixable **permanently** inside this
  repo’s R source, no dependency on anything upstream ever changing. Fix
  1–4 above are all this category.
- **Data bug** — the stored values themselves are wrong or implausible
  regardless of what any client code does with them (bad coordinates, an
  implausible weight, a miscoded species). No code change here touches
  this; it needs the submitting country or ICES Datacenter to correct
  the database, not a PR.
- **Webserver/schema gap** — the DATRAS *webserver itself* is missing or
  wrong (typically
  [`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)’s
  metadata, not the underlying data), and what we write here is
  explicitly an **interim, escapable patch**: the real fix belongs on
  ICES’s server, and ours should be trivial to remove once it lands. The
  entire `if(TRUE) {...}` hot-fix block in `R/getDatrasFieldList.R` is
  this category, retroactively — it predates this distinction being made
  explicit. CA’s `Age` gap (`einar_dev/ca-age-field-name-gap`) is also
  this category, not a code bug: the field list’s own metadata says
  `FieldNameOld` is `AgeRings`, but the live server (even with
  `new_names = FALSE`) actually sends `Age` — a webserver metadata
  inconsistency, not something wrong in this package’s own logic.
- **Interpretation ambiguity** — a fourth bucket, distinct from all
  three: it’s genuinely unclear whether the “obviously correct”
  behaviour is actually the intended one, so it isn’t yet a fixable bug
  of any kind until that’s resolved — typically needs the upstream
  maintainer’s judgement, not just evidence.

**Live example the code-bug/data-bug split was written for:**
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
skipping `HaulDuration/60` scaling for `DataType == "C"` hauls looks at
first like a clean code bug — but `R/zzz.R`’s own `.onAttach()` startup
message warns “there are known issues with the way CatCatchWgt has been
reported until 2023,” and the evidence gathered for the bug so far (obus
side) is from 2020 data. Whether this is a pure code gap, a
since-resolved historical data-era issue, or both, isn’t settled yet —
check post-2023 data before writing any fix on
`einar_dev/getcatchwgt-datatype-c-scaling`.

**Resolved 2026-07-22 — data bug, not a code bug, no fix needed.**
Checked NS-IBTS 2024 Q1: median total-catch-per-minute-towed for
`DataType == "C"` hauls is ~0.97x the `DataType == "R"` median (was
expected to be ~60x if still unscaled). Post-2023 `C`-type submissions
are already correctly per-haul, not per-hour — matching the
`.onAttach()` disclaimer’s own “until 2023” wording exactly. Applying
the `HaulDuration/60` conversion now would incorrectly shrink correct
post-2023 values while only being valid for pre-2023 data. No branch
created; closing this as investigated, not a
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
bug.

**ICES is mid-transition on header names server-side — confirmed live,
2026-07-22.** Of the 25 operations on the DATRAS webservice, exactly one
has an old/new pair: `getHLdata` and `getHLdataNewHeaders` — no
equivalent exists yet for HH, CA, FL, LT, Indices, or CPUE\*. icesDatras
itself calls only the old form everywhere (`R/`, zero `NewHeaders`
references). Cross-checked `getHLdataNewHeaders` against icesDatras’s
own `new_names = TRUE` translation of the old endpoint (NS-IBTS 2022 Q1,
live): **28 of 29 columns agree exactly** — good validation of the
translation mechanism generally. The one mismatch: ICES’s own
`NewHeaders` endpoint still calls the field `Valid_Aphia`, unchanged
from the old name, while this repo’s own hot-fix (“DB-added columns”
section) had invented `aphia` as its canonical new name. That’s a real,
evidenced case of this repo choosing a name ICES’s own migration doesn’t
actually use.

**Decided 2026-07-22 — general rule, not a one-off call: ICES’s own
authoritative naming always wins over a locally-invented one, once
knowable.** `FieldName` for this entry was changed to `Valid_Aphia` (==
`FieldNameOld`, i.e. no rename) in `R/getDatrasFieldList.R`’s
DB-added-columns block. **Not dealt with, deliberately deferred:**
`obus` depends on the old `aphia` name extensively (dozens of files,
grepped 2026-07-22) — real breakage, but for a future `obus`-side
session; not a reason to hold back this repo’s own correctness.

**The same shape recurs wherever this ecosystem wraps an ICES-provided
list, not just here.** `obus`’s own `data-raw/DATASET_lookup_fields.R`
layers a hotfix on top of this identical `getDatrasFieldList` URL,
independently of anything in this repo; `obus`’s
`data-raw/DATASET_vocabulary.R` does the same to
[`icesVocab::getCodeTypeList()`](https://rdrr.io/pkg/icesVocab/man/getCodeTypeList.html).
Confirms ICES-official-source-plus-local-patch is a recurring pattern,
not a one-off — the same “ICES’s source wins, keep patches escapable”
rule should apply there too, whenever that repo is actually being worked
on. Out of scope for this session (`icesDatras` only) — noted here so it
isn’t re-discovered from scratch later.

**Reporting gaps back to ICES, not just to GitHub:** a webserver/schema
gap found here (or in `obus`’s parallel hotfixes) is a *data/metadata*
problem, most likely owned by ICES Datacenter’s data team rather than
whoever maintains the `icesDatras` R package on GitHub — filing a GitHub
issue against `ices-tools-prod/icesDatras` (the “Contribution workflow”
section above) may be the wrong channel, or only half of it. No
confirmed reporting channel for this identified yet — the `.onAttach()`
startup disclaimer points at a *known-issues* page, not a *submit a new
issue* one. Needs either the user’s own institutional knowledge of ICES
Datacenter contacts, or research, before this can actually happen.

**Escape-hatch design for the webserver/schema-gap category — not yet
applied.** The current hot-fix block’s
[`rbind()`](https://rdrr.io/r/base/cbind.html)-based additions (LT
extra, FL extra, DB-added columns) are **not** idempotent — if ICES’s
webserver independently adds any of these same rows later, the result is
duplicate rows, not a clean no-op. A more escapable design would (a)
skip injecting a row if the raw response already has a matching one,
and/or (b) add a test asserting the raw (unpatched) field list is still
missing the row it’s supposed to be missing, so the test starts failing,
loudly, the moment it’s safe to delete the patch. Neither exists yet —
worth doing before adding more entries to this block (e.g. for
`einar_dev/ca-age-field-name-gap`).

## Authoritative schema project (started 2026-07-23, from the `obus` side)

**The finding that started this:** `obus`’s full `DATASET_RAW.R` rebuild
crashed consolidating `CPUEL` – DuckDB refused to union files because
`Area` was `VARCHAR` in one file, `INTEGER` in another. Root cause,
traced precisely:
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
call `formatDatras()` without ever passing `record = "CPUEL"`/`"CPUEA"`,
so `applyDatrasTypeSchema()` runs against the *entire*, unfiltered
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
table. That table declares `Area` (both `CPUEL` and `CPUEA`)
`DataFormat == "int"`. But the per-operation WSDL page
(`?op=getCPUELength`/`?op=getCPUEAge`) declares it `"string"` – and real
data proves the WSDL page right: EVHOE 2001 Q4’s `Area` values are
`Gn`/`Cc`/`Cs`/`Gs`/`Cn`, genuine ICES area codes, not noise (37,949
rows, zero numeric values). Verified live: calling
`getCPUELength("EVHOE", 2001, 4, fix_types = TRUE)` right now silently
coerces every one of those real codes to `NA`
(`"NAs introduced by coercion"`), because `applyDatrasTypeSchema()`
trusts
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)’s
wrong declaration. This is active data destruction, not just a type
inconsistency – worse than the crash it was found through.

**Why the WSDL page is the authoritative source and
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
isn’t:** the per-operation page is generated by ASP.NET directly from
the operation’s actual server-side return type at request time – it
cannot drift from reality, by construction.
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
is a separate, independently-maintained reference table, and has now
been shown wrong on *both* names (the pre-existing LT
wrong-`FieldNameOld` case, sections above) and types (this `Area` case)
– two different failure modes of the same underlying problem: a
hand-maintained secondary source standing between the schema and the
data.

**Tooling built for this:** `data-raw/datras_operation_types.R` (new
dir, this session) – `get_datras_operations()` (lists every currently
valid operation from the base ASMX page) and
`get_datras_operation_types(operation)` (crawls one operation’s WSDL
page for its true field/type pairs, validating `operation` against the
former first). This is a *foundation tool*, not yet the final generation
script – see that file’s own header for the concrete next steps.

**The strategic plan (sketched, not yet built):** replace
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
as the source `applyDatrasTypeSchema()`/`applyDatrasNameSchema()`
consult with one verified table, generated via a proper `data-raw/`
script (mirroring `obus`’s own convention, which is where this pattern
was validated first): 1. Types come from crawling every operation’s WSDL
page (the tool above), not from
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md).
2. Old\<-\>new name mappings are derived empirically too – call each
operation both ways (`new_names = TRUE`/`FALSE`) and match columns
positionally – rather than trusting
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
for names either. 3. The table carries only names ICES itself uses (old
and new, both server-verified) – no icesDatras-invented conventions
(e.g. `obus`’s own `sex` unification belongs one layer up, in `obus`,
not here – see `dr_get.R`’s `.dr_rename_sex_col()`). 4. Where ICES has
no distinct new name for a field, self-map (`new = old`), but flag it
(e.g. `has_distinct_new_name`) so a future real rename isn’t missed. 5.
Regenerate deliberately (same “once in a while” cadence as
`get_datras_operations()`), not patch reactively – this is the actual
fix for “built around not fixing the past.”

**A concrete lesson worth citing when building this:** `obus`’s own
`dr_lookup_fields` (`data-raw/DATASET_lookup_fields.R`) has the
*identical* wrong assumption – `"CPUEL", "Area", "Area", "int"` – added
this same session, almost certainly inherited from this same bad source.
Proof the error propagates downstream into every consumer, not just a
one-off; the strongest argument for fixing it here rather than
continuing to patch consumer-side tables.

**Two standing decisions, not to re-litigate:** - **Start from this fork
(`einarhjorleifsson/icesDatras`), not a fresh
`ices-tools-prod/icesDatras` checkout.** Verified live: upstream’s
`master` has the identical
`applyDatrasTypeSchema()`/[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
code as this fork’s pre-fix state – as a starting point the two are
equivalent, and a fresh checkout would only cost redoing the four fixes
below for no benefit. - **Keep the four
`parseDatras()`/`applyDatrasTypeSchema()` fixes** (sentinel scrub,
`xsi:nil` name leak, empty-result consistency, `Age_*` string bug) – all
independent of where type/name info comes from, still correct regardless
of this project. **Retire the
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
hot-fix-block patches** once the new table lands – all of them become
unnecessary once the table gets these right without a hand-patch,
including the three added/updated 2026-07-22 (`aphia`-\>`Valid_Aphia`
realignment, CA `Age` field-name fix, and section 8’s self-mapped
`IDX`/`CPUEL`/`CPUEA` rows – that section already frames itself as
“still a quickfix”, same conclusion this project reaches independently).

**Update (2026-07-23) — Phase A built and run:
`data-raw/build_datras_schema.R` (branch
`einar_dev/authoritative-schema-table`).** The crawler foundation above
is no longer foundation-only; it’s been driven end to end for all 8
relevant operations (HH/HL/CA/FL/LT/IDX/CPUEL/CPUEA), cross-checked
against real live pulls (100% of live raw columns matched the WSDL crawl
for every one), and joined into `datras_schema` (304 rows, internal
package data, `R/sysdata.rda`) plus a diff report
(`data-raw/datras_schema_diff.csv`, 64 disagreements). **Not yet done,
deliberately: nothing is wired into
`applyDatrasTypeSchema()`/`applyDatrasNameSchema()` yet** — this is
still Phase A (build + verify), pending review of the diff report below.
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
itself is untouched.

One correction to the strategic plan sketched above, found while
building this: step 2’s “call each operation with
`new_names = TRUE`/`FALSE` and match positionally” is **circular** for
deriving *new* names — `applyDatrasNameSchema()` derives the new name
*from
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
itself*, so such a call just mirrors this repo’s own current table, not
an independent source. There is no live server oracle for new names
covering HH/CA/FL/LT/IDX/CPUEL/CPUEA (only HL has one:
`getHLdataNewHeaders`). Revised sourcing, per column:
`DataFormat`/`FieldNameOld` come from the WSDL crawl (independent,
provably authoritative); `FieldName`/`Description` are relocated from
today’s
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
(hot-fix included), not re-derived; self-map where no match exists.

Two more fields added mid-build, at the user’s request:
`DescriptionNew`, joined in from `obus/data/dr_lookup_fields.rda`’s own
`description_new` column (obus’s hand-curated, usage-focused rewrite of
ICES’s often-terse `Description`) — **joined on `FieldNameOld`/`old`,
not `FieldName`/`new`**, since obus’s `new` column is obus’s *own*
downstream renaming convention (`AphiaID`→`aphia`, `Sex`→`sex`,
`LngtClas`→`length_mm`, etc.), not ICES’s. And `Comment`: new, empty,
for this repo’s own future ad hoc notes — nothing populates it yet.
Coverage is strongest exactly where
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
is weakest: 100% for IDX/CPUEL/CPUEA’s own `description_new` before the
join (26/26, 20/20, 33/33 in obus’s source table),
vs. `Description = ""` for every one of those rows today.

**What the diff report actually found** (four categories; full detail in
the CSV): - `type_mismatch` (14 rows) — real bugs, beyond the
already-known CPUEL/CPUEA `Area` (confirmed present):
**`LT BottomDepth`** WSDL says `decimal` (from `float`), current table
says `int`; **`HL`/`CA Valid_Aphia`** WSDL says `string`(`char`), table
says `int`; **`CA`/`HL SpecCode`** WSDL says `int`, table says `char`
(reverse direction from the `Area` bug); **`FL Cal_Distance`** and
**`FL`/`HH`/`LT Distance`** WSDL says `int`, table says `decimal`;
**`FL`/`LT DateofCalculation`** WSDL says `string`(`char`), table says
`int` — and **`IDX`’s own `DateofCalculation`** is `decimal` at the WSDL
level, a *third* distinct type for the same conceptual field
(HH/HL/CA/CPUEL/CPUEA all have it as `int`). None of these were
previously documented here. - `new_wsdl_field_not_in_fieldlist` (~30
rows) — confirms section 8’s finding in much more detail than previously
checked: IDX/CPUEL/CPUEA aren’t just missing their *own* species/age
columns, they have **zero
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
coverage at all** for common fields like `Survey`, `Year`, `Quarter`,
`Ship`, `Gear`, `HaulNo`, `Depth`, `Sex`, `ShootLat`, `DayNight`,
`HaulDur` — these currently type/rename only by accidentally matching
another RecordHeader’s row in the unfiltered pooled table, since
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
call `formatDatras()` without `record =`. Also: `IDX`’s raw
plus-group-age field is **`PlusGr`** (confirmed both by a live raw pull
and by `CA`’s own WSDL crawl using the same raw name), matching
*neither* of the two variants in obus’s dictionary (`PlusGrAge`,
`AgePlusGroup`) — that field is the one IDX row with no `DescriptionNew`
match; worth a note back to the `obus` side another day, not fixed
here. - `in_fieldlist_not_in_wsdl` (11 rows) —
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
rows the WSDL crawl didn’t find: mostly `"-"` placeholder rows
(harmless, seen on the `obus` side too) plus
`LT RecordType`/`Reserved1`/`Reserved2`. Plausible explanation, not yet
confirmed: these may describe the *upload* spec (what submitting
countries send) rather than the *query* response schema this project
crawls — worth keeping in mind, not necessarily “stale.” -
`cross_recordheader_name_mismatch` (9 rows, new diff category, added
mid-session) — same raw field, different `FieldName` across
RecordHeaders, restricted to rows where *both* sides have an explicit
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
entry (otherwise this just re-flagged the IDX/CPUEL/CPUEA gaps above as
fake “mismatches”). Three groups found: `GearEx` — HH/HL/CA rename to
`GearExceptions`, LT’s own hot-fix entry keeps it self-mapped; `Depth` —
HH/FL rename to `BottomDepth`, LT’s own hot-fix entry keeps it
self-mapped (same shape as `GearEx`, independently found); `Sex` — CA
renames to `IndividualSex`, HL to `SpeciesSex` (this one may be a
legitimate semantic distinction rather than a bug — individual- vs.
category-level sex — needs a human call, not something to auto-resolve).

Minor side-effect worth knowing about:
`usethis::use_data(internal = TRUE)` added `Depends: R (>= 3.5)` to
`DESCRIPTION` (standard for a package that ships binary internal data;
harmless, but touches a shared file so noting it here).

**Update (2026-07-23) — WSDL authority has a real limit, found via
`AphiaID`; a fifth diff category (`cross_recordheader_type_mismatch`)
now tracks it.** The premise that the per-operation WSDL page “cannot
drift from reality” is true about *wire format* (what bytes actually
arrive — the thing that matters for not destroying real values, as in
the `Area` bug) but says nothing about *semantic correctness*, and those
come apart when ICES’s own service is internally inconsistent. Concrete
case: `IDX`’s `AphiaID` is WSDL-declared `string`, while
`CPUEL`/`CPUEA`’s `AphiaID` (same WoRMS concept) is WSDL-declared `int`.
Live evidence gathered: 5 real
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
pulls across 3 surveys and 26+ distinct species — every single `AphiaID`
value is a clean integer, zero exceptions. Tellingly, **today’s
already-shipped hot-fix and obus’s independent dictionary both already
say `int` for `IDX`’s `AphiaID`** — so blindly trusting the WSDL crawl
here would *regress* a case the existing hot-fix, built on the same
domain-knowledge-plus- verification approach, already got right.

A fifth diff category was added to `build_datras_schema.R` to find these
systematically rather than one field at a time: group `datras_schema` by
`FieldNameOld`, flag any group where the WSDL-derived `DataFormat` isn’t
consistent across RecordHeaders (deliberately NOT restricted to rows
with a
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
match, unlike the name-mismatch check — `IDX`’s `AphiaID` has no such
match at all, so restricting would hide the exact case this exists for).
Live run found three groups: - **`AphiaID`**: `CPUEA`/`CPUEL` = `int`,
`IDX` = `char` (the case above). - **`DateofCalculation`**: THREE
distinct types across six tables — `CA`/`HH`/`HL` = `int`, `FL`/`LT` =
`char`, `IDX` = `decimal`. Lines up with the YYYYMMDD/YYYYDDMM
inconsistency already documented above (obus’s `description_new` text) —
the date *format* isn’t the only thing that varies by table, the wire
*type* does too. - **`PlusGr`**: `CA` = `char`, `IDX` = `decimal`. Newly
surfaced, not yet investigated — unlike `AphiaID`, a plus-group age
isn’t constrained by an external ID standard the same way, so don’t
assume it should be numeric without checking real values first.

This check only produces **candidates** — it doesn’t decide which side
is right. The proposed resolution mechanism (not yet built): a small,
explicit override layer on top of the WSDL-derived floor, applied only
when (a) domain knowledge fixes the true type and (b) live data confirms
coercion never destroys a value, with the justification recorded in the
new `Comment` field. Explicitly not a return to “hand-maintain a table”
— each entry is narrow, documented, and empirically checked, though it’s
fair to say this only manages the hand-maintained-layer tension rather
than eliminating it.

**Deliberately paused here, user’s call:** two ways to gather the
evidence needed to actually resolve these candidates were discussed —
(a) continue with targeted live spot-checks from this repo directly (as
done for `AphiaID` above), or (b) get `obus`’s full archive rebuild
(`DATASET_RAW.R`) actually completing across all surveys/years/quarters
first, then check overrides against comprehensive real data instead of
samples (the more rigorous option, but a separate undertaking in a
different repo — and `obus`’s rebuild has previously crashed on exactly
this kind of cross-file type inconsistency, so it’s not a quick
side-step). This was initially held off, pending a realization below
that reopened it.

**Update (2026-07-23) — Phase B done: `datras_schema` is now live.** The
reason to hold off on `obus` testing evaporated once it was pointed out
that the table sat unused: a local install of this branch would show
*zero* behavioral difference, since nothing read `datras_schema` yet. So
`applyDatrasTypeSchema()`/`applyDatrasNameSchema()` (`R/utilities.R`)
were switched from calling live
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
to reading the internal `datras_schema` object directly — a two-line
change in each function, `record =` filtering logic otherwise untouched.
[`getDatrasFieldList()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasFieldList.md)
itself is unchanged, still exported, still does its own live call +
hot-fix — it’s just no longer *consumed* internally.

Verified live before considering this done: - **The original bug is
fixed.** `getCPUELength("EVHOE", 2001, 4, fix_types = TRUE)`’s `Area`
now stays `character` with all 5 real codes (`Gn`/`Gs`/`Cs`/`Cc`/`Cn`)
intact across all 37,949 rows, zero coerced to `NA` (previously *every
one* was destroyed — see the finding this whole project started from,
above). Same confirmed for `CPUEA`. - **`LT`’s `BottomDepth`** now
correctly comes back `numeric` (WSDL says `decimal`) instead of the old
`int` — the first of the newly-found type mismatches to actually get
fixed, not just documented. - `getDATRAS("HH"/"CA", ...)`,
[`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md),
[`getLTassessment()`](https://einarhjorleifsson.github.io/icesDatras/reference/getLTassessment.md)
— all still work, `record =` filtering intact, nothing regressed. -
`applyDatrasNameSchema()` (the `new_names = TRUE` rename path) still
works — spot-checked `Ship` → `Platform`, `GearEx` → `GearExceptions`.

**New finding while verifying:
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
also calls `formatDatras()` without `record =`** (`R/getCatchWgt.R`) —
not previously noted, since this file hadn’t been read this session
until now. Its output is HH-shaped plus `CatchWgt`/`Valid_Aphia`, so
like
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
it relies on unfiltered, pooled name-matching against the whole
`datras_schema` table rather than a proper `record = "HH"` filter.
Tested live (`NS-IBTS`/2022/Q1) and it works correctly — but that’s
incidental, not principled: when `record = NULL`,
`applyDatrasTypeSchema()` builds `char_cols`/`int_cols`/`dbl_cols` from
the *entire* table and applies them **sequentially** (char, then int,
then dbl), so if a field name collides across RecordHeaders with
different declared `DataFormat`s, whichever bucket is applied *last*
wins — not a designed priority, just statement order. Confirmed this
concretely: pooled `AphiaID` (declared `char` for `IDX`, `int` for
`CPUEL`/`CPUEA`) came out `integer` for `IDX` too (int processed after
char — happens to match the domain-correct answer); pooled `PlusGr`
(`char` for `CA`, `decimal` for `IDX`) came out `numeric` (dbl processed
last). Both landed on a reasonable value here, but by accident of code
order, not because the mechanism is actually sound. **Still open, not
done this session** (kept this change to exactly what was asked — the
schema-source swap): pass explicit `record =` in
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)/[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)/[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
so each is matched against only its own RecordHeader’s rows instead of
relying on this accidental ordering.

**Update (2026-07-23) — the `record =` gap above is closed, not just
documented.** User’s call, after discussion: don’t rely on every caller
remembering to pass `record` correctly — make it structurally impossible
to omit. `formatDatras()`, `applyDatrasTypeSchema()`, and
`applyDatrasNameSchema()` (`R/utilities.R`) all had their
`record = NULL` default removed; `record` is now a required argument
with no fallback. A missing argument now fails immediately
(`argument "record" is missing, with no default`) instead of silently
matching the whole pooled table. A new `filter_datras_schema(record)`
helper also validates `record` itself — rejects `NULL`/`NA`/unrecognised
RecordHeader values with a clear error listing the valid options — so a
*typo’d* record (not just a missing one) fails loudly too, rather than
silently matching zero rows. The four previously-unfiltered callers were
updated:
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
→ `"IDX"`,
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)
→ `"CPUEL"`,
[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
→ `"CPUEA"`,
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
→ `c("HH", "HL")` (its output is HH-shaped plus the HL-sourced
`Valid_Aphia` — checked it only ever touches HH/HL data, never CA). The
other 6 callers (already passing a valid value, plus
[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
which validates its own `record` against `c("HH","HL","CA")` before ever
reaching `formatDatras()`) were untouched.

**A design mistake was caught before it shipped, not after — worth
recording so the same check gets run again next time this kind of change
is made.** The natural first attempt (“just switch `==` to `%in%` so
`record` can be a vector, for
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)’s
two-header case”) would have been silently catastrophic:
`applyDatrasTypeSchema()`’s existing filter used single-bracket indexing
(`datras_field_list["RecordHeader"] == record`), and
`data.frame["col"] %in% x` does **not** behave like
`data.frame[["col"]] %in% x` — it collapses to a length-1 logical rather
than one value per row, so `%in%` on a single-bracket slice matched
**zero rows for every RecordHeader**, for every caller, not just the
ones being fixed. Caught by testing the exact expression live before
writing it into the function, not by reasoning about it. Fixed by
switching to double-bracket (`[["RecordHeader"]]`) at the same time —
which also removed a pre-existing inconsistency
(`applyDatrasNameSchema()` already used double-bracket;
`applyDatrasTypeSchema()` didn’t).

**Fixing the `record =` gap surfaced a real regression, addressed with a
second override.** Once
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
is correctly scoped to only `IDX`’s own rows, it picks up `IDX`’s own
WSDL-declared type for `AphiaID` — `char` — instead of the
accidentally-correct `int` pooling had produced. This is exactly the
already-discussed `AphiaID` finding, so the override described just
above (`build_datras_schema.R`, section “4b. Deliberate, documented
overrides”) was needed for this fix to not be a regression, not merely a
nice-to-have. Checking that override also surfaced a second, analogous
case:
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)’s
new `HL` scoping exposes `Valid_Aphia` (the same WoRMS-ID concept as
`AphiaID`, under HL/CA’s naming) as WSDL-declared `char` too. Unlike
`AphiaID`, `HL` and `CA` *agree* with each other here — no internal WSDL
inconsistency to point to — so the evidence for overriding is weaker on
that specific axis. But the pre-Phase-B hot-fix already shipped
`Valid_Aphia` as `int` (`db_extra` block), so leaving it `char` now
would be a live regression relative to yesterday’s behaviour, not just
an inconsistency with `AphiaID`. Live-checked 2026-07-23: `HL` (183
distinct values) and `CA`, zero non-numeric `Valid_Aphia` values in
either. Added as a second override, same pattern
(`build_datras_schema.R`, `Comment` field records the justification for
each row it touches).

Verified live end-to-end after both changes landed: the four
newly-scoped functions still work (`CPUEL`/`CPUEA`’s `Area` fix intact,
zero rows destroyed across 37,949 + 975 real rows); `HH`/`CA`/`FL`/`LT`
and `new_names = TRUE` unaffected;
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
produces identical row counts with `CatchWgt` and now-`integer`
`Valid_Aphia`;
[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)’s
own invalid-`record` early return (`FALSE`) is unaffected since it never
reaches `formatDatras()` in that path; all three new failure modes
(missing/`NULL`/unrecognised `record`) fail with a clear message instead
of silently doing the wrong thing.

**Update (2026-07-23) — `build_datras_schema.R`’s obus dependency is no
longer a live, cross-repo read.** User flagged this directly: reading
`~/R/Pakkar/obus/data/ dr_lookup_fields.rda` live at build time (for
`DescriptionNew`) meant icesDatras’s own reproducibility silently
depended on an independently-evolving sibling repo’s *current* state —
the “gracefully degrade to NA with a warning if the checkout is missing”
fallback wasn’t good enough; icesDatras’s own build needs to be fully
self-contained, full stop.

Fixed by splitting the one script into two: -
**`data-raw/refresh_obus_description_new_snapshot.R`** (new) — the only
place that reads obus live. Run manually and deliberately, only when
pulling in obus’s latest hand-curated descriptions (matching this
project’s existing “regenerate deliberately” cadence). Writes
`data-raw/obus_description_new_snapshot.csv`: 305 rows (`RecordHeader`,
`FieldNameOld`, `DescriptionNew`), renamed to icesDatras’s own column
convention rather than obus’s (`table`/`old`/`description_new`), so the
snapshot reads as an icesDatras-owned artifact decoupled from obus’s own
naming even if obus changes it later. - **`build_datras_schema.R`** —
now reads only the committed CSV snapshot. No
[`file.exists()`](https://rdrr.io/r/base/files.html) check, no fallback,
no absolute path into another repo — the file is just always there,
committed to this repo, like any other `data-raw/` input.

Verified the refactor changed only the *mechanism*: re-ran the full
build before and after — identical `datras_schema` (304 rows), identical
`DescriptionNew` coverage per RecordHeader (CA 2, CPUEA 33, CPUEL 20, FL
25, HH 5, HL 8, IDX 24, LT 42), identical 69-row diff report.
`AphiaID`/`Valid_Aphia` overrides above are unaffected by this — they
were already hardcoded literals in `build_datras_schema.R`, not read
from obus at runtime; only citing obus as supporting evidence in a
comment, which was never a robustness problem.

**Update (2026-07-23) — `DescriptionNew`/`Comment` reviewed against
`obus`’s real source, one recollection corrected, one concrete new
upstream flag found.**

*Provenance, checked directly rather than assumed:* `icesVocab` does
**not** feed `description_new` — it feeds a separate, distinct `obus`
table, `dr_lookup_vocabulary` (`obus/data-raw/DATASET_vocabulary.R`),
mapping individual *code values* (e.g. `Gear` code `"GOV"`) to their
meanings, not whole-field descriptions.
`Description`/`description_new`’s provenance is the field-list-style
text this repo already uses, not `icesVocab`.

*Reviewed whether small-vocabulary fields already have their categories
spelled out in `description_new` (it was assumed they did) — checked
live, they mostly don’t.* `dr_lookup_vocabulary` gives an exact code
count per field (`DayNight`=2, `PlusGr`=2, `DataType`=5, `HaulVal`=8, up
to `StatRec`=7159). For every small field checked
(`DayNight`/`PlusGr`/`SpecCodeType`/`ThermoCline`/`PelSampType`/`DataType`/`OtGrading`/
`StdSpecRecCode`/`HaulVal`), `description_new` either doesn’t exist or
describes the concept without listing what the codes actually mean
(e.g. `PelSampType`’s entire `description_new` is *“Pelagic trawl
sampling type”* — no mention that valid values are `1`/`2`/`3`/`-9` and
what each means, despite `dr_lookup_vocabulary` already having that
exact mapping). Since the standing principle is “full story lives in
`obus` only” (this session’s explicit instruction — icesDatras consumes
a finished snapshot, it doesn’t re-derive or enrich), fixing this
belongs in `obus`’s own `description_new` generation, not patched into
icesDatras’s snapshot. Flagged as its own follow-up task (not started)
rather than fixed here.

*A concrete “upstream is wrong” case turned up while checking the
above*, exactly the kind of finding `Comment` exists for: `icesVocab`’s
own `PlusGr` vocabulary says the only valid values are `"+"` (age plus
group) and `"-9"` (no plus group) — but a live
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
pull (`NS-IBTS` 1965 Q1, species 126417) returned a raw `PlusGr` value
of `"5"`, matching neither. Likely explanation, not confirmed: `obus`’s
`icesVocab` join matches by raw field name only, with no `RecordHeader`
scoping, so `CA`’s flag-style `PlusGr` vocabulary may be getting applied
to `IDX`’s different, numeric `PlusGr` field, which just happens to
share the same raw XML tag name across two unrelated DATRAS operations —
which would also explain why this project’s own diff report already had
`PlusGr` down as a `cross_recordheader_type_mismatch` (`CA` = `char`,
`IDX` = `decimal`): not one side being “wrong,” but two different
concepts sharing one name. Recorded as an `UPSTREAM FLAG` in
`datras_schema`’s own `Comment` column for the `IDX`/`PlusGr` row, and
as the same follow-up task as the vocab-embedding item above.

**`Comment`’s purpose is now stated precisely, not left as a vague “ad
hoc notes” field**: it flags rows where something needs fixing
**upstream** (ICES’s field list, `icesVocab`, or the DATRAS webserver
itself) — a worklist, not general commentary. The `AphiaID`/
`Valid_Aphia` overrides already fit this; `IDX`’s `PlusGr` above is the
first row populated under the clarified definition.

**`DescriptionNew` is now always populated when `Description` is**
(mechanical fix, applied directly in `build_datras_schema.R`, no `obus`
involvement needed): where the join produces `NA` — no matching `obus`
row, or a matching row with no `description_new` — it now falls back to
`Description` instead of leaving `NA` for downstream code to coalesce
itself, mirroring the fallback `obus`’s own consumers already do
(`obus/data-raw/metadata_helpers.R:411`). Verified: `description_new`
coverage is now 100% for every RecordHeader (was 2–42 per table before);
the one exception is rows where *both* sources are genuinely empty
(e.g. self-mapped rows with `Description = ""` to begin with), which
correctly stay blank rather than being backfilled with nothing.

*On keeping the build “dynamic” as the DATRAS webserver changes over
time* — largely already true, worth stating explicitly rather than
adding new machinery for it now: `get_datras_operations()` and the WSDL
type crawl both re-fetch live on every run, so new/changed operations
and types are picked up automatically next time this script is
deliberately re-run; `map_wsdl_type()` already
[`stop()`](https://rdrr.io/r/base/stop.html)s on any WSDL type string it
doesn’t recognise rather than silently guessing, so a genuinely new type
shows up as a loud failure, not silent mis-typing. No new code added for
this — flagged here so it isn’t re-litigated from scratch, not because
anything is currently broken.

**Update (2026-07-23) — correction: “full story lives in obus only”
should have said icesDatras only.** The user caught their own wording
immediately after the previous update shipped. Real direction:
icesDatras should derive `Description`/`DescriptionNew` **fully
independently**, via `icesVocab` directly, with no dependency on `obus`
at all — not even the committed-snapshot model from the update above.
Clarified by direct question: the existing hand-authored analytical text
(join-order notes, “silent error” warnings, etc. — genuinely not
derivable from any API) gets **ported into icesDatras permanently as its
own content**, no ongoing sync; `obus` reads FROM icesDatras from now on
if it wants this content, not the reverse.

Concretely: - `data-raw/obus_description_new_snapshot.csv` → renamed
`data-raw/datras_field_descriptions.csv`. Content unchanged; reframed as
icesDatras’s own hand-maintained file, with the `obus` origin noted as
one-time provenance, not an ongoing relationship. -
`data-raw/refresh_obus_description_new_snapshot.R` deleted — no more
deliberate-refresh workflow; that was the snapshot model this update
retires. - New `data-raw/datras_vocabulary.R`: `get_icesvocab_types()`,
`resolve_vocab_key()`, `get_vocab_codes()`, `first_usable_vocab()` — a
small, self-contained wrapper around
[`icesVocab::getCodeTypeList()`](https://rdrr.io/pkg/icesVocab/man/getCodeTypeList.html)/`getCodeList()`
(already in `DESCRIPTION`’s `Suggests`, no new dependency). Mirrors
`data-raw/datras_operation_types.R`’s shape (a focused crawler module,
sourced by the main build script). - `build_datras_schema.R`’s new step
5b appends `"Codes: X = ...; Y = ...."` to `DescriptionNew` for fields
with a small enough (≤20) resolved vocabulary, for every field where one
resolves — the ported/fallback text from step 4 is never replaced, only
extended.

**Research that shaped the design, all verified live rather than
assumed:** - `icesVocab`’s `Key`s are prefixed (`TS_DataType`, `AC_Sex`,
plus some bare keys like `Gear`) — `TS_` = Trawl Survey (DATRAS’s own
domain), `AC_` = Acoustic survey (a different ICES data domain). Of
`datras_schema`’s 151 unique `FieldNameOld` values, 43 have some
icesVocab match; 4 matched under **both** `TS_` and `AC_` originally
identified, actually 9 once checked properly (`Survey`, `Quarter`,
`DoorType`, `Month`, `Sex`, `DevStage`, `AreaType`, `AgeSource`,
`MaturityScale`). - **Confirmed live**: `obus`’s own
`dr_lookup_vocabulary` pools `TS_Sex` (7 codes, incl.
`Berried`/`Neutral`/“Not included”) and `AC_Sex` (4 simpler codes)
indiscriminately — 7+4=11, matching its own reported count exactly. A
real, confirmed imprecision in `obus`’s existing approach.
`resolve_vocab_key()` here instead prefers `TS_` explicitly. - **A
subtlety the naive “always prefer TS\_” rule would have gotten wrong**:
some codeTypes are registered but have zero actual codes. `TS_Survey`
has 0 codes; `AC_Survey` has 22; a bare `Survey` key (not found in the
first, narrower spot-check) has 133. Blindly picking the “preferred”
prefix would have silently produced no enrichment for `Survey` at all.
Fixed with `first_usable_vocab()`, which tries each candidate in
preference order until one yields usable codes — `Survey` correctly
resolves to the bare key’s 133 codes (though it’s still excluded from
inline enrichment by the ≤20 size cutoff regardless). - **Two fields
needed hand-verification against the real archive before applying their
vocabulary, using `obus::dr_con()`** (the user’s suggestion, checked
working — `duckdbfs`/ `duckdb` both installed; note `dr_con()`’s own
column names are `obus`’s further-renamed convention, not raw
`FieldNameOld` or even icesDatras’s own new names — e.g. `CA`’s
plus-group column there is `AgePlusGroup`, `IDX`’s is `PlusGrAge`): -
`GearEx` — flagged by this build’s own
`cross_recordheader_name_mismatch` (`LT` self-maps, `HH`/`HL`/`CA`
rename to `GearExceptions`), but that’s a naming disagreement, not a
vocabulary one. Checked `HH`’s `GearExceptions` and `LT`’s `GearEx` real
values: every one observed (`R`/`I2`/`B`/`S2`/`SB`/`D`/`S`/`DB`) matches
`TS_GearEx`’s vocabulary exactly. Enriched normally, no exception
needed. - `PlusGr` — already flagged
(`cross_recordheader_type_mismatch`, `CA`=`char`, `IDX`=`decimal`) with
an `UPSTREAM FLAG` `Comment` from the earlier update (`icesVocab` says
`"+"`/`"-9"` only, `IDX`’s real data showed `"5"`). Checked `CA`’s real
`AgePlusGroup` values this time: exactly `"+"`/`NA`, matching
`TS_PlusGr`’s vocabulary exactly. So the vocabulary **is** correct for
`CA`, just not `IDX` — a genuine per-RecordHeader exception (hand-coded
in step 5b), not a global skip. Verified: `CA`’s row is now enriched,
`IDX`’s is not, existing `Comment` untouched. - The remaining ambiguous
`TS_`/`AC_` pairs (`DoorType`, `AgeSource`, `MaturityScale`, plus `Sex`
above) were resolved via the same domain-based reasoning (`TS_` = trawl
survey, matches DATRAS) rather than an individual `dr_con()` check each
— a deliberate scope boundary, not an oversight: the principle is
already evidence-backed by the `Sex` check, and exhaustively
re-verifying every instance wasn’t judged worth the additional
live-query cost for this pass. - **Out of scope, deliberately**:
exhaustive `dr_con()` verification of all 22 multi-RecordHeader
vocab-matched fields (only the flagged/risky subset above was checked);
a reference/link mechanism for large vocabularies (just skipped, ported
text stays); resolving the root cause of `obus`’s own
`PlusGr`/`icesVocab` join issue (that’s the separately-flagged task,
`task_6f6590be`, running independently — reconcile with its findings
once it completes).

Verified end to end: `datras_schema` still 304 rows, 69-row diff report
unchanged (content sourcing changed, not the diff mechanism);
`AphiaID`/`Valid_Aphia` overrides and the `record =` required-argument
fix both untouched; `devtools::load_all()` succeeds.

**Open question, deliberately paused (2026-07-23): should
`datras_schema` be exported?** Currently internal-only (`R/sysdata.rda`,
`usethis::use_data(internal = TRUE)`), inaccessible outside the package
except via `:::`. Raised directly: no structural reason not to export it
— its columns (`RecordHeader`, `FieldNameOld`, `FieldName`,
`DataFormat`, `has_distinct_new_name`, `Description`, `DescriptionNew`,
`Comment`) are already clean enough for public consumption, and it fits
this session’s own direction (icesDatras as the canonical source others,
e.g. `obus`, should eventually read FROM). Two real considerations, not
blockers: (a) exporting makes it public API — right now the table is
still actively evolving (overrides added mid-session, vocab enrichment
just landed, `DateofCalculation` and some multi-header fields still
openly unresolved), so a future column change would become a breaking
change rather than a free internal refactor; (b)
`usethis::use_data(datras_schema)` (without `internal = TRUE`) will add
`LazyData: true` to `DESCRIPTION` automatically, same category as the
`Depends: R (>= 3.5)` side-effect already noted above. If exporting,
document via `R/data.R` with a roxygen `@format` block (the user’s own
convention) — no existing precedent for this in the package currently
(no `R/data.R`, and the one historical exported dataset, `aphia`, no
longer exists). **Not decided — paused because the user wanted to test
the Phase A/B work via a full `obus` download first**, not because of
any concern found with exporting itself.

**Status (2026-07-23): resolved — the real-world test succeeded.** User
built this branch locally and ran `obus`’s actual pipeline against it:
`DATASET_RAW_download.R` and `DATASET_RAW_consolidate.R` (see “Related
project” below for what those are — the split `obus`’s own
`DATASET_RAW.R` needed) both completed with 100% success. This is the
direct, real-world validation of the original motivating bug
(`CPUEL`/`CPUEA`’s `Area` silently coerced to `NA`, the exact crash this
whole project started from) — confirmed no longer happening.
Independently confirmed via the installed package itself, not just
inferred from the successful run: `applyDatrasTypeSchema()`’s `record`
argument has no default (this session’s fix) and the internal
`datras_schema` object is present. Also re-confirmed live while helping
split `obus`’s `DATASET_IDX.R` the same way: the older
`xsi:nil`-in-column-name leak and the `Age_0`..`Age_15` character-`"NA"`
bug (both fixed well before this session, on `einar_dev/integration`)
are still genuinely fixed in the installed package — a real
`getIndices("NS-IBTS", 1965, 1, 126417, ...)` pull came back with clean
names and uniformly numeric `Age_*` columns.

## Related project

`/Users/einarhj/R/Pakkar/obus` — a separate project that consumes
icesDatras output. `obus/data-raw/DATASET_lookup_fields.R` contains a
fuller hand-curated field dictionary (`dr_lookup_fields`) and was used
as the reference for the correct LT old→new name mappings (see the
`add_lt` tribble in that file).

**On
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
specifically (relevant to issue \#46 above):** its own response schema
is a full `HH`-shaped haul record plus `CatchWgt`/`aphia` — i.e. ICES’s
server joins a haul (HH) to a derived-from-HL weight value and returns
the combined row, not a lean species-weight table. `obus` briefly
archived
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)’s
output as its own table (`CW`), then removed it (2026-07-21) once this
was recognized: `obus` already computes the identical thing locally,
*better* (with zero-fill and `DataType == "C"` scaling
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
itself lacks), from `HH`+ `HL` it already has — see
`obus/R/dr_products.R`’s `dr_catch_weight_by_haul()`. Worth keeping in
mind for any other icesDatras function whose output turns out to just be
HH/HL(/CA) joined server-side — it likely doesn’t need its own separate
consumer-side archive either.

**Update (2026-07-23) — `obus`’s `data-raw/DATASET_RAW.R` split into
download/consolidate, in preparation for testing today’s icesDatras work
via a full archive rebuild.** User’s own requirement: the download stage
should be solely dependent on icesDatras (no `obus` loaded at all);
consolidation is a pure `obus` construct and needs neither icesDatras
nor a live connection — only the download stage’s own output. Split into
`obus/data-raw/DATASET_RAW_config.R` (shared constants/manifest helpers,
no package dependency), `DATASET_RAW_download.R` (icesDatras-only; also
now writes the ICES survey×year catalog to a file so consolidate never
has to call icesDatras itself to get it), and
`DATASET_RAW_consolidate.R` (all the existing `obus`-specific logic —
`dr_translate()`/`dr_add_id()`/KV_METADATA — untouched). `REBUILD_ALL.R`
updated to source both. Confirmed live: `dr_translate()`’s safety-net
role for `CPUEL`/`CPUEA` is genuinely still needed, not made redundant
by today’s icesDatras changes — this session fixed `DataFormat`/type
issues and the `record =` scoping bug, but deliberately kept
`AphiaID`/`LngtClas`/`CPUE_number_per_hour`/`Cal_DateID`/`ShootLon`
self-mapped rather than inventing new names, so
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)’s
`new_names = TRUE` still doesn’t translate them — `obus`’s own
dictionary-based safety net still has real work to do there.

**A DATRAS-server-side bug found in the process, not an icesDatras or
obus issue**: `obus` had been dropping LT’s `Depth` column during
consolidation because it’s identical to `BottomDepth` — confirmed still
true, and worth recording here since it directly follows today’s earlier
finding that LT’s `BottomDepth` needed its own `DataFormat` fix
(`float`/`decimal`, not `int` — see this file’s
`cross_recordheader_type_mismatch` update above). Both `Depth` and
`BottomDepth` being present and identical for the same DATRAS operation
is ICES sending the same value under two field names — a webserver-side
redundancy, not anything either package’s own logic produces. Now
handled correctly: kept in the download stage (persists exactly what
icesDatras returns, no shaping decisions), dropped only at
consolidation, with the finding itself documented in that script’s own
comment rather than silently applied. Not yet raised with ICES.

**Update (2026-07-23) — real-world test succeeded; `obus`’s
`DATASET_IDX.R` split the same way, with two dead workarounds found and
removed, not just relocated.** User ran the actual split scripts
(`DATASET_RAW_download.R`, `DATASET_RAW_consolidate.R`) against this
branch, locally built — 100% success, the direct validation this whole
project was aimed at.

Applied the identical download/consolidate split to `obus`’s other
icesDatras-fetching script, `DATASET_IDX.R` (age-based survey indices —
its own script since
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
has no vectorized argument and no haul grain, so it never went through
`DATASET_RAW.R`’s SPECS/manifest machinery to begin with):
`DATASET_IDX_config.R` (shared, no package dependency, kept independent
from `DATASET_RAW_config.R` — different manifest schema),
`DATASET_IDX_download.R` (icesDatras-only), `DATASET_IDX_consolidate.R`
(pure `obus`).

Its download stage carried two `obus`-side workarounds inline for old
icesDatras bugs (`.strip_xsi_nil()` — an `obus` function — and an
`Age_0..Age_15` character-to-numeric coercion, both for bugs fixed well
before this session on `einar_dev/integration`). Rather than
mechanically relocate them into the new download script, checked whether
they were still needed: **verified live against the actual installed
package** that both underlying bugs are genuinely fixed (a real
`NS-IBTS`/1965/Q1/126417 pull came back with clean column names and
uniformly numeric `Age_*` columns) — so both were deleted outright, not
moved. One piece of the same block *wasn’t* a bug workaround — `obus`
renaming icesDatras’s `AgePlusGroup` to its own `PlusGrAge` convention —
and that genuinely moved to the consolidate script, since renaming is a
shaping decision the download stage shouldn’t make.
