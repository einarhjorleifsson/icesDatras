# Get Flex File

Get all information in HH plus estimates of Door Spread, Wing Spread and
Swept Area per square km. Only available for NS-IBTS survey.

## Usage

``` r
getFlexFile(
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

[`getHHdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHHdata.md)
get haul data

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Author

Adriana Villamor.

## Examples

``` r
if (FALSE) { # \dontrun{
flex <- getFlexFile(survey = "NS-IBTS", year = 2020, quarter = 1)
str(flex)

# error checking examples:
flex <- getFlexFile(survey = "NS-IBTS", year = 2016, quarter = 1)
flex <- getFlexFile(survey = "NS-IBTS", year = 2030, quarter = 1)
flex <- getFlexFile(survey = "NS-IBTS", year = 2016, quarter = 6)
} # }
```
