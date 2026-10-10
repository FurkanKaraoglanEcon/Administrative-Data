* Inspect raw headers / one observation, not full datasets. Save inventories even
* when mappings are incomplete, then stop before any full import is performed.
tempname schema issues
postfile `schema' str8 source int year str244 file str32 variable str12 storage ///
    using "${diagnostics}/schema_inventory.dta", replace
postfile `issues' str8 source int year str244 file str32 field str120 issue ///
    using "${diagnostics}/preflight_issues.dta", replace
local failures = 0
foreach flag in build_labor build_households require_cpf_checksum coverage_confirmed {
    assert inlist(${`flag'},0,1)
}
foreach y of global rais_years {
    local decimal "${r_decimal_`y'}"
    if !inlist("`decimal'","comma","dot") {
        post `issues' ("RAIS") (`y') ("") ("decimal") ("Decimal convention must be comma or dot")
        local ++failures
    }
    local public "${r_public_codes_`y'}"
    local private "${r_private_codes_`y'}"
    local overlap : list public & private
    if "`overlap'"!="" {
        post `issues' ("RAIS") (`y') ("") ("natjur") ("Public/private code sets overlap")
        local ++failures
    }
    if ${build_labor} {
        if "${r_active_yes_`y'}"=="${r_active_no_`y'}" {
            post `issues' ("RAIS") (`y') ("") ("active_codes") ("Activity codes must differ")
            local ++failures
        }
    }
    local list "${files`y'}"
    if `"`list'"'=="" {
        post `issues' ("RAIS") (`y') ("") ("file_list") ("No configured files for this year")
        local ++failures
        continue
    }
    foreach f of local list {
        local path "${raw_rais}/`y'/`f'"
        capture confirm file "`path'"
        if _rc {
            post `issues' ("RAIS") (`y') ("`path'") ("file") ("File not found")
            local ++failures
            continue
        }
        capture noisily import delimited "`path'", clear varnames(1) ///
            delimiters(";") stringcols(_all) encoding("${rais_encoding}") ///
            case(lower) rowrange(1:2)
        if _rc {
            post `issues' ("RAIS") (`y') ("`path'") ("import") ("Header import failed")
            local ++failures
            continue
        }
        foreach v of varlist _all {
            local storage : type `v'
            post `schema' ("RAIS") (`y') ("`path'") ("`v'") ("`storage'")
        }
        local fields "cpf name sex dob age"
        if ${build_labor} local fields "`fields' wage_avg tenure hours active"
        foreach field of local fields {
            local raw "${r_`field'_`y'}"
            if "`raw'"=="" & inlist("`field'","dob","age") continue
            capture confirm variable `raw'
            if "`raw'"=="" | _rc {
                post `issues' ("RAIS") (`y') ("`path'") ("`field'") ("Required mapping empty or mapped variable absent")
                local ++failures
            }
        }
        foreach field in wage_dec wage_contract wage_last employer jobid cbo cnae municipality natjur {
            local raw "${r_`field'_`y'}"
            if "`raw'"=="" continue
            capture confirm variable `raw'
            if _rc {
                post `issues' ("RAIS") (`y') ("`path'") ("`field'") ("Configured optional variable absent")
                local ++failures
            }
        }
        capture ds rc_*
        if !_rc {
            if "`r(varlist)'"!="" {
                post `issues' ("RAIS") (`y') ("`path'") ("rc_prefix") ("Raw variables already use reserved rc_ prefix")
                local ++failures
            }
        }
    }
}
foreach y of global cad_years {
    local yy = substr("`y'",3,2)
    local path "${raw_cad}/cadunico`yy'_raw.dta"
    capture noisily use in 1/1 using "`path'", clear
    if _rc {
        post `issues' ("CAD") (`y') ("`path'") ("file") ("File missing or unreadable")
        local ++failures
        continue
    }
    foreach v of varlist _all {
        local storage : type `v'
        post `schema' ("CAD") (`y') ("`path'") ("`v'") ("`storage'")
    }
    local fields "cpf name sex dob"
    if ${build_households} local fields "`fields' family"
    foreach field of local fields {
        local raw "${c_`field'_`y'}"
        capture confirm variable `raw'
        if "`raw'"=="" | _rc {
            post `issues' ("CAD") (`y') ("`path'") ("`field'") ("Required mapping empty or mapped variable absent")
            local ++failures
        }
    }
    foreach field in family personid municipality income_family size_family {
        local raw "${c_`field'_`y'}"
        if "`raw'"=="" continue
        capture confirm variable `raw'
        if _rc {
            post `issues' ("CAD") (`y') ("`path'") ("`field'") ("Configured optional variable absent")
            local ++failures
        }
    }
    capture ds rc_*
    if !_rc {
        if "`r(varlist)'"!="" {
            post `issues' ("CAD") (`y') ("`path'") ("rc_prefix") ("Raw variables already use reserved rc_ prefix")
            local ++failures
        }
    }
}
postclose `schema'
postclose `issues'
foreach table in schema_inventory preflight_issues {
    use "${diagnostics}/`table'.dta", clear
    export delimited using "${diagnostics}/`table'.csv", replace
}
if `failures'>0 {
    di as error "Preflight: `failures' issues. See diagnostics/preflight_issues.dta."
    di as error "Set paths and verified raw-field mappings; rerun the master."
    exit 459
}
