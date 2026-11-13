# §24.1 benchmark assessment — headless discovery

**BLOCKED** for worst-legal replay qualification: no frozen and independently reviewed worst-legal six-round input log exists at `09506a8`. Discovery found valid six-round histories; it did not prove a maximum across legal command/Guidance and driver choices. The prior B5 cancellation-stream fixture reaches 114 entries; the catalog pilot below reached 123 with normal owner operations and no cancellation or root mutation. The required fixed workload must be frozen/reviewed before its timed campaign. See [Contract §24.1](../../../../../docs/M4_05_Playable_Integration_Contract.md#241-e4--reproducible-benchmark-contract-execution-not-run).

**NOT RUN** for the full catalog campaign and native GUI performance. Required headless campaign is five fresh processes, each with 10 untimed complete-session warm-ups and 100 measured create/play/release sessions over the fixed five-fixture order, plus 10 replay warm-ups and 100 fixed workload replays per process. The diagnostic pilot used one process, 10 discarded warm-ups, five catalog samples and the cold first sample. These are explicitly discovery samples. At ~29.84 s per session across a single observed cycle, catalog runs alone project to ~4.6 hours serial on this host including warm-ups; running processes concurrently would introduce unqualified contention. No 100-cycle growth conclusion or contract-grade p50/p95/max is claimed. Complete campaign remains necessary; neither shortened repetitions nor the proposed 50 ms replay p95 budget is an Owner-approved gate substitute.

The pilot records monotonic microseconds: whole authorized `transact` time, separate `Rules.replay` on installed immutable seed + actual journal, and full host session to replay equality (excludes file output and teardown). No extra replay call lies inside the pilot's timed transaction wrapper; by inspection every publishing normal transaction validates the root via one full reconstruction, successful close via two (seal and commit), and READY reads do not publish. **Per-transaction internal replay counts/time were not instrumented**; inspection is not a measured counter. Full campaigns also need that separate instrumentation and idle release sampling without retaining a journal in the instrumentation buffer. The sampled after-counters include the detached output record awaiting serialization. Object count alone cannot certify no owner retention.

| Fixture | Closed rounds / journal entries | Whole session ms | Pure replay ms | Transaction calls | Slowest transaction ms |
|---|---:|---:|---:|---:|---:|
| Main (cold) | 6 / 116 | 59,742.896 | 1,344.222 | 138 | 2,822.771 |
| Main | 6 / 116 | 50,425.307 | 1,036.166 | 138 | 2,125.384 |
| Player-down | 6 / 123 | 63,471.279 | 1,317.053 | 149 | 2,545.640 |
| NPC-down | 6 / 108 | 35,281.639 | 740.122 | 126 | 1,513.971 |
| Victory seed | 0 / 1, early-terminal | 4.190 | 1.027 | 1 | 2.230 |
| Defeat seed | 0 / 1, early-terminal | 4.849 | 1.200 | 1 | 2.688 |

All six sample roots equaled reconstruction; generation 1 and distinct session identities. Trace contents, seed references, ordered operations/timings, final digests and per-cycle counters are in `benchmark/discovery.jsonl` inside the [archive](run-evidence.zip). Terminal seeds were not padded. Headless process RSS max via macOS `/usr/bin/time -l`: 135,561,216 bytes. Godot reported 71,634,235 bytes peak static at sampled points; object count went from 1,498 to 1,499 on cold and stayed 1,499 in measured cycles 1–5. See the manifest for build, timing, command and power/background conditions. The failed initial harness prefix is retained separately, outside discovery data. Exploratory nearest-rank transaction statistics within each sample are in `benchmark/diagnostic-percentiles.json`; they do not certify the mandated distributions. GUI play checks in this pack report no GUI latency.

Reproduce the **discovery** probe by saving [the evidence-only driver](catalog_probe.gd.txt) as `catalog_probe.gd` outside the Godot project, importing a clean snapshot at `09506a8`, then:

```sh
/usr/bin/time -l /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$SOURCE" --log-file "$OUT/discovery.engine.log" \
  --script "$PROBE/catalog_probe.gd" -- discovery "$OUT/discovery.jsonl" 5
```

Probe creates owners via normal factory capabilities, plays Defend when command-ready, admits the round, advances each slot, locks genuine decisions, applies/completes genuine effects, closes, and compares replay to the live final snapshot. The last parameter is discovery sample count; increasing it alone does not implement the rest of §24.1. Freeze a stress journal with a reviewed workload definition, then run the complete protocol and evaluate budgets with the Owner.
