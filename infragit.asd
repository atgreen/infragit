;;;; infragit.asd

(asdf:defsystem #:infragit
  :description "A git workflow for a text based CMDB"
  :author "Anthony Green <green@moxielogic.com>"
  :license "MIT"
  :depends-on (#:cl-template
	       #:unix-opts
	       #:alexandria
	       #:chipz
	       #:archive
	       #:inferior-shell
	       #:log4cl
	       #:uiop
	       #:flexi-streams
	       #:cl-ppcre
	       #:cxml
	       #:xpath
	       #:cxml-stp
	       #:ironclad
	       #:str
	       #:cl-fad)
  :serial t
  :components ((:file "package")
               (:file "infragit")))

