/Appl Id:/{
   applid=$3;
}
/Operation/{
   op=substr($0,14)
}
/Section  :/{
   section=$3;
   cursor=applid section;
}
/Text     :/{
   text=substr($0,13)
}
/Exec Time:/{
   exec=$3;
}
/Start Time:/{
   start=$4
}
/Stop Time:/{
   stop=$4;
}
/Rows read:/{
   rows=$3;
}
/SQLCA/{
   n=split(start,stime,":");
   startsecs=stime[1]*3600+stime[2]*60+stime[3];
   n=split(stop,stime,":");
   stopsecs=stime[1]*3600+stime[2]*60+stime[3];
   if (op=="Open") {
      print start, (stopsecs-startsecs)*1000 " ms " op, text;
   }
   if (op=="Static Commit") {
      print start, (stopsecs-startsecs)*1000 " ms " op;
   }
   if (op=="Execute Immediate") {
      print start, (stopsecs-startsecs)*1000 " ms " rows " rows read " text;
   }
   if (op=="Prepare") {
      sqlstart[cursor] = start;
      sqlstartsecs[cursor] = startsecs;
   }
   if (op=="Execute") {
      print start, exec*1000 " ms " op, rows " rows read " text;
   }
   if (op=="Close") {
      print start, exec*1000 " ms " op, rows " rows read " text;
   }
   text=""
}
