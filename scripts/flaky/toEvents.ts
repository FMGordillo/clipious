import { createHash } from "node:crypto";
import { isAbsolute, relative } from "node:path";
import { z } from "zod";

import type { AttemptEventV0 } from "./schemaV0.ts";

export interface RunContext {
  repoUrl: string;
  repoName: string;
  headRef: string;
  sha: string;
  changeId: string | null;
  runId: string;
  runAttempt: number;
  runUrl: string;
  trigger: string | null;
  workflow: string | null;
  /** Checkout root; absolute suite paths are made relative to it. */
  workspace: string;
  /** Wall-clock time of the reporter's `time: 0`; the JSON reporter only has times relative to its start. */
  startedAtMs: number;
}

const reporterEventSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("suite"),
    suite: z.object({ id: z.number(), platform: z.string(), path: z.string().nullable() }),
  }),
  z.object({
    type: z.literal("group"),
    group: z.object({ id: z.number(), name: z.string() }),
  }),
  z.object({
    type: z.literal("testStart"),
    time: z.number(),
    test: z.object({ id: z.number(), name: z.string(), suiteID: z.number(), groupIDs: z.array(z.number()) }),
  }),
  z.object({ type: z.literal("error"), testID: z.number(), error: z.string() }),
  z.object({
    type: z.literal("print"),
    time: z.number(),
    testID: z.number(),
    messageType: z.string(),
    message: z.string(),
  }),
  z.object({
    type: z.literal("testDone"),
    time: z.number(),
    testID: z.number(),
    result: z.enum(["success", "failure", "error"]),
    skipped: z.boolean(),
    hidden: z.boolean(),
  }),
]);

export type ReporterEvent = z.infer<typeof reporterEventSchema>;

const REPORTED_TYPES = new Set<string>(reporterEventSchema.options.map((option) => option.shape.type.value));

const lineSchema = z.object({ type: z.string() });

interface Attempt {
  start: number;
  end: number;
  error: string | null;
}

interface TestRun {
  name: string;
  suiteId: number;
  groupIds: number[];
  attempts: Attempt[];
  done: Extract<ReporterEvent, { type: "testDone" }> | null;
}

/** Parses the `json` reporter output (`flutter test --file-reporter json:<file>`), one JSON object per line. */
export function parseReport(report: string): ReporterEvent[] {
  return report
    .split("\n")
    .filter((line) => line.trim() !== "")
    .flatMap((line) => {
      const raw: unknown = JSON.parse(line);
      return REPORTED_TYPES.has(lineSchema.parse(raw).type) ? [reporterEventSchema.parse(raw)] : [];
    });
}

function localName(name: string, parent: string): string {
  return parent !== "" && name.startsWith(`${parent} `) ? name.slice(parent.length + 1) : name;
}

/**
 * One v0 event per test attempt. A retried test keeps one `testID`: package:test prints `Retry: <name>` after
 * each failed attempt and sends one `testDone` with the final result.
 * shortcut: a test that itself prints exactly `Retry: <its name>` reads as a retry; harmless while nobody does.
 */
export function toEvents(events: ReporterEvent[], context: RunContext): AttemptEventV0[] {
  const suites = new Map<number, { platform: string; path: string | null }>();
  const groups = new Map<number, string>();
  const tests = new Map<number, TestRun>();
  for (const event of events) {
    if (event.type === "suite") {
      suites.set(event.suite.id, event.suite);
    } else if (event.type === "group") {
      groups.set(event.group.id, event.group.name);
    } else if (event.type === "testStart") {
      tests.set(event.test.id, {
        name: event.test.name,
        suiteId: event.test.suiteID,
        groupIds: event.test.groupIDs,
        attempts: [{ start: event.time, end: event.time, error: null }],
        done: null,
      });
    } else {
      const test = tests.get(event.testID);
      const attempt = test?.attempts.at(-1);
      if (test === undefined || attempt === undefined || test.done !== null) {
        continue;
      }
      if (event.type === "error") {
        attempt.error ??= event.error.slice(0, 4096);
      } else if (event.type === "print") {
        if (event.messageType === "print" && event.message === `Retry: ${test.name}`) {
          attempt.end = event.time;
          test.attempts.push({ start: event.time, end: event.time, error: null });
        }
      } else {
        attempt.end = event.time;
        test.done = event;
      }
    }
  }

  const onMain = context.headRef === "main" || context.headRef === "master";
  return [...tests.values()].flatMap((test) => {
    const suite = suites.get(test.suiteId);
    const { done } = test;
    // Tests without groups are the runner's "loading <file>" steps, not tests.
    if (done === null || done.hidden || suite?.path == null || test.groupIds.length === 0) {
      return [];
    }
    const file = isAbsolute(suite.path) ? relative(context.workspace, suite.path) : suite.path;
    const groupNames = test.groupIds.map((id) => groups.get(id) ?? "").filter((name) => name !== "");
    const localGroups = groupNames.map((name, index) => localName(name, groupNames[index - 1] ?? ""));
    const titlePath = [file, ...localGroups, localName(test.name, groupNames.at(-1) ?? "")];
    const testId = createHash("sha256")
      .update([context.repoUrl, suite.platform, ...titlePath].join("|"))
      .digest("hex")
      .slice(0, 32);
    const finalStatus = done.skipped ? "skipped" : done.result === "success" ? "pass" : "fail";
    return test.attempts.map((attempt, index): AttemptEventV0 => ({
      "flaky.schema.version": "0",
      timestamp: new Date(context.startedAtMs + attempt.start).toISOString(),
      "flaky.source.name": "flutter-test",
      "flaky.source.has_attempt_data": true,
      "vcs.repository.url.full": context.repoUrl,
      "vcs.repository.name": context.repoName,
      "vcs.provider.name": "github",
      "vcs.ref.head.name": context.headRef,
      "vcs.ref.head.revision": onMain ? context.sha : null,
      "flaky.vcs.ref.merge.revision": onMain ? null : context.sha,
      "vcs.ref.base.name": null,
      "vcs.change.id": context.changeId,
      "flaky.vcs.revision.author": null,
      "flaky.cicd.provider": "github-actions",
      "cicd.pipeline.name": context.workflow,
      "cicd.pipeline.task.name": null,
      "cicd.pipeline.run.id": context.runId,
      "cicd.pipeline.run.url.full": context.runUrl,
      "flaky.cicd.pipeline.run.attempt": context.runAttempt,
      "flaky.cicd.trigger": context.trigger,
      "flaky.cicd.environment": null,
      "flaky.test.id": testId,
      "flaky.test.framework": "flutter",
      "code.file.path": file,
      "test.suite.name": localGroups.at(-1) ?? null,
      "test.case.name": test.name,
      "flaky.test.title_path": titlePath,
      "flaky.test.project": suite.platform,
      "flaky.test.attempt": index + 1,
      "flaky.test.max_attempts": null,
      "flaky.test.execution_count": test.attempts.length,
      "test.case.result.status": index === test.attempts.length - 1 ? finalStatus : "fail",
      "flaky.test.expected_status": null,
      "flaky.test.error.message": attempt.error,
      "flaky.test.attempt.duration_ms": attempt.end - attempt.start,
      "flaky.test.invocation": "normal",
      "flaky.test.shard": null,
      "flaky.test.tags": null,
      "flaky.test.owner": null,
      "flaky.synthetic": false,
    }));
  });
}
