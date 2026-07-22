# Get CPUE per Length per Haul per Hour for a given Survey, year and Quarter

Get CPUE per Length per Haul per Hour for a given Survey, year and
Quarter

## Usage

``` r
getCPUELength(
  survey,
  year,
  quarter,
  fix_types = getOption("icesDatras.fix_types"),
  new_names = getOption("icesDatras.new_names")
)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

- year:

  the year of the survey, e.g. 2010.

- quarter:

  the quarter of interest, e.g. 1

- fix_types:

  logical, apply the DATRAS type to columns. Takes package default
  unless specified. Use `SetDatrasDefaults()` to change default across
  all functions.

- new_names:

  logical, apply the new DATRAS naming convention to output. Takes
  package default unless specified. Use `SetDatrasDefaults()` to change
  default across all functions.

## Value

A data frame.

## See also

[`getHHdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHHdata.md)
and
[`getCAdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getCAdata.md)
get haul data and age-based data., and
[`getIndices`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md),
and
[`getCPUEAge`](https://einarhjorleifsson.github.io/icesDatras/reference/getCPUEAge.md).

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Author

Adriana Villamor.

## Examples

``` r
if (FALSE) { # \dontrun{
getCPUELength(survey = "NS-IBTS", year = 2018, quarter = 1)
} # }
```
