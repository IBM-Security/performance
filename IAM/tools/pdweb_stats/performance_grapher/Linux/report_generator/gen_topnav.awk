BEGIN {
   description["authn"]="Authentication";
   description["authz"]="Authorization";
   description["certcallbackcache"]="Certificate callback cache";
   description["doccache"]="Document cache";
   description["drains"]="Drains";
   description["http"]="HTTP requests";
   description["https"]="HTTPS requests";
   description["jct"]="Junction requests";
   description["jmt"]="Junction mapping table";
   description["sescache"]="Session cache";
   description["threads"]="Threads"
   description["usersessidcache"]="User ID session cache";
   description["vhj"]="Virtual host junctions";
   print "    <nav class=topnav id=mainnav>";
}
{
   n=split($1,comps,".");
   n=split(comps[1],comps2,"_");
   stat_type=comps2[1];
   if (substr(stat_type,1,3)=="jct" || substr(stat_type,1,3)=="vhj") {
      stat_type=substr(stat_type,1,3)
   }
   if (stat_type != prev_stat_type) {
      print "      <a href=\"#" stat_type "\">" description[stat_type] "</a>";
   }
   prev_stat_type=stat_type;
}
END {
   print "    </nav>";
   print "    ";
}
