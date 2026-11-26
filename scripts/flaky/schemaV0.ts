/**
 * Own copy of the schema v0 attempt event. The spec is PAPA-37661 "Event schema v0"; a published schema will
 * replace this copy.
 */
export interface AttemptEventV0 {
  "flaky.schema.version": "0";
  timestamp: string;
  "flaky.source.name": string;
  "flaky.source.has_attempt_data": boolean;
  "vcs.repository.url.full": string;
  "vcs.repository.name": string | null;
  "vcs.provider.name": string | null;
  "vcs.ref.head.name": string;
  "vcs.ref.head.revision": string | null;
  "flaky.vcs.ref.merge.revision": string | null;
  "vcs.ref.base.name": string | null;
  "vcs.change.id": string | null;
  "flaky.vcs.revision.author": string | null;
  "flaky.cicd.provider": string;
  "cicd.pipeline.name": string | null;
  "cicd.pipeline.task.name": string | null;
  "cicd.pipeline.run.id": string;
  "cicd.pipeline.run.url.full": string | null;
  "flaky.cicd.pipeline.run.attempt": number | null;
  "flaky.cicd.trigger": string | null;
  "flaky.cicd.environment": string | null;
  "flaky.test.id": string;
  "flaky.test.framework": string;
  "code.file.path": string;
  "test.suite.name": string | null;
  "test.case.name": string;
  "flaky.test.title_path": string[] | null;
  "flaky.test.project": string | null;
  "flaky.test.attempt": number | null;
  "flaky.test.max_attempts": number | null;
  "flaky.test.execution_count": number | null;
  "test.case.result.status":
    "pass" | "fail" | "skipped" | "timed_out" | "interrupted";
  "flaky.test.expected_status": string | null;
  "flaky.test.error.message": string | null;
  "flaky.test.attempt.duration_ms": number;
  "flaky.test.invocation": "normal" | "snapshot-update" | null;
  "flaky.test.shard": string | null;
  "flaky.test.tags": string[] | null;
  "flaky.test.owner": string | null;
  "flaky.synthetic": boolean | null;
}
