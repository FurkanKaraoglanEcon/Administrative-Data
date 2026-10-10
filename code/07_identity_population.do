* Preserve source/year evidence before constructing an independent mode for
* name, sex and DOB. Frequencies count input records, not distinct people.
* A frequently employed person's RAIS records can outweigh CadUnico evidence;
* this explicitly preserves the weighting convention in the source project.
local first = 1
foreach y of global rais_years {
    local list "${files`y'}"
    local i = 0
    foreach f of local list {
        local ++i
        if `first' use "${intermediate}/rais_identity_`y'_`i'.dta", clear
        else append using "${intermediate}/rais_identity_`y'_`i'.dta"
        local first = 0
    }
}
foreach y of global cad_years {
    append using "${intermediate}/cad_identity_`y'.dta"
}
compress
save "${intermediate}/identity_evidence.dta", replace
preserve
    keep if !rc_cpf_linkable
    * Missing/invalid CPF evidence remains unlinked; no invented person IDs.
    save "${output}/identity_unresolved.dta", replace
restore
keep if rc_cpf_linkable
if _N==0 {
    di as error "No eligible CPFs. Inspect CPF audit and validation policy."
    exit 2000
}
tempfile eligible
save `eligible'
foreach field in rc_name rc_sex rc_dob {
    use `eligible', clear
    rc_mode `field', saving("${intermediate}/mode_`field'.dta")
}
* Exact birth years dominate age-derived birth-year approximations.
use `eligible', clear
gen byte exact_yob = !missing(rc_dob)
bysort rc_cpf: egen byte has_exact_yob = max(exact_yob)
keep if exact_yob | !has_exact_yob
rc_mode rc_year_birth, saving("${intermediate}/mode_rc_year_birth.dta")
use `eligible', clear
gen double rais_records = rc_n*(rc_source=="RAIS")
gen double cad_records  = rc_n*(rc_source=="CAD")
gen int rais_first = rc_year if rc_source=="RAIS"
gen int rais_last  = rais_first
gen int cad_first  = rc_year if rc_source=="CAD"
gen int cad_last   = cad_first
collapse (sum) source_records=rc_n rais_records cad_records ///
    (min) rais_first cad_first (max) rais_last cad_last, by(rc_cpf)
foreach field in rc_name rc_sex rc_dob rc_year_birth {
    merge 1:1 rc_cpf using "${intermediate}/mode_`field'.dta", assert(1 3) nogen
}
gen byte in_rais = rais_records>0
gen byte in_cad  = cad_records>0
gen byte dob_yob_disagree = year(rc_dob)!=rc_year_birth ///
    if !missing(rc_dob,rc_year_birth)
replace rc_year_birth = year(rc_dob) if !missing(rc_dob)
gen byte year_birth_approx = missing(rc_dob) & !missing(rc_year_birth)
* Guard against Stata missing values comparing greater than numbers.
gen byte identity_conflict = ///
    (rc_name_distinct>1 & !missing(rc_name_distinct)) | ///
    (rc_sex_distinct>1 & !missing(rc_sex_distinct)) | ///
    (rc_dob_distinct>1 & !missing(rc_dob_distinct))
format rc_dob %td
isid rc_cpf
compress
save "${output}/population_identity.dta", replace
preserve
    keep if identity_conflict | rc_name_tie==1 | rc_sex_tie==1 | rc_dob_tie==1
    save "${diagnostics}/identity_conflicts.dta", replace
restore
* Sex-specific compatibility products; unknown/conflicting sex remains in master.
foreach sex in 1 2 {
    preserve
        keep if rc_sex==`sex'
        rename (rc_cpf rc_name rc_dob rc_year_birth source_records) (cpf name dob year_birth n)
        if `sex'==1 save "${output}/men_population.dta", replace
        if `sex'==2 save "${output}/women_population.dta", replace
    restore
}
