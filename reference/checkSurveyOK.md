# Check that a survey name is in the database

Checks a survey name against a list of all survey names in the DATRAS
database. If the name is not matched it puts up a message showing the
available survey names.

## Usage

``` r
checkSurveyOK(survey)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

## Value

logical.

## See also

[`checkSurveyYearOK`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyYearOK.md)
and
[`getSurveyYearQuarterList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearQuarterList.md)
also perform checks against the DATRAS database.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Examples

``` r
if (FALSE) { # \dontrun{
checkSurveyOK(survey = "ROCKALL")
checkSurveyOK(survey = "NOTALL")
} # }
```
