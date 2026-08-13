# sqolor

Colored, sorted `squeue` view for your Slurm jobs.

## What it does

- Colors jobs by **NAME**
- Sorts into three blocks:
  1. preemptable + pending (priority low → high)
  2. preemptable + running (runtime low → high)
  3. non-preemptable (runtime low → high)
- Preemptable = QoS matches `preempt` **or** partition is a comma-separated list
- NAME column width follows the longest job name (keeps `ST` aligned)
- Running jobs show the real node in NODELIST
- If more than 20 jobs are running, reprints the header at the bottom
- Ends with running totals: jobs / CPUs / RAM (preemptable vs not)

## Usage

```bash
bash sqolor.sh
bash sqolor.sh -h
bash sqolor.sh -t R    # extra args go to squeue
```

Optional env:

```bash
PREEMPT_QOS_REGEX=preemptable bash sqolor.sh
```

## Requirements

- bash, awk, sort
- Slurm (`squeue`)

## License

MIT