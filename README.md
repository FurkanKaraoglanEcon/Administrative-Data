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

## Preparation rules

- CPFs are standardized as 11-character strings. Linkage requires valid check digits by default. Missing or invalid CPFs remain unlinked.
- Names are normalized, while raw values are retained. Name, sex and birth-date modes are selected independently using record frequencies. Conflicts, ties and age-derived birth-year approximations are flagged.
- Repeated CPF registrations within a CadÚnico wave are retained for review and excluded from unique-person attributes; they still contribute to wave membership.
- The main employment record is selected across all yearly input parts by mean wage, tenure, hours and year-end activity, with deterministic source-row tie breaking. Missing values rank after observed values.
- Labor outputs include nominal remuneration, hours, tenure, activity and optional employer classifications. Record counts are not assumed to be distinct-job counts. Sums of record mean monthly wages are not annual earnings.
- Household income and reported size are retained when member records agree. Conflicting values become missing; repeated household income is never summed across members.
- The linked panel covers eligible CPFs ever observed in the configured CadÚnico waves. Household attributes are attached only to observed contemporaneous waves. Unmatched employment indicators remain missing unless annual RAIS coverage is explicitly confirmed.

## Main outputs

| Dataset | Key |
|---|---|
| `population_identity.dta` | CPF |
| `rais_labor_outcomes_cpf_year.dta` | CPF × year |
| `cadunico_person_wave.dta` | CPF × wave |
| `cadunico_household_wave.dta` | Family × wave |
| `rais_cadunico_person_year.dta` | CPF × year |

Cleaned record files are saved under `intermediate/`, prepared datasets under `output/`, and audits under `diagnostics/`. Logs are saved under `logs/`.

## Running

Requires Stata 16 or later; no additional packages are used.

1. Set the project path in `00_master.do` and raw-data paths in `code/01_config.do`.
2. Complete the mappings in `code/02_mappings.do`, including mean wage, tenure, weekly hours, year-end activity and family identifiers. Verify units, codes, decimal conventions and date storage against the dataset dictionaries.
3. Run `00_master.do`. Missing files or required mappings stop the pipeline after producing diagnostic inventories. Successful runs rebuild the configured data and save `diagnostics/completion.dta` after the integrity checks pass.
