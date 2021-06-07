import klib
import strformat
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils


proc fastx_rc(argv: var seq[string]): int =
    let args = docopt("""
Usage: rc [options] [<strings-or-files>...] 

Print the reverse complementary of sequences in files or sequences
given as parameters. Can read FASTA/FASTQ also from STDIN, but not
naked strings.

Options:
  -s, --seq-name NAME    Sequence name if coming as string [default: dna]
  -r, --only-rev         Reverse, do not complement
  --strip-comments       Remove sequence comments
  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    var
      files        : seq[string]
 
    
    let
      seqDefaultName = $args["--seq-name"] 

    if args["<strings-or-files>"].len() == 0:
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<strings-or-files>"]:
        files.add(file)
    
    
    var
      stringCount = 0
    for filename in files:
      if not fileExists(filename) and filename != "-":
        # Process as string
        stringCount += 1
        if len(files) == 1:
          echo if args["--only-rev"]: reverse(filename)
            else: revcompl(filename)
          continue
        else:
          echo ">", seqDefaultName, "_" , $stringCount, "\n", if args["--only-rev"]: reverse(filename)
              else: revcompl(filename)
          continue
      else:
        echoVerbose(filename, verbose)

      var 
        f = xopen[GzFile](filename)
        y = 0
        r: FastxRecord
        
      defer: f.close()
      var 
        c  = 0
        printed = 0
      
      
      while f.readFastx(r):
        let comment = if len(r.comment) > 0 and not args["--strip-comments"]: " " & r.comment
                      else: ""
        if args["--only-rev"]:
          r.seq = reverse(r.seq)
        else:
          r.seq = revcompl(r.seq)

        if len(r.qual) > 0:
          r.qual = reverse(r.qual)
          echo '@', r.name, comment, "\n", r.seq, "\n+\n", r.qual
        else:
          echo '>', r.name, comment, "\n", r.seq

      