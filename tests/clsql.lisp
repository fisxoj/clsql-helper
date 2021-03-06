(defpackage :clsql-helper-test
  (:use :cl :clsql-helper :lisp-unit2 :iter)
  (:shadow :run-tests))

(in-package :clsql-helper-test)
(cl-interpol:enable-interpol-syntax)
(clsql-sys:file-enable-sql-reader-syntax)

(defun run-tests (&key suites tests)
  (let* ((*package* (find-package :clsql-helper-test)))
    (lisp-unit2:run-tests
     :tests tests
     :tags suites
     :name :clsql-helper
     :run-contexts #'lisp-unit2:with-summary-context)))

(define-test test-clsql-parse-and-print (:tags '(dates))
  (let ((dates
          `(("7/1/2005"
             "07/01/2005 00:00:00" "7/1/2005" "2005-07-01" "2005-07-01 00:00:00")
            ("\"7/1/2005\""
             "07/01/2005 00:00:00" "7/1/2005" "2005-07-01" "2005-07-01 00:00:00")
            ("12/22/2009"
             "12/22/2009 00:00:00" "12/22/2009" "2009-12-22" "2009-12-22 00:00:00")
            ("09/02/2009"
             "09/02/2009 00:00:00" "9/2/2009" "2009-09-02" "2009-09-02 00:00:00")
            ("09/02/09"
             "09/02/2009 00:00:00" "9/2/2009" "2009-09-02" "2009-09-02 00:00:00")
            ("09/02/09 12:15"
             "09/02/2009 12:15:00" "9/2/2009" "2009-09-02" "2009-09-02 12:15:00")
            ("9/2/2009 12:15:02"
             "09/02/2009 12:15:02" "9/2/2009" "2009-09-02" "2009-09-02 12:15:02")
            ("9/2/2009 12:15:02 PM"
             "09/02/2009 12:15:02" "9/2/2009" "2009-09-02" "2009-09-02 12:15:02")
            ("9/2/2009 11:15:02 PM"
             "09/02/2009 23:15:02" "9/2/2009" "2009-09-02" "2009-09-02 23:15:02")
            ("9/2/2009 11:15:02 AM"
             "09/02/2009 11:15:02" "9/2/2009" "2009-09-02" "2009-09-02 11:15:02")
            ("9/2/2009 11:15:02"
             "09/02/2009 11:15:02" "9/2/2009" "2009-09-02" "2009-09-02 11:15:02")
            ("2009-02-20"
             "02/20/2009 00:00:00" "2/20/2009" "2009-02-20" "2009-02-20 00:00:00")
            ("2009-02-20 11:15:02"
             "02/20/2009 11:15:02" "2/20/2009" "2009-02-20" "2009-02-20 11:15:02")
            ("2009-02-20 11:15:02,,0"
             "02/20/2009 11:15:02" "2/20/2009" "2009-02-20" "2009-02-20 11:15:02")
            ("2009-02-20T11:15:02Z"
             "02/20/2009 11:15:02" "2/20/2009" "2009-02-20" "2009-02-20 11:15:02" )
            ("2009-12-20T11:15:02Z"
             "12/20/2009 11:15:02" "12/20/2009" "2009-12-20" "2009-12-20 11:15:02" )
	    ("2012-05-01T12:56:17"
	     "05/01/2012 12:56:17" "5/1/2012" "2012-05-01" "2012-05-01 12:56:17")
            ("'2012-05-01T12:56:17'"
	     "05/01/2012 12:56:17" "5/1/2012" "2012-05-01" "2012-05-01 12:56:17")
            ("432" nil)
            )))
    (iter (for (d c-time c-date c-iso-date c-iso-time) in dates)
      (for dt = (convert-to-clsql-datetime d))
      (for stime = (print-nullable-datetime dt))
      (for sdate = (print-nullable-date dt))
      (for iso-date = (iso8601-datestamp dt))
      (for iso-time = (iso8601-timestamp dt))
      (assert-equal c-time stime d)
      (assert-equal c-date sdate d)
      (assert-equal c-iso-time iso-time d)
      (assert-equal c-iso-date iso-date d))))

(define-test test-expression-building (:tags '(expressions))
  (assert-false (clsql-ands ()))
  (assert-false (clsql-and () () ()))
  (assert-false (clsql-and))
  (assert-false (clsql-ors ()))
  (assert-false (clsql-or () () ()))
  (assert-false (clsql-or))

  ;; verify that expression collapsing is doing its thing
  ;; and that strings turn correctly into expressions
  (let* ((exp [= [a] [b]])
         (str (clsql:sql exp))
         (and-str (clsql:sql [and exp exp exp]))
         (or-str (clsql:sql [or exp exp exp])))
    (assert-equal str (clsql:sql (clsql-and () () () () exp)))
    (assert-equal
        and-str (clsql:sql (clsql-and () () () ()
                                   exp () ()
                                   exp
                                   str () ())))
    (assert-equal
        or-str (clsql:sql (clsql-or () () () ()
                                      exp () ()
                                      exp
                                      str() ())))))

(define-test test-db-string (:tags '(expressions))
  (assert-equal "'a sql ''string'' quoting test'"
      (db-string "a sql 'string' quoting test")))

(clsql-sys:def-view-class pkey-test-1 ()
    ((name :column "first_name" :accessor name
           :db-constraints nil :initform nil :type clsql-sys:varchar
           :initarg :name)
     (id :column "ID" :accessor id :db-kind :key :db-constraints
         (:not-null :identity) :type integer :initarg :id)))

(clsql-sys:def-view-class pkey-test-2 ()
    ((name :column "first_name" :accessor name :db-kind :key
           :db-constraints nil :initform nil :type clsql-sys:varchar
           :initarg :name)
     (id :accessor id :db-kind :key :db-constraints
         (:not-null) :type integer :initarg :id)))

(clsql-sys:def-view-class pkey-test-3 ()
    ((name :column "first_name" :accessor name
           :db-constraints nil :initform nil :type clsql-sys:varchar
           :initarg :name)
     (id :accessor id :db-kind :key :db-constraints
         (:not-null) :type integer :initarg :id))
 (:default-initargs :VIEW-TABLE "MyTable"))

(define-test test-pkey-stuff (:tags '(keys expressions))
  (assert-equal
      '(id)
      (primary-key-slot-names (make-instance 'pkey-test-1)))
  (assert-equal
      '(id)
      (primary-key-slot-names (find-class 'pkey-test-1)))
  (assert-equal
      '(id)
      (primary-key-slot-names 'pkey-test-1))

  (assert-equal
      '(name id)
      (primary-key-slot-names (make-instance 'pkey-test-2)))
  (assert-equal
      '(name id)
      (primary-key-slot-names (find-class 'pkey-test-2)))
  (assert-equal
      '(name id)
      (primary-key-slot-names 'pkey-test-2))

  (let ((pk1 (make-instance 'pkey-test-1 :name "russ" :id 1))
        (pk2 (make-instance 'pkey-test-2 :name "samael" :id 2)))
    (assert-equal "(\"ID\" = 1)"
        (clsql:sql (primary-key-where-clauses pk1)))
    (assert-equal "((\"first_name\" = 'samael') AND (ID = 2))"
        (clsql:sql (primary-key-where-clauses pk2)))
    ))

(define-test test-db-eql (:tags '(keys expressions))
  (let ((pk1 (make-instance 'pkey-test-1 :name "russ" :id 1))
        (pk1.2 (make-instance 'pkey-test-1 :name "Bobby" :id 1))
        (pk1.3 (make-instance 'pkey-test-1 :name "Bobby" :id 2))
        (pk2 (make-instance 'pkey-test-2 :name "samael" :id 2))
        (pk2.2 (make-instance 'pkey-test-2 :name "samael" :id 2)))
    (assert-true (db-eql pk1 pk1))
    (assert-true (db-eql pk1.2 pk1))
    (assert-true (db-eql pk2 pk2.2))
    (assert-false (db-eql pk1 pk1.3))
    (assert-false (db-eql pk2 pk1))))

(define-test table-and-column-expressions (:tags '(expressions))
  (assert-equal "\"foo\"" (column-name-string "foo"))
  (assert-equal "FOO" (column-name-string 'foo))
  (assert-equal "\"foo\"" (table-name-string "foo"))
  (assert-equal "FOO" (table-name-string 'foo))
  )


#+clsql-sqlite3
(progn
 (defparameter +test-db+
   (princ-to-string
    (asdf:system-relative-pathname :clsql-helper "tests/test.sqlite3")))

 (defmacro with-test-db (()&body body)
   `(clsql-sys:with-database
     (clsql-sys:*default-database*
      (list +test-db+) :database-type :sqlite3)
     ,@body))

 (defvar *log* t)
 (defun sql-log (str &rest args)
   (apply #'format *log* str args))

 (define-test log-test (:tags '(sqlite3))
   (assert-true
       (search
        "
 SELECT id, name
   FROM test
   WHERE ID=1"
        (with-output-to-string (*log*)
          (with-test-db ()
            (log-database-command (sql-log)
              (clsql:query "SELECT id, name FROM test WHERE ID=1"))))
        :test #'string-equal))
   ))

(define-test clsql-date/times->utime-test (:tags '(dates))
  (let ((utime 3542038020))
    (multiple-value-bind (sec min hr date month year day daylight-savings-p zone)
			  (decode-universal-time utime)
	(declare (ignore sec min hr date month year day))
	;; converts from local-time to UTC
	(assert-eql utime
		    (+
		     ;; calculate offset between local time and UTC
		     (* 60 60 (- zone (if daylight-savings-p 1 0)))
		     (clsql-helper:clsql-date/times->utime
		      (clsql-sys:utime->time utime))))
      ;; use the default timezone from encode-universal-time
      (assert-eql utime (clsql-helper:clsql-date/times->utime
			 (clsql-sys:utime->time utime) nil)))))

;; verify that whitespace doesn't matter when generating a hash for migrations
(define-test migrations/whitespace-in-hash (:tags '(migrations))
  (let ((hash (clsql-helper::%sql-hash "A B C")))
    (assert-equal hash (clsql-helper::%sql-hash "A B  C") "more spaces")
    (assert-equal hash (clsql-helper::%sql-hash "A
B C") "newline")))


(define-test connection-db-specs (:tags '(connections))
  (let ((*connection-database* (clsql-helper::new-connection-database)))
    (add-connection-spec
     :a '(("/tmp/a.db") :database-type :sqlite3))
    (add-connection-spec
     :b '(("/tmp/b.db") :database-type :sqlite3))
    (add-connection-spec
     :a '(("/tmp/a2.db") :database-type :sqlite3))
    (add-connection-spec
     :c '(("/tmp/c.db") :database-type :sqlite3))

    (assert-equal 3 (length (clsql-helper::names->spec *connection-database*)))
    (assert-equal '(("/tmp/a2.db") :database-type :sqlite3)
                  (get-connection-spec :a))
    (remove-connection-spec :a)
    (assert-equal 2 (length (clsql-helper::names->spec *connection-database*)))
    ))

(define-test connect-db-conns (:tags '(connections))
  (let ((*connection-database* (clsql-helper::new-connection-database)))
    (add-connection-spec :a '(("/tmp/a.db") :database-type :sqlite3))
    (add-connection-spec :b '(("/tmp/b.db") :database-type :sqlite3))
    (add-connection-spec :c '(("/tmp/c.db") :database-type :sqlite3))
    (flet ((in-db? (name)
             (cl-ppcre:scan
              #?"(?i)/tmp/${name}.db"
              (clsql-sys:database-name clsql-sys:*default-database*))))
    (with-a-database (:a)
      (assert-true (in-db? :a))
      (with-a-database (:b)
        (assert-true (in-db? :b))
        (with-a-database (:a)
          (assert-true (in-db? :a))
          (with-a-database (:c)
            (assert-true (in-db? :c))
            (with-a-database ('(("/tmp/b.db") :database-type :sqlite3))
              (assert-true (in-db? :b))
              (assert-equal 3 (length
                               (clsql-helper::names->conn *connection-database*)))))))))))


