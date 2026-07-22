# Get Survey Indices

Get age based indices of abundance by species, survey and year.

## Usage

``` r
getIndices(
  survey,
  year,
  quarter,
  species,
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

  the aphia species code for the species of interest.

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

## Note

The icesVocab package provides `findAphia`, a function to look up Aphia
species codes.

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
haddock_aphia <- icesVocab::findAphia("haddock")
index <- getIndices(survey = "NS-IBTS", year = 2002, quarter = 3, species = haddock_aphia)
str(index)
} # }
```
