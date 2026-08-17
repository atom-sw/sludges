# Installing Sludges


## Prerequisites

- [Racket](https://racket-lang.org/) 9.3

Checked signatures require Racket 8.9 or later, but `sludges` builds on
internals of `htdp-lib` that changed after 8.9.  Version 9.3 is the one
this package is developed and tested against; earlier versions are
untested and may not compile.


## Installing

### From a package server

If the package is published to `pkgs.racket-lang.org`:

```
raco pkg install sludges
```

### From a local clone

Clone this repository, then install it as a linked package:

```
raco pkg install --name sludges <path-to-cloned-repo>
```

The `--name` flag sets the package name used by `raco pkg` commands
(e.g. `raco pkg remove sludges`).  Without it, the package name
defaults to the directory name of your clone.  In either case, the
collection name used in `require` is always `sludges` (determined by
the subdirectory structure, not the package name).

This creates a development link: the source files in the cloned repo
are used directly by Racket.  After editing the source, run

```
raco setup -l sludges
```

to recompile, then restart DrRacket.

### As a teachpack without `raco pkg install`

If you don't want to install the package system-wide, you can add the
teachpack file manually in DrRacket:

1. Locate the file `sludges/dist/sludges.rkt` from this repository.
2. In DrRacket, go to **Language > Add Teachpack...**.
3. Click **Add Teachpack to List...** (below the **User-installed HtDP
   Teachpacks** column on the right).
4. In the file chooser, navigate to and select the `sludges/dist/sludges.rkt` file.
5. The teachpack now appears in the **User-installed HtDP Teachpacks** column.

`sludges/dist/sludges.rkt` is a self-contained copy of the whole
implementation, generated from `sludges/main.rkt`.  It needs no package
installation.

This installation mode copies the file into DrRacket's user-installed
teachpacks directory.  Thus if the teachpack's source code is updated,
you will need to repeat these steps.


## Usage

### As a library (via `require`)

Add the following line near the top of your student language program:

```racket
(require sludges)
```

This works in all HtDP student languages: BSL, BSL+, ISL, ISL+, ASL.

### As a teachpack in DrRacket

After installing the package with `raco pkg install`, the teachpack
is registered automatically:

1. Open DrRacket.
2. Go to **Language > Add Teachpack...**.
3. In the **Preinstalled HtDP Teachpacks** column (left), select
   **sludges.rkt**.
4. Click **OK**.

If it does not appear in the list, restart DrRacket after installing.


## Verifying the installation

Copy the following program into DrRacket (with the language set to
**ISL**), then click **Run**:

```racket
; You don't need the require if you selected the teachpack in DrRacket
(require sludges)

;;; enum and define-type

(define-type TrafficLight (enum "red" "yellow" "green"))

(: current-light TrafficLight)
(define current-light "green")

;;; one-of (alias for mixed)

(define-type StringOrNumber (one-of String Number))

(: label StringOrNumber)
(define label "hello")

;;; define-type with predicate

(define-type Natural (predicate (lambda (x) (and (integer? x) (>= x 0)))))

(: count Natural)
(define count 42)

;;; Posn and PosnOf

(: origin Posn)
(define origin (make-posn 0 0))

(: unit-pos (PosnOf Number Number))
(define unit-pos (make-posn 1 1))

;;; define-struct/typed

(define-struct/typed student [(name String) (grade Natural)])

(: s Student)
(define s (make-student "Alice" 1))

;;; quick check
(check-expect current-light "green")
(check-expect count 42)
(check-expect (posn-x origin) 0)
(check-expect (student-name s) "Alice")
(check-expect (student-grade s) 1)
```


## Uninstalling

### Removing a `raco pkg install` installation

If you installed with `--name sludges`:

```
raco pkg remove sludges
```

If you installed without `--name` (package name defaults to the
directory name of your clone):

```
raco pkg remove <directory-name>
```

You can check the installed package name with `raco pkg show -l`.

### Removing a user-installed teachpack

If you added the teachpack via **Language > Add Teachpack... > Add
Teachpack to List...**, DrRacket copied the file into its
user-installed teachpacks directory.  To remove it:

1. Find the directory by running in a terminal:

   ```
   racket -e '(require setup/dirs) (displayln (find-user-collects-dir))'
   ```

2. Inside the printed directory, open the `installed-teachpacks`
   subdirectory and delete `sludges.rkt` (and optionally the
   `compiled` subdirectory).

As a one-liner:

```bash
rm "$(racket -e '(require setup/dirs) (displayln (find-user-collects-dir))')/installed-teachpacks/sludges.rkt"
```


## Running the test suite

```
raco test sludges/tests/
```
