/*--------------------------------------------------------------------------------
Generic abbreviated codebook macro, Shane Rosanbalm, Rho, Inc., 2016

Description:
   This macro produces an abbreviated PDF summary of a dataset. For each variable
   in the dataset the macro produces a plot and some summary statistics, both of
   which are displayed together in a thin horizontal strip. This is not a verbose
   codebook that tells you everything about each variable. The focus of this
   codebook is to tell you a little bit about each variable, fitting as many
   variables on each page as is possible. 
   The plot and statistics vary depending on the type and values of the variable.
   For instance, given a numeric variable with many unique values, the plot will 
   be a histogram and the statistics will include a mean, median, min, max, etc.

Required parameters:
   data=       two-level dataset names
               use spaces to separated if multiple 
               e.g., data=work.fred sdtm.george adam.charlie
   -OR-
   library=    library to process
               if specified, data= will be ignored
   
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
   appendix=   include appendix of all formatted values: yes or no
               DEFAULT: no
   maxappx=    maximum number of unique values a variable can have and still 
               be allowed to show up in the appendix 
               DEFAULT: 20
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

   *--- create one PDF, in the same folder as the dataset ---;
   %codebook_generic
      (data=level2.dm
      ,maxfreqs=7
      );
      
   *--- create many PDFs, not stored with the datasets ---;
   %codebook_generic
      (library=level2
      ,pdfpath=H:\mystudy\level2\codebooks
      ,pdfprefix=mybook
      ,dotlength=15
      );
      
--------------------------------------------------------------------------------*/


*--------------------------------------------------------------------------------;
*--------------------------------------------------------------------------------;
*---------- Possible future enhancements... ----------;
*---------- add appendix of all figures (order=pdv) ----------;
*---------- add appendix of all decodes (order=alpha, full length) ----------;
*--------------------------------------------------------------------------------;
*--------------------------------------------------------------------------------;



%macro codebook_generic
      (data=
      ,library=
      ,pdfpath=
      ,pdfprefix=
      ,dotlength=20
      ,maxfreqs=5
      ,minfreqs=2
      ,plotheight=1.0
      ,uniquepct=90
      ,lowestpct=0.5
      ,catplot=dot
      ,appendix=no
      ,maxappx=20
      ,debug=0
      );

   options minoperator fmterr;
   
   %let tab = %str( );



   %*--------------------------------------------------------------------------------;
   %*---------- helper macros ----------;
   %*--------------------------------------------------------------------------------;
   
   %*---------- trim and write macro variable values to the log ----------;
   
   %macro letput(mvar);
      %let op_mprint = %sysfunc(getoption(mprint));
      %if &op_mprint = MPRINT %then
         options nomprint;
         ;
      %let op_notes = %sysfunc(getoption(notes));
      %if &op_notes = NOTES %then 
         options nonotes nomprint;
         ;
      %if %symexist(&mvar) eq 1 %then %do;
         data _null_;
            mvar = strip("&&&mvar");
            call symputx("&mvar",mvar);
         run;
         options notes;
         %put NOTE- &mvar = [%nrbquote(&&&mvar)];
      %end;
      %else %do;
         options notes;
         %put NOTE- Macro variable %upcase(&mvar) does not exist.;
      %end;
      options &op_mprint &op_notes;
   %mend letput;

   %macro titlefootnote;
      title1 
         j=l "~S={cellwidth=6.5in}Abbr. codebook for %upcase(&&data&d) (&varlist_n vars, &&nobs&d obs)" 
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
   %mend titlefootnote;
   


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
   %*---------- determine list of datasets to process ----------;
   %*--------------------------------------------------------------------------------;
   
   %*---------- if LIBRARY specified, get all datasets therein ----------;
   
   %if %nrbquote(&library) ne %str() %then %do;
   
      %if %nrbquote(%sysfunc(pathname(&library))) ne %str() %then %do;
   
         %if %nrbquote(&data) ne %str() %then 
            %put %str(W)ARNING: because parameter LIBRARY was specified, parameter DATA will be ignored.;
   
         proc sql noprint;
            select   memname
            into     :member1-
            from     dictionary.tables
            where    libname = upcase("&library")
            ;
         quit;
   
         %global data_n;
         %let data_n = &sqlobs;
         %letput(data_n);
   
         %do i = 1 %to &data_n;
         
            %global data&i;
            %let data&i = &library..&&member&i;
            %letput(data&i);
            
         %end;
         
      %end;
      
      %else %do;

         %put %str(W)ARNING: invalid LIBRARY (&library) was specified.;      
         %put %str(W)ARNING: macro terminating.;      
         %goto badending;
      
      %end;

   %end;
   
   %*---------- otherwise, parse the DATA parameter ----------;
   
   %else %if %nrbquote(&data) ne %str() %then %do;
   
      %let data = %sysfunc(compbl(&data));
      %letput(data);
      
      %global data_n;
      %let data_n = %eval( %sysfunc(count(&data,%str( ))) + 1 );
      %letput(data_n);
      
      %do i = 1 %to &data_n;
      
         %global data&i;
         %let data&i = %scan(&data,&i,%str( ));
         %letput(data&i);
         
         %if not %sysfunc(exist(&&data&i)) %then %do;
         
            %put %str(W)ARNING: invalid DATA (&&data&i) was specified.;
            %put %str(W)ARNING: macro terminating.;      
            %goto badending;
         
         %end;
      
      %end;
   
   %end;

   %*---------- or maybe they made a really bad call ----------;
   
   %else %do;

      %put %str(W)ARNING: parameters LIBRARY and DATA both missing.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
   
   %end;



   %*--------------------------------------------------------------------------------;
   %*---------- cycle over datasets ----------;
   %*--------------------------------------------------------------------------------;
   
   %do d = 1 %to &data_n;

      %*---------- find dataset and establish PDF path ----------;
      
      %cb_prelims;
   
      %*---------- get variables set up for processing ----------;
      
      %cb_varsetup;   
      
      %*---------- calculate stats for each variable ----------;
      
      %cb_calcstats;
         
      %*---------- generate codebook ----------;
      
      %cb_makepdf;
   
   %end;



   %*--------------------------------------------------------------------------------;
   %*---------- if bad ending... ----------;
   %*--------------------------------------------------------------------------------;
   
   %badending:


%mend codebook_generic;