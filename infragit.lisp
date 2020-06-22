;;; infragit.lisp

;;; Copyright (C) 2020  Anthony Green <green@moxielogic.com>
;;; Distrubuted under the terms of the MIT license.

(in-package #:infragit)

(log:config :debug)

(defvar *dot-infragit*
  (with-open-file (stream "dot-infragit.tar.gz" :element-type '(unsigned-byte 8))
    (let ((seq (make-array (file-length stream) :element-type '(unsigned-byte 8))))
      (read-sequence seq stream)
      seq)))

(opts:define-opts
  (:name :help
   :description "print this help text"
   :short #\h
   :long "help")
  (:name :version
   :description "print version information"
   :short #\v
   :long "version"))

(defun unknown-option (condition)
  (format t "warning: ~s option is unknown!~%" (opts:option condition)) 
 (invoke-restart 'opts:skip-option))

(defmacro when-option ((options opt) &body body)
  `(let ((it (getf ,options ,opt)))
     (when it
       ,@body)))

(defun usage ()
  (opts:describe
   :prefix "infragit - copyright (C) 2020 Anthony Green <green@moxielogic.com>"
   :suffix "Choose from the following infragit commands:

   init              Create an empty infragit repository or reinitialize an existing one
   scan              Scan infragit roots to update content

Distributed under the terms of MIT License"
   :usage-of "infragit"
   :args     "command"))

(defun infragit-init ()
  "Initialize an infragit directory"
  (log:info "Initializing infragit directory")
  (handler-case
      (truename (ensure-directories-exist ".infragit/"))
    (error ()
      (log:error "Can't initialize .infragit directory")
      nil))
  (inferior-shell:run "git init")
  (uiop:with-current-directory (".infragit/")
    (archive::extract-files-from-archive
     (archive:open-archive 'archive:tar-archive
			   (chipz:make-decompressing-stream 'chipz:gzip
							    (flexi-streams:make-in-memory-input-stream *dot-infragit*))
			   :direction :input)))
  (inferior-shell:run "git add .infragit && git commit -m \"infragit init first commit\""))

(defparameter +libvirt-matcher+
  (cl-ppcre:create-scanner ":>:> libvirt (.+) <:<:"))

(defparameter +arp-matcher+
  (cl-ppcre:create-scanner ":>:> arp (.+) <:<:"))

(defparameter +nmap-matcher+
  (cl-ppcre:create-scanner ":>:> nmap (.+) <:<:"))

(defun generate-host-suffix (str)
  "Generate an 8 character host suffix from a utf8 encoded string"
  (let ((digest (ironclad:make-digest :shake256 :output-length 4)))
    (ironclad:byte-array-to-hex-string
     (ironclad:digest-sequence digest (flexi-streams:string-to-octets str :external-format :utf8)))))

(defun process-scan-output/libvirt (root-dir libvirt-xml-file)
  (log:debug "Processing libvirt file ~A" libvirt-xml-file)
  (xpath:do-node-set (domain (xpath:evaluate "/infragit/domain"
					     (cxml:parse-file libvirt-xml-file (stp:make-builder))))
    (let* ((name (xpath:evaluate "string(name)" domain))
	   (uuid (xpath:evaluate "string(uuid)" domain))
	   (host-dir (format nil "hosts/~A-~A/" name (generate-host-suffix uuid))))
      (ensure-directories-exist host-dir)
      (inferior-shell:run (format nil "ln -f -s -r ~A ~A/hosts/" host-dir root-dir))
      (xpath:do-node-set (mac-address (xpath:evaluate "devices/interface/mac/@address" domain))
	(let ((mac-dir (format nil "~Amacs/~A" root-dir (string-downcase (stp:value mac-address)))))
	  (inferior-shell:run (format nil "mkdir -p ~A/macs && ln -f -s -r ~A ~A/macs" host-dir mac-dir host-dir))
	  (inferior-shell:run (format nil "mkdir -p ~A && ln -f -s -r ~A ~A/host"
				      mac-dir host-dir mac-dir)))))))

(defun process-scan-output/nmap (root-dir nmap-file)
  (log:debug "Processing nmap file ~A" nmap-file)
  (xpath:do-node-set (host-node (xpath:evaluate "/nmaprun/host"
					      (cxml:parse-file nmap-file (stp:make-builder))))
    (let ((ipv4 nil)
	  (ipv6 nil)
	  (mac nil)
	  (vendor nil))
      (xpath:do-node-set (node (xpath:evaluate "address[@addrtype='mac']/@addr" host-node))
	(setf mac (string-downcase (xpath:evaluate "string()" node))))
      (xpath:do-node-set (node (xpath:evaluate "address[@addrtype='mac']/@vendor" host-node))
	(setf vendor (xpath:evaluate "string()" node)))
      (xpath:do-node-set (node (xpath:evaluate "address[@addrtype='ip4']/@addr" host-node))
	(setf ipv4 (xpath:evaluate "string()" node)))
      (xpath:do-node-set (node (xpath:evaluate "address[@addrtype='ipv6']/@addr" host-node))
	(setf ipv6 (xpath:evaluate "string()" node)))

      (when mac
	(let ((mac-dir (format nil "~Amacs/~A" root-dir mac)))
	  (inferior-shell:run (format nil "mkdir -p ~A" mac-dir))
	  (when vendor
	    (inferior-shell:run (format nil "echo '~A' > ~A/vendor" vendor mac-dir)))
	  (when ipv4
	    (inferior-shell:run (format nil "echo '~A' > ~A/ipv4" ipv4 mac-dir)))
	  (when ipv6
	    (inferior-shell:run (format nil "echo '~A' > ~A/ipv6" ipv6 mac-dir))))))))

(defparameter +arp-line-matcher+ "^(.+) dev (.*) lladdr ([a-f0-9:]+) .*")

(defun process-scan-output/arp (root-dir arp-file)
  (log:debug "Processing arp file ~A" arp-file)
  (with-open-file (stream arp-file)
    (loop for line = (read-line stream nil)
	  while line do
	    (multiple-value-bind (match map)
		(cl-ppcre:scan-to-strings +arp-line-matcher+ line)
	      (when match
		(let ((mac-dir (format nil "~Amacs/~A" root-dir (aref map 2))))
		  (if (position #\: (aref map 0) :test #'equal)
		      ;; This is an ipv6 address
		      (inferior-shell:run (format nil "mkdir -p ~A && echo '~A' > ~A/ipv6" mac-dir (aref map 0) mac-dir))
		      ;; This is an ipv4 address
		      (inferior-shell:run (format nil "mkdir -p ~A && echo '~A' > ~A/ipv4" mac-dir (aref map 0) mac-dir)))))))))

(defun process-scan-output (dir output)
  (multiple-value-bind (match filename-array)
      (cl-ppcre:scan-to-strings +libvirt-matcher+ output)
    (when match
      (let ((filename (aref filename-array 0)))
	(process-scan-output/libvirt dir filename))))
  (multiple-value-bind (match filename-array)
      (cl-ppcre:scan-to-strings +arp-matcher+ output)
    (when match
      (let ((filename (aref filename-array 0)))
	(process-scan-output/arp dir filename))))
  (multiple-value-bind (match filename-array)
      (cl-ppcre:scan-to-strings +nmap-matcher+ output)
    (when match
      (let ((filename (aref filename-array 0)))
	(process-scan-output/nmap dir filename)))))

(defun infragit-scan ()
  "Scan infragit roots to update content"
  (if (not (probe-file ".infragit/"))
      (log:error "This is not an infragit directory")
      (progn
	(log:debug "Searching for _root...")
	(cl-fad:walk-directory
	 #p"." (lambda (filename)
		 (let ((root-dir (directory-namestring filename)))
		   (log:debug "ansible-playbook -i ~A .infragit/playbook/infragit-discover.yaml" filename)
		   (ensure-directories-exist (format nil "~A/hosts/" root-dir))
		   (ensure-directories-exist (format nil "~A/macs/" root-dir))
		   (process-scan-output
		    root-dir
		    (inferior-shell:run/ss
		     (format nil "ansible-playbook -i ~A .infragit/playbook/infragit-discover.yaml" filename)))))
	 :follow-symlinks nil
	 :test (lambda (filename)
		 (string= "_root" (file-namestring filename)))))))
  
(defun main (args)
  (multiple-value-bind (options free-args)
		       (handler-case
			   (handler-bind ((opts:unknown-option #'unknown-option))
			     (opts:get-opts))
			 (opts:missing-arg (condition)
					   (format t "fatal: option ~s needs an argument!~%"
						   (opts:option condition)))
			 (opts:arg-parser-failed (condition)
						 (format t "fatal: cannot parse ~s as argument of ~s~%"
							 (opts:raw-arg condition)
							 (opts:option condition))))
		       (when-option (options :help)
				    (usage))
		       (if (not (eq 1 (length free-args)))
			   (usage)
			 (alexandria:switch ((car free-args) :test #'equal)
					    ("init"      (infragit-init))
					    ("scan"      (infragit-scan))
					    (t (log:error "Unrecognized command ~A" (car free-args)))))))
