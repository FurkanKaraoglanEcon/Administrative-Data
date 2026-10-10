* Helpers use only built-in Stata 16 commands.
* Each canonical identity variable is derived without modifying the raw input.
capture program drop rc_string
program define rc_string
    syntax varname, Generate(name) [Identifier]
    capture confirm string variable `varlist'
    if !_rc gen strL `generate' = ustrtrim(`varlist')
    else {
        if "`identifier'"!="" {
            local storage : type `varlist'
            count if `varlist'!=floor(`varlist') & !missing(`varlist')
            if r(N)>0 {
                di as error "Noninteger identifier in `varlist'; inspect raw import."
                exit 459
            }
            if "`storage'"=="float" {
                count if abs(`varlist')>16777216 & !missing(`varlist')
                if r(N)>0 {
                    di as error "Float identifier `varlist' may have lost digits. Reimport as string/double."
                    exit 459
                }
            }
        }
        gen strL `generate' = strtrim(string(`varlist',"%21.0f"))
        replace `generate' = "" if missing(`varlist')
    }
end

capture program drop rc_cpf
program define rc_cpf
    syntax varname
    rc_string `varlist', generate(rc_cpf_raw) identifier
    tempvar digits s1 s2 d1 d2
    gen strL `digits' = subinstr(subinstr(subinstr(rc_cpf_raw,".","",.),"-","",.)," ","",.)
    gen byte rc_cpf_structure = ustrregexm(`digits',"^[0-9]{6,11}$")
    gen str11 rc_cpf = ""
    replace rc_cpf = substr("00000000000",1,11-strlen(`digits')) + `digits' if rc_cpf_structure
    replace rc_cpf_structure = 0 if rc_cpf=="00000000000"
    replace rc_cpf = "" if !rc_cpf_structure
    gen double `s1' = 0
    gen double `s2' = 0
    forvalues j=1/9 {
        replace `s1' = `s1' + real(substr(rc_cpf,`j',1))*(11-`j') if rc_cpf_structure
        replace `s2' = `s2' + real(substr(rc_cpf,`j',1))*(12-`j') if rc_cpf_structure
    }
    gen byte `d1' = mod(`s1'*10,11) if rc_cpf_structure
    replace `d1' = 0 if `d1'==10
    replace `s2' = `s2' + `d1'*2 if rc_cpf_structure
    gen byte `d2' = mod(`s2'*10,11) if rc_cpf_structure
    replace `d2' = 0 if `d2'==10
    gen byte rc_cpf_checksum = `d1'==real(substr(rc_cpf,10,1)) & ///
        `d2'==real(substr(rc_cpf,11,1)) & rc_cpf_structure
    * Reject all repeated-digit CPFs even if their arithmetic check passes.
    forvalues j=0/9 {
        replace rc_cpf_checksum = 0 if rc_cpf==("`j'"*11)
    }
    gen byte rc_cpf_linkable = rc_cpf_structure
    if ${require_cpf_checksum} replace rc_cpf_linkable = rc_cpf_checksum
    label var rc_cpf_linkable "Eligible for CPF links under configured policy"
end

capture program drop rc_name
program define rc_name
    syntax varname
    rc_string `varlist', generate(rc_name_raw)
    gen strL rc_name_spaced = ustrupper(ustrregexra(ustrnormalize(rc_name_raw,"nfd"),"\p{Mark}",""))
    replace rc_name_spaced = subinstr(rc_name_spaced,"-"," ",.)
    replace rc_name_spaced = ustrregexrf(rc_name_spaced,"\(.*\)","")
    replace rc_name_spaced = ustrregexra(rc_name_spaced,"[^A-Z ]","")
    replace rc_name_spaced = stritrim(strtrim(rc_name_spaced))
    gen strL rc_name = subinstr(rc_name_spaced," ","",.)
    * compress converts strL to fixed strings for sorting/grouping, without truncation.
    compress rc_name rc_name_spaced
end

capture program drop rc_sex
program define rc_sex
    syntax varname, Kind(string)
    tempvar value
    rc_string `varlist', generate(`value')
    replace `value' = ustrupper(ustrtrim(`value'))
    gen byte rc_sex = .
    if "`kind'"=="code" {
        replace rc_sex = 1 if inlist(`value',"1","01")
        replace rc_sex = 2 if inlist(`value',"2","02")
    }
    else if "`kind'"=="word" {
        replace rc_sex = 1 if `value'=="MASCULINO"
        replace rc_sex = 2 if `value'=="FEMININO"
    }
    else if "`kind'"=="letter" {
        replace rc_sex = 1 if `value'=="M"
        replace rc_sex = 2 if `value'=="F"
    }
    else exit 198
    label define rc_sex_label 1 "Male" 2 "Female", replace
    label values rc_sex rc_sex_label
    gen byte rc_sex_unparsed = !missing(`value') & missing(rc_sex)
end

capture program drop rc_date
program define rc_date
    syntax varname, Year(integer) Mask(string) [Storage(string)]
    if "`storage'"=="" local storage "string"
    if "`storage'"=="string" {
        confirm string variable `varlist'
        tempvar value
        gen strL `value' = ustrtrim(`varlist')
        if "`mask'"=="DMY" replace `value' = "0" + `value' ///
            if strlen(`value')==7 & ustrregexm(`value',"^[0-9]+$")
        gen double rc_dob = daily(`value',"`mask'")
        gen byte rc_dob_unparsed = `value'!="" & missing(rc_dob)
    }
    else {
        confirm numeric variable `varlist'
        if "`storage'"=="daily" gen double rc_dob = `varlist'
        else if "`storage'"=="datetime" gen double rc_dob = dofc(`varlist')
        else exit 198
        gen byte rc_dob_unparsed = !missing(`varlist') & missing(rc_dob)
    }
    gen byte rc_dob_out_of_range = !missing(rc_dob) & ///
        (!inrange(rc_dob,mdy(1,1,1900),mdy(12,31,`year')) | rc_dob!=floor(rc_dob))
    replace rc_dob = . if rc_dob_out_of_range
    format rc_dob %td
end

capture program drop rc_number
program define rc_number
    syntax varname, Generate(name) Decimal(string) [Nonnegative]
    tempvar value
    capture confirm numeric variable `varlist'
    if !_rc {
        gen double `generate' = `varlist'
        gen byte `generate'_bad = 0
    }
    else {
        gen strL `value' = ustrtrim(`varlist')
        replace `value' = "" if inlist(ustrupper(`value'),".","NA","N/A","NULL")
        replace `value' = subinstr(`value'," ","",.)
        if "`decimal'"=="comma" {
            replace `value' = subinstr(`value',".","",.)
            replace `value' = subinstr(`value',",",".",.)
        }
        else if "`decimal'"!="dot" exit 198
        gen double `generate' = real(`value')
        gen byte `generate'_bad = `value'!="" & missing(`generate')
    }
    if "`nonnegative'"!="" {
        replace `generate'_bad = 1 if `generate'<0 & !missing(`generate')
        replace `generate' = . if `generate'<0
    }
end

capture program drop rc_mode
program define rc_mode
    * Inputs: identity evidence currently in memory; eligible CPF only; rc_n weight.
    * Output: one nonmissing modal attribute per CPF, its distinct count, tie flag.
    * Mode computed separately for each attribute, never conditional on modal name.
    syntax varname, Saving(string)
    keep if !missing(`varlist')
    keep rc_cpf `varlist' rc_n
    count
    if r(N)==0 {
        drop rc_n
        gen long `varlist'_distinct = .
        gen byte `varlist'_tie = .
        save "`saving'", replace
        exit
    }
    collapse (sum) rc_n, by(rc_cpf `varlist')
    bysort rc_cpf: gen long `varlist'_distinct = _N
    bysort rc_cpf: egen double max_weight = max(rc_n)
    gen byte is_max = rc_n==max_weight
    bysort rc_cpf: egen long n_max = total(is_max)
    gen byte `varlist'_tie = n_max>1
    keep if is_max
    * Alphabetical name / earliest date / lowest numeric code resolves a tie;
    * retain flag so researchers can exclude ambiguous identities if necessary.
    bysort rc_cpf (`varlist'): keep if _n==1
    drop rc_n max_weight is_max n_max
    isid rc_cpf
    save "`saving'", replace
end

capture program drop rc_main_record
program define rc_main_record
    tempvar mw mt mh ma
    gen byte `mw' = missing(rc_wage_avg)
    gen byte `mt' = missing(rc_tenure)
    gen byte `mh' = missing(rc_hours)
    gen byte `ma' = missing(rc_active_yearend)
    gsort rc_cpf `mw' -rc_wage_avg `mt' -rc_tenure `mh' -rc_hours ///
        `ma' -rc_active_yearend rc_part rc_row
    by rc_cpf: keep if _n==1
end

