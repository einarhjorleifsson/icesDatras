# Check that a survey and year combination is in the database

Checks a year and/or survey name against a list of all survey year
combinations in the DATRAS database. If the combination is not matched
it puts up a message showing the available options.

## Usage

``` r
checkSurveyYearOK(survey, year, checksurvey = TRUE)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

- year:

  the year of the survey, e.g. 2010.

- checksurvey:

  logical, should the survey name also be checked.

## Value

logical.

## See also

[`checkSurveyOK`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyOK.md)
and
[`checkSurveyYearQuarterOK`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyYearQuarterOK.md)
also perform checks against the DATRAS database.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Examples

``` r
if (FALSE) { # \dontrun{
checkSurveyYearOK(survey = "ROCKALL", 2015)
checkSurveyYearOK(survey = "ROCKALL", 2000)
checkSurveyYearOK(survey = "NOTALL", 2000)
} # }
```
