# Code Fixes: einar_dev/integration vs. master

## What this covers

Four fixes to this package’s own R code, present on this fork’s
`einar_dev/integration` branch and not yet on `master`. Each is a
genuine code bug: given the same values the DATRAS API already returns,
the existing logic produced a result that contradicts a clear,
well-defined convention – fixable permanently in this package’s own
source, with no dependency on ICES’s server ever changing.

A related but separate class of finding – gaps and inconsistencies in
what ICES’s own webservice and field list provide, not fixable by any
change to this package’s code – is covered in a companion document,
[DATRAS Webservice and Field-List
Gaps](https://einarhjorleifsson.github.io/icesDatras/articles/datras-webservice-and-fieldlist-gaps.md).

## Fix 1 – `-9` sentinel not fully scrubbed to `NA`

`applyDatrasTypeSchema()` coerces column types but never converted
DATRAS’s `-9` missing-value sentinel to `NA`. `parseDatras()` already
catches the *string* `"-9"`, but not decimal forms like `"-9.0"` – a
valid representation DATRAS uses for missing float fields. After
`simplify()` converts such a string to numeric, the value becomes `-9`
and passes through unchanged.

``` r

x <- data.frame(HaulDur = -9)
applyDatrasTypeSchema(x, record = "HH")$HaulDur
#> [1] -9      # before this fix -- should be NA
```

**Fix:** explicit `-9`/`-9L` scrubbing added to
`applyDatrasTypeSchema()` for all `int`/`decimal` columns, after type
coercion.

## Fix 2 – Empty or unavailable results returned `FALSE`/`NULL` instead of a data frame

[`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md),
[`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md),
[`getLTassessment()`](https://einarhjorleifsson.github.io/icesDatras/reference/getLTassessment.md),
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md),
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md),
[`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md),
and
[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
each had at least one path that returned a bare `FALSE` (an invalid
survey name, an unavailable year/quarter) or silently returned `NULL`
when an empty XML response collapsed before reaching `formatDatras()`.
Both break idiomatic downstream code:

``` r

out <- getDATRAS("HH", "NS-IBTS", years = 1800, quarters = 1)
nrow(out)
#> Error: argument is not a data frame
```

**Fix:** every such early exit now returns
[`data.frame()`](https://rdrr.io/r/base/data.frame.html). Two shapes of
gap, covered differently:

- [`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)/[`getFlexFile()`](https://einarhjorleifsson.github.io/icesDatras/reference/getFlexFile.md)/[`getLTassessment()`](https://einarhjorleifsson.github.io/icesDatras/reference/getLTassessment.md)/[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
  had their own
  [`checkSurveyOK()`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyOK.md)/[`checkSurveyYearOK()`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyYearOK.md)/[`checkSurveyYearQuarterOK()`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyYearQuarterOK.md)
  validation already in place; only the early-exit return value needed
  changing.
- [`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md),
  [`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md),
  and
  [`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
  have no such validation of their own –
  [`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
  inherits failure from two internal
  [`getDATRAS()`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
  calls and would otherwise hard-error on column-dependent processing
  against an empty result;
  [`getCPUELength()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUELength.md)/[`getCPUEAge()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md)
  have only a `checkDatrasWebserviceOK()` reachability check, so an
  unavailable cell hit the `NULL`-propagation path in `parseDatras()`
  with nothing to catch it. Each needed a genuinely new guard, not a
  mechanical substitution.

## Fix 3 – `xsi:nil` XML attribute leaking into column names

DATRAS represents a missing field as a self-closing tag, e.g.
`<Age_6 xsi:nil="true" />`. `parseDatras()`’s name-extraction regex
relied on a lazy quantifier (`(.*?)`) that isn’t reliably supported
across regex engines, and captured the whole `Age_6 xsi:nil="true"` as
the column name instead of `Age_6`.

**Fix:** replaced with `([^ >]+)[^>]*`, which stops the capture at the
first space or `>` without relying on lazy-quantifier support. Verified
live: all 16 `Age_0`-`Age_15` columns from a real
[`getIndices()`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md)
call come back with clean names.

## Fix 4 – Literal text `"NA"` surviving as a real, non-missing value

A deeper, separate bug in the same area: the self-closing-tag expansion
in `parseDatras()` produced the *literal text* `"NA"` as the field’s
content, not a true `NA`. Two lines later, `-9` and `""` are explicitly
normalised to `NA` – but `"NA"` was never included, and `is.na("NA")` is
`FALSE`, so `simplify()`’s numeric-conversion guard was fooled and left
the whole column as `character`, holding the string `"NA"` in every
affected cell.

**Fix:** the tag expansion now produces empty content rather than the
literal text `"NA"`, so the existing `x[x == ""] <- NA` normalisation
catches it – for every column type, not just numeric ones. This is a
real gap beyond `Age_*`: declared-character columns get zero scrubbing
either.

## Investigated, not fixed: `getCatchWgt()` and `DataType == "C"`

The most interesting negative result.
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
never applies a `HaulDuration/60` scaling for `DataType == "C"` hauls –
2020 data showed catch weights inflated by exactly that factor on
affected hauls. This looks like a clean code bug at first.

But `R/zzz.R`’s own package-startup message already warns: *“there are
known issues with the way CatCatchWgt has been reported until 2023.”*
That’s ICES’s own disclaimer, and it lines up: real NS-IBTS 2024 Q1 data
shows the median catch-per-minute-towed for `DataType == "C"` hauls at
**~0.97x** the `DataType == "R"` rate – not ~60x. Post-2023 submissions
are already correctly per-haul.

Applying the “obvious” fix now would *break* current and future data
while only helping historical records. Conclusion: a data-reporting-era
issue, time-bounded and already resolved on ICES’s side, not a
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
code bug. No change made.

## Related upstream issues

Two of the fixes above map directly onto an issue already open on
`ices-tools-prod/icesDatras`:
[\#48](https://github.com/ices-tools-prod/icesDatras/issues/48) (fixes 3
and 4). The
[`getCatchWgt()`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md)
investigation above is directly relevant to
[\#46](https://github.com/ices-tools-prod/icesDatras/issues/46).
