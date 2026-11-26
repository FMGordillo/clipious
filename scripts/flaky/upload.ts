import { readFileSync, statSync } from "node:fs";

import { parseReport, type RunContext, toEvents } from "./toEvents.ts";

/** One bulk POST of schema v0 events. No retry, and the exit code is always 0: a failed upload must not fail CI. */
async function upload(): Promise<void> {
  const {
    FLAKY_INGEST_URL: url,
    FLAKY_INGEST_TOKEN: token,
    GITHUB_REPOSITORY: repo,
    GITHUB_RUN_ID: runId,
  } = process.env;
  if (!url || !token) {
    console.log("upload skipped: FLAKY_INGEST_URL or FLAKY_INGEST_TOKEN is not set");
    return;
  }
  if (!repo || !runId) {
    console.log("upload skipped: not running in GitHub Actions");
    return;
  }
  const file = process.env.RESULTS_FILE ?? "test-results.json";
  const events = parseReport(readFileSync(file, "utf8"));
  const reportEndMs = Math.max(0, ...events.map((event) => ("time" in event ? event.time : 0)));
  const server = process.env.GITHUB_SERVER_URL ?? "https://github.com";
  const context: RunContext = {
    repoUrl: `${server}/${repo}`,
    repoName: repo,
    headRef: process.env.GITHUB_HEAD_REF || process.env.GITHUB_REF_NAME || "main",
    sha: process.env.GITHUB_SHA ?? "",
    changeId: /^refs\/pull\/(\d+)\//.exec(process.env.GITHUB_REF ?? "")?.[1] ?? null,
    runId,
    runAttempt: Number(process.env.GITHUB_RUN_ATTEMPT ?? "1"),
    runUrl: `${server}/${repo}/actions/runs/${runId}`,
    trigger: process.env.GITHUB_EVENT_NAME ?? null,
    workflow: process.env.GITHUB_WORKFLOW ?? null,
    workspace: process.env.GITHUB_WORKSPACE ?? process.cwd(),
    startedAtMs: statSync(file).mtimeMs - reportEndMs,
  };
  const attempts = toEvents(events, context);
  const response = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(attempts),
  });
  console.log(`uploaded ${attempts.length} attempts: HTTP ${response.status}`);
}

upload().catch((error: unknown) => {
  console.log(`upload failed: ${error instanceof Error ? error.message : String(error)}`);
});
