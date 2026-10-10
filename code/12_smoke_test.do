version 16.0
* Optional synthetic helper tests. Run after master has loaded config/programs,
* or set project and do 01_config.do and 03_programs.do first.
* No administrative data needed; does not modify production output files.
preserve
clear
input str20 cpf_raw str40 name_raw str12 date_raw str12 amount
"123.456.789-09" "João da Silva" "01021980" "1.234,56"
"00000000000" "Maria-Souza" "31132000" "-1,00"
"ABC" "   " "" "not_numeric"
end
rc_cpf cpf_raw
assert rc_cpf=="12345678909" in 1
assert rc_cpf_checksum==1 in 1
assert rc_cpf_checksum==0 in 2/3
rc_name name_raw
assert rc_name=="JOAODASILVA" in 1
assert rc_name=="MARIASOUZA" in 2
assert rc_name=="" in 3
rc_date date_raw, year(2019) mask("DMY")
assert rc_dob==mdy(2,1,1980) in 1
assert rc_dob_unparsed==1 in 2
rc_number amount, generate(test_number) decimal("comma") nonnegative
assert abs(test_number-1234.56)<1e-8 in 1
assert missing(test_number) & test_number_bad==1 in 2/3

* The DOB mode must use ALL evidence rather than only modal-name rows.
clear
input str11 rc_cpf str8 rc_name int birthyear double rc_n
"12345678909" "ALPHA" 1980 5
"12345678909" "BETA" 1990 4
"12345678909" "BETA" 1995 4
end
gen double rc_dob = mdy(1,1,birthyear)
tempfile evidence names dates
save `evidence'
rc_mode rc_name, saving("`names'")
use `names', clear
assert rc_name=="BETA"
assert rc_name_distinct==2
use `evidence', clear
rc_mode rc_dob, saving("`dates'")
use `dates', clear
assert rc_dob==mdy(1,1,1980)
assert rc_dob_distinct==3

* Observed wage must beat missing wage; deterministic tie favors lower source key.
clear
input str11 rc_cpf double rc_wage_avg rc_tenure rc_hours byte rc_active_yearend int rc_part double rc_row
"12345678909" . 100 40 1 1 1
"12345678909" 200 12 40 1 2 3
"12345678909" 200 12 40 1 1 5
"12345678909" 100 24 40 1 1 6
end
rc_main_record
assert _N==1
assert rc_wage_avg==200 & rc_part==1 & rc_row==5
restore
di as result "Synthetic helper tests passed."
