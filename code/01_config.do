* Paths use forward slashes on Windows as well as Linux.
global raw_rais "D:/RAIS"
global raw_cad  "D:/CadUnico"
global intermediate "${project}/intermediate"
global output       "${project}/output"
global diagnostics  "${project}/diagnostics"
* These are the years and file layout actually present in the supplied script.
global rais_years "2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019"
global cad_years  "2008 2012 2013 2014 2015 2016 2017 2018 2019"
* Add a year only after adding its file list and schema mappings in 02_mappings.
global rais_encoding "latin1"
* Full preparation requires the labor and family mappings below.
* Set either to 0 only if deliberately requesting identity preparation alone.
global build_labor 1
global build_households 1
* 1: only structurally valid CPFs with valid check digits enter CPF linkages.
* 0: accept structurally valid CPFs, retaining the checksum-failure flag.
global require_cpf_checksum 1
* Require affirmative manual verification that each configured annual file list
* covers the intended labor-market universe. 0 leaves no-record outcomes missing.
global coverage_confirmed 0
* Descriptive nominal values only. Supply an external price index separately
* before interpreting wage changes as changes in purchasing power.
global full_time_hours 40
* Main-job order: observed highest mean wage, longest tenure, most hours,
* active at year end, then source-file index and original row number.
* Unknown activity and missing wages never imply zero.
