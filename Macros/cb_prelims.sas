%macro cb_prelims;

   %global libname&d memname&d nobs&d;
   
   

   %*--------------------------------------------------------------------------------;
   %*---------- parse data parameter ----------;
   %*--------------------------------------------------------------------------------;

   %if %sysfunc(index(&&data&d,.)) eq 0 %then %let data&d = work.&&data&d;
   %let libname&d = %upcase(%scan(&&data&d,1,.));
   %let memname&d = %upcase(%scan(&&data&d,2,.));
   %letput(data&d);
   %letput(libname&d);
   %letput(memname&d);
   %let memname&d = %unquote(memname&d);
   
   proc sql noprint;
      select   nobs
      into     :nobs&d
      from     dictionary.tables
      where    libname = "&&libname&d"
               and memname = "&&memname&d"
      ;
   quit;
   
   %letput(nobs&d);
   
   data _w_&&memname&d;
      set &&data&d;
   run;
   
   
   
   %*--------------------------------------------------------------------------------;
   %*---------- pdfpath fallback ----------;
   %*--------------------------------------------------------------------------------;
   
   %if %nrbquote(&pdfpath) eq %str() %then %do;
      %let pdfpath = %sysfunc(pathname(&&libname&d));
      %if %upcase(&&libname&d) eq WORK %then %do;
         %put %str(W)ARNING: no PDFPATH specified for dataset &&data&d...;
         %put %str(W)ARNING: PDF will be stored in the highly temporary WORK folder.;
      %end;
   %end;
   %letput(pdfpath);



   %*--------------------------------------------------------------------------------;
   %*---------- pdfname ----------;
   %*--------------------------------------------------------------------------------;
   
   %global pdfname&d;
   %let pdfname&d = &&data&d;
   %if %nrbquote(&pdfprefix) ne %str() %then %let pdfname&d = &pdfprefix._&&pdfname&d;
   %letput(pdfname&d);


%mend cb_prelims;

