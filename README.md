# infragit

Infragit is a git-centric CMDB for your IT environment, where
everything is stored as plain text.

This is an experimental work in progress.

The main idea behind infragit is to free your CMDB from proprietary
tools by managing everything as plain text content using the
ubiquitous distributed version control system, `git`.  Infragit also
uses `ansible` behind the scenes for host and configuration discovery.

By storing everything as plain text, it becomes very simple to write
simple scripts to search and report on your IT inventory.

By storing that plain text in git, we get user authentication,
auditable change logs, and the power of `git bisect` to report on
change over time.

## Author

Infragit was written by Anthony Green.

* email    : green@moxielogic.com
* linkedin : http://linkedin.com/in/green
* twitter  : [@antgreen](https://twitter.com/antgreen)
