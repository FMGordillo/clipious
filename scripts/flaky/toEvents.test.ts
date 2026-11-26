import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { parseReport, toEvents } from "./toEvents.ts";

test("converts a Flutter reporter log into one event per test attempt", () => {
  const report = readFileSync(new URL("fixtures/retries.jsonl", import.meta.url), "utf8");
  const attempts = toEvents(parseReport(report), {
    repoUrl: "https://github.com/acme/probe",
    repoName: "acme/probe",
    headRef: "master",
    sha: "abc123",
    changeId: null,
    runId: "42",
    runAttempt: 1,
    runUrl: "https://github.com/acme/probe/actions/runs/42",
    trigger: "push",
    workflow: "ci",
    workspace: "/home/runner/work/probe/probe",
    startedAtMs: 0,
  });

  assert.deepEqual(attempts.map((event) => [
    event["test.case.name"],
    event["flaky.test.attempt"],
    event["test.case.result.status"],
  ]), [
    ["outer group inner passes", 1, "pass"],
    ["outer group flaky retried", 1, "fail"],
    ["outer group flaky retried", 2, "pass"],
    ["always fails", 1, "fail"],
    ["always fails", 2, "fail"],
    ["skipped one", 1, "skipped"],
    ["top level", 1, "pass"],
  ]);
});
