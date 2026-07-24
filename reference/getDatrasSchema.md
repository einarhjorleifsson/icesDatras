# Get the DATRAS field/type schema

Returns the internal schema table (field names, types, and descriptions
per DATRAS record type) that applyDatrasTypeSchema()/
applyDatrasNameSchema() use internally via filter_datras_schema().

## Usage

``` r
getDatrasSchema(record = NULL)
```

## Arguments

- record:

  Optional character vector of RecordHeader value(s) to filter to (e.g.
  "HH", c("HL", "CA")). If NULL (default), returns the full schema
  across every RecordHeader, each row still labeled with its own
  RecordHeader – unlike filter_datras_schema()'s own internal contract
  (which requires record explicitly, precisely to avoid pooling field
  names across RecordHeaders during type-fixing), nothing is pooled or
  ambiguous here: the RecordHeader column is preserved on every row, so
  a caller can filter/group by it downstream. That's a different use
  case (introspection/export) from filter_datras_schema()'s own
  (internal type/name coercion), which is why the same "no implicit
  default" caution doesn't need to apply here.

## Value

A data.frame with columns RecordHeader, FieldNameOld, FieldName,
DataFormat, has_distinct_new_name, Description, DescriptionNew, Comment.
