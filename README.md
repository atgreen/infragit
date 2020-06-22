# infragit

Infragit is a plain text git-centric CMDB for your IT environment.

This is an experimental work in progress.

The main idea behind infragit is to free your CMDB from proprietary
tools by managing everything as plain text content using the
ubiquitous distributed version control system, `git`.  Infragit also
uses `ansible` behind the scenes for host and configuration discovery.

Storing everything as plain text simplifies the process of creating 
custom scripts to search and report on your IT inventory.

By storing that plain text in git we get auditable change logs, 
user authentication, access control, and the power of `git bisect` to 
report on change over time.

## Author

Infragit was written by Anthony Green.

* email    : green@moxielogic.com
* linkedin : http://linkedin.com/in/green
* twitter  : [@antgreen](https://twitter.com/antgreen)
