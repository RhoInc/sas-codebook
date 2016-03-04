%macro cb_alttext(text1,text2);
                     
   data cb_alttext;
      x = 0; y = 0; output;
      x = 100; y = 100; output;
      length text $50;
      x = 60; y = 80; text = "&text1"; output;
      x = 60; y = 65; text = "&text2"; output;
   run;

   proc sgplot data=cb_alttext noborder;
      title1;
      footnote1;
      scatter x=x y=y / markerchar=text markercharattrs=(size=10);
      xaxis display=none min=0 max=100 offsetmin=0 offsetmax=0;
      yaxis display=none;
   run;
   
%mend cb_alttext;

                  
