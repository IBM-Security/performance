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
   print "    <section id=\"main\">"
   print "    ";
}
{
   n=split($1,comps,".");
   n=split(comps[1],comps2,"_");
   stat_type=comps2[1];
   stat_description=comps2[3];
   for (i=4;i<=n;i++) {
      stat_description=stat_description " " comps2[i];
   }
   if (!stat_description) stat_description=stat_type;
   if (substr(stat_type,1,3)=="jct" || substr(stat_type,1,3)=="vhj") {
      stat_description=stat_type " " stat_description;
      stat_type=substr(stat_type,1,3);
   }
   if (stat_type != prev_stat_type) {
      if (prev_stat_type) {
         print "      </div>";
         print "      ";
      }
      print "      <div id=\"" stat_type "\" class=\"stats\">";
      print "	<div><h2>" description[stat_type] " </h2></div>";
   }
   print "	<div class=\"gallery\">";
   print "	  <a target=\"_blank\" href=\"graphs/" $1 "\">";
   print "	    <img src=\"graphs/" $1 "\" alt=\"" stat_description "\" width=\"640\" height=\"480\">";
   print "	  </a>";
   print "	  <div class=\"desc\">" stat_description "</div>";
   print "	</div>";
   prev_stat_type=stat_type;
}
END {
   print "";
   print "      </div>";
   print "      ";
   print "    </section>";
   print "    ";
}