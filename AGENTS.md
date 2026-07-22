# icesDatras — Project Notes

This project is a local clone of the [icesDatras](https://github.com/ices-tools-prod/icesDatras) R package.
Work here is done via `devtools::load_all()` — do **not** call `library(icesDatras)`.

## Key files modified

- `R/getDatrasFieldList.R` — fetches the ICES DATRAS field list from the web service. Contains a
  hot-fix block (`if(TRUE) { ... }`) that corrects upstream errors and fills gaps in the URL response.
- `R/getFlexFile.R` — changed `record = "HH"` to `record = "FL"` in the `formatDatras()` call,
  now that FL entries exist in the field list.

## Hot-fix block: what it does

### 1. Miscellaneous format/description fixes
- `DataFormat == "float"` normalised to `"decimal"` across all records.
- `Year` forced to `"int"` everywhere.
- FA `StationName` forced to `"char"`; FA/LT `HaulNumber` forced to `"int"`.

### 2. LT — wrong `FieldNameOld` for three HH-shared fields
The URL echoes the new name instead of the actual old column name that
`getLTassessment(..., new_names = FALSE)` returns:

| FieldName | FieldNameOld (URL, wrong) | FieldNameOld (correct) |
|---|---|---|
| `Platform` | `Platform` | `Ship` |
| `StationName` | `StationName` | `StNo` |
| `HaulNumber` | `HaulNumber` | `HaulNo` |

### 3. LT — missing rows for ~40 HH-style columns
The URL only covers the LT upload-spec fields (~22 rows). `getLTassessment()` returns many
additional columns (coordinates, gear metrics, haul metadata, etc.) absent from the URL list,
so `new_names = TRUE` translation silently failed for them. The hot-fix appends the correct
`FieldName`/`FieldNameOld` rows for all of these. After the fix, `new_names = TRUE` vs
`new_names = FALSE` correctly translates 22 column pairs (e.g. `ShootLat` ↔ `ShootLatitude`,
`StatRec` ↔ `StatisticalRectangle`, etc.).

### 4. FL — entirely absent from the URL
`getFlexFile()` returns all HH columns plus FL-specific swept-area columns
(`ICESArea`, `Cal_DoorSpread`, `DSflag`, `Cal_WingSpread`, `WSflag`, `Cal_Distance`,
`DistanceFlag`, `SweptAreaDSKM2`, `SweptAreaWSKM2`, `SweptAreaBWKM2`, `DateofCalculation`).
The URL has no FL entries at all. The hot-fix builds FL entries by copying the matching HH rows
(preserving `FieldNameOld` and `Description`) and appending the FL-only extras.

### 5. Back-filled Descriptions for LT and FL
After adding LT and FL rows, any row with an empty `Description` is back-filled from the
matching HH row (same `FieldName`).

### 6. DB-added columns not in the upload spec
The ICES database appends extra columns that have no entry in the upstream field list:

| RecordHeader | FieldName | FieldNameOld | DataFormat |
|---|---|---|---|
| HH, HL, CA | `DateofCalculation` | `DateofCalculation` | `int` |
| HL, CA | `aphia` | `Valid_Aphia` | `int` |

`Valid_Aphia` is the DB-validated aphia code; the new canonical name used here is `aphia`.

### 7. Known remaining gap — CA `Age`
`getDATRAS("CA", ..., new_names = TRUE)` returns a column named `Age`. The upstream field list
has `IndividualAge` (new) / `AgeRings` (old); icesDatras returns `Age` instead, matching
neither. This mismatch is left unresolved intentionally.

**Update (2026-07-22):** live-verified as the *only* field, across HH/HL/CA/FL/LT, missing from
the (hot-fixed) field list entirely (checked against NS-IBTS 2022 Q1 real data — see
`einar_dev/ca-age-field-name-gap`). Also: calling with `new_names = FALSE` *still* returns `Age`,
not `AgeRings` — meaning the raw server response itself uses `Age`, the same pattern as the
already-fixed "LT wrong `FieldNameOld`" case (section 2 above). That's evidence this is fixable
with a field-list correction (`FieldNameOld` for CA's `IndividualAge` row: `AgeRings` → `Age`),
not the deeper `getDATRAS()` renaming surgery originally assumed here — needs confirming on the
branch itself before assuming it's that simple.

## Local fixes applied (2026-07-06)

Three bugs were fixed locally in `R/utilities.R` and `R/getDATRAS.R`. Each has a corresponding
upstream issue that should be raised with the package developer.

### Fix 1 — `-9` sentinel not scrubbed by `fix_types = TRUE` (`R/utilities.R`)

**What was fixed:** `applyDatrasTypeSchema()` now replaces numeric `-9` / `-9L` with `NA` for all
`int` and `decimal` columns, after type coercion.

**Why `parseDatras()` alone is insufficient:** `parseDatras()` scrubs `-9` via string comparison
(`x[x == -9] <- NA`), which catches the string `"-9"` but not `"-9.0"` — a valid decimal
representation DATRAS uses for missing float fields. After `simplify()` converts such strings to
numeric, the `-9.0` value becomes `-9` and passes through `applyDatrasTypeSchema()` unchanged.

**Upstream issue to raise:**
> **`fix_types = TRUE` does not fully scrub DATRAS `-9` sentinels**
>
> `applyDatrasTypeSchema()` coerces column types but never converts the `-9` sentinel to `NA`.
> `parseDatras()` attempts this via string comparison, but misses decimal representations such as
> `"-9.0"`. Minimal reproducible example:
>
> ```r
> # Simulate what parseDatras + simplify produce for a "-9.0" decimal field:
> x <- data.frame(HaulDur = -9)   # numeric -9 survived simplify()
> applyDatrasTypeSchema(x, record = "HH")$HaulDur
> #> [1] -9   # expected NA
> ```
>
> Sentinel scrubbing should be applied inside `applyDatrasTypeSchema()` for `int` and `decimal`
> columns, so that `fix_types = TRUE` is a reliable single-step clean-up regardless of how values
> arrive.

---

### Fix 2 — `getDATRAS()` returns `FALSE` instead of a zero-row data frame (`R/getDATRAS.R`)

**What was fixed:** The two availability-check early exits (all years unavailable; all quarters
unavailable) now `return(data.frame())` rather than `return(FALSE)`. **Update (2026-07-21):**
this was extended to `R/getFlexFile.R` and `R/getLTassessment.R` too (their own early-exit
`return(FALSE)`s → `return(data.frame())`) — the "should be fixed in the same sweep" note below
was acted on; check `git diff` for the actual patches, this file wasn't updated at the time.
**Still needed, not yet applied:** `getIndices()` and `getCatchWgt()` have the identical
`return(FALSE)` pattern for their own availability checks (verified live from the `obus` side,
2026-07-21 — `getIndices(..., year = <unavailable>)` returns `FALSE`, `nrow()` on it errors the
same way). Same fix, same two functions still to touch.

**Upstream issue to raise:**
> **`getDATRAS()` returns the scalar `FALSE` (or `NULL`) instead of a zero-row data frame**
>
> There are two distinct paths that produce a non-data-frame result:
>
> 1. **Early exits** — when `intersect(years, available_years)` or the quarter availability
>    check is empty, the function messages the user and `return(FALSE)`.
> 2. **`NULL` propagation** — when the DATRAS web service returns an empty XML response,
>    `parseDatras()` returns `NULL`. `do.call(rbind, list(NULL))` then propagates `NULL` out
>    of `getDATRAS()` rather than an empty data frame, silently bypassing `formatDatras()`.
>
> Both paths break idiomatic downstream code:
>
> ```r
> out <- getDATRAS("HH", "NS-IBTS", years = 1800, quarters = 1)
> nrow(out)      # Error: argument is not a data frame  (FALSE path)
>
> # Empty-response path (valid survey/year/quarter but no records uploaded yet):
> out <- getDATRAS("HH", "NS-IBTS", years = 2024, quarters = 1)
> nrow(out)      # Error: argument is not a data frame  (NULL path)
> ```
>
> Fix the early exits with `return(data.frame())` and add a `NULL` guard after
> `do.call(rbind, out)`. The same early-exit issue exists in `getFlexFile()` and
> `getLTassessment()` and should be fixed in the same sweep.

---

### Fix 3 — `xsi:nil` attribute leaks into column names (`R/utilities.R`)

**What was fixed:** The `parseDatras()` name-extraction regex was changed from `(.*?)` (intended
lazy but unreliable across regex engines) to `([^ >]+)[^>]*`, which unambiguously stops the
capture at the first space or `>` and then skips any remaining tag attributes with `[^>]*`.

**Upstream issue to raise:**
> **`parseDatras()` leaks XML attributes into column names (e.g. `Age_6 xsi:nil="true"`)**
>
> When DATRAS returns a self-closing null field such as `<Age_6 xsi:nil="true" />`, line 46
> of `parseDatras()` expands it to `<Age_6 xsi:nil="true"> NA </Age_6 xsi:nil="true">`. The
> subsequent name-extraction regex `gsub(" *<(.*?)>.*", "\\1", ...)` then captures
> `Age_6 xsi:nil="true"` as the column name rather than `Age_6`:
>
> ```r
> # Reproduce the bad name extraction:
> gsub(" *<(.*?)>.*", "\\1", '    <Age_6 xsi:nil="true">NA</Age_6>')
> #> [1] "Age_6 xsi:nil=\"true\""   # expected "Age_6"
> ```
>
> Fix: replace `(.*?)` with `([^ >]+)[^>]*` so tag attributes are skipped without relying on
> lazy quantifier support:
>
> ```r
> gsub(" *<([^ >]+)[^>]*>.*", "\\1", '    <Age_6 xsi:nil="true">NA</Age_6>')
> #> [1] "Age_6"
> ```

---

### Fix 4 (not yet applied here — found from the `obus` side, 2026-07-21) — a numeric column
stays `character("NA")` when it's entirely missing in one response, even after Fix 3's name fix

**Distinct from Fix 3.** Fix 3 stops the `xsi:nil` *attribute* leaking into the column *name*.
This is a separate bug in the column's *value*, one level deeper — it happens even with Fix 3
already applied, whenever every value in a numeric column is missing for a given response (a
single-row response — `getIndices()`/`getCPUEAge()` — is the case most likely to trigger it,
since there's no other row's real value to pull the column's inferred type toward numeric).

**Root cause**, both pieces in `R/utilities.R`:

1. `parseDatras()` line 46 turns a self-closing/empty tag into the **literal text** `"NA"`:
   ```r
   x <- gsub("^ *<(.*?) />$", "<\\1> NA </\\1>", x)
   ```
   Two lines later, `-9` and `""` are explicitly normalized to a real `NA`:
   ```r
   x[x == -9] <- NA
   x[x == ""] <- NA
   ```
   but the `"NA"` string this substitution just created is never similarly normalized — it
   survives as a genuine, non-missing character value all the way to `simplify()`.

2. `simplify()` decides whether a character column can be safely converted to numeric by
   comparing NA counts before and after conversion:
   ```r
   if (is.character(x)) {
     y <- as.numeric(x)
     if (sum(is.na(y)) == sum(is.na(x)))
       x <- y
   }
   ```
   `as.numeric("NA")` correctly yields `NA_real_`, so `sum(is.na(y))` counts every row of an
   all-missing column correctly. But `is.na("NA")` is `FALSE` — the character string `"NA"` is a
   real, present value from `is.na()`'s point of view, not a missing one — so `sum(is.na(x))` is
   `0` for a column made entirely of these converted empty tags. `0 != n`, the guard fails, and
   the whole column is left `character`, with the literal text `"NA"` in every cell.

**Reproduce:**
```r
d <- getIndices(survey = "NS-IBTS", year = 1965, quarter = 1, species = 126417,
                fix_types = TRUE, new_names = TRUE)
sapply(d[grep("^Age_", names(d))], class)
# Age_0-5 numeric/integer (real catch at those ages here); Age_6-15 character,
# holding the literal string "NA"
```

**Impact:** affects every function going through `formatDatras(fix_types = TRUE)` whenever a
numeric column is entirely missing in one response — `getIndices()`/`getCPUEAge()` especially,
since they return exactly one row per call. Building an archive from many separate per-call
responses (the normal usage pattern here) means some files get the column as numeric and others
as character, breaking any tool that expects one type per column across files (DuckDB, Arrow,
`bind_rows()` without prior coercion) — this is exactly how it was found, from the `obus` side,
building a per-response parquet archive of `getIndices()` output.

**Suggested fix:** in `parseDatras()`, either encode a missing value as an empty string instead
of the literal text `"NA"` (consistent with the existing `""` → `NA` handling two lines later),
or explicitly add `x[x == "NA"] <- NA` alongside the existing `-9`/`""` normalization. Either
removes the count mismatch that defeats `simplify()`'s numeric-conversion check.

**Full writeup with commit-pinned citations against both this fork and upstream:**
`~/R/Pakkar/obus/dev/upstream_reports/getindices_age_column_type_inconsistency.qmd`.

---

## Existing upstream issues already filed (on `ices-tools-prod/icesDatras`, not this fork)

Checked live via the GitHub API, 2026-07-21 — all three still open, all `einarhjorleifsson`-authored:

| # | Title | Maps to |
|---|---|---|
| [#46](https://github.com/ices-tools-prod/icesDatras/issues/46) | "on getCatchWgt" | Not a code bug — a design question about `CatchWgt`/`DataType` interpretation. `obus`'s own `dr_add_n_and_cpue()`/`dr_catch_weight_by_haul()` (in `obus/R/`) already have a principled, coded answer — see "Related project" below — worth a comment, low priority. |
| [#47](https://github.com/ices-tools-prod/icesDatras/issues/47) | "on getFlexFile" | `getFlexFile()` returns no `StNo` — the exact gap `obus`'s `crosswalk_id_from_hh()` exists to work around. Still open, 0 comments. Worth adding: `getCPUELength()`/`getCPUEAge()` have the *same* gap, worse (also missing `Country`). |
| [#48](https://github.com/ices-tools-prod/icesDatras/issues/48) | "getCPUELength - variable name returned" | Exactly Fix 3 above (the `xsi:nil` name leak) — already has a local fix here. The one existing comment on this issue (by the same user, same day it was filed) already shows `getCPUEAge()`'s `Age_6`..`Age_15` coming back with the same `xsi:nil`-in-name artifact *and* landing as literal `"NA"` strings — that second half is Fix 4 above, not fully recognized as a separate bug until the `obus`-side session that added Fix 4. |

## Contribution workflow (worked out 2026-07-21, from the `obus` side — full version with a
diagram at `~/R/Pakkar/obus/dev/icesdatras_contribution_workflow.qmd`)

Two repos, two different rules:

- **This fork (`einarhjorleifsson/icesDatras`, `origin`)**: full control, no pacing needed — push
  or self-merge freely, any time. What `obus` actually depends on
  (`pak::pak("einarhjorleifsson/icesDatras")`, no `@ref`, always current `master`).
- **Upstream (`ices-tools-prod/icesDatras`)**: a real maintainer, shared with everyone else who
  depends on the package. "Don't fire everything at once" applies *here*, not to this fork.

The loop, per bug:
1. **Check upstream's existing issues first** (including by your own username) before filing
   anything new — see the table above; this is what surfaced that #47/#48 already existed.
2. File a new upstream issue **before** writing the fix, only if nothing already covers it —
   cheap for the maintainer to read, gives them first right of context (they may already know
   why, or want a different approach), and doesn't block starting the fix here in parallel.
3. Fix it on a branch here, merge to this fork's own `master` (self-reviewed PR or direct push —
   no CI configured, nothing to wait on).
4. `pak::pak("einarhjorleifsson/icesDatras")` from `obus` — picks it up immediately.
5. Close the upstream issue **manually** (merging here does not auto-close a different repo's
   issue) — comment + close, or leave it for a later actual upstream PR's "Closes #N".
6. Whether/when to also send fixes as PRs *to* upstream is separate, unhurried, and should be
   paced (not fired all at once) — group by **logical fix, not by file**: Fix 1/Fix 4 are both in
   `R/utilities.R` but are two unrelated stories and should stay separate PRs; Fix 2 spans four
   functions but is one story (once extended to `getIndices()`/`getCatchWgt()`).

Evidence upstream isn't glacially slow but has no SLA either (checked via the GitHub API): zero
open PRs right now; recent (2026) PRs merged within hours to ~2 weeks; a few small past PRs sat
~2 months before a batch-merge; some plain issues (no PR) have sat open for years (e.g. #26,
filed 2019).

## Code bug vs. data bug vs. webserver/schema gap — a working distinction

Not every wrong-looking result is fixable the same way, or even fixable *here* at all. This
generalizes a scope note that already existed narrowly for two data-anomaly write-ups on the
`obus` side (`obus/dev/upstream_reports/fl_cal_distance_defect.qmd`,
`norway_58g2_58j3_weight_anomaly.qmd`) into a three-way test, applied 2026-07-22:

- **Code bug** — given the *same* values the DATRAS API already returns (`HaulDuration`,
  `DataType`, `CatCatchWgt`, etc., taken as correct), a function's own arithmetic or logic
  produces a result that contradicts a clear, well-defined convention. Fixable **permanently**
  inside this repo's R source, no dependency on anything upstream ever changing. Fix 1–4 above
  are all this category.
- **Data bug** — the stored values themselves are wrong or implausible regardless of what any
  client code does with them (bad coordinates, an implausible weight, a miscoded species). No
  code change here touches this; it needs the submitting country or ICES Datacenter to correct
  the database, not a PR.
- **Webserver/schema gap** — the DATRAS *webserver itself* is missing or wrong (typically
  `getDatrasFieldList()`'s metadata, not the underlying data), and what we write here is
  explicitly an **interim, escapable patch**: the real fix belongs on ICES's server, and ours
  should be trivial to remove once it lands. The entire `if(TRUE) {...}` hot-fix block in
  `R/getDatrasFieldList.R` is this category, retroactively — it predates this distinction being
  made explicit. CA's `Age` gap (`einar_dev/ca-age-field-name-gap`) is also this category, not a
  code bug: the field list's own metadata says `FieldNameOld` is `AgeRings`, but the live server
  (even with `new_names = FALSE`) actually sends `Age` — a webserver metadata inconsistency, not
  something wrong in this package's own logic.
- **Interpretation ambiguity** — a fourth bucket, distinct from all three: it's genuinely unclear
  whether the "obviously correct" behaviour is actually the intended one, so it isn't yet a
  fixable bug of any kind until that's resolved — typically needs the upstream maintainer's
  judgement, not just evidence.

**Live example the code-bug/data-bug split was written for:** `getCatchWgt()` skipping
`HaulDuration/60` scaling for `DataType == "C"` hauls looks at first like a clean code bug — but
`R/zzz.R`'s own `.onAttach()` startup message warns "there are known issues with the way
CatCatchWgt has been reported until 2023," and the evidence gathered for the bug so far (obus
side) is from 2020 data. Whether this is a pure code gap, a since-resolved historical data-era
issue, or both, isn't settled yet — check post-2023 data before writing any fix on
`einar_dev/getcatchwgt-datatype-c-scaling`.

**Resolved 2026-07-22 — data bug, not a code bug, no fix needed.** Checked NS-IBTS 2024 Q1:
median total-catch-per-minute-towed for `DataType == "C"` hauls is ~0.97x the `DataType == "R"`
median (was expected to be ~60x if still unscaled). Post-2023 `C`-type submissions are already
correctly per-haul, not per-hour — matching the `.onAttach()` disclaimer's own "until 2023"
wording exactly. Applying the `HaulDuration/60` conversion now would incorrectly shrink correct
post-2023 values while only being valid for pre-2023 data. No branch created; closing this as
investigated, not a `getCatchWgt()` bug.

**ICES is mid-transition on header names server-side — confirmed live, 2026-07-22.** Of the 25
operations on the DATRAS webservice, exactly one has an old/new pair: `getHLdata` and
`getHLdataNewHeaders` — no equivalent exists yet for HH, CA, FL, LT, Indices, or CPUE*.
icesDatras itself calls only the old form everywhere (`R/`, zero `NewHeaders` references).
Cross-checked `getHLdataNewHeaders` against icesDatras's own `new_names = TRUE` translation of
the old endpoint (NS-IBTS 2022 Q1, live): **28 of 29 columns agree exactly** — good validation of
the translation mechanism generally. The one mismatch: ICES's own `NewHeaders` endpoint still
calls the field `Valid_Aphia`, unchanged from the old name, while this repo's own hot-fix
("DB-added columns" section) had invented `aphia` as its canonical new name. That's a real,
evidenced case of this repo choosing a name ICES's own migration doesn't actually use.

**Decided 2026-07-22 — general rule, not a one-off call: ICES's own authoritative naming always
wins over a locally-invented one, once knowable.** `FieldName` for this entry was changed to
`Valid_Aphia` (== `FieldNameOld`, i.e. no rename) in `R/getDatrasFieldList.R`'s DB-added-columns
block. **Not dealt with, deliberately deferred:** `obus` depends on the old `aphia` name
extensively (dozens of files, grepped 2026-07-22) — real breakage, but for a future `obus`-side
session; not a reason to hold back this repo's own correctness.

**The same shape recurs wherever this ecosystem wraps an ICES-provided list, not just here.**
`obus`'s own `data-raw/DATASET_lookup_fields.R` layers a hotfix on top of this identical
`getDatrasFieldList` URL, independently of anything in this repo; `obus`'s
`data-raw/DATASET_vocabulary.R` does the same to `icesVocab::getCodeTypeList()`. Confirms
ICES-official-source-plus-local-patch is a recurring pattern, not a one-off — the same "ICES's
source wins, keep patches escapable" rule should apply there too, whenever that repo is actually
being worked on. Out of scope for this session (`icesDatras` only) — noted here so it isn't
re-discovered from scratch later.

**Reporting gaps back to ICES, not just to GitHub:** a webserver/schema gap found here (or in
`obus`'s parallel hotfixes) is a *data/metadata* problem, most likely owned by ICES Datacenter's
data team rather than whoever maintains the `icesDatras` R package on GitHub — filing a GitHub
issue against `ices-tools-prod/icesDatras` (the "Contribution workflow" section above) may be the
wrong channel, or only half of it. No confirmed reporting channel for this identified yet — the
`.onAttach()` startup disclaimer points at a *known-issues* page, not a *submit a new issue* one.
Needs either the user's own institutional knowledge of ICES Datacenter contacts, or research,
before this can actually happen.

**Escape-hatch design for the webserver/schema-gap category — not yet applied.** The current
hot-fix block's `rbind()`-based additions (LT extra, FL extra, DB-added columns) are **not**
idempotent — if ICES's webserver independently adds any of these same rows later, the result is
duplicate rows, not a clean no-op. A more escapable design would (a) skip injecting a row if the
raw response already has a matching one, and/or (b) add a test asserting the raw (unpatched)
field list is still missing the row it's supposed to be missing, so the test starts failing,
loudly, the moment it's safe to delete the patch. Neither exists yet — worth doing before adding
more entries to this block (e.g. for `einar_dev/ca-age-field-name-gap`).

## Related project

`/Users/einarhj/R/Pakkar/obus` — a separate project that consumes icesDatras output.
`obus/data-raw/DATASET_lookup_fields.R` contains a fuller hand-curated field dictionary
(`dr_lookup_fields`) and was used as the reference for the correct LT old→new name mappings
(see the `add_lt` tribble in that file).

**On `getCatchWgt()` specifically (relevant to issue #46 above):** its own response schema is a
full `HH`-shaped haul record plus `CatchWgt`/`aphia` — i.e. ICES's server joins a haul (HH) to a
derived-from-HL weight value and returns the combined row, not a lean species-weight table.
`obus` briefly archived `getCatchWgt()`'s output as its own table (`CW`), then removed it
(2026-07-21) once this was recognized: `obus` already computes the identical thing locally,
*better* (with zero-fill and `DataType == "C"` scaling `getCatchWgt()` itself lacks), from `HH`+
`HL` it already has — see `obus/R/dr_products.R`'s `dr_catch_weight_by_haul()`. Worth keeping in
mind for any other icesDatras function whose output turns out to just be HH/HL(/CA) joined
server-side — it likely doesn't need its own separate consumer-side archive either.
