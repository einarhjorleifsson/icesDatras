# Get a List of Quarters

Get a list of quarters available for a given survey and year.

## Usage

``` r
getSurveyYearQuarterList(survey, year)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

- year:

  the year of the survey, e.g. 2010.

## Value

A numeric vector.

## See also

[`getSurveyYearList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearList.md),
`getSurveyYearQuarterList`, and
[`getDatrasDataOverview`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasDataOverview.md)
also list available data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Author

Colin Millar.

## Examples

``` r
if (FALSE) { # \dontrun{
getSurveyYearQuarterList(survey = "ROCKALL", year = 2002)
} # }
```
