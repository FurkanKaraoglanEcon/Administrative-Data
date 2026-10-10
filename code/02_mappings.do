* Identity names below are grounded in the supplied do-file.
* ALL OTHER RAW VARIABLES ARE RETAINED in clean part files.
* Canonical fields use rc_ prefixes; raw fields are never renamed or overwritten.
* Labor and household fields were discarded by the source script, so their raw
* names cannot be inferred reliably. Enter exact Stata variable names here.
* Use describe on the raw files / inspect diagnostics/schema_inventory.dta.
* No guessed alias or forced numeric conversion is used.
local ufs_all  AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO
local ufs_nosp AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE TO

global files2004 centro_oeste.TXT nordeste.TXT Norte.TXT SP.TXT SP1.TXT sudeste.TXT sul.TXT
global files2005 centro05.TXT nordeste05.TXT norte05.TXT sp05.TXT sp105.TXT sudeste05.TXT sul05.TXT
global files2006 centro06.TXT nordeste06.TXT norte06.TXT sp06.TXT sp106.TXT sudeste06.TXT sul06.TXT
global files2007 centooeste07.TXT nordeste07.TXT norte07.TXT sp07.TXT sudeste07.TXT sul07.TXT
global files2008 centrooeste08.TXT nordeste08.TXT norte08.TXT sp08.TXT sp08_1.TXT sudeste08.TXT sul08.TXT

global files2009 ""
foreach uf of local ufs_nosp {
    global files2009 "${files2009} `uf'2009ID.TXT"
}
global files2009 "${files2009} SP2009ID_ATIVOS.TXT SP2009ID_INATIVOS.TXT"

global files2010 ""
foreach uf of local ufs_nosp {
    global files2010 "${files2010} `uf'2010ID.TXT"
}
global files2010 "${files2010} SP2010ID_1.TXT SP2010ID_2.TXT SP2010ID_3.TXT"

global files2011 ""
foreach uf of local ufs_nosp {
    global files2011 "${files2011} `uf'2011ID.txt"
}
global files2011 "${files2011} SP12011ID.txt SP22011ID.txt SP32011ID.txt"

foreach yr in 2012 2013 2017 {
    local lname "files`yr'"
    global `lname' ""
    foreach uf of local ufs_all {
        global `lname' "${`lname'} `uf'`yr'ID.txt"
    }
}

foreach yr in 2014 2015 2016 {
    local lname "files`yr'"
    global `lname' ""
    foreach uf of local ufs_all {
        global `lname' "${`lname'} `uf'`yr'ID/`uf'`yr'ID.TXT"
    }
}

foreach yr in 2018 2019 {
    local lname "files`yr'"
    global `lname' ///
        "RAIS_VINC_ID_CENTRO_OESTE.txt RAIS_VINC_ID_MG_ES_RJ.txt RAIS_VINC_ID_NORDESTE.txt RAIS_VINC_ID_NORTE.txt RAIS_VINC_ID_SP.txt RAIS_VINC_ID_SUL.txt"
}


foreach y of global rais_years {
    global r_cpf_`y' "cpf"
    global r_age_`y' ""
    global r_dob_`y' ""
    global r_dobmask_`y' "DMY"
    if `y'<=2010 {
        global r_name_`y' "nome"
        global r_dob_`y' "dtnasciment"
        global r_sex_`y' "genero"
        global r_sextype_`y' "word"
        if `y'==2004 {
            global r_sex_`y' "sexo"
            global r_sextype_`y' "code"
        }
    }
    else {
        global r_name_`y' "nometrabalhador"
        global r_sex_`y' "sexotrabalhador"
        global r_sextype_`y' "code"
        global r_age_`y' "idade"
        if `y'>=2014 global r_dob_`y' "datadenascimento"
    }
    * Required for labor: mean wage, tenure, hours, year-end activity.
    * Enter a field only after verifying its units and definition for that year.
    global r_wage_avg_`y' ""
    global r_tenure_`y' ""
    global r_hours_`y' ""
    global r_active_`y' ""
    * Decimal convention: comma e.g. 1.234,56; dot e.g. 1234.56.
    global r_decimal_`y' "comma"
    * Raw year-end activity codes (edit after consulting the local dictionary).
    global r_active_yes_`y' "1"
    global r_active_no_`y'  "0"
    * Optional fields: leave blank to produce documented missing values.
    global r_wage_dec_`y' ""
    global r_wage_contract_`y' ""
    global r_wage_last_`y' ""
    global r_employer_`y' ""
    global r_jobid_`y' ""
    global r_cbo_`y' ""
    global r_cnae_`y' ""
    global r_municipality_`y' ""
    global r_natjur_`y' ""
    * Do not infer public/private status without verified nature-of-entity codes.
    global r_public_codes_`y' ""
    global r_private_codes_`y' ""
}
foreach y of global cad_years {
    global c_dobmask_`y' "YMD"
    * string (source assumption), daily, or datetime for numeric Stata dates.
    global c_dobstorage_`y' "string"
    if `y'==2008 {
        global c_cpf_`y' "nu_cpf"
        global c_name_`y' "nm_pessoa"
        global c_sex_`y' "cd_sexo"
        global c_dob_`y' "dt_nascimento"
        global c_sextype_`y' "letter"
    }
    else {
        global c_cpf_`y' "num_cpf_pessoa"
        global c_name_`y' "nom_pessoa"
        global c_sex_`y' "cod_sexo_pessoa"
        global c_dob_`y' "dta_nasc_pessoa"
        global c_sextype_`y' "code"
    }
    * Required for household preparation; unknown in supplied script.
    global c_family_`y' ""
    * Optional: an identifier unique to each person within a wave, not NIS/CPF
    * unless that field is actually the dictionary's person identifier.
    global c_personid_`y' ""
    global c_municipality_`y' ""
    * Household-level income/size; not individual income repeated or summed.
    global c_income_family_`y' ""
    global c_size_family_`y' ""
    global c_decimal_`y' "comma"
}
* Put per-year overrides HERE, after the loops (not before them).
* Example syntax only: global r_wage_avg_2019 "verified_raw_variable_name"
* Add later RAIS years' file lists here as well; no 2020+ layout is assumed.
