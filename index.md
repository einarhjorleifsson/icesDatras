# icesDatras

[![ICES
Logo](https://ices.dk/_layouts/15/1033/images/icesimg/iceslogo.png)](http://ices.dk)

icesDatras provides R functions that access the [web
services](https://datras.ices.dk/WebServices/Webservices.aspx) of the
[ICES](http://ices.dk) [DATRAS](http://datras.ices.dk) trawl survey
database.

icesDatras is implemented as an [R](https://www.r-project.org) package
and available on [CRAN](https://cran.r-project.org/package=icesDatras).

## DATRAS database support

If you have questions relating to the ICES DATRAS database or web
services please email: <DatrasAdministration@ices.dk>

## Installation

icesDatras can be installed from CRAN using the `install.packages`
command:

``` r

install.packages("icesDatras")
```

## Usage

For a summary of the package:

``` r

library(icesDatras)
?icesDatras
```

Information on available surveys in DATRAS:

``` r

getSurveyList()
```

## Working Examples

Extracting survey haul (HH), lenght (HL) and agebased (CA) data from a
given survey, quarter and year, i.e. North Sea IBTS, Quarter 1, 2019:

``` r

survey <- "NS-IBTS"
year <- 2019
quarter <- 1

HH <- getHHdata(survey, year, quarter) 
HL <- getHLdata(survey, year, quarter) 
CA <- getCAdata(survey, year, quarter) 
```

Extracting catch weight of cod from the Baltic Sea survey, year 2019,
quarter 1.  
Note: The icesVocab package provides `findAphia`, a function to look up
Aphia species codes.

``` r

library(icesVocab)
aphia <- icesVocab::findAphia("cod") 

survey <- "BITS"
years <- 2019
quarters <- 1
codwgt <- getCatchWgt(survey, years, quarters, aphia)
```

Get catch weight for Baltic cod from all quarters in a small timeseries
(e.g. 1991 to 2011) and plot the weight in a sipmle graph per quarter.

``` r

library(icesVocab)
library(ggplot2)

aphia <- icesVocab::findAphia("cod") 

survey <- "BITS"
years <- 1991:2011
quarters <- 1:4
codwgt <- getCatchWgt(survey, years, quarters, aphia)
codwgt %>% ggplot(aes(x = Year, y = CatchWgt, colour= Quarter)) + geom_point()
```

## References

ICES DATRAS database: <http://datras.ices.dk>

ICES DATRAS web services:
<https://datras.ices.dk/WebServices/Webservices.aspx>

AphiaID of marine organisms: <http://www.marinespecies.org/index.php>

## Development

icesDatras is developed openly on
[GitHub](https://github.com/ices-tools-prod/icesDatras).

Feel free to open an
[issue](https://github.com/ices-tools-prod/icesDatras/issues) there if
you encounter problems or have suggestions for future versions.

The current development version can be installed using:

``` r

library(devtools)
install_github("ices-tools-prod/icesDatras")
```
