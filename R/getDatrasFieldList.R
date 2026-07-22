#' Get Datras field list with column classes and mapping to old naming schema
#'
#' @return A dataframe
#' @export
#' @importFrom XML xmlToDataFrame
getDatrasFieldList <- function() {

  url <- "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList"
  # read XML string and parse to data frame
  response <- readDatras(url)
  response2 <- gsub(
    'xmlns="ices.dk.local/DATRAS"',
    'xmlns="https://ices.dk.local/DATRAS"',
    response,
    fixed = TRUE
  )
  out <- xmlToDataFrame(response2)
  out <- lapply(out, trimws)
  out <- as.data.frame(out)

  # This needs to be fixed upstream
  if(TRUE) {

    out$DataFormat[out$DataFormat == "float"] <- "decimal"

    out$DataFormat[out$FieldName == "Year"] <- "int"
    out$Description[out$RecordHeader == "FA" & out$FieldName == "Year"] <- "Cruise year (YYYY)"

    out$DataFormat[out$RecordHeader == "FA" & out$FieldName == "StationName"] <- "char"
    out$Description[out$RecordHeader %in% c("FA", "LT") & out$FieldName == "StationName"] <- "Station number. National coding system, not defined by ICES."

    out$DataFormat[out$RecordHeader == "FA" & out$FieldName == "HaulNumber"] <- "int"
    out$Description[out$RecordHeader %in% c("FA", "LT") & out$FieldName == "HaulNumber"] <- "Sequential numbering of hauls during cruise."

    # LT: for fields shared with HH, FieldNameOld incorrectly echoes the new name
    # instead of the actual old column names that getLTassessment(..., new_names = FALSE) returns.
    out$FieldNameOld[out$RecordHeader == "LT" & out$FieldName == "Platform"]    <- "Ship"
    out$FieldNameOld[out$RecordHeader == "LT" & out$FieldName == "StationName"] <- "StNo"
    out$FieldNameOld[out$RecordHeader == "LT" & out$FieldName == "HaulNumber"]  <- "HaulNo"

    # CA: FieldNameOld says "AgeRings" but the live server actually sends "Age"
    # (confirmed live 2026-07-22, even with new_names = FALSE).
    out$FieldNameOld[out$RecordHeader == "CA" & out$FieldName == "IndividualAge"] <- "Age"

    # LT: the URL only covers the upload-spec fields; getLTassessment() returns many
    # additional HH-style columns that are absent from the URL list, so new_names
    # translation silently fails for them.  Add the missing entries here.
    lt_extra <- data.frame(
      RecordHeader = "LT",
      FieldName = c(
        "ShootLatitude",       "ShootLongitude",      "HaulLatitude",        "HaulLongitude",
        "OSPARArea",           "MSFDArea",             "BottomDepth",         "Distance",
        "DoorSpread",          "WingSpread",           "SweepLength",         "GearEx",
        "DoorType",            "Month",                "Day",                 "StartTime",
        "HaulDuration",        "StatisticalRectangle", "Depth",               "HaulValidity",
        "DataType",            "NetOpening",           "Rigging",             "Tickler",
        "WarpLength",          "WarpDiameter",         "WarpDensity",         "DoorSurface",
        "DoorWeight",          "TowDirection",         "SpeedGround",         "SpeedWater",
        "WindDirection",       "WindSpeed",            "SwellDirection",      "SwellHeight",
        "CodendMesh",          "EEZ",                  "NMArea",              "DateofCalculation"
      ),
      FieldNameOld = c(
        "ShootLat",   "ShootLong",  "HaulLat",    "HaulLong",
        "OSPARArea",  "MSFDArea",   "BottomDepth","Distance",
        "DoorSpread", "WingSpread", "SweepLngt",  "GearEx",
        "DoorType",   "Month",      "Day",        "TimeShot",
        "HaulDur",    "StatRec",    "Depth",      "HaulVal",
        "DataType",   "Netopening", "Rigging",    "Tickler",
        "Warplngt",   "Warpdia",    "WarpDen",    "DoorSurface",
        "DoorWgt",    "TowDir",     "GroundSpeed","SpeedWater",
        "WindDir",    "WindSpeed",  "SwellDir",   "SwellHeight",
        "CodendMesh", "EEZ",        "NMArea",     "DateofCalculation"
      ),
      DataFormat = c(
        "decimal", "decimal", "decimal", "decimal",
        "char",    "char",    "int",     "decimal",
        "decimal", "decimal", "int",     "char",
        "char",    "int",     "int",     "char",
        "int",     "char",    "int",     "char",
        "char",    "decimal", "char",    "int",
        "int",     "int",     "int",     "decimal",
        "int",     "int",     "decimal", "decimal",
        "int",     "int",     "int",     "decimal",
        "int",     "char",    "char",    "int"
      ),
      Description   = "",
      stringsAsFactors = FALSE
    )
    out <- rbind(out, lt_extra)

    # FL: getFlexFile() returns all HH columns plus FL-specific swept-area columns.
    # Copy matching HH rows (preserves FieldNameOld and Description), then append
    # the FL-only extras.
    fl_hh_cols <- c(
      "RecordHeader", "Survey", "Quarter", "Country", "Platform", "Gear",
      "HaulNumber", "Year", "Month", "Day", "StartTime", "DepthStratum",
      "HaulDuration", "DayNight", "ShootLatitude", "ShootLongitude",
      "StatisticalRectangle", "SweepLength", "BottomDepth", "HaulValidity",
      "DataType", "WarpLength", "DoorSpread", "WingSpread", "Distance"
    )
    fl_from_hh <- out[out$RecordHeader == "HH" & out$FieldName %in% fl_hh_cols, ]
    fl_from_hh$RecordHeader <- "FL"

    fl_extra <- data.frame(
      RecordHeader = "FL",
      FieldName    = c("ICESArea", "Cal_DoorSpread", "DSflag", "Cal_WingSpread",  "WSflag",
                       "Cal_Distance", "DistanceFlag", "SweptAreaDSKM2", "SweptAreaWSKM2",
                       "SweptAreaBWKM2", "DateofCalculation"),
      FieldNameOld = c("ICESArea", "Cal_DoorSpread", "DSflag", "Cal_WingSpread",  "WSflag",
                       "Cal_Distance", "DistanceFlag", "SweptAreaDSKM2", "SweptAreaWSKM2",
                       "SweptAreaBWKM2", "DateofCalculation"),
      DataFormat   = c("char",    "decimal",        "char",   "decimal",          "char",
                       "decimal", "char",            "decimal","decimal",
                       "decimal", "int"),
      Description  = "",
      stringsAsFactors = FALSE
    )
    out <- rbind(out, fl_from_hh, fl_extra)

    # DB-added columns not in the upload spec: DateofCalculation (HH/HL/CA) and
    # Valid_Aphia (HL/CA). FieldName == FieldNameOld == "Valid_Aphia" deliberately (no
    # rename): ICES's own getHLdataNewHeaders endpoint still calls this field "Valid_Aphia"
    # (confirmed live 2026-07-22), so this repo aligns to ICES's real direction rather than
    # inventing its own "aphia" name, per the naming rule below.
    db_extra <- data.frame(
      RecordHeader = c("HH",               "HL",               "HL",          "CA",               "CA"),
      FieldName    = c("DateofCalculation", "DateofCalculation", "Valid_Aphia", "DateofCalculation", "Valid_Aphia"),
      FieldNameOld = c("DateofCalculation", "DateofCalculation", "Valid_Aphia", "DateofCalculation", "Valid_Aphia"),
      DataFormat   = c("int",               "int",               "int",         "int",               "int"),
      Description  = "",
      stringsAsFactors = FALSE
    )
    out <- rbind(out, db_extra)

    # Indices/CPUELength/CPUEAge: these three functions have NO RecordHeader at all
    # in the upload-spec field list -- getIndices()/getCPUELength()/getCPUEAge() call
    # formatDatras() without a `record` argument, so applyDatrasTypeSchema() matches
    # against the WHOLE pooled list regardless of RecordHeader label used here.
    # Self-mapped (FieldName == FieldNameOld) throughout: unlike HH/HL/CA/FL/LT, ICES
    # has never defined an old/new naming pair for these fields, so inventing one
    # would repeat the same mistake already corrected for "aphia" above. RecordHeader
    # values ("IDX"/"CPUEL"/"CPUEA") are this repo's own organisational labels, not
    # anything ICES defines -- picked to match the equivalent labels already used in
    # obus's own hand-curated dictionary (`obus/data-raw/DATASET_lookup_fields.R`),
    # which was consulted for the raw field names and formats below, cross-checked
    # against live data before applying (2026-07-22). Confirmed live: without this,
    # Age_0..Age_15 in getIndices()'s own output land as a mix of integer/numeric
    # WITHIN one single response, not just across separate calls.
    idx_cpue_extra <- data.frame(
      RecordHeader = c(
        rep("IDX", 3 + 16),
        rep("CPUEL", 9),
        rep("CPUEA", 6 + 16 + 1)
      ),
      FieldName = c(
        # IDX
        "AphiaID", "Species", "IndexArea", paste0("Age_", 0:15),
        # CPUEL
        "ShootLon", "DateTime", "Area", "SubArea", "AphiaID", "Species",
        "LngtClas", "CPUE_number_per_hour", "Cal_DateID",
        # CPUEA
        "ShootLon", "DateTime", "Area", "SubArea", "AphiaID", "Species",
        paste0("Age_", 0:15), "Cal_DateID"
      ),
      DataFormat = c(
        # IDX
        "int", "char", "char", rep("decimal", 16),
        # CPUEL
        "decimal", "char", "int", "char", "int", "char",
        "int", "decimal", "int",
        # CPUEA
        "decimal", "char", "int", "char", "int", "char",
        rep("decimal", 16), "int"
      ),
      Description = "",
      stringsAsFactors = FALSE
    )
    idx_cpue_extra$FieldNameOld <- idx_cpue_extra$FieldName
    out <- rbind(out, idx_cpue_extra)

    # Back-fill empty Descriptions for LT and FL rows from matching HH entries.
    hh_desc <- out[out$RecordHeader == "HH", c("FieldName", "Description")]
    for (rh in c("LT", "FL")) {
      idx <- which(out$RecordHeader == rh & out$Description == "")
      if (length(idx) > 0) {
        matched          <- match(out$FieldName[idx], hh_desc$FieldName)
        fill             <- hh_desc$Description[matched]
        out$Description[idx] <- ifelse(!is.na(fill), fill, "")
      }
    }
  }
  out
}



