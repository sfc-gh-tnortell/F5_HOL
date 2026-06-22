# Plan: Formal Evaluation Challenge (Revised)

## Context

Tested the actual `F5_SUPPORT_TELEMETRY_SEMANTIC_VIEW` with various questions. Found these confirmed failure modes:

**Fixable failures (view needs improvement):**
1. **P1 filter silent failure** - "How many open P1 cases do we have?" returns 0 because view generates `'P1 Critical'` instead of `'P1 - Critical'`. Actual answer is 45. Fix: add AI_SQL_GENERATION instruction with exact priority enum values.
2. **Case escalations** - "Which accounts have the most escalated cases (P3/P4 to P1/P2)?" is refused because view doesn't expose `INITIAL_PRIORITY_CODE`. But the column EXISTS in DIM_SUPPORT_CASE. Fix: add it as a dimension.
3. **SLA thresholds per priority** - "What is our first response SLA compliance by priority?" is refused because thresholds aren't defined. Fix: add AI_SQL_GENERATION instruction defining P1=30min, P2=2hr, P3=8hr, P4=24hr.

**Correct refusals (data genuinely doesn't exist):**
4. **Support engineer** - "Which engineer handled the most P1s?" - no assignee data in schema.
5. **Case reopens** - "How many times has a case been reopened?" - no status history audit log.

## Implementation

Replace Challenge 2 with a 3-phase formal evaluation process:

### Phase 1: Establish Baseline
- Navigate to AI & ML > Cortex Analyst > select support/telemetry semantic view > Evaluations tab
- Create evaluation run using existing VQRs from Module 1
- Record accuracy % and review any failures

### Phase 2: Write 5 New Verified Queries
Provide 5 specific questions with the expected correct SQL. Attendees add these as VQRs to their semantic view, then re-evaluate. The questions are designed so that 3 will fail (revealing gaps) and 2 will pass (establishing that the view handles some complex queries fine).

The 5 questions:
1. "How many open P1 cases do we have right now?" (FAILS - priority enum)
2. "Which accounts have cases that escalated from P3/P4 to P1/P2?" (FAILS - missing dimension)
3. "What is our first response SLA compliance rate by priority?" (FAILS - no threshold definition)
4. "Which accounts have more than 10 cases in the last 6 months?" (PASSES - straightforward)
5. "Show me accounts with declining health scores and high bot traffic" (PASSES - multi-table join works)

### Phase 3: Fix and Re-evaluate
- Review failures from Phase 2 evaluation run
- Click "Improve" on the accuracy box to let Snowflake suggest changes
- Or manually fix using the documented approaches:
  - Add AI_SQL_GENERATION for enum values and thresholds
  - Add missing dimensions (INITIAL_PRIORITY_CODE)
  - Add VQRs for complex join patterns
- Re-run evaluation to measure improvement

### Success Criteria
Measurable: "Started at X% accuracy, ended at Y% after fixes."

## Critical Files
- [HOL/README.md](HOL/README.md) - Challenge 2 section (lines 618-659)
- [HOL/README.html](HOL/README.html) - Challenge 2 HTML equivalent
