# Get Catch Weights

Calculate the total reported catch weight by species and haul.

## Usage

``` r
getCatchWgt(
  survey,
  years,
  quarters,
  aphia,
  fix_types = getOption("icesDatras.fix_types"),
  new_names = getOption("icesDatras.new_names")
)
```

## Arguments

- survey:

  the survey acronym e.g. NS-IBTS.

- years:

  a vector of years of the survey, e.g. c(2010, 2012) or 2005:2010.

- quarters:

  a vector of quarters of the year the survey took place, e.g. c(1, 4)
  or 1:4.

- aphia:

  a vector of Aphia species codes defined in the WoRMS database, e.g.
  c(126436, 1264374).

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

[`getSurveyYearList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearList.md),
[`getSurveyYearQuarterList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearQuarterList.md),
and
[`getDatrasDataOverview`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasDataOverview.md)
also list available data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Examples

``` r
if (FALSE) { # \dontrun{
getCatchWgt(survey = "ROCKALL", years = 2002, quarters = 3, aphia = 126437)

# look up specific species
aphia <- icesVocab::findAphia(c("cod", "haddock"))
cwt <- getCatchWgt(survey = "ROCKALL", years = 2002, quarters = 3, aphia = aphia)
} # }
```
