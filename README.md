# RAIS–CadÚnico Data Preparation

A modular Stata pipeline for importing, cleaning and linking RAIS employment records and CadÚnico registrations. It preserves raw variables, standardizes identifiers and demographic fields, prepares labor and household outcomes, and produces an exact-CPF linked person-year panel.

## Datasets

- **RAIS:** semicolon-delimited employment files for 2004–2019, organized by year and geographic part.
- **CadÚnico:** registration datasets in Stata format for 2008 and 2012–2019.

Years, input files, variable mappings, encoding and parsing conventions are configurable. Additional years require corresponding file lists and field mappings.

## Code structure

| File | Purpose |
|---|---|
| `00_master.do` | Runs the pipeline and records the log |
| `code/01_config.do` | Paths, years, preparation options and linkage policy |
| `code/02_mappings.do` | Input file lists and year-specific variable mappings |
| `code/03_programs.do` | Identifier, text, date and numeric cleaning helpers |
| `code/04_preflight.do` | Checks files and mappings; exports schema inventories |
| `code/05_import_rais.do` | Imports employment records and preserves raw columns |
| `code/06_import_cadunico.do` | Cleans registrations and flags repeated CPFs within waves |
| `code/07_identity_population.do` | Selects identity attributes and flags conflicting evidence |
| `code/08_labor_outcomes.do` | Prepares main-record and aggregate person-year outcomes |
| `code/09_cad_households.do` | Prepares person-wave and household-wave datasets |
| `code/10_link_panel.do` | Links registrations and labor outcomes by CPF |
| `code/11_checks.do` | Checks output keys and consistency; summarizes linkage |
| `code/12_smoke_test.do` | Optional synthetic tests of cleaning and selection helpers |

## Running

Requires Stata 16 or later; no additional packages are used.

1. Set the project path in `00_master.do` and raw-data paths in `code/01_config.do`.
2. Complete the mappings in `code/02_mappings.do`, including mean wage, tenure, weekly hours, year-end activity and family identifiers. Verify units, codes, decimal conventions and date storage against the dataset dictionaries.
3. Run `00_master.do`. Missing files or required mappings stop the pipeline after producing diagnostic inventories. Successful runs rebuild the configured data and save `diagnostics/completion.dta` after the integrity checks pass.
