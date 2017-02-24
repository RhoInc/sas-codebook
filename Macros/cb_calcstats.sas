%macro cb_calcstats;



   %*--------------------------------------------------------------------------------;
   %*---------- calculate summary stats for each variable ----------;
   %*--------------------------------------------------------------------------------;

   %do i = 1 %to &varlist_n;

      %put -------------------------------------------------------------------------------------;
      %letput(name&i);
      %let i = %unquote(&i);
      %put -------------------------------------------------------------------------------------;



      %*--------------------------------------------------------------------------------;
      %*---------- always do N, Missing, Unique ----------;
      %*--------------------------------------------------------------------------------;

      %global N&i Missing&i Unique&i;
      
      proc sql noprint;
         select   n(&&name&i), nmiss(&&name&i), n(distinct &&name&i)
         into     :N&i, :Missing&i, :Unique&i
         from     _w_&&memname&d
         ;
      quit;

      %letput(N&i);
      %letput(Missing&i);
      %letput(Unique&i);
      %letput(panelby);



      %*--------------------------------------------------------------------------------;
      %*---------- calculate percent unique, possibly suppressing if too high ----------;
      %*--------------------------------------------------------------------------------;
      
      %global toounique&i;
      
      data _null_;
         uniquepct = 100 * &&Unique&i / &&N&i;
         if "&&anly&i" = "freqsome" and uniquepct > &uniquepct then 
            toounique = 1;
         else toounique = 0;
         call symputx("toounique&i",toounique);
      run;

      %letput(toounique&i);



      %*--------------------------------------------------------------------------------;
      %*---------- prepare for toolow calculation ----------;
      %*--------------------------------------------------------------------------------;
      
      %global toolow&i;
      
      %let toolow&i = 0;



      %*--------------------------------------------------------------------------------;
      %*---------- means case is straightforward, though longish ----------;
      %*--------------------------------------------------------------------------------;

      %if &&anly&i = means %then %do;

         %*---------- basic stats calculated ----------;
         
         ods exclude summary;
         ods output summary=cb_means&i;
         proc means data=_w_&&memname&d mean stddev min q1 median q3 max;
            var &&name&i;
            %if %symexist(panelby) %then %do;
               %if &panelbytype = char %then
                  where &panelby ne "&allchar" ;
               %else
                  where &panelby ne &allnum ;
               ;
            %end;
         run;

         %*---------- determine precision via min/max ----------;
         
         %let name&i = %unquote(&&name&i);
         
         data _null_;
            set cb_means&i;
            _min = put(&&name&i.._min,best.);
            if index(_min,'.') then _minprec = length(scan(_min,2,'.'));
            else _minprec = 0;
            _max = put(&&name&i.._max,best.);
            if index(_max,'.') then _maxprec = length(scan(_max,2,'.'));
            else _maxprec = 0;
            _prec = max(_minprec,_maxprec);
            call symputx("prec&i",_prec);
         run;
         
         %letput(prec&i);

         %*---------- use precision to round select values----------;
         
         data cb_stats&i;
            set cb_means&i;
            prec_mean = min(0.1,10**(-1*(&&prec&i-1)));
            prec_stddev = min(0.01,10**(-1*(&&prec&i-2)));
            &&name&i.._mean = round(&&name&i.._mean,prec_mean);
            &&name&i.._stddev = round(&&name&i.._stddev,prec_stddev);
            &&name&i.._q1 = round(&&name&i.._q1,prec_mean);
            &&name&i.._median = round(&&name&i.._median,prec_mean);
            &&name&i.._q3 = round(&&name&i.._q3,prec_mean);
            rename
               &&name&i.._Mean = Mean 
               &&name&i.._StdDev = StdDev
               &&name&i.._Min = Min
               &&name&i.._Q1 = Q1
               &&name&i.._Median = Median
               &&name&i.._Q3 = Q3
               &&name&i.._Max = Max
               ;
         run;

         %*---------- apply formats ----------;
         
         %if %nrbquote(&&format&i) ne %str() %then %let format = &&format&i;
         %else %let format = best.;
         %letput(format);
         %let format = %unquote(&format);
         
         %macro cb_c(var);
            &var._c = put(&var,&format);
         %mend cb_c;
         
         data cb_stats_c&i;
            set cb_stats&i;
            format mean stddev min q1 median q3 max &format;
            %cb_c(mean);
            stddev_c = put(stddev,best.);
            %cb_c(min);
            %cb_c(q1);
            %cb_c(median);
            %cb_c(q3);
            %cb_c(max);
         run;
            
         %*---------- into a macro variable ----------;
         
         %global stats1_&i stats2_&i;
         
         data _null_;
            set cb_stats_c&i;
            length stats1 stats2 $200;
            stats1 = 
               'Mean (StdDev) = ' || compress(mean_c) || ' (' || compress(stddev_c) || ')     '
               ||
               'Min, Max = ' || compress(min_c) || ', ' || compress(max_c) 
               ;
            stats2 = 
               'Median [Q1, Q3] = ' || compress(median_c) || ' [' || compress(q1_c) || ', ' || compress(q3_c) || ']' 
               ;
            call symputx("stats1_&i",stats1);
            call symputx("stats2_&i",stats2);
        run;
         
         %letput(stats1_&i);
         %letput(stats2_&i);
                  
      %end;



      %*--------------------------------------------------------------------------------;
      %*---------- freqall case is not bad ----------;
      %*--------------------------------------------------------------------------------;

      %else %if &&anly&i = freqall %then %do;
      
         %*---------- initial results ----------;
         
         proc sql;
            create   table cb_owf1_&i as
            select   &&name&i, cb_char_&&short&i, cb_fmt_sh_&&short&i, count(*) as frequency
            from     cb_fmt_&&memname&d
            where    &&name&i is not missing
                     %if %symexist(panelby) %then %do;
                        %if &panelbytype = char %then
                           and &panelby ne "&allchar" ;
                        %else
                           and &panelby ne &allnum ;
                     %end;
            group by &&name&i, cb_char_&&short&i, cb_fmt_sh_&&short&i
            ;
         quit;
         
         %*---------- put results in appropriate order ----------;
         
         proc sort data=cb_owf1_&i;
            by descending frequency 
               %if &&type&i = num %then 
                  &&name&i
                  ;
               %else 
                  cb_fmt_sh_&&short&i
                  ;
               ;
         run;
         
         %*---------- create results for each unique value ----------;
         
         data cb_owf2_&i;
            set cb_owf1_&i;
            length result $500;
            percent = 100*frequency/&&n&i;
            result = 
               %if &&isfmtreal&i eq 1 %then %do;
                  trim(left(cb_char_&&short&i)) 
                  || ' = ' || 
               %end;
               trim(left(cb_fmt_sh_&&short&i))
               || ' (' 
               || compress(put(frequency,best.)) 
               || ', '
               || compress(put(percent,5.1)) 
               || '%)'
               ;
            keep cb_fmt_sh_&&short&i result frequency percent;
         run;

         %*---------- combine into one long text string ----------;
         
         %global freqall&i;
         
         data cb_owf3_&i;
            set cb_owf2_&i end=eof;
            length freqall $2000;
            retain freqall;
            if _N_ = 1 then freqall = result;
            else freqall = trim(freqall)
               || ",&tab"
               || result
               ;
            if eof then call symputx("freqall&i",freqall);
         run;
         
         %letput(freqall&i);
         
      %end;



      %*--------------------------------------------------------------------------------;
      %*---------- freqsome case will show lowest 5 and highest 5 if lots of uniques ----------;
      %*---------- and show the most frequent 5 if not too many uniques ----------;
      %*--------------------------------------------------------------------------------;

      %else %if &&anly&i = freqsome %then %do;

         %*---------- calculate initial counts and percents ----------;
         
         proc sql;
            create   table cb_owf1_&i as
            select   &&name&i, cb_char_&&short&i, cb_fmt_sh_&&short&i, count(*) as frequency
            from     cb_fmt_&&memname&d
            where    &&name&i is not missing
                     %if %symexist(panelby) %then %do;
                        %if &panelbytype = char %then
                           and &panelby ne "&allchar" ;
                        %else
                           and &panelby ne &allnum ;
                     %end;
            group by &&name&i, cb_char_&&short&i, cb_fmt_sh_&&short&i
            ;
         quit;
            
         data cb_owf2_&i;
            set cb_owf1_&i;
            percent = 100*frequency/&&n&i;
         run;
            
         %*---------- flag if highest percent is too low ----------;
         
         proc sql noprint;
            create   table cb_maxpct_&i as
            select   max(percent) as maxpct
            from     cb_owf2_&i
            ;
         quit;
         
         data _null_;
            set cb_maxpct_&i;
            if maxpct < &lowestpct then toolow = 1;
            else toolow = 0;
            call symputx("toolow&i",toolow);
         run;
         
         %letput(toolow&i);
            
         %*---------- if too many uniques, flag lowest 5 and highest 5 ----------;
         
         %if &&toounique&i eq 1 or &&toolow&i eq 1 %then %do;
         
            proc sort data=cb_fmt_&&memname&d (keep=cb_fmt_sh_&&short&i) out=cb_lohi1_&i;
               by cb_fmt_sh_&&short&i;
            run;
            
            data cb_lohi2_&i;
               set cb_lohi1_&i;
               if _N_ <= &maxfreqs then lo = 1;
            run;
   
            %global lowest&i;
            
            data cb_lowest&i;
               set cb_lohi2_&i end=eof;
               where lo;
               length lowest $2000;
               retain lowest;
               if _N_ = 1 then lowest = cb_fmt_sh_&&short&i;
               else lowest = trim(lowest)
                  || ",&tab"
                  || cb_fmt_sh_&&short&i
                  ;
               if eof then call symputx("lowest&i",lowest);
            run;
   
            %letput(lowest&i);
   
            proc sort data=cb_lohi1_&i out=cb_lohi3_&i;
               by descending cb_fmt_sh_&&short&i;
            run;
            
            data cb_lohi4_&i;
               set cb_lohi3_&i;
               if _N_ <= &maxfreqs then hi = 1;
            run;
   
            %global highest&i;
            
            data cb_highest&i;
               set cb_lohi4_&i end=eof;
               where hi;
               length highest $2000;
               retain highest;
               if _N_ = 1 then highest = cb_fmt_sh_&&short&i;
               else highest = trim(highest)
                  || ",&tab"
                  || cb_fmt_sh_&&short&i
                  ;
               if eof then call symputx("highest&i",highest);
            run;
   
            %letput(highest&i);
            
         %end;

         %*---------- otherwise, flag most frequent 5 ----------;
         
         %else %do;

            %*---------- create results for each unique value ----------;
            
            data cb_owf3_&i;
               set cb_owf2_&i;
               length result $500;
               result = compress(put(frequency,best.)) 
                  || ' (' 
                  || compress(put(percent,5.1)) 
                  || '%)'
                  ;
            run;
   
            proc sort data=cb_owf3_&i out=cb_owf4_&i;
               by descending frequency cb_fmt_sh_&&short&i;
            run;
   
            data cb_owf5_&i;
               set cb_owf4_&i;
               if _N_ <= &maxfreqs then mo = 1;
            run;
   
            %global most&i;
            
            data cb_owf6_&i;
               set cb_owf5_&i end=eof;
               where mo;
               length most $2000;
               retain most;
               result = 
                  %if &&isfmtreal&i eq 1 %then %do;
                     trim(left(cb_char_&&short&i)) 
                     || ' = ' || 
                  %end;
                  trim(left(cb_fmt_sh_&&short&i))
                  || ' (' 
                  || compress(put(frequency,best.)) 
                  || ', '
                  || compress(put(percent,5.1)) 
                  || '%)'
                  ;
               if _N_ = 1 then most = result;
               else most = trim(most)
                  || ",&tab"
                  || result
                  ;
               if eof then call symputx("most&i",most);
            run;
   
            %letput(most&i);
   
            %*---------- make plot dataset for most frequent ----------;
   
            data cb_most&i;
               set cb_owf5_&i;
               where mo;
               proportion = percent / 100;
               keep cb_fmt_sh_&&short&i result frequency proportion;
            run;
            
         %end;

      %end;



      %*--------------------------------------------------------------------------------;
      %*---------- generate appendix resuults ----------;
      %*--------------------------------------------------------------------------------;

      %if &&appx&i = yes %then %do;

         %*---------- initial results ----------;
         
         proc sql;
            create   table cb_appx1_&i as
            select   &&name&i, cb_char_&&short&i, cb_fmt_sh_&&short&i, count(*) as frequency
            from     cb_fmt_&&memname&d
            where    &&name&i is not missing
            group by &&name&i, cb_char_&&short&i, cb_fmt_sh_&&short&i
            ;
         quit;
         
         %*---------- put results in appropriate order ----------;
         
         proc sort data=cb_appx1_&i;
            by &&name&i;
         run;
         
         %*---------- finalize dataset ----------;
         
         data cb_appx_&i;
            set cb_appx1_&i;
            length col1 $100 col2 col3 $200;
            col1 = "&&name&i";
            if "&&format&i" ne "" then col1 = trim(col1) || " {&&format&i}";
            col2 = cb_char_&&short&i;
            if "&&format&i" ne "" then col3 = cb_fmt_sh_&&short&i;
            col4 = frequency;
            col5 = 100*frequency/&&n&i;
            format col5 5.1;
            label
               col1 = "Variable {Format}"
               col2 = "Unformatted"
               col3 = "Formatted"
               col4 = "Count"
               col5 = "Percent"
               ;
            keep col1-col5;
         run;

      %end;

   %end;


%mend cb_calcstats;