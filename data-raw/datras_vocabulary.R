# icesVocab code-value lookups for datras_schema's field-level DataFormat/name info.
#
# icesVocab (https://vocab.ices.dk) publishes per-field code lists (e.g. Gear code "GOV" ->
# "Grande Ouverture Verticale") independently of DATRAS's own field-list/WSDL machinery
# (data-raw/datras_operation_types.R). Used here to enrich datras_schema's DescriptionNew
# with what a field's valid codes actually mean, for fields with few enough codes that
# listing them inline is useful (see data-raw/build_datras_schema.R's step 4b).
#
# Key finding (2026-07-23, verified live): icesVocab's own Key values are prefixed --
# e.g. "TS_DataType", "AC_Sex" -- plus some bare keys with no prefix (e.g. "Gear"). "TS_" =
# Trawl Survey (DATRAS's own domain), "AC_" = Acoustic survey (a different ICES data domain
# entirely). Some field names resolve under BOTH prefixes -- confirmed concretely for "Sex":
# TS_Sex has 7 codes (incl. Berried/Neutral/"Not included"), AC_Sex has 4 simpler codes. This
# repo's own dictionary work (obus's dr_lookup_vocabulary) pools both indiscriminately for
# "Sex" (7+4=11 codes) with no RecordHeader scoping -- a real, confirmed imprecision, not
# hypothetical, and the same class of problem behind the IDX/PlusGr mismatch documented in
# AGENTS.md. Since DATRAS is entirely trawl-survey data, resolve_vocab_key() below prefers
# TS_ over bare over AC_, rather than obus's name-only, prefix-blind matching.

get_icesvocab_types <- function() {
  types <- icesVocab::getCodeTypeList()
  types$prefix <- ifelse(grepl("^TS_", types$Key), "TS",
                   ifelse(grepl("^AC_", types$Key), "AC", "bare"))
  types$stripped <- sub("^(TS_|AC_)", "", types$Key)
  types[, c("Key", "stripped", "prefix", "Description")]
}

# Resolves a raw DATRAS field name (FieldNameOld) to candidate icesVocab Keys, in preference
# order TS_ > bare > AC_ (see header note above for why). Returns ALL candidates, not just the
# top one -- some codeTypes are registered but have zero actual codes (confirmed live for
# "Survey": TS_Survey has 0 codes, AC_Survey has 22), so callers need to fall through to the
# next candidate rather than trust the top preference blindly. `ambiguous = TRUE` flags fields
# matching under more than one prefix, for deciding which fields deserve extra scrutiny.
resolve_vocab_key <- function(field_name, types) {
  matches <- types[types$stripped == field_name, ]
  if (nrow(matches) == 0) {
    return(list(candidates = character(0), ambiguous = FALSE))
  }
  pref_order <- c("TS", "bare", "AC")
  matches <- matches[order(match(matches$prefix, pref_order)), ]
  list(candidates = matches$Key, ambiguous = nrow(matches) > 1)
}

# Fetches the actual code:meaning pairs for one resolved Key. Drops Deprecated codes -- no
# reason to document a code that's no longer valid. Some registered codeTypes have zero
# actual codes (confirmed live for TS_Survey) -- getCodeList() doesn't return a normal
# data.frame for these, so that's treated as "no codes" rather than an error.
get_vocab_codes <- function(key) {
  codes <- tryCatch(icesVocab::getCodeList(key), error = function(e) NULL)
  if (!is.data.frame(codes) || !"Deprecated" %in% names(codes) || nrow(codes) == 0) {
    return(data.frame(Key = character(0), Description = character(0)))
  }
  codes <- codes[!codes$Deprecated, c("Key", "Description")]
  row.names(codes) <- NULL
  codes
}

# Tries each candidate key in preference order, returning the first that yields at least one
# usable code. Returns list(key=NA, codes=<0-row df>) if none do.
first_usable_vocab <- function(field_name, types) {
  resolved <- resolve_vocab_key(field_name, types)
  for (key in resolved$candidates) {
    codes <- get_vocab_codes(key)
    if (nrow(codes) > 0) return(list(key = key, codes = codes, ambiguous = resolved$ambiguous))
  }
  list(key = NA_character_, codes = get_vocab_codes(NA_character_), ambiguous = resolved$ambiguous)
}
