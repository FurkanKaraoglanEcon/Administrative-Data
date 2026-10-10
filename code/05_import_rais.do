* Unit: original RAIS row (usually employment record); all raw columns retained.
* Process each geographic file separately. No sex filter and no automatic row
* deduplication: repeated contracts can be real jobs, not duplicate people.
tempname manifest audit
postfile `manifest' int year int part str244 raw_file str244 clean_file double rows ///
    using "${intermediate}/rais_manifest.dta", replace
postfile `audit' int year int part double rows bad_cpf blank_name bad_sex bad_dob ///
    using "${diagnostics}/rais_import_audit.dta", replace
foreach y of global rais_years {
    local list "${files`y'}"
    local i = 0
    foreach f of local list {
        local ++i
        import delimited "${raw_rais}/`y'/`f'", clear varnames(1) ///
            delimiters(";") stringcols(_all) encoding("${rais_encoding}") case(lower)
        gen int rc_year = `y'
        gen int rc_part = `i'
        gen double rc_row = _n
        gen str8 rc_source = "RAIS"
        rc_cpf ${r_cpf_`y'}
        rc_name ${r_name_`y'}
        rc_sex ${r_sex_`y'}, kind("${r_sextype_`y'}")
        if "${r_dob_`y'}"!="" {
            rc_date ${r_dob_`y'}, year(`y') mask("${r_dobmask_`y'}")
        }
        else {
            gen double rc_dob = .
            gen byte rc_dob_unparsed = 0
            gen byte rc_dob_out_of_range = 0
        }
        gen int rc_year_birth = year(rc_dob)
        gen byte rc_yob_approx = 0
        gen double rc_age_reported = .
        if "${r_age_`y'}"!="" {
            rc_number ${r_age_`y'}, generate(rc_age_value) decimal("dot") nonnegative
            replace rc_age_reported = rc_age_value
            replace rc_age_reported = . if !inrange(rc_age_reported,0,110) | ///
                rc_age_reported!=floor(rc_age_reported)
            replace rc_year_birth = `y'-rc_age_reported if missing(rc_year_birth) & !missing(rc_age_reported)
            replace rc_yob_approx = 1 if missing(rc_dob) & !missing(rc_year_birth)
        }
        * An age gives an approximate birth-year interval, not a birth date.
        gen int rc_yob_lower = rc_year_birth-rc_yob_approx
        gen int rc_yob_upper = rc_year_birth
        if ${build_labor} {
            foreach field in wage_avg wage_dec wage_contract wage_last tenure hours {
                local raw "${r_`field'_`y'}"
                if "`raw'"!="" rc_number `raw', generate(rc_`field') decimal("${r_decimal_`y'}") nonnegative
                else {
                    gen double rc_`field' = .
                    gen byte rc_`field'_bad = 0
                }
            }
            tempvar active_text
            rc_string ${r_active_`y'}, generate(`active_text')
            gen byte rc_active_yearend = .
            replace rc_active_yearend = 1 if `active_text'=="${r_active_yes_`y'}"
            replace rc_active_yearend = 0 if `active_text'=="${r_active_no_`y'}"
            gen byte rc_active_bad = `active_text'!="" & missing(rc_active_yearend)
            drop `active_text'
            foreach field in employer jobid cbo cnae municipality natjur {
                local raw "${r_`field'_`y'}"
                if "`raw'"!="" rc_string `raw', generate(rc_`field') identifier
                else gen str1 rc_`field' = ""
            }
            gen byte rc_public = .
            gen byte rc_private = .
            foreach code in ${r_public_codes_`y'} {
                replace rc_public = 1 if rc_natjur=="`code'"
                replace rc_private = 0 if rc_natjur=="`code'"
            }
            foreach code in ${r_private_codes_`y'} {
                replace rc_private = 1 if rc_natjur=="`code'"
                replace rc_public = 0 if rc_natjur=="`code'"
            }
            assert !(rc_public==1 & rc_private==1)
        }
        local N = _N
        count if !rc_cpf_linkable
        local badcpf = r(N)
        count if rc_name==""
        local badname = r(N)
        count if rc_sex_unparsed
        local badsex = r(N)
        count if rc_dob_unparsed | rc_dob_out_of_range
        local baddob = r(N)
        post `audit' (`y') (`i') (`N') (`badcpf') (`badname') (`badsex') (`baddob')
        compress
        save "${intermediate}/rais_clean_`y'_`i'.dta", replace
        post `manifest' (`y') (`i') ("`f'") ///
            ("${intermediate}/rais_clean_`y'_`i'.dta") (`N')
        * Small identity-frequency table, separate from full job data.
        keep rc_cpf rc_cpf_linkable rc_name rc_sex rc_dob rc_year_birth rc_yob_approx rc_source rc_year
        gen double rc_n = 1
        if _N>0 collapse (sum) rc_n, by(rc_cpf rc_cpf_linkable rc_name rc_sex ///
            rc_dob rc_year_birth rc_yob_approx rc_source rc_year)
        save "${intermediate}/rais_identity_`y'_`i'.dta", replace
    }
}
postclose `manifest'
postclose `audit'
