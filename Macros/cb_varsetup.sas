%macro cb_varsetup;



   %*--------------------------------------------------------------------------------;
   %*---------- get variable name list and attributes of data= ----------;
   %*--------------------------------------------------------------------------------;

   proc sql noprint;
      create   table cb_varlist as
      select   name, type, label, format
      from     dictionary.columns
      where    libname = "&&libname&d"
               and memname = "&&memname&d"
               %if %symexist(panelby) %then and upcase(name) ne upcase("&panelby");
      ;
   quit;

   %global varlist_n;   
   %let varlist_n = &sqlobs;
   %letput(varlist_n);
   
   %do i = 1 %to &varlist_n;
      %global name&i type&i label&i format&i;
   %end;

   data cb_temp;
      set cb_varlist;
      i = compress(put(_N_,best.));
      mname = 'name' || i;
      mtype = 'type' || i;
      mlabel = 'label' || i;
      mformat = 'format' || i;
      call symputx(mname,name);
      call symputx(mtype,type);
      call symputx(mlabel,label);
      call symputx(mformat,format);
   run;

   %do i = 1 %to &varlist_n;
      %if %nrbquote(&&label&i) = %str() %then %let label&i = %nrbquote(-- no label --);
   %end;



   %*--------------------------------------------------------------------------------;
   %*---------- distinguish some features of each variable ----------;
   %*--------------------------------------------------------------------------------;

   %do i = 1 %to &varlist_n;
   
      %letput(name&i);

      %*---------- is the formatted numeric variable a factor variable ---------;
            
      %let isfactor&i = 0;
      
      %if &&type&i = num and %nrbquote(&&format&i) ne %str() %then %do;
      
         proc sql noprint;
            create   table cb_allvalues&i as
            select   distinct put(&&name&i,&&format&i) as allvalues
            from     _w_&&memname&d
            where    &&name&i is not missing
            ;
         quit;
         
         data _null_;
            set cb_allvalues&i end=eof;
            retain lavall alphasall funkyall;
            lav = length(allvalues);
            lavall = sum(lavall,lav);
            do i = 1 to lav;
               alphas = sum(alphas,anyalpha(substr(allvalues,i,1)));
            end;
            alphasall = sum(alphasall,alphas);
            do funk = "<", ">", "{", "}", "[", "]";            
               funkys = sum(funkys,index(allvalues,funk));
            end;            
            funkyall = sum(funkyall,funkys);
            if eof then do;
               alphaspct = alphasall/lavall;
               if 0.5 < alphaspct or 0 < funkyall then isfactor = 1;
               else isfactor = 0;
               call symputx("isfactor&i",isfactor);
            end;
         run;
         
      %end;
      
      %letput(isfactor&i);
      
      %*---------- is the formatted numeric variable all integer ----------;
      
      %global isinteger&i;
      %let isinteger&i = 0;
      
      %if &&type&i = num and %nrbquote(&&format&i) eq %str() %then %do;
      
         proc sql;
            create   table cb_allvalues&i as
            select   distinct &&name&i as allvalues
            from     _w_&&memname&d
            where    &&name&i is not missing
            ;
         quit;
         
         data _null_;
            set cb_allvalues&i end=eof;
            retain isinteger 1;
            if allvalues ne round(allvalues) then isinteger = 0;
            if eof then call symputx("isinteger&i",isinteger);
         run;
         
      %end;
      
      %letput(isinteger&i);
   
      %*---------- is the formatted numeric variable a time variable ----------;
      
      %global istime&i;
      %let istime&i = 0;
      
      %let timefmts = %str('B8601LZ', 'B8601TM', 'B8601TX', 'B8601TZ', 'E8601LZ', 'E8601TM', 
            'E8601TX', 'E8601TZ', 'HHMM', 'HOUR', 'MMSS', 'TIME', 'TOD');
      
      %if &&type&i = num and %nrbquote(&&format&i) ne %str() %then %do;
      
         data _null_;
            istime = 0;
            length subformat $20;
            do fmt = &timefmts;
               fmtlen = length(fmt);
               formatlen = length("&&format&i");
               minlen = min(fmtlen,formatlen);
               subformat = substr("&&format&i",1,minlen);
               if fmt = subformat then istime = 1;
            end;
            call symputx("istime&i",istime);
         run;
               
      %end;
      
      %letput(istime&i);
      
   %end;


   
   %*--------------------------------------------------------------------------------;
   %*---------- choose analyses: means, freqall, freqnone, or freqsome ----------;
   %*--------------------------------------------------------------------------------;

   %do i = 1 %to &varlist_n;
   
      %global anly&i distinct&i;
   
      proc sql noprint;
         select   count(distinct &&name&i)
         into     :distinct&i
         from     _w_&&memname&d
         ;
      quit;
      
      %if &&distinct&i = 0 %then %do;
         %let anly&i = freqnone;
      %end;
      %else %if &&type&i = char %then %do;
         %if &&distinct&i > &maxfreqs %then %let anly&i = freqsome;
         %else %let anly&i = freqall;         
      %end;
      %else %if &&type&i = num %then %do;
         %if &&isfactor&i = 0 and &&distinct&i > &minfreqs %then %let anly&i = means;
         %else %if &&distinct&i > &maxfreqs %then %let anly&i = freqsome;
         %else %let anly&i = freqall;
      %end;

      %letput(name&i);
      %letput(distinct&i);
      %letput(anly&i);

   %end;
   
   %do i = 1 %to &varlist_n;
   
      %letput(name&i);
      %letput(anly&i);
      %letput(distinct&i);
   
   %end;



   %*--------------------------------------------------------------------------------;
   %*---------- character versions of variables, using formats when available ----------;
   %*--------------------------------------------------------------------------------;
   
   data cb_fmt_&&memname&d;
      set _w_&&memname&d;
      cb_index = _N_;
      
      %do i = 1 %to &varlist_n;
      
         %if (&&anly&i in (freqsome freqall)) and %nrbquote(&&format&i) ne %str() %then %do;
            cb_fmt_&&name&i = put(&&name&i,&&format&i);
         %end;
         %else %if &&type&i = char %then %do;
            cb_fmt_&&name&i = &&name&i;
         %end;
         %else %do;
            cb_fmt_&&name&i = put(&&name&i,best.);
         %end;
         
         %if &&type&i = num %then %do;
            cb_char_&&name&i = left(put(&&name&i,best.));
         %end;
         %else %do;
            cb_char_&&name&i = &&name&i;
         %end;
         
      %end;      
      
   run;



   %*--------------------------------------------------------------------------------;
   %*---------- create shortened versions of cb_fmt variables ----------;
   %*--------------------------------------------------------------------------------;

   %do i = 1 %to &varlist_n;

      %*---------- create short version of cb_fmt ----------;
      
      data cb_short0_&i;
         set cb_fmt_&&memname&d (keep=cb_fmt_&&name&i);
         where cb_fmt_&&name&i is not missing;
         length short $200;
         if length(cb_fmt_&&name&i) > &dotlength then short = substr(cb_fmt_&&name&i,1,&dotlength);
         else short = cb_fmt_&&name&i;
      run;
      
      %*---------- count number of dups within each short version ----------;
      
      proc sql noprint;
         create   table cb_short1_&i as
         select   short, count(distinct cb_fmt_&&name&i) as dups
         from     cb_short0_&i
         group by short
         ;
         create   table cb_short2_&i as
         select   distinct cb_fmt_&&name&i, short
         from     cb_short0_&i
         ;
         create   table cb_short3_&i as
         select   a.*, b.dups
         from     cb_short2_&i as a
                  left join cb_short1_&i as b
                  on a.short = b.short
         ;
      quit;
      
      %*---------- put suffixes on the short text if dups ----------;
      
      data cb_short4_&i;
         set cb_short3_&i;
         by short;
         retain count;
         width = floor(log10(dups));
         if first.short then count = 0;
         if dups = 1 then do;
            if length(cb_fmt_&&name&i) > length(short) then short = cats(short,'...');
         end;
         else do;
            count + 1;
            count_c = put(count,best.);
            short = cats(short,'...$',count_c);
         end;
         fmtname = "$f&i.sh";
         hlo = '';
         keep fmtname cb_fmt_&&name&i short hlo;
         rename 
            cb_fmt_&&name&i = start
            short = label
            ;
      run;
      
      proc format cntlin=cb_short4_&i;
      run;
      
      %*---------- at long last, create cb_fmt_sh ----------;
            
      data cb_fmt_&&memname&d;
         set cb_fmt_&&memname&d;
         %if &&distinct&i > 0 %then %do;
            cb_fmt_sh_&&name&i = put(cb_fmt_&&name&i,$f&i.sh.); 
         %end;
         %else %do;
            cb_fmt_sh_&&name&i = cb_fmt_&&name&i;
         %end;
      run;
      
      %*---------- does the format really change anything ----------;
      
      %global isfmtreal&i;
      %let isfmtreal&i = 0;
      
      %if %nrbquote(&&format&i) ne %str() %then %do;
      
         proc sql;
            create   table cb_ifr0_&i as
            select   distinct cb_char_&&name&i, cb_fmt_&&name&i
            from     cb_fmt_&&memname&d
            where    &&name&i is not missing
            ;
         quit;

         data _null_;
            set cb_ifr0_&i end=eof;
            retain isfmtreal 0;
            if left(cb_char_&&name&i) ne left(cb_fmt_&&name&i) then isfmtreal = 1;
            if eof then call symputx("isfmtreal&i",isfmtreal);
         run;
      
      %end;      
      
      %letput(isfmtreal&i);
      
   %end;
   

%mend cb_varsetup;