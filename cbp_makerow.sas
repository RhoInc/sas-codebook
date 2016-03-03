%macro cbp_makerow;


   %put NOTE- ---------------------------------------------------------------;
   %letput(i);
   %letput(name&i);
            
            
            
   %*--------------------------------------------------------------------------------;
   %*---------- determine height of plots ----------;
   %*--------------------------------------------------------------------------------;
   
   proc sql noprint;
      select   count(distinct &panelby)
      into     :panelby_n
      from     _w_&&memname&d
      %if &panelbytype = char %then 
         where &panelby ne "&allchar"
         ;
      %else 
         where &panelby ne &allnum
         ;
      ;
   quit;
   
   %letput(panelby_n);
   
   %global histheight catheight;
   
   data cbp_macvars;
      top = 0.25;
      bottom = 0.25;
      histrowheight = 0.9;
      catrows = min(&&distinct&i,&maxfreqs);
      catrowheight = 0.1 * (2.1*&maxfreqs - 1);
      by_n = &panelby_n;
      if &&panels&d <= &maxcolumns then do;
         rows = 1;
         columns = max(&mincolumns,&&panels&d);
      end;
      else if &maxcolumns < &&panels&d then do;
         rows = ceil(&&panels&d / &maxcolumns);
         columns = ceil(&&panels&d / rows);
      end;
      histheight = round(top + bottom + (histrowheight * rows), 0.001);
      histheight = min(histheight,9.5);
      catheight = round(top + bottom + (catrowheight * rows), 0.001);
      catheight = min(catheight,9.5);
      call symputx('rows',rows);
      call symputx('columns',columns);
      call symputx('histheight',histheight);
      call symputx('catheight',catheight);
   run;
   
   %letput(rows);
   %letput(columns);
   %letput(histheight);
   %letput(catheight);



   %*--------------------------------------------------------------------------------;
   %*---------- column 1 ----------;
   %*--------------------------------------------------------------------------------;
   
   ods region row=&i column=1;
   
      proc odstext;
         p " ";
      run;
   
      %if &&anly&i = means %then %do;
   
         ods graphics / height=1in width=2in noborder;
         
         proc sgplot data=_w_&&memname&d;
            title1 "&&name&i, All data";
            footnote1;
            %if &panelbytype = char %then
               where &panelby eq "&allchar"
               ;
            %else 
               where &panelby eq &allnum
               ;
            ;
            histogram &&name&i /
               scale=count
               fillattrs=(color=lightgray)               
               ;
            yaxis display=(nolabel);
            xaxis display=(nolabel);
         run;
         
      %end;
      
      %else %if &&anly&i = freqall %then %do;
      
         ods graphics / height=1in width=2in noborder;
         
         proc sgplot data=cb_fmt_&&memname&d;
            title1 "&&name&i, All data";
            footnote1;
            %if &panelbytype = char %then 
               where &panelby eq "&allchar"
               ;
            %else
               where &panelby eq &allnum
               ;
            ;
            where also compress(cb_fmt_sh_&&name&i) not in (' ' '.' '...');
            hbar cb_fmt_sh_&&name&i /
               stat=freq
               categoryorder=respdesc
                  fillattrs=(color=lightgray)
                  ;
               ;
            yaxis display=(nolabel);
            xaxis display=(nolabel) min=0;
         run;
            
      %end;
   
      %else %if &&anly&i = freqsome %then %do;
   
         %if &&toounique&i = 1 or &&toolow&i = 1 %then %do;
   
            %*--- leave this region empty ---; 
            
         %end;
   
         %else %do;
   
            ods graphics / height=1in width=2in noborder;
            
            proc sgplot data=cb_most&i;
               title1 "&&name&i, Top 5";
               footnote1;
               where also compress(cb_fmt_sh_&&name&i) not in (' ' '.' '...');
               hbar cb_fmt_sh_&&name&i / 
                  response=frequency
                  categoryorder=respdesc  
                  fillattrs=(color=lightgray)
                  ;
               yaxis 
                  display=(nolabel)
                  ;
               xaxis 
                  display=(nolabel) 
                  min=0 
                  ;
            run;
            
         %end;
   
      %end;

   
   
   %*--------------------------------------------------------------------------------;
   %*---------- column 2 ----------;
   %*--------------------------------------------------------------------------------;
   
   ods region row=&i column=2;

      %if &&anly&i = means %then %do;
   
         ods graphics / height=&histheight.in width=5.75in noborder;
         
         proc sgpanel data=_w_&&memname&d;
            title1 j=l "&&name&i: &&label&i";
            footnote1;
            panelby &panelby / 
               columns=&columns novarname onepanel uniscale=all skipemptycells
               ;
            %if &panelbytype = char %then
               where &panelby ne "&allchar"
               ;
            %else
               where &panelby ne &allnum
               ;
            ;
            histogram &&name&i /
               scale=count
               fillattrs=(color=lightgray)
               ;
            rowaxis display=(nolabel);
            colaxis display=(nolabel);
         run;
         
      %end;
      
      %else %if &&anly&i = freqall or &&anly&i = freqsome %then %do;
         
         %if &&toounique&i = 1 or &&toolow&i = 1 %then %do;
   
            ods graphics / height=&catheight.in width=5.75in noborder;
            
            %cb_alttext(Too many unique values for &&name&i.,No graphic will be produced.);
   
         %end;
   
         %else %do;
   
            %*--------------------------------------------------------------------------------;
            %*---------- put categories in RESPASC order overall (not based on row) ----------;
            %*--------------------------------------------------------------------------------;
            
            proc sql;
               *--- counts within panel and category ---;
               create   table cb_respdesc00_&i as
               select   &panelby, cb_fmt_sh_&&name&i, count(*) as cb_respdesc
               from     cb_fmt_&&memname&d
               group by &panelby, cb_fmt_sh_&&name&i
               ;
               *--- select overall counts ---;
               create   table cb_respdesc10_&i as
               select   cb_fmt_sh_&&name&i, cb_respdesc
               from     cb_respdesc00_&i
               %if &panelbytype = char %then
                  where &panelby eq "&allchar"
                  ;
               %else
                  where &panelby eq &allnum
                  ;
               order by cb_respdesc desc, cb_fmt_sh_&&name&i
               ;
               *--- rank overall counts ---;
               create   table cb_respdesc15_&i as
               select   cb_fmt_sh_&&name&i, cb_respdesc, monotonic() as cb_respdesc_order
               from     cb_respdesc10_&i
               ;
               *--- all panels levels ---;
               create   table cb_shell00_&i as
               select   distinct &panelby
               from     cb_respdesc00_&i
               ;
               *--- all panel by category combinations ---;
               create   table cb_shell10_&i as
               select   a.&panelby, b.cb_respdesc_order, cb_fmt_sh_&&name&i
               from     cb_shell00_&i as a, cb_respdesc15_&i as b
               where    cb_respdesc_order <= &maxfreqs
               order by &panelby, cb_respdesc_order, cb_fmt_sh_&&name&i
               ;
               *--- merge counts onto shell ---;
               create   table cb_respdesc20_&i as
               select   a.*, max(b.cb_respdesc,0) as cb_respdesc_final
               from     cb_shell10_&i as a
                        left join cb_respdesc00_&i as b
                        on a.&panelby = b.&panelby
                           and a.cb_fmt_sh_&&name&i = b.cb_fmt_sh_&&name&i
               order by &panelby, cb_respdesc_order, cb_fmt_sh_&&name&i
               ;
            quit;
            
            ods graphics / height=&catheight.in width=5.75in noborder;
            
            proc sgpanel data=cb_respdesc20_&i;
               title1 j=l "&&name&i: &&label&i";
               footnote1;
               panelby &panelby / 
                  columns=&columns novarname onepanel uniscale=all skipemptycells
                  ;
               %if &panelbytype = char %then
                  where &panelby ne "&allchar"
                  ;
               %else
                  where &panelby ne &allnum
                  ;
               ;
               where also compress(cb_fmt_sh_&&name&i) not in (' ' '.' '...');
               hbarparm category=cb_fmt_sh_&&name&i response=cb_respdesc_final /
                  fillattrs=(color=lightgray)
                  ;
               rowaxis 
                  display=(nolabel)
                  discreteorder=data
                  valueattrs=(size=6pt)
                  ;
               colaxis display=(nolabel);
            run;
               
         %end;
        
      %end;
   
      %else %if &&anly&i ne freqnone %then %do;
      
         ods graphics / height=&histheight.in width=5.75in noborder;
            
         %cb_alttext(- - - - - under - - - - -,- - - - - construction - - - - -);
      
      %end;


%mend cbp_makerow;