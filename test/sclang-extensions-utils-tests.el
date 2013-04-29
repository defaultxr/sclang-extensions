;;; sclang-extensions-utils-tests.el --- Tests for sclang-extensions-utils.

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Tests for sclang-extensions-utils.

;;; Code:

(require 'sclang-extensions-utils)
(require 's)

;;; Response parsing

(defmacro with-stubbed-response (response-string &rest body)
  "Rebind `scl:blocking-eval-string' to return RESPONSE-STRING in BODY."
  (declare (indent 1))
  `(flet ((scl:blocking-eval-string (&rest _args) ,response-string))
    ,@body))

(defmacro check-parses (desc _sep response-string _-> expected )
  "Check that the given response from SuperCollider is parsed to expected.
* DESC describes the type of response being parsed.
* RESPONSE-STRING is the simulated response from SuperCollider.
* EXPECTED is the expect output by the parser."
  `(check ,(concat "check parses " desc)
     (with-stubbed-response ,response-string
       (should (equal (scl:request ,response-string) ,expected)))))

(check-parses "Arrays to lists"      : "[1, 2, 3]" -> '(1 2 3))

(check-parses "Strings to strings"   : " \"foo\" " -> "foo")

(check-parses "empty strings to nil" : ""          -> nil)

(check-parses "blank strings to nil" : " "         -> nil)

(check-parses "sane requests only"   : "ERROR: "   -> nil)

;;; Syntax

(check "foo.bar form is understood as a member access"
  (with-temp-buffer
    (insert "foo.bar")
    (should (scl:looking-at-member-access?))))

(check "foobar form is not understood as a member access"
  (with-temp-buffer
    (insert "foobar")
    (should (not (scl:looking-at-member-access?)))))

(check "foo(bar) form is not understood as a member access"
  (with-temp-buffer
    (insert "foo(bar)")
    (should (not (scl:looking-at-member-access?)))))

(check "foo [bar] form is not understood as a member access"
  (with-temp-buffer
    (insert "foo [bar]")
    (should (not (scl:looking-at-member-access?)))))

(defmacro move-to-expr-start (desc before _-> after)
  "Check that a given motion moves POINT to an expected position.
* BEFORE and AFTER are strings, where a vertical pipe `|` represents POINT.
* DESC is a description of the test."
  (declare (indent 1))
  (cl-assert (equal (length before) (length after)))
  `(check ,(concat "check move to expression start " desc)
     (with-temp-buffer
       ;; Do all sorts of wacky string replacement. I could have just compared
       ;; the position of point against the pipe character, but comparing
       ;; strings gives you much better error feedback in ERT.
       (insert ,before)
       ;; delete the pipe in BEFORE
       (goto-char (1+ (s-index-of "|" ,before)))
       (delete-char 1)
       (goto-char (scl:expression-start-pos))
       ;; put a pipe where we are now.
       (insert "|")
       ;; assert that the buffer now looks like AFTER.
       (should (equal ,after (buffer-string))))))

;;; As a rule of thumb, scl:expression-start-pos should return the first
;;; non-whitespace charater of the expression, or the start of the line if we're
;;; outside a brace context.

(move-to-expr-start "stops at semicolon at same nesting level"
  "{ foo; foo| }" -> "{ foo;| foo }")

(move-to-expr-start "skips semicolon at different nesting level"
  " { foo; foo } |" -> "| { foo; foo } ")

(move-to-expr-start "stops at comma at same nesting level"
  "( foo, foo| )" -> "( foo,| foo )")

(move-to-expr-start "skips comma at different nesting level"
  " ( foo, foo ) |" -> "| ( foo, foo ) ")

(move-to-expr-start "stops at comma before parenthesized expression"
  "( foo(), foo| )" -> "( foo(),| foo )")

(move-to-expr-start "stops at open brace at same nesting level"
  "{ foo| }" -> "{| foo }")

(move-to-expr-start "bounded at open brace"
  "{| foo }" -> "{ |foo }")

(move-to-expr-start "bounded at open paren"
  "(| foo )" -> "( |foo )")

(move-to-expr-start "bounded at open square"
  "[| foo ]" -> "[ |foo ]")

(move-to-expr-start "skips over braces"
  "foo { bar } |" -> "|foo { bar } ")

(move-to-expr-start "skips over lists"
  " [1, 2, 3] |" -> "| [1, 2, 3] ")

(move-to-expr-start "skips over arglists"
  " foo(bar) |" -> "| foo(bar) ")

(move-to-expr-start "moves to start in multiline expression"
  "foo { \n bar \n } |" -> "|foo { \n bar \n } ")

;;; Class inference of literals
;;;
;;; Should infer the types of literals in code without communicating with
;;; SuperCollider.

(provide 'sclang-extensions-utils-tests)

(defmacro check-infers (expr _-> class)
  "Check that string EXPR is inferred be an instance of CLASS."
  `(check ,(format "check infers %s -> %s" expr class)
     (with-temp-buffer
       (insert ,expr)
       (goto-char (point-max))
       (should (equal (scl:class-of-thing-at-point)
                      ,(symbol-name class))))))

(check-infers "[1,2,3]"           -> Array)
(check-infers "[1,2,3].collect"   -> Array)
(check-infers "1"                 -> Integer)
(check-infers "1.pow"             -> Integer)
(check-infers " \"Hello\" "       -> String)
(check-infers " \"Hello\".world " -> String)
(check-infers " \\Symbol "        -> Symbol)
(check-infers " \\Symbol.method " -> Symbol)

;;; sclang-extensions-utils-tests.el ends here
