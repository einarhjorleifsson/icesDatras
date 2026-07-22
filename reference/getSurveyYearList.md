# Get a List of Survey Years

Get a list of all data years for a given survey.

## Usage

``` r
getSurveyYearList(survey)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

## Value

A numeric vector.

## See also

[`getSurveyList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyList.md),
[`getSurveyYearQuarterList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearQuarterList.md),
and
[`getDatrasDataOverview`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasDataOverview.md)
also list available data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Author

Colin Millar.

## Examples

``` r
if (FALSE) { # \dontrun{
getSurveyYearList(survey = "ROCKALL")
} # }
```
