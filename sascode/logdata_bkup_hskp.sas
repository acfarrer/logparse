/* Run after daily processing if rc = 0 */

%macro libtest(lib=) ;
%if (%sysfunc(LIBREF(&lib)) = 0 ) %then %put Library &lib Assigned;
%else %if "&sysuserid" eq "bicocsas" %then libname LOGDATA '/sasdata/bicoc_output01/monitoring/logparse/sasdata' ; /* Owned by bicocsas */
%else %if "&sysuserid" eq "sas" %then libname LOGDATA '/sasdata/bicoc_output01/monitoring/logparse/sasdata' ;      /* Owned by sas */
%else libname LOGDATA "!HOME/sasdata/" ;  /* For testing */
%mend libtest ;
%libtest(lib=LOGDATA) ;

%let tdy = %sysfunc(today()) ;
%let tdyymd = %sysfunc(putn(&tdy,yymmddn8.)) ;
%let weekago = %sysfunc(putn(%sysfunc(intnx(day,&tdy,-7)),yymmddn8.)) ;
%put &=tdyymd &=weekago ;

/* Backup latest */
data logdata.logparse_data_&tdyymd ; set logdata.logparse_data ; run ;
data logdata.logparse_hdrs_&tdyymd ; set logdata.logparse_hdrs ; run ;

/* delete week old datasets */
proc delete data=logdata.logparse_data_&weekago ; run ;
proc delete data=logdata.logparse_hdrs_&weekago ; run ;

/* Is this better?*/
/*proc datasets lib=logdata nolist mt=data ;*/
/*delete logparse_data_&weekago logparse_hdrs_&weekago ;*/
/*quit ;*/
