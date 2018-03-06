#!/usr/bin/perl

while (<>) {
   last if /1XMTHDINFO/
}
   
while (<>) {
#print $_;
   chomp();
   if (/0SECTION/) {
      if ($stack) {
         print $threadname." ".$stack."->".$nativestack."\n";
      }
      last;
   }
   if (/(".+") J9VMThread/) {
      if ($stack) {
         print $threadname." ".$stack."->".$nativestack."\n";
         $stack = "";
         $nativestack = "";
      }
      $threadname = $1;
#print $threadname."\n";
   } elsif (/at 0x/) {
      ($tag, $at, $addr, $in, $method) = split(/ +/);
      if ($nativestack) {
         $nativestack = $method."->".$nativestack;
      } else {
         $nativestack = $method;
      }
   } elsif (/at /) {
      ($tag, $at, $stackname) = split(/ +/);
      ($method) = split(/\(/,$stackname);
      if ($stack) {
         $stack = $method."->".$stack;
      } else {
         $stack = $method;
      }
#print $method."\n";
   }
}
