* Inputs: clean RAIS part files. Outputs: all eligible-CPF person-years, plus
* selected main employment record and aggregate remuneration across records.
* Counts are RECORD counts; separate contracts/duplicate extracts cannot be
* distinguished without a verified job identifier. Raw records remain intact.
tempname audit
postfile `audit' int year int part double eligible_rows bad_wages bad_hours ///
    bad_tenure bad_activity using "${diagnostics}/labor_parse_audit.dta", replace
foreach y of global rais_years {
    local i = 0
    local list "${files`y'}"
    foreach f of local list {
        local ++i
        use "${intermediate}/rais_clean_`y'_`i'.dta", clear
        keep if rc_cpf_linkable
        local N = _N
        count if rc_wage_avg_bad
        local bw = r(N)
        count if rc_hours_bad
        local bh = r(N)
        count if rc_tenure_bad
        local bt = r(N)
        count if rc_active_bad
        local ba = r(N)
        post `audit' (`y') (`i') (`N') (`bw') (`bh') (`bt') (`ba')
        * Never use a single main job to infer activity in all other jobs.
        preserve
            gen double rais_records = 1
            gen double active_records = rc_active_yearend==1
            gen double unknown_active_records = missing(rc_active_yearend)
            gen double wage_observed_records = !missing(rc_wage_avg)
            gen double wage_sum_observed = rc_wage_avg
            keep rc_cpf rais_records active_records unknown_active_records ///
                wage_observed_records wage_sum_observed
            if _N>0 collapse (sum) rais_records active_records unknown_active_records ///
                wage_observed_records wage_sum_observed, by(rc_cpf)
            save "${intermediate}/labor_totals_`y'_`i'.dta", replace
        restore
        keep rc_cpf rc_year rc_part rc_row rc_wage_avg rc_wage_dec ///
            rc_wage_contract rc_wage_last rc_hours rc_tenure rc_active_yearend ///
            rc_employer rc_jobid rc_cbo rc_cnae rc_municipality rc_natjur rc_public rc_private
        if _N>0 rc_main_record
        save "${intermediate}/labor_main_`y'_`i'.dta", replace
    }
    * Append already collapsed per-file totals; large raw job files never append.
    use "${intermediate}/labor_totals_`y'_1.dta", clear
    local parts = `i'
    if `parts'>1 {
        forvalues j=2/`parts' {
            append using "${intermediate}/labor_totals_`y'_`j'.dta"
        }
    }
    if _N==0 {
        di as error "No eligible RAIS records for `y'; inspect inputs/CPF policy."
        exit 2000
    }
    collapse (sum) rais_records active_records unknown_active_records ///
        wage_observed_records wage_sum_observed, by(rc_cpf)
    gen int rc_year = `y'
    gen byte has_rais_record = 1
    gen byte any_active_yearend = 1 if active_records>0
    replace any_active_yearend = 0 if active_records==0 & unknown_active_records==0
    gen byte wage_sum_complete = wage_observed_records==rais_records
    * Sum of annual MEAN MONTHLY remuneration over reported records. This is
    * not annual earnings and is not exposure-adjusted for simultaneous jobs.
    gen double wage_avg_records_total = wage_sum_observed if wage_sum_complete
    replace wage_sum_observed = . if wage_observed_records==0
    tempfile totals
    save `totals'
    use "${intermediate}/labor_main_`y'_1.dta", clear
    if `parts'>1 {
        forvalues j=2/`parts' {
            append using "${intermediate}/labor_main_`y'_`j'.dta"
        }
    }
    * The global best record must be among the per-file best records.
    rc_main_record
    rename (rc_part rc_row) (main_source_part main_source_row)
    rename (rc_wage_avg rc_wage_dec rc_wage_contract rc_wage_last) ///
        (wage_avg_main wage_dec_main wage_contract_main wage_last_main)
    rename (rc_hours rc_tenure rc_active_yearend) (hours_main tenure_main active_yearend_main)
    rename (rc_employer rc_jobid rc_cbo rc_cnae rc_municipality rc_natjur rc_public rc_private) ///
        (employer_main jobid_main cbo_main cnae_main municipality_main natjur_main public_main private_main)
    gen byte full_time_main = hours_main>=${full_time_hours} if !missing(hours_main)
    gen double ln_wage_avg_main = ln(wage_avg_main) if wage_avg_main>0 & !missing(wage_avg_main)
    merge 1:1 rc_cpf rc_year using `totals', assert(3) nogen
    label var has_rais_record "At least one RAIS row; not proof of year-round employment"
    label var wage_avg_main "Mean monthly nominal remuneration, selected main record"
    label var wage_avg_records_total "Sum of record mean monthly wages; complete observations only"
    label var rais_records "Number of raw RAIS employment records, without deduplication"
    isid rc_cpf rc_year
    compress
    save "${output}/rais_labor_`y'.dta", replace
}
postclose `audit'
local first = 1
foreach y of global rais_years {
    if `first' use "${output}/rais_labor_`y'.dta", clear
    else append using "${output}/rais_labor_`y'.dta"
    local first = 0
}
isid rc_cpf rc_year
compress
save "${output}/rais_labor_outcomes_cpf_year.dta", replace
