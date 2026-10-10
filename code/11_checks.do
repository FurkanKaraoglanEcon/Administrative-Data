* Required integrity assertions. These do not substitute for raw-data QA.
use "${output}/population_identity.dta", clear
isid rc_cpf
assert strlen(rc_cpf)==11 & ustrregexm(rc_cpf,"^[0-9]+$")
assert in_cad | in_rais
assert rc_year_birth==year(rc_dob) if !missing(rc_dob)
assert inlist(rc_sex,1,2) | missing(rc_sex)
if ${build_labor} {
    use "${output}/rais_labor_outcomes_cpf_year.dta", clear
    isid rc_cpf rc_year
    assert rais_records>=1 & rais_records==floor(rais_records)
    assert inrange(wage_observed_records,0,rais_records)
    assert inrange(active_records+unknown_active_records,0,rais_records)
    assert missing(wage_avg_records_total) if !wage_sum_complete
    assert wage_avg_main>=0 if !missing(wage_avg_main)
    assert hours_main>=0 if !missing(hours_main)
    assert missing(full_time_main) if missing(hours_main)
    use "${output}/rais_cadunico_person_year.dta", clear
    isid rc_cpf rc_year
    assert in_cad==1
    assert rais_record_observed==(rais_merge==3)
    assert missing(wage_avg_main) & missing(hours_main) & missing(tenure_main) if rais_merge==1
    assert missing(has_rais_record) if rais_merge==1 & !rais_coverage_confirmed
    assert has_rais_record==0 if rais_merge==1 & rais_coverage_confirmed
    assert missing(cad_in_wave) if !cad_wave_available
    * Cohort x year summaries reveal changes in matching/coverage, not causality.
    gen byte no_rais_record = !rais_record_observed
    gen byte known_wage = !missing(wage_avg_main)
    collapse (count) persons=person_id (sum) observed_rais=rais_record_observed ///
        no_rais_record known_wage (mean) match_share=rais_record_observed ///
        mean_wage_main=wage_avg_main, by(rc_year)
    save "${diagnostics}/panel_summary.dta", replace
    export delimited using "${diagnostics}/panel_summary.csv", replace
}
if ${build_households} {
    use "${output}/cadunico_person_wave.dta", clear
    isid rc_cpf rc_wave
    use "${output}/cadunico_household_wave.dta", clear
    isid rc_family rc_wave
    assert rc_family!=""
    assert identified_cpf_members<=observed_rows
    assert missing(income_family) if family_income_conflict==1
    assert missing(size_family_reported) if family_size_conflict==1
}
clear
set obs 1
gen str40 status = "All configured integrity assertions passed"
gen str32 finished_date = "`c(current_date)' `c(current_time)'"
gen byte labor_enabled = ${build_labor}
gen byte household_enabled = ${build_households}
save "${diagnostics}/completion.dta", replace
