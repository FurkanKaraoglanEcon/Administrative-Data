version 16.0
clear all
set more off
set varabbrev off
* EDIT THIS ONE PATH, then edit code/01_config.do and code/02_mappings.do.
global project "C:/RAIS_Cadunico_Project"
do "${project}/code/01_config.do"
foreach folder in intermediate output diagnostics logs {
    capture mkdir "${project}/`folder'"
}
capture erase "${diagnostics}/completion.dta"
capture log close rc_project
log using "${project}/logs/pipeline.log", text replace name(rc_project)
do "${project}/code/02_mappings.do"
do "${project}/code/03_programs.do"
* Stop immediately on an error; never continue with an old output silently.
do "${project}/code/04_preflight.do"
do "${project}/code/05_import_rais.do"
do "${project}/code/06_import_cadunico.do"
do "${project}/code/07_identity_population.do"
if ${build_labor} do "${project}/code/08_labor_outcomes.do"
if ${build_households} do "${project}/code/09_cad_households.do"
if ${build_labor} do "${project}/code/10_link_panel.do"
do "${project}/code/11_checks.do"
di as result "RAIS-CadUnico preparation completed."
log close rc_project
