# Get Haul Data

Get haul data such as position, depth, sampling method, etc.

## Usage

``` r
getHHdata(
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

  the quarter of the year the survey took place, i.e. 1, 2, 3 or 4.

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

[`getDATRAS`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md)
supports querying many years and quarters in one function call.

[`getHLdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHLdata.md)
and
[`getCAdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getCAdata.md)
get length-based data and age-based data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Author

Colin Millar.

## Examples

``` r
if (FALSE) { # \dontrun{
hhdata <- getHHdata(survey = "ROCKALL", year = 2002, quarter = 3)
str(hhdata)

# error checking examples:
hhdata <- getHHdata(survey = "NS-IBTS", year = 2016, quarter = 1)
hhdata <- getHHdata(survey = "NS-IBTS", year = 2030, quarter = 1)
hhdata <- getHHdata(survey = "NS-IBTS", year = 2016, quarter = 6)
} # }
```
