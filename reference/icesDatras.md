# DATRAS Trawl Survey Database Web Services

R interface to access the web services of the ICES DATRAS trawl survey
database.

## Details

*Exchange data:*

|  |  |
|----|----|
| [`getHHdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHHdata.md) | haul data |
| [`getHLdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getHLdata.md) | length-based data |
| [`getCAdata`](https://einarhjorleifsson.github.io/icesDatras/reference/getCAdata.md) | age-based data |
| [`getDATRAS`](https://einarhjorleifsson.github.io/icesDatras/reference/getDATRAS.md) | exchange data |

*Catch weights:*

|  |  |
|----|----|
| [`getCatchWgt`](https://einarhjorleifsson.github.io/icesDatras/reference/getCatchWgt.md) | catch weights |

*Survey indices:*

|  |  |
|----|----|
| [`getIndices`](https://einarhjorleifsson.github.io/icesDatras/reference/getIndices.md) | survey indices |

*Overview of available data:*

|  |  |
|----|----|
| [`getSurveyList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyList.md) | surveys |
| [`getSurveyYearList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearList.md) | years |
| [`getSurveyYearQuarterList`](https://einarhjorleifsson.github.io/icesDatras/reference/getSurveyYearQuarterList.md) | quarters |
| [`getDatrasDataOverview`](https://einarhjorleifsson.github.io/icesDatras/reference/getDatrasDataOverview.md) | surveys, years, and quarters |

*Basic queries (thin web service wrappers):*  
`getCAdata`, `getHHdata`, `getHLdata`, `getIndices`, `getSurveyList`,
`getSurveyYearList`, `getSurveyYearQuarterList`

*Derived queries (combining web services with R computations):*  
`getCatchWgt`, `getDatrasDataOverview`, `getDATRAS`

## References

ICES DATRAS database: <http://datras.ices.dk>.

ICES DATRAS web services:
<https://datras.ices.dk/WebServices/Webservices.aspx>.

## Author

Colin Millar, Scott Large, and Arni Magnusson.
