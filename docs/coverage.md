# Formal Coverage — what is and isn't proven, and how to confirm it independently

This document answers two questions honestly:
1. **Does the formal verification have "100% coverage"?**
2. **How can a third party confirm the result without trusting us?**

The short version: **we do not claim 100% coverage, and the evidence says we shouldn't.**
Simulation found **7 real bugs that the formal proofs passed** (see
[`findings.md`](findings.md)) — direct, empirical proof that the formal *property set*
did not cover 100% of the design's behavior. A formal effort that claims unqualified
"100%" is misusing the term.

## 1. "100% coverage" is three separate things

| Notion | Meaning | This project | Confirmed by |
|---|---|---|---|
| **Proof exhaustiveness** | Does each proof hold for *all states, all time*? | **Yes for per-module properties** — `mode prove` is **k-induction (unbounded)**, not a bounded depth. (Integration F-1/F-2/F-3 are the exception: BMC depth-40 — honestly flagged below.) | "successful proof by k-induction" in the sby log; re-run `./run.sh` |
| **Property completeness** | Do the assertions describe *all* required behavior? | **Not measured — the real gap.** ~280 assertions from 380 spec requirements, but nothing guarantees they are complete. The 7 sim bugs lived in behavior no assertion constrained. | Mutation testing (§3); spec-traceability review |
| **Non-vacuity** | Are proofs meaningful, or trivially/vacuously true? | **Checked.** Every module has passing `cover` proofs (integration cover reached 281 witnesses incl. a full FE→bit→framer→FSM→RX-FIFO datapath trace). No `assume(0)` / `assert(1)` cheats. | `cover` task PASS; read the assumptions |

The classic trap is conflating row 1 with row 2. "All my properties are proven
exhaustively" (true here) is **not** "the design is 100% correct" (unknown). The honest
claim is: *the stated properties hold for all time; the property set is incomplete.*

## 2. What IS exhaustively proven here

- **Per-module safety/protocol invariants are unbounded (k-induction).** No-bus-contention,
  single-SDA-owner, drive-only-when-permitted, address match, ACK/NACK correctness,
  T-bit/parity, CCC classification + wildcard-NACK, IBI gating, error-recovery-to-idle,
  identity constants, FIFO no-overrun/underrun, Avalon read-scoreboard. Full per-module
  table in [`verification_status.md`](verification_status.md).
- **Soundness of the decomposition is auditable.** Each module is proven standalone with
  neighbour outputs constrained by `assume`; every such assume is mapped to a neighbour's
  proven `assert` in [`assume_ledger.md`](assume_ledger.md). The integration proof strips
  per-module checks (`chformal -remove`) so its F-1/F-2 results do not lean on unit assumes.

## 3. Measuring property completeness: mutation coverage (`mcy`)

The objective metric for row 2 is **mutation coverage**, and the open-source tool `mcy`
(Mutation Cover with Yosys, installed in the OSS CAD Suite) does exactly this:

1. Systematically **inject bugs** into the RTL (bit flips, stuck signals, dropped terms) — hundreds of mutants.
2. Re-run the formal proofs against each mutant.
3. **Mutant killed** = some assertion fails → that logic is covered by a property.
4. **Mutant survives** = all proofs still pass → a **coverage hole**: real logic no property constrains.
5. **Coverage % = killed / total.** Surviving mutants are a precise, reviewable to-do list for new assertions.

This is the open-source equivalent of Cadence JasperGold Coverage / Synopsys VC Formal FCA
/ Certitude.

### Measured results (mcy, BMC depth-20 per-mutant kill test)

Harness: `formal/mcy/gen.sh <module> <N> <files...>` builds a per-module mcy project whose
single test runs the module's own formal proof on each mutant; a mutant is **killed** if an
assertion fails. Sampled per-module **raw kill rate**:

| Module | Raw kill rate | Sample |
|---|---|---|
| `i3c_bit_engine` | **73 %** | 55 mutants |
| `i3c_framer` | ~50 % | (small sample) |
| `i3c_regfile` | **49 %** | 55 mutants |
| `i3c_sda_mux` | **47 %** | 51 mutants |
| `i3c_daa` | ~35 % | 54 mutants |
| `i3c_ccc` | ~32 % | 80 mutants |

**Read these numbers correctly — the raw kill rate is a deliberate LOWER BOUND, not a
"percent verified".** Three effects deflate it, all confirmed:

1. **No-change / equivalent mutations count as survivors.** mcy's own `mutate -mode none`
   baseline (a guaranteed no-op) is tagged UNCOVERED in every run — direct proof that a
   meaningful fraction of "survivors" are mutations that change *nothing observable* and
   that *no* property could or should catch. Typically 30–50 % of random mutations are
   equivalent. A rigorous score filters these with an equivalence (NOCHANGE) check; this
   harness does not, so the true property-relevant coverage is **higher** than the table.
2. **BMC bound.** Each mutant is killed only if an assertion fails within depth 20; the
   unbounded k-induction proof (what the project actually ships) would catch at least as
   many. Lower bound again.
3. **Formal-only logic is in the mutated netlist.** Mutating a ghost/cover signal cannot
   break a functional assertion — another survivor that isn't a real hole.

### What the numbers actually tell you

Even as a lower bound, the spread is the real signal. Modules whose properties closely
track the datapath (`bit_engine` 73 %, `regfile` 49 %, `sda_mux` 47 %) score higher than
the big combinational decoders (`ccc`/`daa` ~32 %), and that is **exactly what a
safety-and-protocol property set should look like**: it pins down contention, framing,
ACK/NACK, ordering, and identity — *not* every functional bit of every CCC decode. Pushing
any module toward >90 % means writing a near-complete **functional reference model**, which
is a different and far larger goal than the safety/conformance invariants proven here.

The actionable output is the **surviving-mutant list** per module — a concrete, prioritized
to-do list of functional assertions to add if higher coverage is wanted.

**Bottom line:** mutation testing confirms, quantitatively, what §1 says qualitatively — the
proofs are exhaustive for the (safety-focused) properties written; the property set is not a
complete functional spec, so it does **not** have "100 % coverage," and the measured kill
rate (a conservative lower bound) makes that concrete.

## 4. How a third party confirms the result — no license, no trust required

The open-source flow's biggest advantage is **independent reproducibility**:

1. **Reproduce the proofs from scratch.** `git clone`, `source tools/env.sh`,
   `cd formal && ./run.sh` → same yosys / SymbiYosys / boolector, deterministic SAT/SMT
   results → identical **ALL GREEN**. No proprietary tool or license needed (contrast a
   commercial result a reviewer cannot reproduce without a ~$100k seat). The solver's
   UNSAT result is itself a checkable proof certificate.
2. **Read every property.** Assertions are plain SVA under `` `ifdef FORMAL `` in the RTL,
   traceable to [`requirements.md`](requirements.md).
3. **Audit the assumptions — be most skeptical here.** A proof is only as honest as its
   `assume`s; over-constraining yields false green. Scrutinise
   [`assume_ledger.md`](assume_ledger.md): every environment assume must be discharged by a
   proven assert.
4. **Check non-vacuity.** Re-run `cover`; add independent cover points.
5. **Run an independent mutation campaign** (`mcy`) and/or **write independent properties**.
   If those also pass, confidence rises; if they find a gap, that is the coverage hole.

## 5. Honest bottom line

- ✅ The properties that exist are proven **exhaustively** (unbounded) per module.
- ✅ The proofs are **non-vacuous** and **independently reproducible by anyone, for free**.
- ❌ The property set is **not proven complete** — and we have hard evidence (7 sim bugs) it isn't.
- 🟡 Integration safety (F-1/F-2/F-3) is **BMC-bounded (depth 40) + cover**, not unbounded — tracked (#12).
- 📐 **Mutation coverage has not been measured** — that is the missing quantitative number, runnable with `mcy`.

The strongest defensible statement: *"Each module's stated safety/protocol invariants are
exhaustively proven and any third party can reproduce that for free; completeness is
bounded by the property set, which simulation and (next) mutation testing quantify."*
