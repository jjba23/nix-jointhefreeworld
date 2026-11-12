;; maak.scm -- the tasks of nix-jointhefreeworld

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; nix-jointhefreeworld is free software, released under the MIT license: you
;; may use, copy, modify, merge, publish, distribute, sublicense and sell it,
;; provided that the copyright notice and this permission notice are included in
;; all copies or substantial portions of it; see LICENSE.

;; nix-jointhefreeworld is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  In no event shall the authors or copyright
;; holders be liable for any claim, damages or other liability arising from it.

(define-module (maak)
  #:declarative? #t
  #:use-module (ice-9 format)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (maak maak)
  ;; Three tasks, and every helper below private: `maak --list' is the menu, not
  ;; the implementation.
  #:export (default check-updates update))

;; ====== Maak constants ======

;; The lock the set ships.  It is the release: what a consumer of
;; `git+https://github.com/jjba23/nix-jointhefreeworld' builds is exactly the
;; revisions in here, which is why these tasks read it and not `flake.nix'.
;; flake.nix says which tag a project released at; the lock says what this
;; channel pins today, branches included.
(define lock-file
  "flake.lock")

;; The three flakes of the set.  An input is declared in exactly one of them --
;; the set's own, or one of the halves it follows -- and that is where its pin is
;; edited and its branch moved.  Searching them beats carrying a table of which
;; project belongs to which half, which would go stale the first time a project
;; is added.
(define flake-files
  '("flake.nix" "emacs/flake.nix" "guile-deps/flake.nix"))

;; The input that carries nixpkgs.  It is checked like every other pin, but
;; reported on a line of its own, left out of the count and never moved by
;; `maak update': it follows `nixos-unstable', which moves every day by design
;; and which changes the dependencies under every package, so moving it is a
;; decision of its own rather than a step of a release.
(define nixpkgs-input
  "nixpkgs")

;; Pins that are behind on purpose, and why.  A release that cannot be packaged
;; is not an update, and a check that keeps naming one teaches the reader to skim
;; the report; so the pin stays where it is and its line says why.  Each entry is
;; the input's name and the reason, printed as written.  When the reason stops
;; being true the release moves like any other and the entry goes -- which is why
;; a hold that is no longer behind is reported as stale rather than kept quiet.
(define held-pins
  '(("maak-el"
     . "its `maak-test-project-maak-file-is-wired' test still expects the tasks of the commit before `agents' was added, so the suite fails on trunk")
    ("veritas-el"
     . "v0.2.0 and v0.2.1 write a `;;; Version:' header its default.nix does not read")))

;; Nix spells enabled features longer than a task should have to explain them;
;; passing them on every call means the tasks work on a machine where flakes are
;; not enabled in nix.conf yet, and cost nothing where they are.
(define nix-argv
  (list "nix" "--extra-experimental-features" "nix-command flakes"))

;; ====== Reading what is pinned ======
;;
;; flake.lock is JSON, and this file stays an ordinary Guile module with no JSON
;; library behind it: Nix reads JSON already, so one expression over
;; `builtins.fromJSON' turns the lock into one tab separated line per input --
;; name, type, URL, ref, revision.  `nix-instantiate' rather than `nix eval'
;; because it needs no experimental features, and `--raw' because the result is
;; already the text these tasks want.  `nix-instantiate' is in a flake's world by
;; definition: this set cannot be built without it.

(define lock-query
  (text
   "let"
   (format #f "  lock = builtins.fromJSON (builtins.readFile ./~a);" lock-file)
   "  nodes = lock.nodes;"
   "  lockedOf = node: node.locked or { };"
   "  originalOf = node: node.original or { };"
   "  typeOf = node: (lockedOf node).type or (originalOf node).type or \"unknown\";"
   "  refOf = node: (lockedOf node).ref or (originalOf node).ref or \"\";"
   "  revOf = node: (lockedOf node).rev or \"\";"
   "  urlOf = node:"
   "    let l = lockedOf node; o = originalOf node; in"
   "    if typeOf node == \"github\""
   "    then \"https://github.com/${l.owner or o.owner}/${l.repo or o.repo}\""
   "    else l.url or o.url or \"\";"
   "  describe = name:"
   "    let node = nodes.${name}; in"
   "    \"${name}\\t${typeOf node}\\t${urlOf node}\\t${refOf node}\\t${revOf node}\";"
   "in"
   "builtins.concatStringsSep \"\\n\" (map describe (builtins.attrNames nodes))"))

(define (query command)
  "Run COMMAND and return what it printed, even when the run is a dry run.

`capture' answers nothing in a dry run, which is right for a command that exists
only to change something.  Reading what a pin says changes nothing, and a dry run
of `update' is only worth having when it can say what it would move, so the
reading half of these tasks goes through here."
  (let* ((process (open-input-pipe command))
         (output (get-string-all process)))
    (close-pipe process)
    output))

(define (locked-inputs)
  "Return what LOCK-FILE pins, as (NAME TYPE URL REF REV) lists, in name order."
  (unless (file-exists? lock-file)
    (task-error "no ~a in this directory" #:args (list lock-file)
                #:hint "Run this task from the root of the nix-jointhefreeworld checkout."))
  (map (lambda (line) (string-split line #\tab))
       (remove string-null?
               (string-lines
                (string-trim-right
                 (query (string-join (list "nix-instantiate" "--eval" "--strict" "--raw"
                                           "--expr" (shell-quote lock-query))
                                     " ")))))))

;; ====== Reading the projects ======

(define (ls-remote . arguments)
  "Run `git ls-remote' with ARGUMENTS, returning its lines, or #f when it fails.

A repository that is gone -- a project that moved and left no forwarding, a URL
with a typo in it -- answers nothing, and for these tasks that is a finding
rather than an error: it is reported against the pin that names it.  A lost
packet answers nothing too, so the call is made up to three times before the
silence becomes that finding: a check that cries wolf on one hiccup is a check
nobody trusts.

Git's own complaint is sent to /dev/null: the report already says which pin could
not be read, and three retries' worth of `fatal:' lines under it would bury the
run rather than explain it."
  (let loop ((attempts 3))
    (let ((output
           (string-trim
            (query (string-append
                    (string-join (map shell-quote (cons* "git" "ls-remote" arguments))
                                 " ")
                    " 2>/dev/null")))))
      (cond ((not (string-null? output)) (string-lines output))
            ((> attempts 1) (sleep 2) (loop (- attempts 1)))
            (else #f)))))

(define (ref-and-commit line)
  "Split one `git ls-remote' LINE into (REF . COMMIT)."
  (let ((fields (string-split line #\tab)))
    (cons (if (> (length fields) 1) (second fields) "")
          (first fields))))

(define (full-ref ref)
  "Return REF as a ref `git ls-remote' accepts, defaulting to the remote HEAD."
  (cond ((string-null? ref) "HEAD")
        ((string-prefix? "refs/" ref) ref)
        (else (string-append "refs/heads/" ref))))

(define (branch-of ref)
  "Return the branch name REF names, or HEAD when it names no branch."
  (cond ((string-prefix? "refs/heads/" ref)
         (string-drop ref (string-length "refs/heads/")))
        ((string-null? ref) "HEAD")
        ((string-prefix? "refs/" ref) ref)
        (else ref)))

(define (remote-commit url ref)
  "Return the commit REF names in URL, or #f when URL cannot be read."
  (let ((lines (ls-remote url (full-ref ref))))
    (and (pair? lines)
         (cdr (ref-and-commit (first lines))))))

(define (remote-tags url)
  "Return URL's tags as an alist of tag name to commit, or #f when URL is unreadable.

`git ls-remote --tags' prints an annotated tag twice: the tag object, then the
commit it points at, as `<tag>^{}'.  The second line comes last and wins here, so
the commit reported is the one the lock would record."
  (let ((lines (ls-remote "--tags" url)))
    (and lines
         (let ((tags (make-hash-table)))
           (for-each
            (lambda (line)
              (let* ((ref-and (ref-and-commit line))
                     (ref (car ref-and)))
                (when (string-prefix? "refs/tags/" ref)
                  (let ((name (string-drop ref (string-length "refs/tags/"))))
                    (hash-set! tags
                               (if (string-suffix? "^{}" name)
                                   (string-drop-right name 3)
                                   name)
                               (cdr ref-and))))))
            lines)
           (hash-map->list cons tags)))))

;; ====== Comparing release names ======
;;
;; A tag is a release name, and release names are ordered the way `sort -V'
;; orders them: v0.9.10 comes after v0.9.9, where a string comparison would put
;; it before.  Runs of digits are compared as numbers and everything else as
;; text, so v0.2.0 next to v1.24.0 sorts the way a reader expects.

(define (version-parts version)
  "Split VERSION into its runs of digits and its runs of everything else."
  (let loop ((chars (string->list version)) (run '()) (digits? #f) (parts '()))
    (define (flush)
      (if (null? run)
          parts
          (let ((text (list->string (reverse run))))
            (cons (if (and digits? (string->number text))
                      (string->number text)
                      text)
                  parts))))
    (cond ((null? chars) (reverse (flush)))
          ((eq? (char-numeric? (car chars)) digits?)
           (loop (cdr chars) (cons (car chars) run) digits? parts))
          (else
           (loop (cdr chars) (list (car chars)) (char-numeric? (car chars)) (flush))))))

(define (version<? a b)
  "Return #t when release name A is older than release name B."
  (let loop ((as (version-parts a)) (bs (version-parts b)))
    (cond ((null? as) (not (null? bs)))
          ((null? bs) #f)
          ((and (number? (car as)) (number? (car bs)))
           (cond ((< (car as) (car bs)) #t)
                 ((> (car as) (car bs)) #f)
                 (else (loop (cdr as) (cdr bs)))))
          ((and (string? (car as)) (string? (car bs)))
           (cond ((string<? (car as) (car bs)) #t)
                 ((string>? (car as) (car bs)) #f)
                 (else (loop (cdr as) (cdr bs)))))
          (else (loop (cdr as) (cdr bs))))))

(define (latest-tag tags)
  "Return the (TAG . COMMIT) pair in TAGS that names the newest release."
  (let loop ((rest (cdr tags)) (newest (first tags)))
    (if (null? rest)
        newest
        (let ((candidate (first rest)))
          (loop (cdr rest)
                (if (version<? (car newest) (car candidate)) candidate newest))))))

;; ====== What one pin says ======
;;
;; One alist per input, so that the report and the updater read the same fields
;; instead of deriving them twice:
;;
;;   name           the input, as the lock names it
;;   kind           tag or branch, which is how its pin is moved
;;   url            where the project lives
;;   ref, rev       what the lock pins
;;   file           the flake file that declares it, or #f if none does
;;   pinned         the tag, or the branch, as it is written there
;;   latest         the newest tag, or the branch (which does not move its name)
;;   latest-commit  the commit behind latest
;;   state          ok, behind, or held
;;   sentence       the line the report prints for it

(define (make-pin name kind url ref rev file pinned latest latest-commit state sentence)
  (list (cons 'name name) (cons 'kind kind) (cons 'url url) (cons 'ref ref)
        (cons 'rev rev) (cons 'file file) (cons 'pinned pinned)
        (cons 'latest latest) (cons 'latest-commit latest-commit)
        (cons 'state state) (cons 'sentence sentence)))

(define (pin-field pin key)
  "Return PIN's KEY."
  (cdr (assq key pin)))

(define (hold-reason name)
  "Return why the pin named NAME is held, or #f when it is not."
  (let ((entry (assoc name held-pins)))
    (and entry (cdr entry))))

(define (declares-line? name line)
  "Return #t when LINE declares the input NAME, as `name = { ... }' does."
  (let ((trimmed (string-trim line)))
    (and (string-prefix? name trimmed)
         (let ((rest (string-trim (string-drop trimmed (string-length name)))))
           (string-prefix? "=" rest)))))

(define (declaring-file name)
  "Return the flake file that declares the input NAME, or #f when none does.

An input is written once, as a line that starts with its name and an `=', in the
flake that declares it -- so the file is found by reading the three of them
rather than by carrying a table of which project belongs to which half."
  (find (lambda (file)
          (and (file-exists? file)
               (any (lambda (line) (declares-line? name line))
                    (string-lines (read-file file)))))
        flake-files))

(define (short-commit commit)
  "Return COMMIT abbreviated, the way git abbreviates one."
  (string-take commit (min 10 (string-length commit))))

(define (scan-input input)
  "Return what INPUT's pin says, as an alist of fields (see `make-pin').

A pin that is behind and named in `held-pins' is `held' rather than `behind': the
report still says so, and `maak update' leaves it where it is."
  (let* ((name (first input))
         (url (third input))
         (ref (fourth input))
         (rev (fifth input))
         (file (declaring-file name))
         (hold (hold-reason name))
         (tag? (string-prefix? "refs/tags/" ref))
         (pinned (if tag?
                     (string-drop ref (string-length "refs/tags/"))
                     (branch-of ref))))
    (if tag?
        (let ((tags (remote-tags url)))
          (cond
           ((not tags)
            (make-pin name 'tag url ref rev file pinned #f #f 'behind
                      (format #f "cannot read ~a" url)))
           ((null? tags)
            (make-pin name 'tag url ref rev file pinned #f #f 'behind
                      (format #f "~a publishes no tags" url)))
           (else
            (let ((latest (latest-tag tags)))
              (cond
               ((string=? pinned (car latest))
                (make-pin name 'tag url ref rev file pinned
                          (car latest) (cdr latest) 'ok
                          (format #f "~a, up to date" pinned)))
               ((version<? pinned (car latest))
                (make-pin name 'tag url ref rev file pinned
                          (car latest) (cdr latest)
                          (if hold 'held 'behind)
                          (if hold
                              (format #f "~a, held: ~a" pinned hold)
                              (format #f "~a -> ~a (~a)"
                                      pinned (car latest) (short-commit (cdr latest))))))
               (else
                (make-pin name 'tag url ref rev file pinned
                          (car latest) (cdr latest) 'behind
                          (format #f "~a is not a tag of ~a, which stops at ~a"
                                  pinned url (car latest)))))))))
        (let ((head (remote-commit url ref)))
          (cond
           ((not head)
            (make-pin name 'branch url ref rev file pinned #f #f 'behind
                      (format #f "cannot read ~a at ~a" pinned url)))
           ((string=? head rev)
            (make-pin name 'branch url ref rev file pinned rev head 'ok
                      (format #f "~a at ~a, up to date" pinned (short-commit rev))))
           (else
            (make-pin name 'branch url ref rev file pinned rev head
                      (if hold 'held 'behind)
                      (if hold
                          (format #f "~a at ~a, held: ~a"
                                  pinned (short-commit rev) hold)
                          (format #f "~a moved: ~a -> ~a"
                                  pinned (short-commit rev) (short-commit head))))))))))

(define (scan-all)
  "Return (PROJECT-PINS . NIXPKGS-PIN) for the whole lock.

The two halves of the set travel inside the lock as path inputs, so their own
inputs are in here too: one pass covers the tags, the branches of the projects,
and the branches of the nixpkgs fork the Guile dependencies come from."
  (let* ((inputs (locked-inputs))
         (nixpkgs (find (lambda (input) (string=? (first input) nixpkgs-input)) inputs))
         (projects (remove (lambda (input)
                             (let ((name (first input))
                                   (type (second input)))
                               (or (string=? type "path")
                                   (string=? name "root")
                                   (string=? name nixpkgs-input))))
                           inputs)))
    (cons (map scan-input projects)
          (and nixpkgs (scan-input nixpkgs)))))

;; ====== Reporting ======

(define (pad-right str width)
  "Return STR padded with spaces to WIDTH, so a column of them lines up."
  (string-append str (make-string (max 0 (- width (string-length str))) #\space)))

(define (say fmt . args)
  "Print one formatted line, unless the run is quiet."
  (unless (quiet?)
    (apply format #t fmt args)))

(define (print-pins pins)
  "Print PINS, one line each, with their names in one column."
  (let ((width (apply max 0 (map (lambda (pin) (string-length (pin-field pin 'name)))
                                 pins))))
    (for-each
     (lambda (pin)
       (say "  ~a  ~a\n" (pad-right (pin-field pin 'name) width)
            (pin-field pin 'sentence)))
     pins)))

(define (state-is? state)
  "Return a predicate that holds for the pins in STATE."
  (lambda (pin) (eq? (pin-field pin 'state) state)))

(define (stale-holds pins)
  "Return the names `held-pins' holds that PINS no longer report as held."
  (remove (lambda (entry)
            (find (lambda (pin)
                    (and (string=? (pin-field pin 'name) (car entry))
                         (eq? (pin-field pin 'state) 'held)))
                  pins))
          held-pins))

(define (print-held pins)
  "Print the pins that are held, with the reason each one stays where it is."
  (unless (null? pins)
    (say "\n  held, and not part of a release:\n")
    (print-pins pins)))

(define (print-stale-holds pins)
  "Note the entries of `held-pins' that PINS no longer report as held.

A hold is a note to the next release, not a permanent exemption: when the release
moves, the entry is dead weight and its line says so instead of hiding."
  (for-each (lambda (entry)
              (say "\n  note: ~a is not held any more; drop it from held-pins.\n"
                   (car entry)))
            (stale-holds pins)))

(define (print-nixpkgs pin)
  "Print the nixpkgs line, out of the count."
  (when pin
    (say "\n  ~a (not counted)  ~a\n" nixpkgs-input (pin-field pin 'sentence))))

;; ====== Maak tasks ======

(define (default)
  "List the tasks this Maak file offers."
  (list-tasks))

;; `check-updates' -- what this set ships, against what the projects publish.
;;
;; The set is a flake of other flakes: each project is pinned to a tag or to a
;; branch, and the pin is what the channel builds until somebody moves it.  The
;; task scans the lock -- the tagged projects, the branch followers, and the
;; branches of the nixpkgs fork the Guile dependencies come from -- and asks each
;; repository what it has now: the newest tag for a project pinned to a tag, the
;; commit a branch points at for one pinned to a branch.  A project that cut a
;; release after this set pinned it, a branch that moved, or a repository that
;; stopped answering is a line that does not say `up to date'.  The task then
;; fails naming the pins that are behind, so a release can open with it.
;;
;; flake.lock rather than flake.nix, because a branch's revision is only written
;; there: what a tag says a project released and what this channel builds are two
;; different statements, and the second one is the one worth checking.
;;
;; Read-only, network-bound (one `git ls-remote' per input), and honest in a dry
;; run: `maak -n check-updates' prints the same report, since reading a remote
;; changes nothing.
;;
;; The docstring stays short because maak prints it before every run, and
;; `maak --list' is where the rest of the set's documentation lives.

(define (check-updates)
  "Report each pin in flake.lock against the release its project publishes now.

The run fails, naming the pins that are behind, so it can open a release."
  (let* ((scanned (scan-all))
         (pins (car scanned))
         (nixpkgs (cdr scanned))
         (behind (filter (state-is? 'behind) pins))
         (held (filter (state-is? 'held) pins)))
    (say "\n~a pins in ~a:\n\n" (length pins) lock-file)
    (print-pins pins)
    (print-nixpkgs nixpkgs)
    (say "\n~a of ~a up to date~a~a.\n"
         (- (length pins) (length behind) (length held))
         (length pins)
         (if (null? behind) "" (format #f ", ~a behind" (length behind)))
         (if (null? held) "" (format #f ", ~a held" (length held))))
    (print-stale-holds pins)
    (unless (null? behind)
      (let ((count (length behind)))
        (task-error "~a pin~a behind: ~a"
                    #:args (list count
                                 (if (= count 1) " is" "s are")
                                 (string-join (map (lambda (pin)
                                                     (pin-field pin 'name))
                                                   behind)
                                              ", "))
                    #:hint
                    (string-append "`maak update' moves every pin that is behind, "
                                   "and `nix flake check' then builds the set."))))))

;; `update' -- the same scan, acted on.
;;
;; A tag pin is a string in the flake that declares it, so the task rewrites that
;; string -- the URL and the ref together, which is unique in the file -- rather
;; than restating how a pin is spelled.  A branch pin is moved by nix itself,
;; with `nix flake update <input>', in the flake that declares it.
;;
;; Then the locks, from the inside out: a half whose flake.nix changed is
;; relocked first, and the set is told about it with `nix flake update <half>',
;; because `nix flake lock' at the root does not re-read the halves' locks.  The
;; set's own lock comes last.
;;
;; Only pins that are behind move.  A held pin is skipped with its reason in the
;; report, and nixpkgs is left to `nix flake update nixpkgs', which is a decision
;; about every package's dependencies rather than about one release.
;;
;; `maak -n update' says what it would move and changes nothing: the scan is a
;; read, and the writes and the nix calls are the parts maak's dry run covers.

(define (update)
  "Move every pin that is behind to the release its project publishes now.

Tags are rewritten in the flake that declares them, branches are moved with
`nix flake update', and the locks are relocked inside out.  Held pins and
nixpkgs stay where they are; `nix flake check' is what builds the result."
  (let* ((scanned (scan-all))
         (pins (car scanned))
         (nixpkgs (cdr scanned))
         (behind (filter (state-is? 'behind) pins))
         (held (filter (state-is? 'held) pins)))
    (if (null? behind)
        (say "\nEvery pin in ~a is current.\n" lock-file)
        (begin
          (say "\n~a pin~a to move:\n\n" (length behind)
               (if (= 1 (length behind)) "" "s"))
          (print-pins behind)
          (say "\n")
          (for-each move-pin behind)
          (relock behind)
          (unless (dry-run?)
            (say "\n~a now pins:\n\n" lock-file)
            (print-moved behind))))
    (print-held held)
    (print-stale-holds pins)
    (print-nixpkgs nixpkgs)
    (unless (or (null? behind) (dry-run?))
      (say "\nRun `nix flake check' to build the set.\n"))))

(define (move-pin pin)
  "Move PIN to the release its project publishes now."
  (unless (pin-field pin 'file)
    (task-error "cannot find where ~a is declared" #:args (list (pin-field pin 'name))
                #:hint (format #f "Looked for a line naming it in ~a."
                               (string-join flake-files ", "))))
  (if (eq? (pin-field pin 'kind) 'tag)
      (rewrite-tag pin)
      (move-branch pin)))

(define (rewrite-tag pin)
  "Rewrite PIN's tag in the flake file that declares it."
  (let* ((name (pin-field pin 'name))
         (file (pin-field pin 'file))
         (url (pin-field pin 'url))
         (old (format #f "~a?ref=refs/tags/~a" url (pin-field pin 'pinned)))
         (new (format #f "~a?ref=refs/tags/~a" url (pin-field pin 'latest)))
         (text (read-file file)))
    (unless (string-contains text old)
      (task-error "~a is not in ~a" #:args (list old file)
                  #:hint "The pin is written differently now; move it by hand."))
    (if (dry-run?)
        (say "[DRY-RUN]: would rewrite ~a in ~a\n" new file)
        (begin
          (write-file file (string-replace-substring text old new))
          (say "  ~a  ~a -> ~a in ~a\n" (pad-right name 24)
               (pin-field pin 'pinned) (pin-field pin 'latest) file)))))

(define (move-branch pin)
  "Move PIN's branch with `nix flake update', in the flake that declares it."
  (let* ((file (pin-field pin 'file))
         (directory (dirname file)))
    (say "  ~a  ~a in ~a\n" (pad-right (pin-field pin 'name) 24)
         (pin-field pin 'pinned) file)
    (with-directory directory
      (lambda ()
        (run (append nix-argv (list "flake" "update" (pin-field pin 'name))))))))

(define (relock pins)
  "Relock the flakes PINS touched, from the halves up to the set."
  (let* ((files (delete-duplicates
                 (filter (lambda (file) file)
                         (map (lambda (pin) (pin-field pin 'file)) pins))))
         (halves (remove (lambda (file) (string=? file "flake.nix")) files)))
    (for-each
     (lambda (file)
       (say "\n  relocking ~a\n" file)
       (with-directory (dirname file)
         (lambda () (run (append nix-argv (list "flake" "lock"))))))
     halves)
    (when (or (member "flake.nix" files) (pair? halves))
      (say "\n  relocking ~a\n" "flake.nix")
      (run (append nix-argv (list "flake" "lock"))))
    ;; `nix flake lock' at the root leaves the halves as they were, so each half
    ;; that moved is read back in as its own input.
    (for-each
     (lambda (file)
       (say "\n  reading ~a back in\n" file)
       (run (append nix-argv
                    (list "flake" "update" (basename (dirname file))))))
     halves)))

(define (print-moved pins)
  "Print the revisions PINS carry now, read from the lock that was just written."
  (let* ((inputs (locked-inputs))
         (width (apply max 0 (map (lambda (pin)
                                    (string-length (pin-field pin 'name)))
                                  pins))))
    (for-each
     (lambda (pin)
       (let* ((name (pin-field pin 'name))
              (row (find (lambda (input) (string=? (first input) name)) inputs))
              (ref (fourth row))
              (label (if (string-prefix? "refs/tags/" ref)
                         (string-drop ref (string-length "refs/tags/"))
                         (branch-of ref))))
         (say "  ~a  ~a at ~a\n" (pad-right name width) label (short-commit (fifth row)))))
     pins)))
