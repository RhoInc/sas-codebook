%macro cbp_prelims;

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
   %let memname&d = %unquote(&&memname&d);
   
   proc sql noprint;
      select   nobs
      into     :nobs&d
      from     dictionary.tables
      where    libname = "&&libname&d"
               and memname = "&&memname&d"
      ;
   quit;
   
   %letput(nobs&d);
   
   
   
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
   %let pdfname&d = &&data&d.._by_&panelby;
   %if %nrbquote(&pdfprefix) ne %str() %then %let pdfname&d = &pdfprefix._&&pdfname&d;
   %letput(pdfname&d);



   %*--------------------------------------------------------------------------------;
   %*---------- create ALL level ----------;
   %*--------------------------------------------------------------------------------;
   
   %global panelbytype panelbylength panelbyformat;
   
   proc sql noprint;
      select   type, length, format
      into     :panelbytype, :panelbylength, :panelbyformat
      from     dictionary.columns
      where    libname = upcase("&&libname&d")
               and memname = upcase("&&memname&d")
               and upcase(name) = upcase("&panelby")
      ;
   quit;
   
   %letput(panelbytype);
   %letput(panelbylength);
   %letput(panelbyformat);
   
   data _w_&&memname&d;
      %*--- a short sidebar to make sure ALL text is not truncated ---;
      %let allcharlength = %length(&allchar);
      %if &panelbytype eq char and &panelbylength < &allcharlength %then %do;
         length &panelby $&allcharlength;
         %if &panelbyformat eq $&panelbylength.. %then %do;
            format &panelby $&allcharlength..;
         %end;
      %end;
      %*--- end sidebar ---;
      set &&data&d;
      %*--- drop records where &panelby is missing ---;
      %if &panelbytype eq char %then
         where &panelby ne "" ;
      %else %if &panelbytype eq num %then
         where n(&panelby) ;
      ;
      %*--- end record dropping ---;
      output;
      %if &panelbytype = num %then &panelby = &allnum;
      %else &panelby = "&allchar";
      ;
      output;
   run;
   
   proc sort data=_w_&&memname&d;
      by &panelby;
   run;
      
   %global panels&d;
   
   proc sql noprint;
      select   count(distinct &panelby)
      into     :panels&d
      from     _w_&&memname&d
      %if &panelbytype = char %then %do;
         where &panelby ne "&allchar";
      %end;
      %else %do;
         where &panelby ne &allnum;
      %end;
      ;
   quit;
   
   %letput(panels&d);

   
%mend cbp_prelims;