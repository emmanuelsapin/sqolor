#!/bin/bash
# sqolor.sh — colored / sorted squeue for my jobs
#
# usage:
#   bash sqolor.sh
#   bash sqolor.sh -h
# extra args are passed to squeue (e.g. -t R)
#
# env (optional):
#   PREEMPT_QOS_REGEX   qos name pattern that means preemptable (default: preempt)

usage() {
  cat <<'EOF'
sqolor.sh — pretty squeue for $USER

Usage:
  bash sqolor.sh [-h|--help] [squeue args...]

What it does:
  - lists your jobs with colors by job NAME
  - sorts into 3 blocks:
      1) preemptable + pending   (priority low -> high)
      2) preemptable + running   (runtime low -> high)
      3) non-preemptable         (runtime low -> high)
  - preemptable = qos matches "preempt" OR partition is a comma-list
  - NAME column width fits the longest name (so ST stays aligned)
  - if >20 jobs are running, reprints the header at the bottom
  - ends with running totals: jobs / cpus / ram (preempt vs not)

Examples:
  bash sqolor.sh
  bash sqolor.sh -t R          # only running (squeue filter)
  PREEMPT_QOS_REGEX=preemptable bash sqolor.sh

EOF
}

# -h / --help
for a in "$@"; do
  case "$a" in
    -h|--help) usage; exit 0 ;;
  esac
done

USER="${USER:-$(whoami)}"
PREEMPT_RE="${PREEMPT_QOS_REGEX:-preempt}"

# --- main: squeue -> awk (parse/color/sort keys) -> sort -> awk (print) ---
squeue -u "$USER" -h -o '%i|%P|%j|%t|%Q|%M|%l|%D|%C|%m|%q|%S|%R' "$@" | awk -F'|' -v pre_re="$PREEMPT_RE" \
  -v R=$'\033[0m' -v B=$'\033[1m' '

# convert slurm time strings (D-HH:MM:SS etc) to seconds
function tsec(t, d,n,a,b) {
  if (t=="" || t=="N/A" || t=="Invalid" || t=="UNLIMITED") return 0
  d=0
  if (index(t,"-")>0) { split(t,b,"-"); d=b[1]+0; t=b[2] }
  n=split(t,a,":")
  if (n==1) return d*86400 + a[1]
  if (n==2) return d*86400 + a[1]*60 + a[2]
  if (n==3) return d*86400 + a[1]*3600 + a[2]*60 + a[3]
  return 0
}

# memory field (80G, 96000M, ...) -> megabytes
function tomb(s, n,u) {
  s=toupper(s); gsub(/ /,"",s)
  if (s=="" || s=="N/A") return 0
  if (match(s,/^[0-9]+(\.[0-9]+)?/)) {
    n=substr(s,RSTART,RLENGTH)+0
    u=substr(s,RSTART+RLENGTH)
    if (u ~ /^T/) return n*1024*1024
    if (u ~ /^G/) return n*1024
    if (u ~ /^K/) return n/1024
    return n   # assume MB
  }
  return 0
}

# pretty print MB as G/T
function showmem(mb, g) {
  g=mb/1024
  if (g>=1024) return sprintf("%.2fT", g/1024)
  if (g>=100) return sprintf("%.0fG", g)
  if (g>=10) return sprintf("%.1fG", g)
  return sprintf("%.2fG", g)
}

BEGIN {
  # 256-color palette; one color per distinct job name
  nc=split("39 208 48 213 220 51 141 203 120 75 198 82 99 214 45 171 118 33 205 190 69 162 86 135", pal, " ")
  ci=1
  nw=4  # min NAME width ("NAME"); grows to longest name
}

{
  # fields from squeue -o above
  jid=$1; part=$2; nam=$3; st=$4; pri=$5+0
  tm=$6; lim=$7; nd=$8; cpu=$9; mem=$10
  qos=$11; start=$12; why=$13
  for (i=14;i<=NF;i++) why=why "|" $i

  # on blanca, a comma-separated partition list means preemptable
  multip = (index(part,",")>0)
  ispre = (qos ~ pre_re) || multip
  pend = (st=="PD" || st=="CF")
  run = (st=="R" || st=="CG" || st=="RS")

  # display: collapse multi-partition to the word "preemptable"
  pshow = multip ? "preemptable" : part
  # NODELIST: always the real node (running) or pending reason — never blank it to "preemptable"
  nodelist = why
  el = tsec(tm)

  # sort groups / keys
  #   g=1 pending preempt  -> sort by priority
  #   g=2 running preempt  -> sort by elapsed time
  #   g=3 non-preempt      -> sort by elapsed time
  if (ispre && pend) { g=1; k=pri }
  else if (ispre)    { g=2; k=el }
  else               { g=3; k=el }

  # assign color the first time we see this name
  if (!(nam in color)) {
    color[nam]=sprintf("\033[38;5;%sm", pal[ci])
    ci = ci % nc + 1
  }
  if (length(nam)>nw) nw=length(nam)

  # running-only totals for the summary at the end
  if (run) {
    nrun++
    nn=nd+0; if (nn<1) nn=1
    mb=tomb(mem)*nn   # MIN_MEM * nodes
    c=cpu+0
    if (ispre) { pc+=c; pm+=mb; pj++ }
    else       { nc_+=c; nm_+=mb; nj++ }
  }

  # stash row for END (need full pass for namax + totals)
  n++
  G[n]=g; K[n]=k; ID[n]=jid; C[n]=color[nam]
  J[n]=jid; P[n]=pshow; N[n]=nam; S[n]=st
  PR[n]=pri; T[n]=tm; L[n]=lim
  ND[n]=nd; CP[n]=cpu; MM[n]=mem
  Q[n]=qos; ST[n]=start; W[n]=nodelist
}

END {
  # build header with dynamic NAME width
  hdr=sprintf("%-12s %-12s %-*s %-2s %10s %10s %10s %5s %4s %8s %-12s %-19s %s",
    "JOBID","PARTITION",nw,"NAME","ST","PRIORITY","TIME","TIMELIMIT",
    "NODES","CPUS","MIN_MEM","QOS","START","NODELIST(REASON)")

  # emit lines as: group \t sortkey \t jobid \t group \t colored_line
  # (group 0 = header, sorts to the top)
  printf "0\t%020d\t\t0\t%s%s%s\n", 0, B, hdr, R

  for (i=1;i<=n;i++) {
    line=sprintf("%-12s %-12s %-*s %-2s %10s %10s %10s %5s %4s %8s %-12s %-19s %s",
      J[i],P[i],nw,N[i],S[i],PR[i],T[i],L[i],ND[i],CP[i],MM[i],Q[i],ST[i],W[i])
    printf "%d\t%020d\t%s\t%d\t%s%s%s\n", G[i],K[i],ID[i],G[i],C[i],line,R
  }

  # if many running jobs, reprint header at bottom (group 9)
  if (nrun>20)
    printf "9\t%020d\t\t9\t%s%s%s\n", 0, B, hdr, R

  # resource summary (group 10 = after everything)
  printf "10\t%020d\t\t10\t%s--- running totals ---%s\n", 0, B, R
  printf "10\t%020d\t\t10\t  preemptable:     %5d jobs  %6d cpus  %s ram\n", 1, pj+0, pc+0, showmem(pm)
  printf "10\t%020d\t\t10\t  non-preemptable: %5d jobs  %6d cpus  %s ram\n", 2, nj+0, nc_+0, showmem(nm_)
  printf "10\t%020d\t\t10\t  all:             %5d jobs  %6d cpus  %s ram\n", 3, pj+nj, pc+nc_, showmem(pm+nm_)
}
' | sort -t$'\t' -k1,1n -k2,2n -k3,3 | awk -F'\t' -v B=$'\033[1m' -v R=$'\033[0m' '
# second pass: strip sort keys, print section banners + rows
{
  g=$4+0
  if (g==0 || g==9 || g==10) { print $5; next }  # header / footer / summary
  if (g!=last) {
    if (g==1) h="--- preemptable pending (pri low->high) ---"
    else if (g==2) h="--- preemptable running (time low->high) ---"
    else h="--- non-preemptable (time low->high) ---"
    print B h R
    last=g
  }
  print $5
}
'

# reminder
echo ""
echo "(run: bash sqolor.sh -h  for help)"
