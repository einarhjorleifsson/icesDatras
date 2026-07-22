# Get Any DATRAS Data

This function combines the functionality of getHHdata, getHLdata, and
getCAdata. It supports querying many years and quarters in one function
call.

## Usage

``` r
getDATRAS(
  record = "HH",
  survey,
  years,
  quarters,
  species = NULL,
  fix_types = getOption("icesDatras.fix_types"),
  new_names = getOption("icesDatras.new_names")
)

getDATRASCatched(
  record = "HH",
  survey,
  years,
  quarters,
  species = NULL,
  fix_types = getOption("icesDatras.fix_types"),
  new_names = getOption("icesDatras.new_names")
)
```

## Arguments

- record:

  the data type required: "HH" haul data, "HL" length-based data, "CA"
  age-based data.

- survey:

  the survey acronym e.g. NS-IBTS.

- years:

  a vector of years of the survey, e.g. c(2010, 2012) or 2005:2010.

- quarters:

  a vector of quarters of the year the survey took place, i.e. c(1, 4)
  or 1:4.

- species:

  a vector of valid aphia code of the species to download, if NULL all
  species are included.

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

## Functions

- `getDATRASCatched()`: cached version of getDATRAS

## See also

[`getHHdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHHdata.md),
[`getHLdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHLdata.md),
and
[`getCAdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getCAdata.md)
get haul data, length-based data, and age-based data.

[`icesDatras-package`](https://einarhjorleifsson.github.io/icesDatras/reference/icesDatras.md)
gives an overview of the package.

## Author

Colin Millar and Scott Large.

## Examples

``` r
if (FALSE) { # \dontrun{
hhdata <- getDATRAS(record = "HH", survey = "ROCKALL", years = 2002, quarters = 3)
hldata <- getDATRAS(record = "HL", survey = "ROCKALL", years = 2002, quarters = 3, species = 105883)
cadata <- getDATRAS(record = "CA", survey = "ROCKALL", years = 2002, quarters = 3)
} # }
```
