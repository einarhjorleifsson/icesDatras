# Get Length-Based Data

Get length-based information such as measured length, individual counts,
and sub-factors of sampled species.

## Usage

``` r
getHLdata(
  survey,
  year,
  quarter,
  species = NULL,
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

- species:

  the valid aphia code of the species to download, if NULL all species
  are included

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

[`getHHdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHHdata.md)
and
[`getCAdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getCAdata.md)
get haul data and age-based data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Examples

``` r
if (FALSE) { # \dontrun{
hldata <- getHLdata(survey = "ROCKALL", year = 2002, quarter = 3, species = 11760)
str(hldata)
} # }
```
