
#' @name GENEAread-package
#' @aliases GENEAread-package
#' @aliases GENEAread
#' @docType package
#'
#' @title A package to process binary accelerometer output files.
#'
#' @description This is a package to process binary output files from the GENEA accelerometer data.
#'
#' The main functions are: \itemize{
#'  \item read.bin
#'  \item stft
#'  \item epoch
#' }
#'
#' @section Main tasks performed
#'
#' @details The main tasks performed by the package are listed below.
#' The relevant topic contains documentation and examples for each.
#' \itemize{
#'    \item Extraction of file header material is accomplished by \code{\link{header.info}}.
#'    \item Input and downsampling of data is accomplished by \code{\link{read.bin}}.
#'    \item Selection of time intervals is accomplished via \code{\link{get.intervals}}.
#'    \item Computation of epochal summaries is accomplished by \code{\link{epoch}} and other functions documented therein.
#'    \item Computation of STFT analyses is accomplished by \code{\link{stft}}.
#'}
#'
#' @section Classes implemented
#'
#' @details The package provides definitions and methods for the following S3 classes:
#'    \itemize{
#'      \item GRtime: Provides numeric storage and streamlined plotting for times. \code{\link{GRtime}}
#'      \item AccData: Stores GENEA accelerometer data, allowing plotting, subsetting and other computation.\code{\link{AccData}}
#'      \item VirtAccData: A virtual AccData object, for just-in-time data access via \code{\link{get.intervals}}.
#'      \item stft: Processed STFT outputs, for plotting via \code{\link{plot.stft}}.
#'    }
#'
#' @author Zhou Fang <zhou@activinsights.co.uk>
#' @author Activinsights Ltd. <joss.langford@activinsights.co.uk>
#' @author Charles Sweetland <charles@sweetland-solutions.co.uk>



#' @name read.bin
#'
#' @title read.bin
#'
#' @description A function to process binary accelerometer files and convert the information into R objects.
#'
#' @param binfile A filename of a file to process.
#' @param outfile An optional filename specifying where to save the processed data object.
#' @param start Either: A representation of when in the file to begin processing, see Details.
#' @param end Either: A representation of when in the file to end processing, see Details.
#' @param Use.Timestamps To use timestamps as the start and end time values this has to be set to TRUE. (Default FALSE)
#' @param verbose A boolean variable indicating whether some information should be printed during
#' processing should be printed.
#' @param do.temp A boolean variable indicating whether the temperature signal should be extracted
#' @param do.volt A boolean variable indicating whether the voltage signal should be extracted.
#' @param calibrate A boolean variable indicating whether the raw accelerometer values and the light
#' variable should be calibrated according to the calibration data in the headers.
#' @param downsample A variable indicating the type of downsampling to apply to the data as it is loaded.
#' Can take values:
#' NULL: (Default) No downsampling
#' Single numeric: Reads every downsample-th value, starting from the first.
#' Length two numeric vector: Reads every downsample[1]-th value, starting from
#' the downsample[2]-th.
#' Non-integer, or non-divisor of 300 downsampling factors are allowed, but will
#' lead to imprecise frequency calculations, leap seconds being introduced, and
#' generally potential problems with other methods. Use with care.
#' @param blocksize Integer value giving maximum number of data pages to read in each pass. Defaults
#' to 10000 for larger data files. Sufficiently small sizes will split very
#' large data files to read chunk by chunk, reducing memory requirements for the
#' read.bin function (without affecting the final object), but conversely possibly
#' increasing processing time. Can be set to Inf for no splitting.
#' @param virtual logical. If set TRUE, do not do any actual data reading. Instead construct a VirtualAccData
#' object containing header information to allow use with get.intervals
#' @param pagerefs A variable that can take two forms, and is considered only for \code{mmap.load = TRUE}
#' NULL or FALSE, in which case pagerefs are dynamically calculated for each record. (Default)
#' A vector giving sorted byte offsets for each record for mmap reading of data files.
#' TRUE, in which case a full page reference table is computed before any processing occurs.
#'
#' Computing pagerefs takes a little time and so is a little slower.
#' However, it is safer than dynamic computations in the case of missing pages and high temperature variations.
#' Further, once page references are calculated, future reads are much faster, so long as the previously
#'  computed references are supplied.
#' @param mmap.load Default is (.Machine$sizeof.pointer >= 8). see \code{\link[mmap]{mmap}} for more details
#' @param ... Any other optional arguments can be supplied that affect manual calibration and data processing.
#' These are: \itemize{
#'   \item mmap: logical. If TRUE (Default on 64bit R), use the mmap package to process the binfile
#'   \item gain: a vector of 3 values for manual gain calibration of the raw (x,y,z) axes. If gain=NULL, the
#'   gain calibration values are taken from within the output file itself.
#'   \item offset: a vector of 3 value for manual offset calibration of the raw (x,y,z) axes. If offset=NULL,
#'   the offset calibration values are taken from within the output file itself.
#'   \item luxv: a value for manual lux calibration of the light meter. If luxv=NULL, the lux calibration value
#'    is taken from within the output file itself.
#'   \item voltv: a value for manual volts calibration of the light meter. If voltv=NULL, the volts calibration
#'    value is taken from within the output file itself.
#'   \item warn: if set to true, give a warning if input file is large, and require user confirmation.
#' }
#'
#' @details The read.bin package reads in binary files compatible with the GeneActiv line of Accelerometers,
#' for further processing by the other functions in this package. Most of the default options are those
#' required in the most common cases, though users are advised to consider setting start and end to
#' smaller intervals and/or choosing some level of downsampling when working with data files of
#' longer than 24 hours in length.
#'
#' The function reads in the desired analysis time window specified by start and end. For convenience,
#' a variety of time window formats are accepted:
#'
#'   Large integers are read as page numbers in the dataset. Page numbers larger than that which is
#' available in the file itself are constrained to what is available. Note that the first page is page 1.
#' Small values (between 0 and 1) are taken as proportions of the data. For example, ‘start = 0.5‘
#' would specify that reading should begin at the midpoint of the data.
#' Strings are interpreted as dates and times using parse.time. In particular, times specified as
#' "HH:MM" or "HH:MM:SS" are taken as the earliest time interval containing these times in the
#' file. Strings with an integer prepended, using a space seperator, as interpreted as that time after
#' the appropriate number of midnights have passed - in other words, the appropriate time of day on
#' the Nth full day. Days of the week and dates in "day/month", "day/month/year", "month-day",
#' "year-month-day" are also handled. Note that the time is interpreted in the same time zone as the
#' data recording itself.
#'
#' Actual data reading proceeds by two methods, depending on whether mmap is true or false. With
#' mmap = FALSE, data is read in line by line using readLine until blocksize is filled, and then
#' processed. With mmap = TRUE, the mmap package is used to map the entire data file into an address
#' file, byte locations are calculated (depending on the setting of pagerefs), blocksize chunks of
#' data are loaded, and then processed as raw vectors.
#'
#' There are advantages and disadvantages to both methods: the \code{\link[mmap]{mmap}} method is usually much faster,
#' especially when we are only loading the final parts of the data. \code{\link[base]{readLines}} will have to
#' process the entire file in such a case. On the other hand, mmap requires a large amount of memory address
#' space, and so can fail in 32 bit systems. Finally, reading of compressed bin files can only be done
#' with the readLine method. Generally, if mmap reading fails, the function will attempt to catch the
#' failure, and reprocess the file with the readLine method, giving a warning. Once data is loaded,
#' calibration is then either performed using values from the binary file, or using
#' manually inputted values (using the gain, offset,luxv and voltv arguments).
#'
#' @section WARNING: Reading in an entire .bin file will take a long time if the file contains a lot of datasets.
#' Reading in such files without downsampling can use up all available memory. See memory.limit.
#' This function is specific to header structure in GENEActiv output files.
#' By design, it should be compatible with all firmware and software versions to date
#' (as of version of current release).
#' If order or field names are changed in future .bin files, this function may have to be updated appropriately.
#'
#' @import mmap
#' @importFrom utils txtProgressBar setTxtProgressBar tail object.size
#'
#' @export
#' @examples
#' requireNamespace("GENEAread")
#' binfile = system.file("binfile/TESTfile.bin", package = "GENEAread")[1]
#' #Read in the entire file, calibrated
#' procfile <- read.bin(binfile)
#' # print(procfile)
#' # procfile$data.out[1:5,]
#' # Uncalibrated, mmap off
#' procfile2 <- read.bin(binfile, calibrate = FALSE)
#' # procfile2$data.out[1:5,]
#' #Read in again, reusing already computed mmap pagerefs
#' # procfile3 <- read.bin(binfile, pagerefs = procfile2$pagerefs )
#' #Downsample by a factor of 10
#' procfilelo<-read.bin(binfile, downsample = 10)
#' # print(procfilelo)
#' object.size(procfilelo) / object.size(procfile)
#' #Read in a 1 minute interval
#' procfileshort <- read.bin(binfile, start = "16:50", end = "16:51")
#' # print(procfileshort)
#' ##NOT RUN: Read, and save as a R workspace
#' #read.bin(binfile, outfile = "tmp.Rdata")
#' #print(load("tmp.Rdata"))
#' #print(processedfile)

read.bin <- function(binfile,
                     outfile = NULL,
                     start = NULL,
                     end = NULL,
                     Use.Timestamps = FALSE,
                     verbose = TRUE,
                     do.temp = TRUE,
                     do.volt = TRUE,
                     calibrate = TRUE,
                     downsample = NULL,
                     blocksize,
                     virtual = FALSE,
                     mmap.load = (.Machine$sizeof.pointer >= 8),
                     pagerefs = TRUE, ...){

  #### 1. Setting envirnoment and variables ####

  invisible(gc()) # garbage collect

  requireNamespace("mmap") # Ensure that mmap is loaded.

  # Suppress all warnings
  options(warn = -1)

  if (verbose){options(warn=0)}

  #### 2. Optional argument initialization as NULL. Arguments assigned ####
  # if they appear in the function call.

  opt.args <- c("gain","offset","luxv","voltv", "warn")

  warn <- FALSE # This gives a warning to the user about the number of pages about to be read in.
  gain <- offset <- NULL
  luxv <- voltv <- NULL

  # This lists all unassisnged parameters given to the function. The ... e.g opt.args.
  argl <- as.list(match.call())

  # This finding the index of the arguments that are relevant
  argind <- pmatch(names(argl),opt.args)
  argind <- which(!is.na(argind))

  # Assigning the names of the variables
  if (length(argind) > 0){
    called.args <- match.arg(names(argl),
                             opt.args,
                             several.ok = TRUE)
    for(i in 1:length(called.args)){
      assign(called.args[i],
             eval(argl[[argind[i]]]))
    }
  }

  #### 3. Variables for positions and record lengths in file ####
  nobs <- 300
  reclength <- 10
  position.data <- 10
  position.temperature <- 6
  position.volts <- 7
  orig.opt <- options(digits.secs = 3)
  # Initialise some variables
  pos.rec1 <- npages <- t1c <- t1midnight <- pos.inc <- headlines <- NA

  #### 4 Get header and calibration info using header.info. ####

  header = header.info(binfile, more = T)
  commasep = unlist(header)[17] == ","   # decimal seperator is comma?

  # Pulls the attributes out of the binfile.
  H = attr(header, "calibration")

  # Assigning out the variables from the header.info function
  for (i in 1:length(H)) assign(names(H)[i], H[[i]])

  if ((!exists("pos.rec1")) || (is.na(pos.rec1))) mmap.load = FALSE

  # temporary workaround.... calculate pagerefs - So this is taking away
  if ((mmap.load == T) &&
      (length(pagerefs)) < 2) {
    pagerefs = TRUE
  }
  if (missing(blocksize)){
    blocksize = Inf
    if (npages > 10000) blocksize = 10000
  }

  freqint = round(freq)

  #### 5. Downsampling Message ####

  if (!is.null(downsample)) {
    if (verbose) {
      cat("Downsampling to ", round(freq/downsample[1],2) , " Hz \n")
      if (nobs %% downsample[1] != 0)
        cat("Warning, downsample divisor not factor of ", nobs, "!\n")
      if ( downsample[1] != floor( downsample[1]) )
        cat("Warning, downsample divisor not integer!\n")
    }
  }

  if (verbose) {
    cat("Number of pages in binary file:", npages, "\n")
  }

  #### 6. Setting up the time sequence ####
  freqseq <- seq(0, by = 1/freq, length = nobs)
  timespan <- nobs/freq
  #    t1 <- t1[2:length(t1)]
  #   t1[1] <- substr(t1[1], 6, nchar(t1[1]))

  timestampsc <- seq(t1c, by = timespan, length = npages)
  timestamps <- seq(t1, by = timespan, length = npages)
  tnc <- timestampsc[npages]
  tn <- timestamps[npages]

  ##### 6.1 Keep original start and end times for trimming ####
  if (Use.Timestamps == TRUE){
    start_precise = start
    end_precise   = end
  }

  #### 7. Default start and end times ####
  if (is.null(start)) {
    start <- 1
  }
  if (is.null(end)) {
    end <- npages
  }

  #### 8. Time entries ####

  if (Use.Timestamps == TRUE){
    # Ensuring that timstamps are not in the range between 0 and 1
    if (start >= 0 &
        start <= 1 &
        !missing(start)){
      stop("Please eneter the start parameter as a timestamp if using Use.Timestamps = TRUE")
    }

    if (end >= 0 &
        end <= 1 &
        !missing(end)){
      stop("Please eneter the end parameter as a timestap if using Use.Timestamps = TRUE")
    }

    # Entering a timestamp rather than a time needs to be explicit.
    if (is.numeric(start)){
      start = findInterval(start - 0.5, timestamps, all.inside = T)
      t1 = timestamps[start+1]
    } else{
      stop(cat("Please enter the start as a numeric timestamp"))
    }

    if (is.numeric(end)){
      end = findInterval(end, timestamps, all.inside = T) +1
    } else{
      stop(cat("Please enter the start as a numeric timestamp"))
    }
  } else{
    # goal is to end up with start, end as page refs!
    if (is.numeric(start)) {
      if ((start[1] > npages)) {
        stop(cat("Please input valid start and end times between ",
                 t1c, " and ", tnc, " or pages between 1 and ",
                 npages, ".\n\n"), call. = FALSE)
      } else if (start[1] < 1) {
        #specify a proportional point to start
        start = pmax(ceiling( start * npages),1)
      }
    }

    if (is.numeric(end)) {
      if ((end[1] <= 1)) {
        #specify a proportional point to end
        end= ceiling(end * npages)
      }
      else {
        end <- pmin(end, npages)
      }
    }
    # parse times, including partial times, and times with day offsets
    if (is.character(start)) {
      start <- parse.time(start,
                          format = "seconds",
                          start = t1,
                          startmidnight = t1midnight)
      start = findInterval(start - 0.5,
                           timestamps,
                           all.inside = T) #which(timestamps >= start-(0.5))[1]
      t1 = timestamps[start+1]
    }

    if (is.character(end)) {
      end <- parse.time(end, format = "seconds", start = t1, startmidnight = t1midnight)
      end = findInterval(end, timestamps, all.inside = T) +1 #max(which(timestamps<= (end+0.5) ))
    }
  }

  #### 9 Indexing binary file by page ref start and end times (Seq number in bin file) ####

  index <-  NULL

  for (i in 1:length(start)){
    index = c(index, start[i]:end[i])
  }

  if (length(index) == 0) {
    if (npages > 15) {
      stop("No pages to process with specified timestamps.  Please try again.\n",
           call. = FALSE)
    }
    else {
      stop("No pages to process with specified timestamps.
             Please try again. Timestamps in binfile are:\n\n",
           paste(timestampsc, collapse = " \n"), " \n\n",
           call. = FALSE)
    }
  }

  if (do.temp) {
    temperature <- NULL
  }

  #### 10. Calibrating data ####

  if (calibrate) {
    if (!is.null(gain)) {
      if (!is.numeric(gain)) {
        stop("Please enter 3 valid values for the x,y,z gains.\n")
      }
      else {
        xgain <- gain[1]
        ygain <- gain[2]
        zgain <- gain[3]
      }
    }
    if (!is.null(offset)) {
      if (!is.numeric(offset)) {
        stop("Please enter 3 valid values for the x,y,z offsets.\n")
      }
      else {
        xoffset <- offset[1]
        yoffset <- offset[2]
        zoffset <- offset[3]
      }
    }
    if (!is.null(voltv)) {
      if (!is.numeric(voltv)) {
        stop("Please enter a valid value for the volts.\n")
      }
      else {
        volts <- voltv
      }
    }
    if (!is.null(luxv)) {
      if (!is.numeric(luxv)) {
        stop("Please enter a valid value for the lux.\n")
      }
      else {
        lux <- luxv
      }
    }
  }

  #### 11. nstreams - Number of blocks of data to be processed ####

  nstreams <- length(index)

  if(warn){
    if (nstreams > 100) {
      cat("About to read and process", nstreams, "datasets.  Continue? Press Enter or control-C to quit.\n")
      scan(, quiet = TRUE)
    }
  }

  data <- NULL

  #### 12. mmap load routine ####

  if (mmap.load) {
    # function to get numbers from ascii codes
    numstrip <- function(dat, size = 4, sep = "." ){

      apply(matrix(dat, size), 2, function(t)
        as.numeric(sub(sep, ".", rawToChar(as.raw(t[t != 58])), fixed = TRUE)))
    }

    offset =  pos.rec1 - 2  # findInterval(58, cumsum((mmapobj[1:3000] == 13)))+ 1 #TODO
    rec2 = offset + pos.inc

    if ((identical(pagerefs , FALSE)) || is.null(pagerefs)){
      pagerefs = NULL
    } else if (length(pagerefs) < max(index)){
      #calculate pagerefs!
      textobj = mmap(binfile, char(), prot = mmapFlags("PROT_READ"))
      if (is.mmap(textobj)){

        startoffset = max(pagerefs, offset) + pos.inc

        if (identical(pagerefs, TRUE)) pagerefs = NULL

        numblocks2 = 1
        blocksize2 = min(blocksize, max(index+1))*3600

        if ( (length(textobj) - startoffset) > blocksize2 ){
          numblocks2 = ceiling((length(textobj) - startoffset) /blocksize2)
        }

        curr = startoffset

        for (i in 1:numblocks2){
          pagerefs = c(pagerefs, grepRaw("Recorded Data",
                                         textobj[curr + 1: min(blocksize2, length(textobj) - curr)],
                                         all = T)+ curr-2)
          curr = curr + blocksize2
          if (length(pagerefs) >= max(index)) break
        }

        if (curr >= length(textobj)){    # pagerefs = c(pagerefs, length(textobj)  -1)
          pagerefs = c(pagerefs, length(textobj) - grepRaw("[0-9A-Z]",
                                                           rev(textobj[max(pagerefs):length(textobj)]))+2)
        }

        if (verbose) cat("Calculated page references... \n")

        munmap(textobj)
        invisible(gc()) # garbage collect

      } else {
        pagerefs = NULL
        warning("Failed to compute page refs")
      }
    }

    mmapobj = mmap(binfile, uint8(), prot = mmapFlags("PROT_READ"))

    if (!is.mmap(mmapobj)){
      warning("MMAP failed, switching to ReadLine. (Likely insufficient address space)")
      mmap.load = FALSE
    }

    # if (firstpage != 0) pos.inc = pos.inc - floor(log10(firstpage))

    # getindex gives either the datavector, or the pos after the tail of the record
    if (is.null(pagerefs)){
      print("WARNING: Estimating data page references. This can fail if data format is unusual!")
      #better warn about this, it can come up
      digitstring = cumsum(c(offset,10*(pos.inc), 90 *(pos.inc + 1) ,
                             900 *( pos.inc +2 ), 9000*(pos.inc +3) ,
                             90000*(pos.inc +4) , 900000*(pos.inc +5),
                             9000000 * (pos.inc + 6)))

      digitstring[1] = digitstring[1] + pos.inc #offset a bit since 10^0 = 1
      getindex = function(pagenumbers, raw = F   ){
        digits = floor(log10(pagenumbers))
        if (raw){
          return( digitstring[digits+1] + (pagenumbers - 10^digits)*(pos.inc+digits  ))
        } else {
          return( rep(digitstring[digits+1] + (pagenumbers - 10^digits)*(pos.inc+digits),
                      each =  nobs * 12)  -((nobs*12):1))
        }
      }

    } else {
      getindex = function(pagenumbers, raw = F){
        if (raw){
          return(pagerefs[pagenumbers])
        }else{
          return(rep(pagerefs[pagenumbers], each = nobs * 12 )  -((nobs*12):1))
        }
      }
    }

  } else{
    fc2 = file(binfile, "rt")
    # skip to start of data blocks
    # skip header
    tmpd <- readLines(fc2, n = headlines)

    #skip unneeded pages
    replicate ( min( index - 1 ), is.character(readLines(fc2, n=reclength)))
  }

  #### 13. Calculate the blocksizes ####

  numblocks = 1
  blocksize = min(blocksize, nstreams)
  if (nstreams > blocksize ){
    if (verbose) cat("Splitting into ", ceiling(nstreams/blocksize), " chunks.\n")
    numblocks = ceiling(nstreams/blocksize)
  }

  #### 14. Initate Outputs ####
  Fulldat    = NULL
  Fullindex  = index #matrix(index, ncol = numblocks)
  index.orig = index

  ##### 15. Show processing time ####
  if (verbose)	    {
    cat("Processing...\n")
    pb <- txtProgressBar(min = 0, max = 100,style = 1)
  }

  start.proc.time <- Sys.time()

  #### 16. Downsample offset ####
  if(!is.null(downsample)){
    downsampleoffset = 1
    if (length(downsample) == 2){
      downsampleoffset = downsample[2]
      downsample = downsample[1]
    }
  }

  #### 17. Virtual loading Option ####

  if (virtual){
    if (is.null(downsample)) downsample = 1
    if (verbose) close(pb)
    if (exists("fc2")) close(fc2)
    if (exists("mmapobj")) munmap(mmapobj)
    #todo...
    Fulldat = timestamps[index]
    if (verbose) cat("Virtually loaded",
                     length(Fulldat)*length(freqseq)/downsample,
                     "records at", round(freq/downsample,2),
                     "Hz (Will take up approx ",
                     round(56 * as.double(length(Fulldat) * length(freqseq)/downsample )/1000000)
                     ,"MB of RAM)\n")

    if (verbose) cat(format.GRtime(Fulldat[1],
                                   format = "%y-%m-%d %H:%M:%OS3 (%a)")," to ", format.GRtime(tail(Fulldat,1) +
                                                                                                nobs /freq,format = "%y-%m-%d %H:%M:%OS3 (%a)"), "\n")


    output = list(data.out = Fulldat,
                  page.timestamps = timestampsc[index.orig],
                  freq= as.double(freq)/downsample,
                  filename =tail(strsplit(binfile, "/")[[1]],1),
                  page.numbers = index.orig,
                  call = argl,
                  nobs = floor(length(freqseq)/downsample) ,
                  pagerefs = pagerefs, header = header)

    class(output) = "VirtAccData"
    return(invisible( output  ))
  }

  #### 18. For loop to read data ####
  # Reading data in block by block.

  voltages = NULL
  lastread = min(index) - 1

  for (blocknumber in 1: numblocks){
    index = Fullindex[1:min(blocksize, length(Fullindex))]
    Fullindex = Fullindex[-(1:blocksize)]
    proc.file <- NULL

    if (!mmap.load){
      #### 19. Using mmap = F ####
      tmpd <- readLines(fc2, n = (max(index) -lastread) * reclength  )
      bseq = (index - lastread -1 ) * reclength
      lastread = max(index)
      if (do.volt){
        vdata = tmpd[bseq + position.volts]
        if (commasep) vdata = sub(",", ".", vdata, fixed = TRUE)
        voltages = c(voltages, as.numeric(substring(vdata, 17, nchar(vdata))))
      }
      if (is.null(downsample)){
        data <- strsplit(paste(tmpd[ bseq + position.data], collapse = ""), "")[[1]]

        if (do.temp) {
          tdata <- tmpd[bseq + position.temperature]
          if (commasep) tdata = sub(",", ".", tdata, fixed = TRUE)
          temp <- as.numeric(substring(tdata, 13, nchar(tdata)))
          temperature <- rep(temp, each = nobs)
        }
        # line below added for future beneficial gc
        rm(tmpd)
        #  data <- check.hex(data) #removed checks because taking too long,
        #    convert.hexstream should throw an error anyway.
        proc.file <- convert.hexstream(data)

        nn <- rep(timestamps[index], each = length(freqseq)) + freqseq
        ##So we are downsampling
      } else {

        data <- strsplit(paste(tmpd[ bseq + position.data], collapse = ""), "")[[1]]
        if (do.temp) {
          tdata <- tmpd[bseq + position.temperature]
          if (commasep) tdata = sub(",", ".", tdata, fixed = TRUE)
          temp <- as.numeric(substring(tdata, 13, nchar(tdata)))
          temperature <- rep(temp, each = nobs)
        }
        # line below added for future beneficial gc
        rm(tmpd)
        #  data <- check.hex(data) #removed checks because taking too long,
        #          convert.hexstream should throw an error anyway.
        proc.file <- convert.hexstream(data)
        nn <- rep(timestamps[index], each = length(freqseq)) + freqseq

        positions = downsampleoffset +
          (0: floor(( nobs * length(index)  - downsampleoffset )/downsample)) * downsample

        proc.file = proc.file[, positions]
        if (do.temp){
          temperature = temperature[positions]
        }
        nn  = nn[positions]
        #	freq = freq * ncol(proc.file)/ (nobs * (length(index)))
        downsampleoffset = downsample - (nobs*blocksize - downsampleoffset  )%% downsample
      }

    } else {

      #### 20. mmap reads ####
      # read from file - remove NAs here. Exception from not analysed files
      infeed = getindex(index)
      infeed = infeed[!is.na(infeed)]
      tmp = mmapobj[infeed]
      proc.file = convert.intstream(tmp)
      # remember that getindex(id , raw = T) gives the byte offset after the end of
      # each data record. Seems like battery voltages and temperatures can vary in
      # terms of the number of bytes they take up... which is annoying
      # new plan:
      # try and discover where the byte offsets are...
      pageindices = getindex(index, raw = T)
      firstrec = as.raw(mmapobj[pageindices[1]:pageindices[2]])
      a = grepRaw("Temperature:", firstrec)
      b = grepRaw(ifelse(commasep, ",", "."), firstrec, offset = a, fixed = TRUE)
      c = grepRaw("Battery voltage:", firstrec, offset = b)
      d = grepRaw("Device", firstrec, offset = c)
      tind = (b-2):(c-2) - length(firstrec)
      vind = (c+16):(d-2) - length(firstrec)

      if (do.temp){
        tempfeed = rep(pageindices, each = length(tind)) + tind
        tempfeed = tempfeed[!is.na(tempfeed)]
        temperature = rep(numstrip(mmapobj[tempfeed],
                                   size = length(tind), sep = ifelse(commasep, ",", ".") ),
                          each = nobs) #lets hope this doesn't slow things too much
      }

      nn <- rep(timestamps[index], each = length(freqseq)) + freqseq

      if (!is.null(downsample)){
        positions = downsampleoffset +
          (0: floor(( nobs * length(index)  - downsampleoffset )/downsample)) * downsample
        proc.file = proc.file[, positions]
        nn  = nn[positions]
        if (do.temp){
          temperature = temperature[positions]
        }
        #	freq = freq * ncol(proc.file)/ (nobs * (length(index)))
        downsampleoffset = downsample - (nobs*blocksize - downsampleoffset) %% downsample
      }

      if (do.volt){
        voltfeed = rep(pageindices, each = length(vind)) + vind
        voltfeed = voltfeed[!is.na(voltfeed)]
        voltages = c(voltages, numstrip(mmapobj[voltfeed],
                                        size = length(vind) , sep = ifelse(commasep, ",", ".")) )
      }

    }

    if (verbose)	setTxtProgressBar(pb, 100 *  (blocknumber-0.5) / numblocks )

    if (calibrate) {
      proc.file[1, ] <- (proc.file[1, ] * 100 - xoffset)/xgain
      proc.file[2, ] <- (proc.file[2, ] * 100 - yoffset)/ygain
      proc.file[3, ] <- (proc.file[3, ] * 100 - zoffset)/zgain
      proc.file[4, ] <- proc.file[4, ] * lux/volts
    }

    ## Ensuring that nn and proc.file are the same length.
    if ( length(proc.file[1,]) < length(nn)){
      nn = nn[1:(length((proc.file[1,])))] # Remove additional timestamps
    }

    proc.file <- t(proc.file)
    proc.file <- cbind(nn, proc.file)
    # rownames(proc.file) <- paste("obs.", 1:nrow(proc.file))
    # strip out row labels - waste of memory
    cnames <- c("timestamp", "x", "y", "z", "light", "button")
    if (do.temp) {
      proc.file <- cbind(proc.file, temperature)
      colnames(proc.file) <- c(cnames, "temperature")
    }
    else {
      colnames(proc.file) <- cnames
    }

    Fulldat = rbind(Fulldat, proc.file)
    if (verbose)	setTxtProgressBar(pb, 100 *  blocknumber / numblocks)

  }

  #### 21. Calculating proccessing time and outputting to console ####
  if (verbose) close(pb)

  freq = freq * nrow(Fulldat) / (nobs *  nstreams)
  end.proc.time <- Sys.time()
  cat("Processing took:", format(round(as.difftime(end.proc.time -
                                                     start.proc.time), 3)), ".\n")
  cat("Loaded", nrow(Fulldat), "records (Approx ",
      round(object.size(Fulldat)/1000000) ,"MB of RAM)\n")

  cat(format.GRtime( Fulldat[1,1], format = "%y-%m-%d %H:%M:%OS3 (%a)"),
      " to ", format.GRtime(tail(Fulldat[,1],1) , format = "%y-%m-%d %H:%M:%OS3 (%a)"), "\n")

  if (!mmap.load){
    close(fc2)
  } else {
    munmap(mmapobj)
  }

  #### 21.1 Trim the data here now! ####
  # Only use if there is a precise measurement
  if (Use.Timestamps == TRUE){
    Fulldat =  Fulldat[Fulldat[,1] >= start_precise &
                       Fulldat[,1] <= end_precise, ]
  }

  #### 22. Finalise Output ####
  processedfile <- list(data.out = Fulldat,
                        page.timestamps = timestampsc[index.orig],
                        freq = freq,
                        filename = tail(strsplit(binfile, "/")[[1]],1),
                        page.numbers = index.orig,
                        call = argl,
                        page.volts = voltages,
                        pagerefs = pagerefs,
                        header = header)

  class(processedfile) = "AccData"

  if (is.null(outfile)) {
    return(processedfile)
  }
  else {
    save(processedfile, file = outfile)
  }
}

#' @title convert.hexstream
#'
#' @description internal function for read.bin
#'
#' @param stream Data from GENEActiv .bin file feed into this stream
#'
#' @return Returns a decrypted raw data
#'
#' @importFrom bitops bitShiftL bitShiftR bitAnd
#'
#' @keywords internal

convert.hexstream <-function(stream){
  maxint <- 2^(12-1)

  #packet <- as.integer(paste("0x",stream,sep = "")) #strtoi is faster
  packet <-bitShiftL(strtoi(stream, 16),4*(2:0))
  packet<-rowSums(matrix(packet,ncol=3,byrow=TRUE))
  packet[packet>=maxint] <- -(maxint - (packet[packet>=maxint] - maxint))

  packet<-matrix(packet, nrow=4)

  # Light packet needs a higher integer than the rest
  # Make a new one for light - This now works
  packet1 <- bitShiftL(strtoi(stream, 16),4*(2:0))
  packet1 <-rowSums(matrix(packet1,ncol=3,byrow=TRUE))
  maxint1 = 2^12
  packet1[packet1>=maxint1] <- -(maxint1 - (packet1[packet1>=maxint1] - maxint1))
  packet1<-matrix(packet1, nrow=4)

  light <- bitShiftR(packet1[4,],2)

  button <-bitShiftR(bitAnd(packet[4,],2),1)

  packet<-rbind(packet[1:3,],light,button)

  packet
}

#' @title convert.instream
#'
#' @description internal function for read.bin
#'
#' @param stream Data from GENEActiv .bin file feed into this stream
#'
#' @return Returns a decrypted raw data
#'
#' @keywords internal

# ========================================
# REFACTORED VERSION OF CONVERT.INTSTREAM
# ========================================

convert.intstream <- function(stream){
  
  # Constants for 12-bit signed conversion
  maxint_signed <- 2048 # 2^(12-1)
  two_maxint_signed <- 4096 # 2 * maxint_signed
  
  # 1. Calculate combined 12-bit raw values directly from stream bytes (once)
  #    'stream - 48 - 7 * (stream > 64)' converts ASCII hex char codes to numeric 0-15
  #    Matrix multiplication combines 3 hex digits using powers of 16 (16^2, 16^1, 16^0)
  packet_raw <- drop(matrix(stream - 48 - 7 * (stream > 64), ncol = 3, byrow = TRUE) %*% c(256, 16, 1))
  
  # 2. Reshape the raw 12-bit values into 4 rows (XYZ, Light/Button info)
  packet_mat <- matrix(packet_raw, nrow = 4)
  
  # 3. Extract XYZ components (first 3 rows)
  xyz_raw = packet_mat[1:3, , drop = FALSE]
  
  # 4. Apply signed 12-bit correction (2's complement) to XYZ values
  #    Values >= 2048 are negative in 12-bit signed representation
  needs_correction <- xyz_raw >= maxint_signed
  xyz_raw[needs_correction] <- xyz_raw[needs_correction] - two_maxint_signed
  
  # 5. Extract the 4th component (contains raw unsigned 12-bit value for Light/Button)
  light_button_raw = packet_mat[4, ]
  
  # 6. Calculate intermediate value for light/button logic (as per original logic)
  ltmp = light_button_raw / 4
  
  # 7. Calculate light value (as per original logic: take floor, then abs)
  #    abs() likely redundant if light_button_raw is guaranteed >= 0, but kept for consistency
  light = abs(floor(ltmp))
  
  # 8. Calculate button state (as per original logic)
  #    Checks if the fractional part of the division by 4 is >= 0.5
  #    This corresponds to checking if (light_button_raw mod 4) is 2 or 3
  button = (ltmp - light) > 0.49
  
  # 9. Combine corrected XYZ, calculated light, and button state into the final matrix
  #    Ensure button state is numeric (0 or 1)
  rbind(xyz_raw, light, as.numeric(button))
}


#' utility function for checking timestamps
#' @title Utility functions to be used within GENEAread
#'
#' @description To check the timestamps are of the correct format when using within read.bin
#'
#' @param x Time object passed to check class
#'
#' @keywords internal

is.POSIXct <- function(x) inherits(x, "POSIXct")
is.POSIXlt <- function(x) inherits(x, "POSIXlt")
is.POSIXt <- function(x) inherits(x, "POSIXt")
is.Date <- function(x) inherits(x, "Date")





