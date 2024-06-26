##' Batch analysis
##'
##' \code{runBatch} analyzes all image sequences in a specified
##' directory. Use this function when settings have been optimized
##' previously on a single or selection of movies/image sequences.
##' @param path A character vector of path name that contains all directories
##' with image sequences.
##' @param settings Object of class 'tracked' containing all optimized settings
##' in attributes,
##' as obtained from \code{\link{trackParticles}}.
##' Alternatively, settings can be specified using arguments described below.
##' @param dirnames If not all image sequences should be
##' analyzed, specify which files to use as a character string.
##' @param nImages See \code{\link{loadImages}}
##' @param pixelRange See \code{\link{identifyParticles}}
##' @param threshold See \code{\link{identifyParticles}}
##' @param qthreshold See \code{\link{identifyParticles}}
##' @param select See \code{\link{identifyParticles}}
##' @param autoThres See \code{\link{identifyParticles}}
##' @param perFrame See \code{\link{identifyParticles}}
##' @param frames See \code{\link{identifyParticles}}
##' @param nn Name of artificial neural net if apply it to images. Default
##' is \code{NULL}, resulting in no neural net being applied.
##' @param L See \code{\link{trackParticles}}
##' @param R See \code{\link{trackParticles}}
##' @param plotOutput Default is \code{FALSE}. Set \code{TRUE} to plot results.
##' @param plotType Default is 'trajectories'. Other options are 'sizes' and
##' 'animation'.
##' @param weight See \code{\link{trackParticles}}
##' @param methodBg See \code{\link{createBackground}}
##' @param saveAll Logical. Set \code{TRUE} to save for each image sequence the
##' full object obtained from \code{\link{loadImages}}. Default is FALSE.
##' @param incThres Minimum number of frames that a particle must be
##' present. By default, automated estimate is used.
##' @seealso \code{\link{loadImages}}, \code{\link{createBackground}},
##' \code{\link{subtractBackground}}, \code{\link{identifyParticles}},
##' \code{\link{trackParticles}}.
##' @return Dataframe with estimated population size for each image sequence.
##' @author Marjolein Bruijning, Caspar A. Hallmann & Marco D. Visser
##' @examples
##' \dontrun{
##' ## Simulate 3 image sequences
##' wd <- getwd()
##' folders <- paste0(rep("images",3),1:3)
##' populations <- c(15,25,50)
##' dir.create("./batchTest")
##' setwd("./batchTest")
##' for(i in 1:length(folders)){
##'   dir.create(folders[i])
##'   traj <- simulTrajec(path=folders[i],
##'                       nframes=30,nIndividuals=populations[i],
##'                       h=0.01,rho=0.9,
##'                       sizes=runif(populations[i],0.004,0.006))
##' }
##' setwd(wd)
##' batchpath <- "./batchTest"
##' results <- runBatch(path=batchpath,
##'                     nImages=1:30,threshold=-0.1,select='dark',
##'                     pixelRange=c(1,100),L=50,R=3,
##'                     incThres=10)
##' results
##'	}
##' @export
##
runBatch <- function(path,settings=NULL,dirnames=NULL,nImages=1:30,
                     pixelRange=NULL,
                     threshold=-0.1,qthreshold=NULL,select='dark',
                     nn=NULL,incThres=NULL,plotOutput=FALSE,
                     plotType='trajectories',L=20,R=2,
                     weight=c(1,1,1),
                     autoThres=FALSE,perFrame=FALSE,methodBg='mean',
                     frames=NULL,saveAll=FALSE) {
  if (is.null(dirnames)) {
    allDirec <- paste0(list.dirs(path,recursive=FALSE),'/')
  } else {allDirec <- paste0(path,'/',dirnames,'/')}

  if (!is.null(settings)) {
    settings <- attributes(settings)$settings
    nImages <- settings$nImages
    threshold <- settings$threshold
    pixelRange <- settings$pixelRange
    qthreshold <- settings$qthreshold
    select <- settings$select
    autoThres <- settings$autoThres
    perFrame <- settings$perFrame
    frames <- settings$frames
    R <- settings$R
    L <- settings$L
    weight <- settings$weight
    methodBg <- settings$BgMethod
  }
  dat <- data.frame(Directory=rep(NA,length(allDirec)),
                    Count=NA)

  if (is.null(dirnames)) {
    dat$Directory <- list.dirs(path,recursive=FALSE,full.names=FALSE)
  } else {dat$Directory <- dirnames}

  results <- vector('list',length(allDirec))
  cat("\n")
  for (i in seq_along(allDirec)) {
    tryCatch ({
      cat("\r \t Batch analysis: Image sequence",i,"of",length(allDirec),"\t \n")
      dirPictures <- allDirec[i]
      allFullImages <- loadImages (dirPictures=dirPictures,nImages=nImages)
      stillBack <- createBackground(allFullImages,method=methodBg)
      allImages <- subtractBackground(bg=stillBack,colorimages=allFullImages)
      invisible(utils::capture.output(partIden <- identifyParticles(
                                    sbg=allImages,
                                    qthreshold=qthreshold,
                                    threshold=threshold,
                                    select=select,
                                    pixelRange=pixelRange,
                                    colorimages=allFullImages,
                                    autoThres=autoThres,
                                    perFrame=perFrame,
                                    frames=frames)))
      if (!is.null(nn)) {
        pca <- any(names(attributes(nn)) == 'pca')
        invisible(utils::capture.output(partIden <- stats::update(partIden,
                                                     nn,pca=pca,
                                                     colorimages=allFullImages,
                                                     sbg=allImages)))
      }
      invisible(utils::capture.output(records <- trackParticles(partIden,L=L,
                                                                R=R,
                                                                weight=weight)))
      if (saveAll) results[[i]] <- records

      dat$Count[i] <- summary(records,incThres=incThres)$N

      if (plotOutput == TRUE) {
        graphics::plot(records,type=plotType,colorimages=allFullImages,name=i,
             path=path,incThres=incThres)
      }
      rm(list=c('allFullImages','stillBack','allImages','partIden','records'))
      gc()
    }, error=function(e){message(paste('Error in',dirPictures,':',e))}
   )
  }
  cat("\n")
  class(dat) <- c('TrDm','batch','data.frame')
  attr(dat,"settings") <- settings
  attr(dat,"path") <- path
  if (saveAll) attr(dat,"results") <- results
  return(dat)
}

# is.TrDm
#
# Generic lower-level function to test whether an object
# is an TrackDem object.
is.TrDm <- function(object) {
  inherits(object, "TrDm")
}


## Summary TrDm objects
##'
##' \code{summary} methods for class 'TrDm'.
##' @param object an object of class 'TrDm'.
##' @param incThres Minimum length of tracked segments for particles to be
##' included. By default an automated threshold is calculated. Only for
##' 'tracked' objects.
##' @param funSize Statistic to be calculated to obtain particle sizes. By
##' default \code{median} is used.
##' @param \dots further arguments passed to or from other methods.
##' @author Marjolein Bruijning, Caspar A. Hallmann & Marco D. Visser
##' @export
summary.TrDm <- function(object,incThres=NULL,funSize=stats::median,...) {
  if (inherits(object,"particles")) {
    numbers <- table(factor(object$frame, levels = 1:dim(attributes(object)$images)[3]))
    mu <- mean(numbers)
    sdd <- stats::sd(numbers)
    cv <- sdd/mu
    thr <- attributes(object)$threshold
    tab <- cbind(Mean=mu,SD=sdd,CV=cv)
    res <- list(particles=tab,
                n=numbers,thr=thr)
    class(res) <- c('summaryTrDm','particles')
    return(res)
  } else if (inherits(object,"tracked")) {
    if (is.null(incThres)) {
      dist <- apply(object$trackRecord[,,1],1,function(x)
                    sum(!is.na(x)))
      mod <- stats::kmeans(dist,2)
      incLabels <- mod$cluster == which.max(mod$centers)
      incThres <- max(dist[!incLabels])
    } else {
      incLabels <- apply(object$trackRecord[,,1],1,function(x)
                                               sum(!is.na(x))) > incThres
    }
    tr <- object$trackRecord[incLabels,,,drop=FALSE]
    sr <- object$sizeRecord[incLabels,,drop=FALSE]
    cr <- object$colorRecord[incLabels,,,drop=FALSE]
    # Distance
    dr <- t(vapply(seq_len(nrow(tr)),function (x)
                               sqrt(diff(tr[x,,1])^2 + diff(tr[x,,2])^2),
                   numeric(dim(tr)[2]-1)))


    perID <- apply(sr,1,funSize,na.rm=TRUE)
    sdd <- apply(sr,1,stats::sd,na.rm=TRUE)
    muD <- apply(dr,1,sum,na.rm=TRUE) # total movement
    muC <- apply(cr,c(1,3),mean,na.rm=TRUE) # mean colors

    tab <- cbind(ID=which(incLabels),Mean=perID,SD=sdd,movement=muD,
                 R=muC[,1],G=muC[,2],B=muC[,3])
    colnames(tab) <- c('ID','Size','SD size',
                       'Total movement','Red','Green','Blue')
    res <- list(N=nrow(tab),
                particles=tab,
                trackrecord=tr,
                sizerecord=sr,
                distrecord=dr,
                colorrecord=cr,
                presence=incThres,
                area=100 * sum(perID) /
                     (nrow(attributes(object)$images)*
                      ncol(attributes(object)$images))
                )
    class(res) <- c('summaryTrDm','tracked')
    return(res)

  } else if (inherits(object,"tfp")) {
      class(object) <- c('summaryTrDm','tfp')
      return(object)
  } else if (inherits(object,"neuralnet")) {
      class(object) <- c('summaryTrDm','neuralnet')
      return(object)
  } else {cat("\t No summary available for this object.\n\n")}
}

## Print TrDm summary objects
##' \code{print} methods for class 'TrDm'.
##' @param x Object of class 'summaryTrDm'.
##' @param\dots Further arguments passed to or from other methods.
##' @author Marjolein Bruijning, Caspar A. Hallmann & Marco D. Visser
##' @export
print.summaryTrDm <- function(x,...) {
  if (inherits(x,"particles")) {
    cat("\t Summary of identified particles (unlinked): \n\n")
    cat("\t Average number of identified particles: ",
        as.numeric(round(x$particles[1],2)) , "( sd =",
        as.numeric(round(x$particles[2],2)), ")\n",
        "\t Coefficient of variation: ",
        as.numeric(round(x$particles[3],2)))
    cat("\n\t Range of particles for each frame ( 1-", length(x$n),"):",
        range(x$n)[1],"-",range(x$n)[2])
    cat("\n\t Threshold values:", round(x$thr,3),"\n")
    cat(ifelse(attributes(x)$nn==TRUE,'\t With neural network.\n',
        '\t Without neural network.\n'))

  } else if (inherits(x,"tracked")) {
    cat("\t Summary of Linked particles: \n\n")
    print(x$particles)
    cat(paste("\t Total of",x$N,"Identified particles.\n"))
    cat(paste("\t Particles have a total area  of",round(x$area,4),"%\n"))
    cat(paste("\t Minimum presence is set at",x$presence,"frames \n",sep=' '))

  } else if (inherits(x,"tfp")) {
    cat("\t Summary of manually identified false and true positives.\n")
    wrong <- unlist(lapply(x,function(i) i$wrong))
    correct <- unlist(lapply(x,function(i) i$correct))
    cat(paste("\t True positives:",length(correct),'\n'))
    cat(paste("\t False positives:",length(wrong),'\n\n'))
  } else if (inherits(x,"neuralnet")) {
    cat("\t Summary of trained neural network: \n")
    cat("\t Confusion table: \n")
    print.default(format(x$confusion,digits = 3)
                 ,print.gap = 2L,
                  quote = FALSE)

    cat("\t F-score:",round(x$fscore,2),'\n')
    cat("\t",x$bestNN$reps," repetitions.\n")
    cat("\t",x$bestNN$hidden," hidden layer(s).\n")

  } else {cat("\t No summary available for this object.\n\n")}
}


## Print TrDm objects
##' \code{print} methods for class 'TrDm'.
##' @param x Object of class 'TrDm'.
##' @param\dots Further arguments passed to or from other methods.
##' @author Marjolein Bruijning, Caspar A. Hallmann & Marco D. Visser
##' @export
print.TrDm <- function(x,...) {
  if (inherits(x,"colorimage")) {
    d <- dim(x)
    cat("\t Trackdem color image \n")
    cat(paste("\t Images with size:",d[1],"x",d[2],"pixels and",d[3],
              "color channel(s).\n"))
    if (length(d) == 4) {
      cat(paste("\t Total of",d[4],"images. \n\n"))
    } else if (length(d) == 3) {
      cat(paste("\t Total of 1 image. \n\n"))
    }
  } else if (inherits(x,"sbg")) {
    d <- dim(x)
    cat("\t Trackdem subtracted background image. \n")
    cat(paste("\t Images with size:",d[1],'x',d[2],' pixels. \n'))
    cat(paste("\t Total of",d[4],"images. \n\n"))
  } else if (inherits(x,"particles")) {
    cat("\t Trackdem list with identified particles (without tracking). \n\n")
  } else if (inherits(x,"tracked")) {
    cat("\t Trackdem object. \n \t
       Coordinates and sizes of all identified particles (with tracking) \n\n")
  } else if (inherits(x,"tfp")) {
    cat("\t Trackdem object with manually identified true and false positives.",
        " \n\n")
  } else if (inherits(x,"trainingdata")) {
    print.data.frame(x)
  } else if (inherits(x,"neuralnet")) {
      cat("\t Trained neural network with",x$bestNN$hidden,"layer(s).\n")
  } else if (inherits(x,"batch")) {
      print.data.frame(x)
  } else if (inherits(x,"simtrajectory")) {
    cat("\t Simulated trajectories of", max(unique(x$id)),"particles, for",
        max(unique(x$t)),"frames. \n \n")
  }
  else {}
}

## Plot TrDm objects
##' \code{plot} methods for class 'TrDm'.
##' @param x An object of class 'TrDm'.
##' @param frame Choose which frame to be plotted. By default, \code{frame=1}.
##' @param type Only for 'tracked' objects. By default, both trajectories and
##' size distribution are plotted. Choose
##' \code{'trajectories'} to plot only trajectories on the original color image.
##' Choose \code{'sizes'}
##' to only plot the particle size distribution. Choose \code{'animation'} to
##' create an .mp4 animation.
##' Here, images are temporarily saved in \code{path}. Set name of file with
##' argument \code{name}.
##' @param incThres Minimum length of tracked segments for particles to be included.
##' By default an automated threshold is calculated. Only for 'tracked' objects.
##' @param colorimages Original color images. By default, original color images
##' are obtained from the global environment.
##' @param cl When plotting a subtracted background image, choose which color layer
##' is plotted. By default, \code{cl=1}.
##' @param path When creating an animation, choose directory in which images
##' are saved temporarily, and where the animation should be saved.
##' @param libavpath Path to location where the executable file for libav
##' can be found (named 'avconv.exe'), in case it is not found automatically,
##' e.g. \code{'C:/Users/libav/usr/bin/avconv.exe'}. Only required when creating
##' an animation.
##' @param name of animation; by default \code{'animation'}.
##' @param \dots further arguments passed to \code{\link[raster]{plotRGB}}
##' @author Marjolein Bruijning, Caspar A. Hallmann & Marco D. Visser
##' @export
plot.TrDm <- function(x,frame=1,type=NULL,incThres=NULL,colorimages=NULL,
                      cl=1,path=NULL,name='animation',libavpath=NULL,...) {

  jet.colors <- grDevices::colorRampPalette(c("#00007F", "blue", "#007FFF",
                                              "cyan","#7FFF7F", "yellow",
                                              "#FF7F00", "red", "#7F0000"))

  oldPar <- graphics::par()

   if (inherits(x, "colorimage")) {
    if (length(dim(x)) > 3) { ## multiple frames
      x <- x[,,,frame,drop=FALSE]
      x <- array(x,dim=c(dim(x)[1:3]))
      x <- raster::brick(x)
    } else if (length(dim(x)) == 3) { ## for background image (1 frame)
      class(x) <- 'array'
      x <- raster::brick(x)
    }
    if (dim(x)[3] == 1) warning("Creating plot for 1 color channel image")
    raster::plotRGB(x,scale=1,asp=nrow(x)/ncol(x),...)
  } else if (inherits(x,"tracked")) {
    if (is.null(incThres)) {
      dist <- apply(x$trackRecord[,,1],1,function(x)
                    sum(!is.na(x)))
      mod <- stats::kmeans(dist,2)
      incLabels <- mod$cluster == which.max(mod$centers)
      incThres <- max(dist[!incLabels])
    } else {
      incLabels <- apply(x$trackRecord[,,1],1,function(x)
                                               sum(!is.na(x))) > incThres
    }
      if(is.null(colorimages)) { colorimages <- get(attributes(x)$originalImages,
                                                    envir=.GlobalEnv) }
      if (is.null(type)) {
        graphics::par(mfrow=c(1,2))
        tmp <- x$trackRecord[incLabels,,,drop=FALSE]
        graphics::plot(100,100,xlim=c(0,1),ylim=c(0,1),xlab='x',ylab='y',...)
        for (i in 1:nrow(tmp)) {
          graphics::lines(tmp[i,,1]/ncol(colorimages),
                          1-tmp[i,,2]/nrow(colorimages),
               col=paste0(jet.colors(nrow(tmp))[i],'99'),lwd=1.5)
        }

        tmp <- x$sizeRecord[incLabels,,drop=FALSE]
        perID <- apply(tmp,1,mean,na.rm=TRUE)
        sdperID <- apply(tmp,1,stats::sd,na.rm=TRUE)
        graphics::plot(seq_along(perID),perID[order(perID)],cex=1.5,pch=21,
                       bg='#00000050',
             xlab='Labeled particle',ylab='Size (pixels)',...)
        graphics::segments(x0=seq_along(perID),
                           y0=perID[order(perID)]-sdperID[order(perID)],
                           y1=perID[order(perID)]+sdperID[order(perID)])
      } else {
          if (type == 'sizes') {
          x <- x$sizeRecord[incLabels,,drop=FALSE]
          perID <- apply(x,1,mean,na.rm=TRUE)
          sdperID <- apply(x,1,stats::sd,na.rm=TRUE)
          graphics::plot(seq_along(perID),perID[order(perID)],cex=1.5,pch=21,
                         bg='#00000050',
                         xlab='Labeled particle',ylab='Size (pixels)',...)
          graphics::segments(x0=seq_along(perID),
                             y0=perID[order(perID)]-sdperID[order(perID)],
                             y1=perID[order(perID)]+sdperID[order(perID)])
        } else if (type == 'trajectories') {
            x <- x$trackRecord[incLabels,,,drop=FALSE]
            graphics::plot(colorimages,...)
            for (i in 1:nrow(x)) {
            graphics::lines(x[i,,1]/ncol(colorimages),
                            1-x[i,,2]/nrow(colorimages),
                            col=paste0(jet.colors(nrow(x))[i],'99'),lwd=1.5)
            }
        } else if (type == 'animation') {
            if(is.null(path)) path <- getwd()
            if (is.null(libavpath)) libavpath <- 'avconv'
            # make sure file does not exist
            if('images' %in% list.files(path)) {
			        stop(paste0('Directory "images" already exists in ',
			             path,'.\n Please remove it or use a different path with ',
                        'argument "path".'))
			      }
            if(paste0(name,'.mp4') %in% list.files(path)) {
			        stop(paste0('Animation with name "',name,'" already exists in ',
			             path,'.\n Please remove it or use a different name with ',
                         'argument "name".'))
			      }
            y <- x$sizeRecord[incLabels,]
            x <- x$trackRecord[incLabels,,]
            dir.create(paste0(path,'/images'))
            width <- ifelse(ncol(colorimages) %% 2 == 0,
                            ncol(colorimages),ncol(colorimages)+1)
            height <- ifelse(nrow(colorimages) %% 2 == 0,
                            nrow(colorimages),nrow(colorimages)+1)
            rownames(x) <- 1:nrow(x)
            tot <- ncol(x)
           for (i in 1:tot) {
              grDevices::png(paste0(path,'/images/images',
                             formatC(i,width=4,flag="0"),'.png'),
                             width=width,
                             height=height)
              graphics::plot(colorimages,frame=i)
              graphics::points(x[,i,1]/width,
                     1-x[,i,2]/height,
                     col=grDevices::rainbow(nrow(x))[as.numeric(rownames(x))],
                     cex=2,lwd=2)
              graphics::text(x[,i,1]/width,
                     1-x[,i,2]/height,
                     col='black',
                     cex=1,lwd=2,labels=which(incLabels),pos=2)

              for (j in 1:nrow(x)) {
                graphics::lines(x[j,1:i,1]/width,
                                1-x[j,1:i,2]/height,
                                col=grDevices::rainbow(nrow(x),
                                                 alpha=0.5)[as.numeric(rownames(x))][j],
                                lwd=4)
              }

              cat("\r \t Animation:",i,"out of",ncol(x))
              grDevices::dev.off()
           }
           system(paste0(libavpath, " -loglevel quiet -r 10 -i ",
                         path,"/images/images%04d.png -b:v 1000k ",
                         path,"/",name,".mp4"))
           unlink(paste0(path,"/images"),TRUE)
           cat('\n')
        }
     }
  } else if (inherits(x,"sbg")) {
    graphics::image(x[,,cl,frame])
  } else if (inherits(x,"particles")) {
    if(is.null(colorimages)) { colorimages <- get(attributes(x)$originalImages,
                                                  envir=.GlobalEnv) }
    graphics::plot(colorimages,frame=frame)
    inc <- x$frame == frame
    graphics::points(x[inc,]$x/ncol(colorimages),1-x[inc,]$y/nrow(colorimages),
           cex=1.2,col='green')
  } else if (inherits(x,"tfp")) {
      warning("No valid plot plot method for created training data.")
  } else if (inherits(x,"neuralnet")) {
      warning("No valid plot plot method for trained neural net.")
  }

  graphics::par(oldPar[c('mar','oma','mfrow')])
}
