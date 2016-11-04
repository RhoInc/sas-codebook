/*--------------------------------------------------------------------------------
Abbreviated vertical codebook macro, Shane Rosanbalm, Rho, Inc., 2016

Description:
   This macro produces an abbreviated PDF summary of a vertical dataset (i.e., a
   dataset in which results for each parameter are stored in a common variable
   such as AVAL or LBSTRESN). For each variable named in the VAR parameter the 
   macro produces a plot and some summary statistics, both of which are displayed  
   together in a thin horizontal strip. This is not a verbose codebook that tells 
   you everything about each variable. The focus of this codebook is to tell you 
   a little bit about each variable, fitting as many variables on each page as is 
   possible. 
   The plot and statistics vary depending on the type and values of the variable.
   For instance, given a numeric variable with many unique values, the plot will 
   be a histogram and the statistics will include a mean, median, min, max, etc.

Required parameters:
   data=       two-level dataset name
               only one dataset is allowed
               e.g., data=work.fred
   by=         variable list for identifying parameters
               e.g., by=parcat1 parcat2 paramn paramcd param
               extraneous variables will not produce a w@rning
   var=        variable list to summarize
               e.g., var=aval avalc anrlo anrhi atoxn atox               
               extraneous variables will not produce a w@rning
   
Optional parameters:
   pdfpath=    folder in which to save PDF file
               DEFAULT: folder in which dataset lives
   pdfprefix=  prefix for PDF file name
               DEFAULT: no prefix
   dotlength=  length after which text is replaced with 3 dots
               DEFAULT: 20
   maxfreqs=   maximum number of values to show in frequencies
               DEFAULT: 5
   minfreqs=   minimum number of values to avoid frequencies
               DEFAULT: 2
   plotheight= height of plots (inches)
               DEFAULT: 1.0
   uniquepct=  uniqueness percent cutoff for showing frequencies
               DEFAULT: 90
   lowestpct=  lowest allowed percent for showing frequencies
               DEFAULT: 0.5
   catplot=    type of categorical plot: dot or hbar
               DEFAULT: dot
               don't be obtuse, stick with the dot plot
   debug=      set to 1 if you want to keep the work datasets
               DEFAULT: 0
   
Assumptions and artistic decisions:
   Minimum SAS version:
      Many 9.4 features are used. 
   Formats: 
      The macro assumes that all needed formats have already been made 
      accessible either through a LIBNAME statement or the CNTLIN option.
      You will get many nasty messages in the log if you do not load your 
      formats.
   Formatted values: 
      When frequencies are displayed, both unformatted and formatted values 
      will be shown. E.g., 1 = MALE (435, 49.3%), 2 = FEMALE (453, 50.7%).
   Character variables:
      A bar chart and frequencies will be shown if no more than 5 unique values.
      If more than 5 unique values, only the 5 most common will be shown.
      Use parameter MAXFREQS to alter the threshold of 5.
   Numeric variables:
      Many numeric variables will get a histogram and univariate stats.
      However, if the formatted values contain mostly alpha characters, contain 
      any brackets, or have <=2 unique values, then the variable is deemed 
      to be a categorical/factor variable, and hence frequencies will be 
      displayed.
      Use parameter MINFREQS to alter the threshold of 2.
   Long text values: 
      Long text values are truncated after 20 characters (with 3 dots added in 
      place of the truncated characters).
      Use parameter DOTLENGTH to alter the threshold of 20.
   Overrun with unique values:
      The 5 most common are replaced with the 5 lowest and 5 highest values if 
      at least 90 percent of values are unique.
      Use parameter UNIQUEPCT to alter the threshold of 90.
   
Example calls:

   *--- what a call for an ADaM BDS dataset might look like ---;
   %codebook_vertical
      (data=adam.adlb
      ,by=parcat1 parcat2 paramn paramcd param
      ,var=aval avalc chg anrlo anrhi atox atoxn adt atm ady anl01fn
      );
      
--------------------------------------------------------------------------------*/



%macro codebook_vertical
      (data=
      ,by=
      ,var=
      ,pdfpath=
      ,pdfprefix=
      ,dotlength=20
      ,maxfreqs=5
      ,minfreqs=2
      ,plotheight=1.0
      ,uniquepct=90
      ,lowestpct=0.5
      ,catplot=dot
      ,debug=0
      );

   ods listing close;
   
   options minoperator fmterr;
   
   %let tab = %str( );



   %*--------------------------------------------------------------------------------;
   %*---------- helper macros ----------;
   %*--------------------------------------------------------------------------------;
   
   %*---------- trim and write macro variable values to the log ----------;
   
   %macro letput(mvar);
      %if %symexist(&mvar) eq 1 %then %do;
         %let &mvar = &&&mvar;
         %put NOTE- &mvar = [&&&mvar];
      %end;
      %else %put NOTE- Macro variable %upcase(&mvar) does not exist.;
   %mend letput;
   
   %*---------- does variable exist in dataset ----------;
   
   %macro VarExist(data=,var=);
      %local dsid varnum rc;
      %let dsid = %sysfunc(open(&data)); 
      %if &dsid %then %do; 
         %let varnum = %sysfunc(varnum(&dsid,&var));
         %if &varnum %then &varnum; 
         %else 0;
         %let rc = %sysfunc(close(&dsid));
      %end;
      %else 0;
   %mend VarExist;



   %*--------------------------------------------------------------------------------;
   %*---------- verify sas version at least 9.4 ----------;
   %*--------------------------------------------------------------------------------;
   
   %put &=sysver;
   
   %if %sysevalf(&sysver < 9.4) %then %do;

      %put %str(W)ARNING: this macro requires SAS 9.4 or higher.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
   
   %end;
   
   
   
   %*--------------------------------------------------------------------------------;
   %*---------- parse the DATA parameter ----------;
   %*--------------------------------------------------------------------------------;
   
   %if %nrbquote(&data) ne %str() %then %do;
   
      %if %sysfunc(exist(&data)) %then %do;
      
         %global libname memname nobs;
      
         %if %sysfunc(index(&data,.)) eq 0 %then %let data = WORK.&data;
         %let libname = %upcase(%scan(&data,1,.));
         %let memname = %upcase(%scan(&data,2,.));
         %letput(data);
         %letput(libname);
         %letput(memname);
      
         proc sql noprint;
            select   nobs
            into     :nobs
            from     dictionary.tables
            where    libname = "&libname"
                     and memname = "&memname"
            ;
         quit;
         
         %letput(nobs);
      
      %end;
         
      %else %do;
      
         %put %str(W)ARNING: invalid DATA (&data) was specified.;
         %put %str(W)ARNING: macro terminating.;      
         %goto badending;
      
      %end;
   
   %end;

   %else %do;

      %put %str(W)ARNING: parameter DATA is missing.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
   
   %end;
   
   
   
   %*--------------------------------------------------------------------------------;
   %*---------- parse the BY parameter ----------;
   %*--------------------------------------------------------------------------------;
   
   %let goodby = ;
   
   %if %nrbquote(&by) ne %str() %then %do;
   
      %let by = %sysfunc(compbl(&by));
      %let by_n = %eval( %sysfunc(count(&by,%str( ))) + 1 );
      %letput(by);
      %letput(by_n);
   
      %do i = 1 %to &by_n;
      
         %let by&i = %scan(&by,&i,%str( ));
         %letput(by&i);
         
         %if %varexist(data=&data,var=&&by&i) %then %let goodby = &goodby &&by&i;
         %else %put %str(N)OTE: BY variable (&&by&i) is not present.;
      
      %end;
      
      %letput(goodby);
      %let goodbycomma = %sysfunc(translate(&goodby,%str(,),%str( )));
      %letput(goodbycomma);
      
      %if %nrbquote(&goodby) eq %str() %then %do;
      
         %put %str(W)ARNING: no valid BY variables specified.;
         %put %str(W)ARNING: macro terminating.;
         %goto badending;
         
      %end;
      
   %end;
   
   %else %do;
   
      %put %str(W)ARNING: parameter BY is missing.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
      
   %end;
   
   proc sql noprint;
      create   table cbv_goodby as
      select   &goodbycomma, count(*) as obs
      from     &data
      group by &goodbycomma
      ;
   quit;
   
   %let data_n = &sqlobs;
   
   %let goodby_n = %eval( %sysfunc(count(&goodby,%str( ))) + 1 );
   %letput(goodby_n);
   
   %do i = 1 %to &goodby_n;
   
      %let goodby&i = %scan(&goodby,&i,%str( ));
      %letput(goodby&i);

      proc sql noprint;
         select   type, format
         into     :goodbytype&i, :goodbyfmt&i
         from     dictionary.columns
         where    libname = 'WORK'
                  and memname = 'CBV_GOODBY'
                  and upcase(name) = upcase("&&goodby&i")
         ;
      quit;
      
      %letput(goodbytype&i);
      %letput(goodbyfmt&i);
      
   %end;
   
   
   
   %*--------------------------------------------------------------------------------;
   %*---------- parse the VAR parameter ----------;
   %*--------------------------------------------------------------------------------;
   
   %let goodvar = ;
   
   %if %nrbquote(&var) ne %str() %then %do;
   
      %let var = %sysfunc(compbl(&var));
      %let var_n = %eval( %sysfunc(count(&var,%str( ))) + 1 );
      %letput(var);
      %letput(var_n);
   
      %do i = 1 %to &var_n;
      
         %let var&i = %scan(&var,&i,%str( ));
         %letput(var&i);
         
         %if %varexist(data=&data,var=&&var&i) %then %let goodvar = &goodvar &&var&i;
         %else %put %str(N)OTE: VAR variable (&&var&i) is not present.;
      
      %end;
      
      %letput(goodvar);
      %let goodvarcomma = %sysfunc(translate(&goodvar,%str(,),%str( )));
      %letput(goodvarcomma);
      
      %if %nrbquote(&goodvar) eq %str() %then %do;
      
         %put %str(W)ARNING: no valid VAR variables specified.;
         %put %str(W)ARNING: macro terminating.;
         %goto badending;
         
      %end;
      
   %end;
   
   %else %do;
   
      %put %str(W)ARNING: parameter VAR is missing.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
      
   %end;
   
   %let goodvar_n = %eval( %sysfunc(count(&goodvar,%str( ))) + 1 );
   %letput(goodvar_n);
   
   %do i = 1 %to &goodvar_n;
   
      %let goodvar&i = %scan(&goodvar,&i,%str( ));
      %letput(goodvar&i);
   
   %end;

   

   %*--------------------------------------------------------------------------------;
   %*---------- check the ODS PDF 999 limit ----------;
   %*--------------------------------------------------------------------------------;
   
   %let images = %sysevalf(&data_n * &goodvar_n);
   
   %if &images > 999 %then %do;
   
      %put %str(W)ARNING: The current dataset has &data_n unique BY= combinations. With &goodvar_n ;
      %put %str(W)ARNING: variables specified in VAR=, this yields &images total images, which ;
      %put %str(W)ARNING: exceeds the ODS PDF limit of 999 images (see SAS note 18258).;
      %put %str(W)ARNING: Split your dataset and try again.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
      
   %end;
   
   
      
   %*--------------------------------------------------------------------------------;
   %*---------- pdfpath fallback ----------;
   %*--------------------------------------------------------------------------------;
   
   %if %nrbquote(&pdfpath) eq %str() %then %do;
      %let pdfpath = %sysfunc(pathname(&libname));
      %if %upcase(&libname) eq WORK %then %do;
         %put %str(W)ARNING: no PDFPATH specified for dataset &data..;
         %put %str(W)ARNING: PDF will be stored in the highly temporary WORK folder.;
      %end;
   %end;
   %letput(pdfpath);



   %*--------------------------------------------------------------------------------;
   %*---------- pdfname ----------;
   %*--------------------------------------------------------------------------------;
   
   %let pdfname = &data._vert;
   %if %nrbquote(&pdfprefix) ne %str() %then %let pdfname = &pdfprefix._&pdfname;
   %letput(pdfname);



   %*--------------------------------------------------------------------------------;
   %*---------- style modifications ----------;
   %*--------------------------------------------------------------------------------;

   proc template;
      define style mystyle;
         parent = styles.pearl;
         style Table from Output /
            rules = none
            frame = void
            cellpadding = 1pt
            ;
         class TitlesAndFooters /
            font_weight = medium
            font_size = 2
            ;
      end;
   run;



   %*--------------------------------------------------------------------------------;
   %*---------- pre-ods statements ----------;
   %*--------------------------------------------------------------------------------;
   
   %let dtm = %sysfunc(putn(%sysfunc(datetime()),E8601DT.));
   %letput(dtm);
   
   options nodate nonumber;

   %macro tfoot;
   
      title1 
         j=l "~S={cellwidth=6.5in}Abbr. vert. codebook for %upcase(&data) (&nobs obs)" 
         /*j=r 'Page ~{thispage} of ~{lastpage}'*/
         j=r 'Page ~{thispage}'
         ;
      footnote1
         j=l "Shortened text strings are denoted by three dots (...)."
         ;
      footnote2
         j=l "~S={cellwidth=6.5in}&pdfpath" 
         j=r "&dtm"
         ;
         
   %mend tfoot;



   %*--------------------------------------------------------------------------------;
   %*---------- start pdf creation ----------;
   %*--------------------------------------------------------------------------------;
   
   ods escapechar='~';
   ods listing gpath="%sysfunc(pathname(work))";
   ods pdf file="&pdfpath\&pdfname..pdf" style=mystyle bookmarkgen=no;



      %*--------------------------------------------------------------------------------;
      %*---------- summary of good by levels ----------;
      %*--------------------------------------------------------------------------------;
      
      %tfoot
      title2 "Summary of BY= value combinations found in this dataset";
      
      proc print data=cbv_goodby noobs;
      run;
      
      title2;
      
      ods pdf startpage=now;
   


      %*--------------------------------------------------------------------------------;
      %*---------- cycle over good by levels ----------;
      %*--------------------------------------------------------------------------------;
   
      %do d = 1 %to &data_n;
      
         %put -------------------------------------------------------------------------------------;
         %put -------------------------------------------------------------------------------------;
         %put -------------------------------------------------------------------------------------;
         %put &=d;
         %put &=d;
         %put &=d;
         %put -------------------------------------------------------------------------------------;
         %put -------------------------------------------------------------------------------------;
         %put -------------------------------------------------------------------------------------;
         
         %let data&d = CB_GBDATA&d;
         %let libname&d = WORK;
         %let memname&d = CB_GBDATA&d;
         
         %*---------- put GOODBY values into macro variables ----------;
         
         data _null_;
            set cbv_goodby;
            if _N_ eq &d;
            %do g = 1 %to &goodby_n;
               call symputx("goodbyval&g",&&goodby&g);
            %end;
         run;
         
         %do g = 1 %to &goodby_n;
            %letput(goodby&g);
            %letput(goodbyval&g);
         %end;
         
         %*---------- create one dataset per GOODBY row ----------;
         
         proc sql noprint;
            create   table cb_gbdata&d as
            select   &goodvarcomma
            from     &data
            where    %if &goodbytype1 eq char %then &goodby1 = "&goodbyval1";
                     %else &goodby1 = &goodbyval1;
                     %if &goodby_n > 1 %then %do g = 2 %to &goodby_n;
                        %if &&goodbytype&g eq char %then and &&goodby&g = "&&goodbyval&g";
                        %else and &&goodby&g = &&goodbyval&g;
                     %end;
            ;
         quit;
   
         data _w_&&memname&d;
            set &&data&d;
         run;
         
         %*---------- create spanning header ----------;
         
         data _null_;
            length span $2000;
            span = trim(upcase("&goodby1")) || ': ' || trim("&goodbyval1");
            %if &goodbyfmt1 ne %str() %then %do;
               %if &goodbytype1 = num %then
                  span = trim(span) || ' = ' || put(&goodbyval1,&goodbyfmt1);
               %else
                  span = trim(span) || ' = ' || put("&goodbyval1",&goodbyfmt1);
               ;
            %end;
            %if &goodby_n > 1 %then %do g = 2 %to &goodby_n;
               span = trim(span) || ';  ' || trim(upcase("&&goodby&g")) || ': ' || trim("&&goodbyval&g");
               %if &&goodbyfmt&g ne %str() %then %do;
                  %if &&goodbytype&g = num %then 
                     span = trim(span) || ' = ' || put(&&goodbyval&g,&&goodbyfmt&g);
                  %else
                     span = trim(span) || ' = ' || put("&&goodbyval&g",&&goodbyfmt&g);
                  ;
               %end;;
            %end;
            call symputx("span&d",span);
         run;
         
         %letput(span&d);
         
         %*---------- get variables set up for processing ----------;
         
         %cb_varsetup;   
         
         %*---------- calculate stats for each variable ----------;
         
         %cb_calcstats;
            
         %*---------- generate codebook ----------;
         
         %cbv_makepdf;
         
         %*---------- page break ----------;
         
         %if &d < &data_n %then ods pdf startpage=now; ;
      
      %end;

   ods pdf close;



   %*--------------------------------------------------------------------------------;
   %*---------- clean up, perhaps ----------;
   %*--------------------------------------------------------------------------------;

   %if &debug ne 1 %then %do;   

      proc datasets library=work;
         delete 
            cbv_: 
            _doctmp:
            ;
      run; quit;
   
   %end;



   %*--------------------------------------------------------------------------------;
   %*---------- if bad ending... ----------;
   %*--------------------------------------------------------------------------------;
   
   %badending:


%mend codebook_vertical;