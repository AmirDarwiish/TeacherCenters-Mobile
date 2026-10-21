# Architecture and integration notes

- `lib/core/api.dart`: Dio boundary, Arabic ProblemDetails errors, secure session envelope, single-flight refresh, tenant-aware public auth routes and generation guard after sign-out.
- `lib/core/live.dart`: one foreground SignalR connection; watch one thread and one attendance session. Debounced hints invalidate REST reads. Rejoin and refresh after reconnection. WebSockets required; failure falls back to manual REST refresh, never a false live badge.
- `lib/core/widgets.dart`: loading, error and empty states; paginated resource reads with stale-request guards.
- `lib/features/login.dart`: password/OTP state, countdown, selection proof kept only in memory.
- `lib/features/shell.dart`: role-specific home, navigation, profile and private QR card.
- `lib/features/teaching.dart`: scoped groups, sessions, students and authoritative attendance windows.
- `lib/features/courses.dart` / `authoring.dart` / `uploads.dart`: independent LMS courses, curriculum, direct signed MP4/HLS, lesson progress, certificates, bank-question quiz authoring, bounded-memory uploads.
- `lib/features/quiz.dart`: separate legacy/course answer payloads, server attempt IDs/deadlines, saved-answer resume, retryable persistence and explicit submission.
- `lib/features/community.dart`: scoped threads, notifications, assignment submissions and teacher grading.
- `lib/features/payments.dart`: settings-provided methods, hosted checkout and server-confirmed transaction status.

Do not add a payment secret, fixed OTP, tenant-agnostic refresh token, raw transport URL logging, or client-only authorization decision. Permission/custom-role restrictions are enforced by the backend. Signed resource URLs must be renewed by reloading detail after expiry.

Date/times are displayed in the device's local timezone. Dates sent to staff calendar use the server's documented Cairo civil-date range semantics. Weekly schedule conversion is not reimplemented by the client. Course ETags use the returned rowVersion with If-Match.

Native media codec support must be tested on target devices. External YouTube/Vimeo playback does not generate fake internal video progress. Video completion and certificate eligibility remain backend decisions.

See README for explicit remaining screens and unverified native/production behavior.
