# sqolor

**sqolor** is a portmanteau of **s**queue and c**olor** — a small bash helper for a clearer view of *your* Slurm jobs.

Colors jobs by name, sorts preemptable vs non-preemptable, and prints a short resource summary at the end.

## Install

```bash
git clone https://github.com/emmanuelsapin/sqolor.git
cd sqolor
chmod +x sqolor.sh
```

Or just copy `sqolor.sh` somewhere on your `PATH`.

## Quick start

```bash
bash sqolor.sh
bash sqolor.sh -h          # help
bash sqolor.sh -t R        # any extra args are passed to squeue
```

## What you get

Jobs are listed in three blocks:

| Block | Order |
| --- | --- |
| Preemptable + pending | priority low → high |
| Preemptable + running | runtime low → high |
| Non-preemptable | runtime low → high |

**Preemptable** means either:

- the job QoS matches `preempt` (override with `PREEMPT_QOS_REGEX`), or  
- the partition field is a comma-separated list (common on some clusters)

Other details:

- each distinct job **NAME** gets its own color  
- the NAME column grows to the longest name so **ST** stays aligned  
- running jobs show the real **node** in NODELIST  
- if more than 20 jobs are running, the header is reprinted at the bottom  
- a **running totals** block sums jobs / CPUs / RAM for preemptable vs non-preemptable  

Example summary:

```text
--- running totals ---
  preemptable:        12 jobs      48 cpus  960.00G ram
  non-preemptable:     3 jobs       6 cpus   90.00G ram
  all:                15 jobs      54 cpus   1.03T ram
```

## Columns

`JOBID`, `PARTITION`, `NAME`, `ST`, `PRIORITY`, `TIME`, `TIMELIMIT`, `NODES`, `CPUS`, `MIN_MEM`, `QOS`, `START`, `NODELIST(REASON)`

Multi-partition preemptable jobs are shown with partition `preemptable` so the line stays readable.

## Options / environment

| Name | Meaning |
| --- | --- |
| `-h` / `--help` | print help |
| extra args | forwarded to `squeue` (e.g. `-t R`, `-p blanca-ibg`) |
| `PREEMPT_QOS_REGEX` | regex for preemptable QoS (default: `preempt`) |

```bash
PREEMPT_QOS_REGEX=preemptable bash sqolor.sh
```

## Requirements

- bash, awk, sort  
- Slurm (`squeue`)  
- a terminal that supports 256 colors  

## License

[MIT](LICENSE)
