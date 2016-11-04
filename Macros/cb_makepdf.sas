%macro cb_makepdf;



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

   %titlefootnote;
   
   

   %*--------------------------------------------------------------------------------;
   %*---------- and now the ods begins ----------;
   %*--------------------------------------------------------------------------------;
   
   ods escapechar='~';
   ods listing close;
   ods pdf file="&pdfpath\&&pdfname&d...pdf" style=mystyle bookmarkgen=no;

      ods layout gridded 
         rows=&varlist_n 
         columns=2 
         column_widths=(2.0in 5.75in) 
         column_gutter=0.2in
         row_gutter=0.05in
         ;

         %do i = 1 %to &varlist_n;

            %cb_makerow(cb_makepdf);
            
         %end;

      ods layout end;
      
      %if &appendix = yes %then %do;
      
         %cb_makeappx;
      
      %end;

   ods pdf close;
   ods listing;


   
   %*--------------------------------------------------------------------------------;
   %*---------- clean up, perhaps ----------;
   %*--------------------------------------------------------------------------------;

   %if &debug ne 1 %then %do;   
   
      proc datasets library=work;
         delete 
            cb_: 
            _doctmp:
            _w_:
            ;
      run; quit;
   
   %end;


%mend cb_makepdf;