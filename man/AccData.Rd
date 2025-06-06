% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AccData.r
\docType{data}
\name{AccData}
\alias{AccData}
\title{Accelerometer Data Object}
\format{
An AccData object
}
\source{
Output of \code{\link{read.bin}}
}
\description{
Accelerometer Data Output from read.bin function
}
\examples{
requireNamespace("GENEAread")
binfile  = system.file("binfile/TESTfile.bin", package = "GENEAread")[1]
#Read in the entire file, calibrated
procfile<-read.bin(binfile)
print(procfile)

plot(procfile$temperature,
xlim = c(min(procfile$data.out[,1]),
        max(procfile$data.out[,1])),
ylim = c(10,40))

plot(procfile$data.out[,c(1,7)])
}
\seealso{
\code{read.bin}
}
\keyword{datasets}
