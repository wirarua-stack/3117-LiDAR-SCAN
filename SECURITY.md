# Security reports

Do not post credentials, private scans or sensitive vulnerability details in public issues.

If GitHub's private vulnerability reporting is enabled, use **Security → Report a vulnerability**. If that option is unavailable, open an issue requesting a private reporting channel without describing the vulnerability or including sensitive data. No private reporting endpoint or response-time commitment is currently established.

This project is an early development build. No production security assessment has been completed. Reports affecting the current default branch are welcome; there are no maintained release branches yet.

The capture app currently saves geometry locally. Exported files may contain sensitive building geometry. Capture archives are retained when projects are removed from the library. See implementation documentation for current storage behavior.
