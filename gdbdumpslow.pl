#!/usr/bin/perl
use strict;
use Getopt::Long;
# t=time, l=lock time, r=rows
# at, al, and ar are the corresponding averages
my %opt = (
    s => 'at',
);

GetOptions(\%opt,
    'v|verbose+',# verbose
    'help+', # write usage info
    'd|debug+', # debug
    's=s', # what to sort by (at,ap,ag,af,c,t,p,g,f)
    'r!', # reverse the sort order (largest last instead of first)
    't=i', # just show the top n queries
    'a!', # don't abstract all numbers to N and strings to 'S'
    'n=i', # abstract numbers with at least n digits within names
    'g=s', # grep: only consider stmts that include this string
) or usage("bad option");

$opt{'help'} and usage();

unless (@ARGV) {
    my $slowlog = "slow_query.log";
    if ( -f $slowlog ) {
        @ARGV = ($slowlog);
        die "Can't find '$slowlog'\n" unless @ARGV;
    }
}


warn "\nReading slow query log from @ARGV\n";
my $whole_file = do {local $/; <> };

my $entry_separator = '(?m)(?=^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}:\d{3}\])';
my @entries = split /$entry_separator/,$whole_file;

my %stmt;
foreach (@entries) {
    warn "[[$_]]\n" if $opt{d}; # show raw paragraph being read

    my ($port,$host,$user,$t,$sql,$p,$g,$f) = s/.*Port\[(\d+)\]Session\[\d*\]TransSerial\[\d*\]LinkIP\[(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]LinkPort\[\d+\]UserName\[(\S+)\]ProxyName\[\S+\]ClusterName\[\S+\]Database\[\S*\]TotalExecTime\[(\d+)us\]BeginTs\[\S+\]EndTs\[\S+\]SQL\[(.*?)\]\n(?:digest\[\S+\]\n)?MsgToExecTime\[\S+\]ParserSQLTime\[(\d+)us,\S+\]PlanTreeCreateTime\[\S+\]GetGTIDTime\[(\d+)us,\S+\]GetAutoIncValueTime\[\S*\]FreeGtidTime\[(\d*)us,\S+\]PlanTreeExecTime\[\S+\].*//s ? ($1,$2,$3,$4,$5,$6,$7,$8) : ('','','','','','','','');
    warn "{{$sql}}\n\n" if $opt{d}; # show processed statement string


    next if $opt{g} and $sql !~ /$opt{g}/io;

    unless ($opt{a}) {
 $sql =~ s/\b\d+\b/N/g;
 $sql =~ s/\b0x[0-9A-Fa-f]+\b/N/g;
    $sql =~ s/''/'S'/g;
    $sql =~ s/""/"S"/g;
    $sql =~ s/(\\')//g;
    $sql =~ s/(\\")//g;
    $sql =~ s/'[^']+'/'S'/g;
    $sql =~ s/"[^"]+"/"S"/g;
 # -n=8: turn log_20001231 into log_NNNNNNNN
 $sql =~ s/([a-z_]+)(\d{$opt{n},})/$1.('N' x length($2))/ieg if $opt{n};
 # abbreviate massive "in (...)" statements and similar
 $sql =~ s!(([NS],){100,})!sprintf("$2,{repeated %d times}",length($1)/2)!eg;
    }

    my $s = $stmt{$sql} ||= { users=>{}, hosts=>{} };
    $s->{c} += 1;
    $s->{t} += $t;
    $s->{p} += $p;
    $s->{g} += $g;
    $s->{f} += $f;
    $s->{hosts}->{$host}++ if $host;
    $s->{users}->{$user}++ if $user;
    warn "{{$sql}}\n\n" if $opt{d}; # show processed statement string
}

foreach (keys %stmt) {
    my $v = $stmt{$_} || die;
    my ($c, $t,$p,$g,$f) = @{ $v }{qw(c t p g f)};
    $v->{at} = $t / $c;
    $v->{ap} = $p / $c;
    $v->{ag} = $g / $c;
    $v->{af} = $f / $c;
}

my @sorted = sort { $stmt{$b}->{$opt{s}} <=> $stmt{$a}->{$opt{s}} } keys %stmt;
@sorted = @sorted[0 .. $opt{t}-1] if $opt{t};
@sorted = reverse @sorted         if $opt{r};

foreach (@sorted) {
    my $v = $stmt{$_} || die;
    my ($c, $t,$p,$g,$f,$at,$ap,$ag,$af) = @{ $v }{qw(c t p g f at ap ag af)};
    my @users = keys %{$v->{users}};
    my $user  = (@users==1) ? $users[0] : sprintf "%dusers",scalar @users;
    my @hosts = keys %{$v->{hosts}};
    my $host  = (@hosts==1) ? $hosts[0] : sprintf "%dhosts",scalar @hosts;
    printf "Count: %d  Time=%.0fus (%dus)  ParserSQLTime=%.0fus (%dus)  GetGTIDTime=%.0fus (%dus)  FreeGtidTime=%.0fus (%dus)  $user\@$host\n%s\n\n",
     $c, $at,$t, $ap,$p,$ag,$g,$af,$f,$_;
}

sub usage {
    my $str= shift;
    my $text= <<HERE;
Usage: gdbdumpslow [ OPTS... ] [ LOGS... ]

Parse and summarize the MySQL slow query log. Options are

  --verbose    verbose
  --debug      debug
  --help       write this text to standard output

  -v           verbose
  -d           debug
  -s ORDER     what to sort by (at,ap,ag,af,c,t,p,g,f), 'at' is default
                at: average query time
                ap: average ParserSQLTime time
                ag: average GetGTIDTime time
                af: average FreeGtidTime time
                 c: count
                 t: query time
                 p: parse sql time
                 g: getgtidtime
                 f: freegtidtime
  -r           reverse the sort order (largest last instead of first)
  -t NUM       just show the top n queries
  -a           don't abstract all numbers to N and strings to 'S'
  -n NUM       abstract numbers with at least n digits within names
  -g PATTERN   grep: only consider stmts that include this string

HERE
    if ($str) {
      print STDERR "ERROR: $str\n\n";
      print STDERR $text;
      exit 1;
    } else {
      print $text;
      exit 0;
    }
}
