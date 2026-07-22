# Summarize Data Availability

Evaluate a presence-absence table for each survey with '1' where there
is data and '0' (printed as '.') otherwise.

## Usage

``` r
getDatrasDataOverview(surveys = NULL, long = TRUE)
```

## Arguments

- surveys:

  a vector of survey names, or `NULL` to process all surveys.

- long:

  whether tables should have year as row names (default) or column
  names.

## Value

A list of tables.

## See also

[`getSurveyList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyList.md),
[`getSurveyYearList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearList.md),
and
[`getSurveyYearQuarterList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearQuarterList.md)
also list available data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Examples

``` r
if (FALSE) { # \dontrun{
getDatrasDataOverview(surveys = "ROCKALL", long = FALSE)
} # }
```
