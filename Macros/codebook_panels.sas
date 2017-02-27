/*--------------------------------------------------------------------------------
Abbreviated paneled codebook macro, Shane Rosanbalm, Rho, Inc., 2016

Description:
   This macro produces an abbreviated PDF summary of a dataset, with separate 
   panels for each BY level. For each variable named in the dataset the 
   macro produces a plot which is paneled according to the BY parameter. 
   The plot vary depending on the type and values of the variable. For instance, 
   given a numeric variable with many unique values, the plot will be a 
   histogram.

Required parameters:
   data=       two-level dataset names
               use spaces to separated if multiple 
               e.g., data=work.fred sdtm.george adam.charlie
   - OR -      
   library=    library to process
               if specified, data= will be ignored
               
   panelby=    variable by which to panel
   
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
   uniquepct=  uniqueness percent cutoff for showing frequencies
               DEFAULT: 90
   lowestpct=  lowest allowed percent for showing frequencies
               DEFAULT: 0.5
   maxcolumns= maximum number of columns in each panel graph
               DEFAULT: 7
   mincolumns= minimum number of columns in each panel graph
               DEFAULT: 4
   allnum=     numeric value for the ALL level of the BY parameter
               DEFAULT: -99
   allchar=    character value for the ALL level of the BY parameter
               DEFAULT: !ALL!
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
      ???When frequencies are displayed, both unformatted and formatted values 
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
      The 5 most common are omitted if at least 90 percent of values are 
      unique.
      Use parameter UNIQUEPCT to alter the threshold of 90.
   
Example calls:

   *--- what a call for an adsl dataset might look like ---;
   %codebook_panels
      (data=adam.adsl
      ,panelby=siteid
      );
      
--------------------------------------------------------------------------------*/


*--------------------------------------------------------------------------------;
*--------------------------------------------------------------------------------;
*---------- TO DO... ----------;
*---------- have a list of dropped variables due to uniqueness ----------;
*--------------------------------------------------------------------------------;
*--------------------------------------------------------------------------------;



%macro codebook_panels
      (data=
      ,library=
      ,panelby=
      ,pdfpath=
      ,pdfprefix=
      ,dotlength=20
      ,maxfreqs=5
      ,minfreqs=2
      ,uniquepct=90
      ,lowestpct=0.5
      ,maxcolumns=7
      ,mincolumns=4
      ,allnum=-99
      ,allchar=!ALL!
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
   %*---------- parse the BY parameter ----------;
   %*--------------------------------------------------------------------------------;
   
   %if %nrbquote(&panelby) ne %str() %then %do;
   
      %if %varexist(data=&data,var=&panelby) eq 0 %then %do;
      
         %put %str(W)ARNING: PANELBY variable (&panelby) is not in dataset.;
         %put %str(W)ARNING: macro terminating.;
         %goto badending;
         
      %end;
      
   %end;
   
   %else %do;
   
      %put %str(W)ARNING: parameter BY is missing.;
      %put %str(W)ARNING: macro terminating.;
      %goto badending;
      
   %end;
   
   
   
   %*--------------------------------------------------------------------------------;
   %*---------- cycle over datasets ----------;
   %*--------------------------------------------------------------------------------;
   
   %do d = 1 %to &data_n;

      %*---------- find dataset and establish PDF path ----------;
      
      %cbp_prelims;
   
      %*---------- get variables set up for processing ----------;
      
      %cb_varsetup;   
      
      %*---------- calculate stats for each variable ----------;
      
      %cb_calcstats;
         
      %*---------- generate codebook ----------;
      
      %cbp_makepdf;
   
   %end;



   %*--------------------------------------------------------------------------------;
   %*---------- if bad ending... ----------;
   %*--------------------------------------------------------------------------------;
   
   %badending:


%mend codebook_panels;