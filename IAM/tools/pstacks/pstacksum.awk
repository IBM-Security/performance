/^#/ {
   n=split($4,comps,"(");
   if (threadstack == "") {
      threadstack = comps[1];
   } else {
      threadstack = comps[1] "->" threadstack;
   }
}
/^Thread/ {
   if (threadstack != "") {
      print "Thread " threadname, threadstack;
      threadstack="";
   }
   threadname=$2;
}
END {
   if (threadstack != "") {
      print "Thread " threadname, threadstack;
   };
}
