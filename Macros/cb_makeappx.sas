%macro cb_makeappx;

   %do i = 1 %to &varlist_n;
   
      %if &&appx&i = yes %then %do;
      
         proc append base=cb_appendix data=cb_appx_&i;
         run;
         
      %end;
   
   %end;
   
   %if %sysfunc(exist(cb_appendix)) %then %do;
   
      proc sql noprint;
         select   count(*)
         from     cb_appendix
         ;
      quit;
      
      %if &sqlobs > 0 %then %do;
      
         ods pdf startpage=now;
         
         proc sort data=cb_appendix;
            by col1 col2;
         run;
         
         %titlefootnote;
   
         proc report data=cb_appendix nofs;
            column col1 col2 col3 col4 col5;
            define col1 / group   width=20 style(column)=[width=20%];
            define col2 / display width=30 style(column)=[width=30%];
            define col3 / display width=20 style(column)=[width=20%];
            define col4 / display width=10 style(column)=[width=10%];
            define col5 / display width=10 style(column)=[width=10%];
         run;
         
      %end;
      
   %end;
   
%mend cb_makeappx;