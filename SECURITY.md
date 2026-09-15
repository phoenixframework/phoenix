# Security Policy

## Supported versions

Phoenix applies bug fixes only to the latest minor branch. Security patches are
available for the last 4 minor branches:

Phoenix version | Support
:-------------- | :-----------------------------
1.8             | Bug fixes and security patches
1.7             | Security patches only
1.6             | Security patches only
1.5             | Security patches only

## Announcements

[Security advisories will be published on GitHub](https://github.com/phoenixframework/phoenix/security).

## Reporting a vulnerability

[Please disclose security vulnerabilities privately via GitHub](https://github.com/phoenixframework/phoenix/security).

### Scope

A security vulnerability is a flaw in Phoenix that allows an attacker to cross an intended security boundary,
such as compromising confidentiality, integrity, authentication, authorization, or availability with disproportionate effort.

Reports are out of scope when they rely solely on sending an unbounded number of otherwise valid requests to exhaust
finite server resources. Phoenix does not impose universal request or concurrency limits; these are deployment-specific and
should be enforced at the application or infrastructure level. The absence of such limits is not, by itself, a vulnerability.
Reports demonstrating disproportionate resource consumption from a bounded number of requests remain in scope.
