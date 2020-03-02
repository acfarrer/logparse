/* 
Program to scan each SAS log with %logparse originally from 2005 
Designed to be run manually in EG or scheduled by service account - must have read access to /sasdata/bicoc_output01/SASlogfiles/
Each log's layout is specified in logconfig.altlog.xml defined in -logconfigloc 
Input logfile must have START as first 5 chars. Tested in calling script : if [ $(head -1 $LOG | cut -c 1-5) != START ] 
First data step reads log header and creates date_pid as unique key
Second data step adds or replaces header info in control master based on unique key date_pid. Set status.
First sql step right joins header with stepname data from %logparse
Second sql step adds full stepname data to data master if status = 'added'
Working version 1.0   12Feb2020 . Andrew Farrer
Scheduled version 1.1 15Feb2010 . Andrew Farrer
To Do:
1) Combine sql steps to eliminate work.logparse_data_temp
2) For re-runs (status='replace'), refine and left join to only update matching date_pid
3) Modify logparse.sas to create date_pid instead of using logfile as matching key 
*/   
/* If $APPHOME not set in calling script, use default for &apphome */
%let apphome=%sysfunc(ifc( "%sysget(APPHOME)" eq "", /sasdata/bicoc_output01/monitoring/logparse, %sysget(APPHOME))) ;
%put &=apphome ;

libname LOGDATA "&apphome./sasdata" ;
options sasautos=(SASAUTOS "&apphome./sasmacros" ) ;

%put &=sysparm ;

%let logfile = %sysfunc(ifc( "&sysparm" eq "" ,
                           /sasdata/bicoc_output01/SASWSlogs/2020-02-10_23496_SASApp01_SASESCCLDVAPP01.log ,
                           &sysparm)) ;

/* 
Read header info from first record of log. 
Calling script process_WSlogs.sh already filters for valid format 
*/
data logdata.logparse_hdr (label = 'header info from first record of log') ;
length user $ 10 host $ 16 app $ 25 cmd $ 520 logfile $ 80 server $ 40 logclsvr $ 17 ;
infile "&logfile" obs = 1 ;
informat startdt E8601DT23. ;
format startdt dtdate9. datepid 14. ;
retain status 'normal ' ;
logfile = "&logfile" ;
label  startdt = 'appender_param_value_%d{ISO8601}'
       pid = 'appender_param_value_%S{pid}'
       user = 'appender_param_value_%S{username}'
       host = 'appender_param_value_%S{hostname}' 
       app = 'appender_param_value_%S{App.Name}'
       cmd = 'appender_param_value_%S{startup_cmd}'
       date_pid = 'datapart(startdt)_pid,z5.'
			 datepid = 'yyyymmddpid numeric'
       logfile = 'Log file name'
			 logclsvr = 'Logical server identity'
			 status = 'logparse_hdrs modify status'
       ;
input startdt= user= pid= host= app= cmd= server= ;
put server= ;
if server ne ' ' then logclsvr = substr(server, 24, 17) ; /* Logical server is last chars of OMSOBJ:SERVERCOMPONENT/A5D0TMXW.AY000009 */
else logclsvr = "No logical server" ;
drop server ;
date_pid = put(datepart(startdt),yymmddn8.) || '_' || put(pid,z5.) ; /* Use z5. to zero pad date_pid string */
datepid = (input(put(datepart(startdt),yymmddn8.),8.) * 1e5) + pid ; /* Unique numeric for INTEGER NOT NULL */
put date_pid= datepid= startdt= user= pid= host= app= logclsvr= cmd= ;
output logdata.logparse_hdr ;
run ;

/* 
One record/log in logparse_hdrs as control master 
Match on unique date_pid and set status='replace' and replace 
Else set status='added' and output new header info to control master
*/
options nomlogic ; /* Suppress %sysrc */
data logdata.logparse_hdrs (label = 'Control master. One record/log') ;
   modify logdata.logparse_hdrs logdata.logparse_hdr ;
   by date_pid ;
   select (_iorc_);
      /* The observation exists in the master data set. */
      when (%sysrc(_sok)) do;
				 status = 'replace ' ;
         replace ; 
         putlog "Already processed &logfile" ; 
				 putlog 'Replacing date_pid = ' date_pid ; 
      end;
      /* The observation does not exist in the master data set. */
      when (%sysrc(_dsenmr)) do; 
				 status = 'added  ' ;
         output; 
         putlog "Not already processed &logfile" ; 
				 putlog 'Need to add date_pid = ' date_pid ; 
         _error_=0;
      end;
      otherwise do; 
           put 'An unexpected I/O error has occurred.' ;
         _error_=0;
         stop;
      end; 
   end; 
run ;

options nomprint nosgen nosource2 ;
options mautosource ;
%put SASAUTOS = %sysfunc(getoption(SASAUTOS)) ;
*include '~/sasmacros/logparse.sas' ;

%logparse(&logfile.,work.logparse,,append=no) ;

proc sql  ;
create table work.logparse_data_temp as
select h.date_pid 
      ,h.datepid  
      ,h.startdt
      ,h.pid 
      ,h.user     
      ,h.host     
      ,h.app      
      ,h.logclsvr 
      ,h.status   
      ,l.stepcnt  
      ,l.stepname 
      ,l.realtime 
      ,l.usertime 
      ,l.systime  
      ,l.pageflt  
      ,l.pagercl  
      ,l.pageswp  
      ,l.osvconsw 
      ,l.osiconsw 
      ,l.blkinput 
      ,l.bkoutput 
      ,l.obsin    
      ,l.obsout   
      ,l.varsout  
      ,l.osmem    
from  logdata.logparse_hdrs h
right join work.logparse l  /* Name is 2nd parameter of %logparse */
on    h.logfile = l.logfile /* Consider modifying %logparse to create datepid */
order by l.stepcnt
;

/* 
After testing, combine steps to eliminate logdata.logparse_data 
*/ 

insert into logdata.logparse_data
select * from work.logparse_data_temp
where status = 'added   '
;
/* For re-runs. Only activate after testing */
*select * 
from   work.logparse_data_temp w
left join logdata.logparse_data l
on    w.date_pid = l.date_pid
and   w.stepcnt = l.stepcnt
where w.status = 'replace '
;
quit ;

/* Create listing of processed logs from control master to exclude from scheduled scan */
filename outlist "&apphome./refdata/processed_logs.lst" ;

data _null_ ;
set logdata.logparse_hdrs ;
file outlist ;
if logfile ne ' ' then put logfile ;
run ;

%put List of processed logs is %sysfunc(pathname(outlist)) ;
