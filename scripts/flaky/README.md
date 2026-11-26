# Flutter test attempt reporting

Vendored from [flaky-demo's Flutter uploader](https://github.com/fmgordillo-dyna/flaky-demo/tree/2bc8db90c0f36bb1e75ad507b738cbf5fcd8ab92/flutter-uploader) under the [MIT license](LICENSE).

CI writes the offline Flutter suite's JSON report without changing console output or the test exit status. The uploader converts the report into one schema v0 event per test attempt and posts the events in one request, even when tests fail.

Set the GitHub Actions secrets `FLAKY_INGEST_URL` to the Dynatrace ingest source endpoint and `FLAKY_INGEST_TOKEN` to an ingest-scoped token. Runs without both secrets, including fork pull requests, skip the upload. Reporting failures do not fail CI.

The uploader reports retries when tests are configured to retry; it does not enable retries. Do not upload reports from `--update-goldens` runs, which the uploader cannot distinguish from normal runs.

To test the converter locally with Node.js 24, run `npm ci` and `node --test` from this directory.
