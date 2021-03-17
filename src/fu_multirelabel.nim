import readfq
import docopt
import os
import posix
import strutils
signal(SIG_PIPE, SIG_IGN)

let version = "1.0"

# Handle Ctrl+C interruptions and pipe breaks
type EKeyboardInterrupt = object of CatchableError
proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
setControlCHook(handler)

proc seq_to_string(name, comment, sequence, quality, separator: string): string =
  let
    printed_comment = if len(comment) > 0: separator & comment
                      else: ""
  if len(quality) == len(sequence):
    return "@" & name & printed_comment & "\n" & sequence & "\n+\n" & quality
  else:
    return ">" & name & printed_comment & "\n" & sequence

proc main(): int =
  let args = docopt("""
  Fastx utility

  A program to print the sequence size of each record in a FASTA/FASTQ file

  Usage: 
  fastx_utility [options] FILE...

  Options:
    -b, --basename             Prepend file basename to sequence
    -r, --rename NAME          Replace original name with NAME
    -n, --numeric-postfix      Add progressive number (reset at each new basename)
    -d, --split-basename CHAR  Remove the final part of basename after CHAR [default: .]
    -s, --separator STRING     Separator between prefix, name, suffix [default: _]
    --no-comments              Strip out comments
    --comment-separator CHAR   Separate comment from name with CHAR [default: TAB]
  
  """, version=version, argv=commandLineParams())

  
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  let
    comment_separator  = if $args["--comment-separator"] == "TAB": "\t"
                 else: $args["--comment-separator"]

  # Check input file existence
  var tot_counter = 0
  for input_file in args["FILE"]:
    var
      counter = 0
    let
      file_split    =  if args["--basename"]: lastPathPart(input_file).split($args["--split-basename"])[0] & $args["--separator"]
                       else: ""


    try:
      for seqObject in readfq(input_file):
        tot_counter += 1
        counter     += 1

        let
          comments = if args["--no-comments"]: ""
                     else: seqObject.comment
          seq_name      = if $args["--rename"] == "nil": seqObject.name
                      else: $args["--rename"]

          seq_counter   = if args["--numeric-postfix"]: $args["--separator"] & $counter
                      else: ""
        
          name =  file_split & seq_name & seq_counter
        
        echo(seq_to_string(name, comments, seqObject.sequence, seqObject.quality, comment_separator))

    except Exception as e:
      stderr.writeLine("ERROR: Unable to parse FASTX file: ", input_file, "\n", e.msg)
      return 1
    
  
  

when isMainModule:
  # Handle "Ctrl+C" intterruption
  try:
    let exitStatus = main()
    quit(exitStatus)
  except EKeyboardInterrupt:
    # Ctrl+C
    quit(1)
  except IOError:
    # Broken pipe
    quit(0)
  except Exception:
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(2)   
