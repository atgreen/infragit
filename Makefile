infragit: *.asd *.lisp Makefile dot-infragit.tar.gz
	buildapp --output infragit \
		--asdf-path `pwd`/.. \
		--asdf-tree ~/quicklisp/dists/quicklisp/software \
		--load-system infragit \
		--compress-core \
		--entry "infragit:main"

dot-infragit.tar.gz:
	(cd dot-infragit; find . -name \*~ | xargs rm -f; tar cvfz ../dot-infragit.tar.gz *)

clean:
	-rm -f infragit
	-rm dot-infragit.tar.gz
	-rm -f *~
