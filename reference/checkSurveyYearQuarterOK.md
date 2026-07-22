# Check that a survey, year and quarter combination is in the database

Checks a quarter and/or year and/or survey name against a list of all
survey year quarter combinations in the DATRAS database. If the
combination is not matched it puts up a message showing the available
options.

## Usage

``` r
checkSurveyYearQuarterOK(
  survey,
  year,
  quarter,
  checksurvey = TRUE,
  checkyear = TRUE
)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

- year:

  the year of the survey, e.g. 2010.

- quarter:

  the quarter of the year the survey took place, i.e. 1, 2, 3 or 4.

- checksurvey:

  logical, should the survey name also be checked.

- checkyear:

  logical, should the year also be checked.

## Value

logical.

## See also

[`checkSurveyOK`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyOK.md)
and
[`checkSurveyYearOK`](https://einarhjorleifsson.github.io/icesDatras/reference/checkSurveyYearOK.md)
also perform checks against the DATRAS database.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Examples

``` r
if (FALSE) { # \dontrun{
checkSurveyYearQuarterOK(survey = "ROCKALL", 2015, 3)
checkSurveyYearQuarterOK(survey = "ROCKALL", 2015, 1)
checkSurveyYearQuarterOK(survey = "ROCKALL", 2000, 1)
checkSurveyYearQuarterOK(survey = "NOTALL", 2000, 1)

# be careful of unexpected results with checksurvey and checkyear!
checkSurveyYearQuarterOK(survey = "NOTALL", 2000, 1, checksurvey=FALSE)
} # }
```
