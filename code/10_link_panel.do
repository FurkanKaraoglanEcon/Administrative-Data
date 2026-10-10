* Descriptive population: CPFs ever observed in supplied CadUnico waves.
* Registry variables are NOT forward-filled to unobserved waves. No name-only
* linkage, no household linkage across time, and no retrospective eligibility
* claim for an eventual CadUnico registrant.
tempfile backbone
use "${output}/population_identity.dta", clear
keep if in_cad
if _N==0 {
    di as error "No eligible CadUnico CPFs for the linked panel."
    exit 2000
}
isid rc_cpf
save `backbone'
tempname linkage
postfile `linkage' int year double cad_population rais_matches cad_wave_matches ///
    using "${diagnostics}/linkage_counts.dta", replace
foreach y of global rais_years {
    use `backbone', clear
    gen int rc_year = `y'
    merge 1:1 rc_cpf rc_year using "${output}/rais_labor_`y'.dta", keep(1 3) gen(rais_merge)
    gen byte rais_record_observed = rais_merge==3
    gen byte rais_coverage_confirmed = ${coverage_confirmed}
    * Indicator of no observed record is always identified. Its economic meaning
    * as absence from covered formal employment requires complete input coverage.
    replace has_rais_record = 0 if rais_merge==1 & rais_coverage_confirmed
    replace rais_records = 0 if rais_merge==1 & rais_coverage_confirmed
    replace any_active_yearend = 0 if rais_merge==1 & rais_coverage_confirmed
    * Wages, hours and tenure stay missing for people with no RAIS record.
    local wave_present = 0
    foreach cy of global cad_years {
        if `cy'==`y' local wave_present = 1
    }
    gen byte cad_wave_available = `wave_present'
    local cad_matches = .
    tempfile panelyear
    save `panelyear'
    if `wave_present' {
        * Membership includes duplicate CPF registrations, but their attributes
        * remain quarantined unless a separate resolution rule is implemented.
        use "${intermediate}/cad_clean_`y'.dta", clear
        keep if rc_cpf_linkable
        keep rc_cpf rc_duplicate_cpf
        gen byte cad_in_wave = 1
        if _N>0 collapse (max) cad_in_wave cad_duplicate_in_wave=rc_duplicate_cpf, by(rc_cpf)
        else rename rc_duplicate_cpf cad_duplicate_in_wave
        tempfile membership
        save `membership'
        use `panelyear', clear
        merge 1:1 rc_cpf using `membership', keep(1 3) gen(cad_membership_merge)
        replace cad_in_wave = 0 if cad_membership_merge==1
        replace cad_duplicate_in_wave = 0 if cad_membership_merge==1
        count if cad_in_wave==1
        local cad_matches = r(N)
        drop cad_membership_merge
        save `panelyear', replace
        if ${build_households} {
            use "${output}/cad_person_wave_`y'.dta", clear
            keep rc_cpf rc_family rc_municipality income_family ///
                size_family_reported income_percapita family_income_conflict family_size_conflict
            rename rc_family cad_family
            rename rc_municipality cad_municipality
            tempfile attributes
            save `attributes'
            use `panelyear', clear
            merge 1:1 rc_cpf using `attributes', keep(1 3) gen(cad_attributes_merge)
            assert cad_attributes_merge!=3 if cad_duplicate_in_wave>0
        }
    }
    else {
        gen byte cad_in_wave = .
        gen byte cad_duplicate_in_wave = .
    }
    count if rais_merge==3
    local nrais = r(N)
    post `linkage' (`y') (_N) (`nrais') (`cad_matches')
    gen int age_dec31 = `y'-year(rc_dob) if !missing(rc_dob)
    replace age_dec31 = . if age_dec31<0 | age_dec31>110
    label var age_dec31 "Age on Dec 31 from exact DOB; missing if invalid or unavailable"
    label var cad_in_wave "Registered in this observed wave; missing if no wave supplied"
    isid rc_cpf rc_year
    compress
    save "${intermediate}/linked_panel_`y'.dta", replace
}
postclose `linkage'
local first = 1
foreach y of global rais_years {
    if `first' use "${intermediate}/linked_panel_`y'.dta", clear
    else append using "${intermediate}/linked_panel_`y'.dta"
    local first = 0
}
isid rc_cpf rc_year
egen long person_id = group(rc_cpf)
label var person_id "Project-local index; CPF is the stable linkage key"
xtset person_id rc_year
compress
save "${output}/rais_cadunico_person_year.dta", replace
