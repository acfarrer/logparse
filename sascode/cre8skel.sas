%macro inittest(lib=) ;  
%global logfile ;
%if (%sysfunc(LIBREF(&lib)) = 0 ) %then %put Library &lib Assigned;
%else %if "&sysuserid" eq "bicocsas" %then %do ;
	libname LOGDATA '/sasdata/bicoc_output01/monitoring/logparse/sasdata' ; /* Owned by bicocsas */
	filename outlist '/sasdata/bicoc_output01/monitoring/logparse/refdata/processed_logs.lst' ;
	options sasautos=(SASAUTOS '/sasdata/bicoc_output01/monitoring/logparse/sasmacros') ;
%end ;
%else %if "&sysuserid" eq "sas" %then %do ;
	libname LOGDATA '/sasdata/bicoc_output01/monitoring/logparse/sasdata' ;      /* Owned by sas */
	filename outlist '/sasdata/bicoc_output01/monitoring/logparse/refdata/processed_logs.lst' ;
	options sasautos=(SASAUTOS '/sasdata/bicoc_output01/monitoring/logparse/sasmacros') ;
%end ;
%else %do ;
	libname LOGDATA "!HOME/sasdata/" ;  /* For testing */
	options sasautos=(SASAUTOS '~/sasmacros') ; 
	filename outlist '~/refdata/processed_logs.lst' ;
%end ;

%if "&sysparm" ne "" %then %let logfile = &sysparm ; /* %symexist(&sysparm) not valid for automatic macro vars */
%else %let logfile = /sasdata/bicoc_output01/SASWSlogs/2020-02-10_23496_SASApp01_SASESCCLDVAPP01.log ; /* Manual override for EG testing */
%mend inittest ;
%inittest(lib=LOGDATA) ;

proc delete data = logdata.logparse_hdrs_skel ;
run ;
proc append base = logdata.logparse_hdrs_skel data = logdata.logparse_hdrs (obs = 0) ;
run ;
proc delete data = logdata.logparse_data_skel ;
run ;
proc append base = logdata.logparse_data_skel data = logdata.logparse_data (obs = 0) ;
run ;
