* Unit: original CadUnico row / registration wave. Preserve every raw column,
* including family, schooling, benefits, race and income variables not mapped.
* Registration wave is not claimed to be the date of each reported outcome.
tempname audit
postfile `audit' int wave double rows bad_cpf blank_name bad_dob duplicate_cpf_rows ///
    using "${diagnostics}/cad_import_audit.dta", replace
foreach y of global cad_years {
    local yy = substr("`y'",3,2)
    use "${raw_cad}/cadunico`yy'_raw.dta", clear
    gen int rc_wave = `y'
    gen double rc_row = _n
    gen str8 rc_source = "CAD"
    rc_cpf ${c_cpf_`y'}
    rc_name ${c_name_`y'}
    rc_sex ${c_sex_`y'}, kind("${c_sextype_`y'}")
    rc_date ${c_dob_`y'}, year(`y') mask("${c_dobmask_`y'}") storage("${c_dobstorage_`y'}")
    gen int rc_year_birth = year(rc_dob)
    gen byte rc_yob_approx = 0
    foreach field in family personid municipality {
        local raw "${c_`field'_`y'}"
        if "`raw'"!="" rc_string `raw', generate(rc_`field') identifier
        else gen str1 rc_`field' = ""
    }
    gen byte rc_family_invalid = inlist(rc_family,"",".","0")
    replace rc_family = "" if rc_family_invalid
    foreach field in income_family size_family {
        local raw "${c_`field'_`y'}"
        if "`raw'"!="" rc_number `raw', generate(rc_`field') decimal("${c_decimal_`y'}") nonnegative
        else {
            gen double rc_`field' = .
            gen byte rc_`field'_bad = 0
        }
    }
    replace rc_size_family_bad = 1 if !missing(rc_size_family) & ///
        (rc_size_family<1 | rc_size_family!=floor(rc_size_family))
    replace rc_size_family = . if rc_size_family_bad
    compress rc_cpf rc_family rc_personid rc_municipality
    duplicates tag rc_cpf if rc_cpf_linkable, generate(rc_duplicate_cpf)
    local N = _N
    count if !rc_cpf_linkable
    local badcpf = r(N)
    count if rc_name==""
    local badname = r(N)
    count if rc_dob_unparsed | rc_dob_out_of_range
    local baddob = r(N)
    count if rc_duplicate_cpf>0 & !missing(rc_duplicate_cpf)
    local ndups = r(N)
    post `audit' (`y') (`N') (`badcpf') (`badname') (`baddob') (`ndups')
    compress
    save "${intermediate}/cad_clean_`y'.dta", replace
    preserve
        * All repeated CPF-wave rows are quarantined; no arbitrary first-row rule.
        keep if rc_cpf_linkable & rc_duplicate_cpf>0
        save "${diagnostics}/cad_duplicate_cpf_`y'.dta", replace
    restore
    preserve
        keep if rc_cpf_linkable & rc_duplicate_cpf==0
        isid rc_cpf
        save "${intermediate}/cad_person_unique_`y'.dta", replace
    restore
    keep rc_cpf rc_cpf_linkable rc_name rc_sex rc_dob rc_year_birth rc_yob_approx rc_source
    gen int rc_year = `y'
    gen double rc_n = 1
    if _N>0 collapse (sum) rc_n, by(rc_cpf rc_cpf_linkable rc_name rc_sex ///
        rc_dob rc_year_birth rc_yob_approx rc_source rc_year)
    save "${intermediate}/cad_identity_`y'.dta", replace
}
postclose `audit'
