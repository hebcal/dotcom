
var SpecialDay=1;var FontSize=5;var ColorBackground="ffffcc";var ColorSpecialDay="red";var ColorToday="green";var ColorEvent="blue";var today=new Date();var FirstMonth=GetFullYear(today)*100+1;var LastMonth=FirstMonth+11;var Events=new Array;function DefineEvent(EventDate,EventDescription,EventLink,Image,Width,Height){var tmp;tmp="";if(Image!="")
tmp=tmp+'<img src="'+Image+'"  width="'+Width+'" height="'+Height+'" align="left" valign="top">';if(EventLink!="")
tmp=tmp+'<a href="'+EventLink+'">';tmp=tmp+EventDescription;if(EventLink!="")tmp=tmp+'</a>';if(Events[EventDate])
Events[EventDate]+="<BR>"+tmp;else
Events[EventDate]=tmp;tmp=Math.floor(EventDate/100);if(tmp<FirstMonth)FirstMonth=tmp;if(tmp>LastMonth)LastMonth=tmp;}
function arr(){for(var n=0;n<arr.arguments.length;n++){this[n+1]=arr.arguments[n];}}
var months=new arr("January","February","March","April","May","June","July","August","September","October","November","December");function Calendar(){var curdy,curmo,yr,mo,dy,dayofweek,yearmonth,bgn,lastday,jump;var weekdays=new arr("Sun","Mon","Tue","Wed","Thu","Fri","Sat");var thispage=window.location.pathname;curdy=today.getDate();curmo=today.getMonth()+1;mo=curmo;yr=GetFullYear(today);yearmonth=(yr*100)+mo;if(location.search.length>1){yearmonth=parseInt(location.search.substring(1,location.search.length));if((""+yearmonth).length==6){mo=yearmonth%100;yr=(yearmonth-mo)/100;}}
if(yearmonth<FirstMonth){mo=FirstMonth%100;yr=(FirstMonth-mo)/100;yearmonth=FirstMonth;}
if(yearmonth>LastMonth){mo=LastMonth%100;yr=(LastMonth-mo)/100;yearmonth=LastMonth;}
bgn=new Date(months[mo]+" 1,"+yr);dayofweek=bgn.getDay();lastday=NumDaysIn(mo,yr);document.write("<TABLE BORDER=2 BGCOLOR="+ColorBackground+"><TR><TD ALIGN=CENTER COLSPAN=7><FONT SIZE="+FontSize+"><B>"+months[mo]+" "+yr+"</B></FONT></TD></TR><TR>");for(var i=1;i<=7;i++){document.write("<TD ALIGN=CENTER WIDTH=14%><FONT SIZE=1>"+weekdays[i]+"</FONT></TD>");}
document.write("</TR><TR>");dy=1;for(var i=1;i<=7;i++){if(i<=dayofweek){document.write("<TD ALIGN=CENTER><FONT SIZE="+FontSize+">&nbsp;</FONT></TD>");}
else{ShowDate(yr,mo,dy,i,curmo,curdy);dy++;}}
document.write("</TR><TR>");while(dy<=lastday){for(var i=1;i<=7;i++){if(dy>lastday){document.write("<TD ALIGN=CENTER>&nbsp;</TD>");}
else{ShowDate(yr,mo,dy,i,curmo,curdy);dy++;}}
document.write("</TR><TR>");}
jump="";if(yearmonth>FirstMonth)
jump+='<a href="'+thispage+'?'+PrevYearMonth(yearmonth)+'">&lt;-- View '+months[PrevMonth(mo)]+'</a>';if((yearmonth>FirstMonth)&&(yearmonth<LastMonth))
jump+=" &nbsp; | &nbsp; ";if(yearmonth<LastMonth)
jump+='<a href="'+thispage+'?'+NextYearMonth(yearmonth)+'">View '+months[NextMonth(mo)]+' --&gt;</a>';document.write("</TR><TR><TD colspan=7 align=center>"+jump+"</TD></TR>");document.write("<TR><TD colspan=7 align=center valign=middle><FORM>Jump to month:&nbsp;&nbsp;");BuildSelectionList(yearmonth,thispage);document.write("</FORM></TD></TR></TABLE>");}
function ShowDate(yr,mo,dy,dayofweek,currentmonth,currentday){var ind,HighlightEvent,tmp;document.write("<TD ALIGN=CENTER VALIGN=TOP><P ALIGN=RIGHT><FONT SIZE="+FontSize);HighlightEvent=true;if(dayofweek==SpecialDay){document.write(" COLOR="+ColorSpecialDay);HighlightEvent=false;}
if((mo==currentmonth)&&(dy==currentday)){document.write(" COLOR="+ColorToday);HighlightEvent=false;}
ind=(((yr*100)+mo)*100)+dy;if(Events[ind]){tmp=Events[ind];if(HighlightEvent){document.write(" COLOR="+ColorEvent);}}else tmp="&nbsp;<BR>&nbsp;";document.write("><B>"+dy+"</B></ALIGN></FONT></P><FONT SIZE=1>"+tmp+"</TD>");}
function NumDaysIn(mo,yr){if(mo==4||mo==6||mo==9||mo==11)return 30;else if((mo==2)&&LeapYear(yr))return 29;else if(mo==2)return 28;else return 31;}
function LeapYear(yr){if(((yr%4==0)&&yr%100!=0)||yr%400==0)return true;else return false;}
function GetFullYear(d){var yr;yr=d.getYear();if(yr<1000)
yr+=1900;return yr;}
function PrevMonth(mth){if(mth==1)return 12;else return(mth-1);}
function NextMonth(mth){if(mth==12)return 1;else return(mth+1);}
function PrevYearMonth(yrmth){if((yrmth%100)==1)return((yrmth-100)+11);else return(yrmth-1);}
function NextYearMonth(yrmth){if((yrmth%100)==12)return((yrmth-11)+100);else return(yrmth+1);}
function JumpTo(calendar,thispage){var sel,yrmo;sel=calendar.selectedIndex;yrmo=calendar.form.jumpmonth[sel].value;document.location=thispage+"?"+yrmo;}
function BuildSelectionList(current,thispage){var mo,yr,yearmonth;yearmonth=FirstMonth;document.write("<select name=\"jumpmonth\" size=1 onchange=\"JumpTo(this,'"+thispage+"')\">");while(yearmonth<=LastMonth){mo=yearmonth%100;yr=(yearmonth-mo)/100;document.write("<option value=");document.write(yearmonth);if(yearmonth==current)document.write(" selected");document.write(">");document.write(months[mo]+" "+yr);yearmonth=NextYearMonth(yearmonth);}
document.write("</select>");}