* Household key is family x wave, never family alone across time.
* No unverified head, relationship, poverty threshold or income definition is
* assumed. All original attributes are available in cad_clean_<wave>.dta.
foreach y of global cad_years {
    use "${intermediate}/cad_clean_`y'.dta", clear
    keep if rc_family!=""
    if _N==0 {
        di as error "No nonmissing family IDs in CadUnico `y'. Check mapping."
        exit 2000
    }
    * Household row counts include duplicates. Unique CPF members are only
    * identifiable for eligible CPF values. Missing CPF rows are NOT people IDs.
    bysort rc_family rc_cpf: gen byte cpf_tag = _n==1 & rc_cpf_linkable
    gen long observed_rows = 1
    gen long unresolved_cpf_rows = !rc_cpf_linkable
    gen long repeated_cpf_rows = rc_duplicate_cpf>0 & !missing(rc_duplicate_cpf)
    gen long women_rows = rc_sex==2
    gen long men_rows = rc_sex==1
    gen double income_min = rc_income_family
    gen double income_max = rc_income_family
    gen double size_min = rc_size_family
    gen double size_max = rc_size_family
    collapse (sum) observed_rows unresolved_cpf_rows repeated_cpf_rows ///
        identified_cpf_members=cpf_tag women_rows men_rows ///
        (min) income_min size_min (max) income_max size_max, by(rc_family rc_wave)
    gen byte family_income_conflict = income_min!=income_max ///
        if !missing(income_min,income_max)
    gen byte family_size_conflict = size_min!=size_max if !missing(size_min,size_max)
    * Never sum income repeated on household member rows.
    gen double income_family = income_max if family_income_conflict==0
    gen double size_family_reported = size_max if family_size_conflict==0
    gen double income_percapita = income_family/size_family_reported ///
        if size_family_reported>0 & !missing(size_family_reported,income_family)
    gen byte size_below_identified = size_family_reported<identified_cpf_members ///
        if !missing(size_family_reported)
    isid rc_family rc_wave
    compress
    save "${output}/cad_households_`y'.dta", replace
    preserve
        keep if family_income_conflict==1 | family_size_conflict==1 | ///
            size_below_identified==1 | repeated_cpf_rows>0
        save "${diagnostics}/cad_household_issues_`y'.dta", replace
    restore
    tempfile families
    save `families'
    use "${intermediate}/cad_person_unique_`y'.dta", clear
    * Keep only canonical fields for appending waves; raw types may change.
    keep rc_cpf rc_wave rc_row rc_name rc_sex rc_dob rc_year_birth rc_family ///
        rc_personid rc_municipality rc_income_family rc_size_family
    merge m:1 rc_family rc_wave using `families', keep(1 3) gen(household_merge)
    assert household_merge!=3 if rc_family==""
    isid rc_cpf rc_wave
    compress
    save "${output}/cad_person_wave_`y'.dta", replace
}
local first = 1
foreach y of global cad_years {
    if `first' use "${output}/cad_person_wave_`y'.dta", clear
    else append using "${output}/cad_person_wave_`y'.dta"
    local first = 0
}
isid rc_cpf rc_wave
compress
save "${output}/cadunico_person_wave.dta", replace
local first = 1
foreach y of global cad_years {
    if `first' use "${output}/cad_households_`y'.dta", clear
    else append using "${output}/cad_households_`y'.dta"
    local first = 0
}
isid rc_family rc_wave
save "${output}/cadunico_household_wave.dta", replace
