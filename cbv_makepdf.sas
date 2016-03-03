%macro cbv_makepdf;



   %tfoot
   
   %*--------------------------------------------------------------------------------;
   %*---------- create gridded layout ----------;
   %*--------------------------------------------------------------------------------;
   
   ods layout gridded 
      rows=%eval(&varlist_n+1)
      columns=2 
      column_widths=(2.0in 5.75in) 
      column_gutter=0.2in
      row_gutter=0.05in
      ;
      
      ods region row=1 column_span = 2;
      
         proc odstext;
            p "&&span&d" / style=[fontsize=12pt fontweight=bold];
         run;

      %do i = 1 %to &varlist_n;

         %cb_makerow(cbv_makepdf);
         
      %end;

   ods layout end;


   
   %*--------------------------------------------------------------------------------;
   %*---------- clean up, perhaps ----------;
   %*--------------------------------------------------------------------------------;

   %if &debug ne 1 %then %do;   

      ods exclude directory members;
      proc datasets library=work;
         delete 
            cb_: 
            _doctmp:
            ;
      run; quit;
   
   %end;


%mend cbv_makepdf;