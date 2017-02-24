%macro cb_makerow(calledby);


   %put NOTE- ---------------------------------------------------------------;
   %letput(i);
   %let i = %unquote(&i);
   %letput(name&i);
   %let name&i = %unquote(&&name&i);
            


   %*--------------------------------------------------------------------------------;
   %*---------- plot ----------;
   %*--------------------------------------------------------------------------------;

   %if &calledby = cb_makepdf %then ods region row=%eval(&i) column=1;;
   %if &calledby = cbv_makepdf %then ods region row=%eval(&i+1) column=1;;

      title1;
      footnote1;

      ods graphics / height=&plotheight.in width=2.0in noborder;

      %if &&anly&i = freqnone %then %do;
      
         %cb_alttext(All values are missing,for this variable.);
         
      %end;
         
      %else %if &&anly&i = means %then %do;

         proc template;
            define statgraph hist;
            begingraph;
               symbolchar name=vertbar char='2758'x;
               layout lattice / rowweights=(0.80 0.20) columndatarange=union;
                  columnaxes;
                     columnaxis / display=(ticks tickvalues)
                        %if &&istime&i eq 1 %then 
                           type=time timeopts=(interval=hour tickvalueformat=hhmm5.)
                           ;
                        %else %if &&isinteger&i eq 1 %then 
                           linearopts=(integer=true) 
                           ;
                        ;
                  endcolumnaxes;
                  layout overlay / 
                        yaxisopts=(
                           linearopts=(tickvalueformat=percent.)
                           display=(ticks tickvalues)
                           );
                     histogram &&name&i / 
                        scale=proportion
                        binaxis=false 
                        fillattrs=(color=lightgray)
                        ;
                  endlayout;
                  layout overlay;
                     boxplot y=&&name&i / 
                        orient=horizontal
                        boxwidth=0.9
                        fillattrs=(color=lightgray) 
                        whiskerattrs=(color=black) 
                        meanattrs=(color=black)
                        outlierattrs=(symbol=vertbar)
                        display=(CAPS FILL MEDIAN OUTLIERS)
                        ;
                  endlayout;
               endlayout;
            endgraph;
            end;
         run;

         proc sgrender data=_w_&&memname&d template=hist;
         run;

      %end;
      
      %else %if &&anly&i = freqall %then %do;
      
         %if &&distinct&i = 1 %then %do;
         
            %cb_alttext(Only one unique value.,No graphic will be produced.);
         
         %end;
         
         %else %do;

            proc sgplot data=cb_fmt_&&memname&d
                  (where=(compress(cb_fmt_sh_&&short&i) not in (' ' '.' '...')))
                  ;
               &catplot cb_fmt_sh_&&short&i /
                  stat=percent
                  categoryorder=respdesc 
                  %if %upcase(&catplot) = DOT %then %do;
                     filledoutlinedmarkers 
                     markeroutlineattrs=(color=black)
                     markerfillattrs=(color=lightgray)
                  %end;
                  %else %if %upcase(&catplot) = HBAR %then %do;
                     fillattrs=(color=lightgray)
                  %end;
                  ;
               yaxis display=(nolabel) 
                  %if &&distinct&i = 2 %then 
                     offsetmin = 0.35 offsetmax = 0.35 
                     ;
                  %else %if &&distinct&i = 3 %then 
                     offsetmin = 0.25 offsetmax = 0.25 
                     ;
                  %else %if &&distinct&i = 4 %then 
                     offsetmin = 0.15 offsetmax = 0.15 
                     ;
                  ;
               xaxis display=(nolabel) min=0;
            run;
            
         %end;
         
      %end;

      %else %if &&anly&i = freqsome %then %do;

         %if &&toounique&i = 1 or &&toolow&i = 1 %then %do;

            %cb_alttext(Too many unique values.,No graphic will be produced.);

         %end;

         %else %do;

            %*---------- use percent format, with decimals if max is small enough ----------;
            
            data _null_;
               set cb_most&i;
               if _N_ = 1 then do;
                  call symputx('maxprop',proportion);
                  if proportion < 0.04 then call symputx('valuesformat','percent10.2');
                  else call symputx('valuesformat','percent.');
               end;
            run;
            
            proc sgplot data=cb_most&i;
               &catplot cb_fmt_sh_&&short&i / 
                  response=proportion 
                  categoryorder=respdesc  
                  %if %upcase(&catplot) = DOT %then %do;
                     filledoutlinedmarkers 
                     markeroutlineattrs=(color=black)
                     markerfillattrs=(color=lightgray)
                  %end;
                  %else %if %upcase(&catplot) = HBAR %then %do;
                     fillattrs=(color=lightgray)
                  %end;
                  ;
               yaxis 
                  display=(nolabel)
                  ;
               xaxis 
                  display=(nolabel) 
                  min=0 
                  valuesformat=&valuesformat
                  ;
            run;
            
         %end;

      %end;

      %else %do;
      
         %cb_alttext(- - - - - under - - - - -,- - - - - construction - - - - -);
      
      %end;



   %*--------------------------------------------------------------------------------;
   %*---------- summary stats ----------;
   %*--------------------------------------------------------------------------------;

   %if &calledby = cb_makepdf %then ods region row=%eval(&i) column=2 style=[just=left];;
   %if &calledby = cbv_makepdf %then ods region row=%eval(&i+1) column=2 style=[just=left];;

      %let header = %lowcase(&&name&i):  %nrbquote(&&label&i)  {type=&&type&i;
      %if %nrbquote(&&format&i) ne %str() %then %let header = %nrbquote(&header), fmt=&&format&i};
      %else %let header = %nrbquote(&header)};
      %letput(header);

      proc odstext;
         p "&header" / style=[fontsize=10pt fontweight=bold];
         p "n=&&N&i, missing=&&Missing&i, unique=&&Unique&i";
      run;
      
      %if &&anly&i = freqnone %then %do;
      
         *--- do nothing ---;
      
      %end;
      
      %else %if &&anly&i = means %then %do;
      
         proc odstext;
            p "&&stats1_&i";
            p "&&stats2_&i";
         run;
         
      %end;
      
      %else %if &&anly&i = freqall %then %do;

         proc odstext;
            p "Frequencies: &&freqall&i";
         run;

      %end;

      %else %if &&anly&i = freqsome %then %do;

         proc odstext;
            %if &&toounique&i eq 1 or &&toolow&i = 1 %then %do;
               p "First &maxfreqs: &&lowest&i";
               p "Last &maxfreqs: &&highest&i";
            %end;
            %else %do;
               p "Frequencies (top &maxfreqs only): &&most&i";
            %end;
         run;

      %end;

      %else %do;
      
         proc odstext;
            p "- - - - - - - - - - under construction - - - - - - - - - -";
         run;
      
      %end;


%mend cb_makerow;