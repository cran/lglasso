#' Construct the temporal component fo correlation function
#'
#' @param t Time points of observations
#' @param tau correlation parameter
#' @param type The type of correlation function, which typically take either 0,1 or 2.
#' @author Jie Zhou
#' @return A square matrix with dimension equal to the length of vector t
phifunction=function(t,tau,type=1){
  n=length(t)
  if (n==1){
    M=as.matrix(1)
  }else{
  M=matrix(nrow = n, ncol = n)
    for (i in 1:n) {
      for (j in i:n){
        M[i,j]=exp(-tau*(abs(t[i]-t[j]))^type)
        M[j,i]=M[i,j]
      }
    }
  diag(M)=1
  }
  return(M)
}


#' Quasi covariance matrix for subject i
#' @param idata Data matrix for the subject i in which the first column is subject (cluster) id, the second column stands for
#' the time points () of observation.  Columns 2 to (p+2) is the observations for p variables respectively.
#' @param itau Correlation parameter
#' @param type  Type of correlation function, which typically take either  0, 1 or 2.
#' @author Jie Zhou
#' @return Empirical quasi covariance matrix
iss=function(idata,itau,type){
  t=idata[,2]
  p=ncol(idata)-2
  inversephi= solve(phifunction(t=t,tau = itau,type = type))
  si=matrix(0,nrow = p,ncol = p)
  yy=as.matrix(idata[,-c(1,2)])
  yy=scale(yy, scale = F)
  for (j in 1:length(t)) {
    for (k in 1:length(t)) {
      si=si+inversephi[j,k]*(yy[j,])%*%t(yy[k,])

    }
  }
  return(si)
}



##For a given network matrix, compute
##MLE of precision matrix
#' Title
#'
#' @param data A Longitudinal data set
#'
#'
#' @param priori Given structure of precision matrix
#' @author Jie Zhou
#' @return The maximum likelihood estimation

mle_net=function(data,priori){
  priori=priori+t(priori)
  priori=ifelse(priori==0,0,1)
  diag(priori)=0
  p=dim(data)[2]
  n=dim(data)[1]
  precision=matrix(0,nrow = p,ncol = p)
  ##for the first row
  for (j in 1:p) {
    if (sum(priori[j,])>=nrow(data)) {
      stop("The number of unknown parameters exceeds the sample size!")
    }
    data=scale(data,scale = F)
    y=data[,j]
    index=which(priori[j,]==1)
    if (length(index)==0) {
      precision[j,]=0
      precision[j,j]=1/stats::var(y)
    }else{
      x=data[,index]
      result=stats::lm(y~0+x)
      alpha=result$coefficients
      sigma=t(result$residuals)%*%(result$residuals)/result$df.residual
      precision[j,index]=-alpha/sigma[1]
      precision[j,j]=1/sigma
    }
    precision=(precision+t(precision))/2
  }
  return(precision)
}




#' @title Graphical Lasso for Longitudinal Data
#' @description This function implements the L_1 penalized maximum likelihood estimation for precision matrix (network)  based on correlated data, e.g., irregularly spaced longitudinal
#'  data. It can be regarded as an extension of the package \code{glasso} (Friedman,Hastie and Tibshirani, 2008) which aims
#'  to find the sparse estimate of the network from independent continuous data.
#' @param data Data matrix  in which the first column is subject id, the second column is
#'  time points of observations for temporal data or site id for spatial data.  Columns \code{3} to \code{(p+2)} is the observations for \code{p} variables.
#' @param rho Tuning parameter used in \code{L_1} penalty
#' @param heter Binary variable \code{TRUE} or \code{FALSE}, indicating heterogeneous model or homogeneous model is fitted. In heterogeneous model,
#' subjects are allowed to have his/her own temporal correlation parameter \code{tau_i}; while in homogeneous model, all the subjects are assumed to
#'  share the same temporal correlation parameter,i.e., \code{tau_1=tau_2=...tau_m}.
#' @param type A positive number which specify the correlation function. The general form of correlation function  is given by \code{ exp(tau|t_i-t_j|^type)}.
#' in which \code{type=0} can be used for spatial correlation while \code{type>0} are used for temporal correlation. For latter, the default value is set to be \code{type=1}.
#' @param tole Threshold for convergence. Default value is \code{1e-2}. Iterations stop when maximum
#' absolute difference between consecutive estimates of parameter change is less than \code{tole}.
#' @param lower  Lower bound for predicts of correlation parameter \code{tau}.
#' Default value is \code{1e-2}. The estimate of \code{tau}(\code{alpha}) will be searched in the
#' interval \code{[lower,upper]}, where parameter \code{upper} is explained in the following.
#' @param upper Upper bound for predicts of correlation parameter \code{tau}.
#' @author Jie Zhou
#' @references  Jie Zhou, Jiang Gui, Weston D.Viles, Anne G.Hoen Identifying Microbial Interaction Networks Based on Irregularly Spaced Longitudinal 16S rRNA sequence data. bioRxiv 2021.11.26.470159; doi: https://doi.org/10.1101/2021.11.26.470159
#' @references Friedman J, Tibshirani TH and R. Glasso: Graphical Lasso: Estimation of Gaussian Graphical Models.; 2019. Accessed November 28, 2021. https://CRAN.R-project.org/package=glasso
#' @references Friedman J, Hastie T, Tibshirani TH, Sparse inverse covariance estimation with the graphical lasso, Biostatistics, Volume 9, Issue 3, July 2008, Pages 432–441, https://doi.org/10.1093/biostatistics/kxm045
#' @return  If \code{heter=TRUE}, then a list with three components is returned which are  respectively
#' the estimate of parameter \code{alpha} in exponent distribution, correlation parameter \code{tau} and precision matrix \code{omega}. If \code{heter=FALSE},
#' then a list with two components is returned which are respectively the estimate of correlation parameter \code{tau} and precision matrix \code{omega}.
#' @export
#' @examples
#' sample_data[1:5,1:5]
#' dim(sample_data)
#' ## Heterogeneous model with dampening correlation rate using the first three clusters
#' a=lglasso(data = sample_data[1:11,], rho = 0.7,heter=TRUE, type=1)
#' ### Estimates of correlation parameters
#' a$tau
#' ### Sub-network for the first five variables
#' a$omega[1:5,1:5]
#' ### Total number of the edges in the estimated network
#' (length(which(a$omega!=0))-ncol(a$omega))/2
#' ## Homogeneous model with dampening correlation rate using the first three clusters
#' b=lglasso(data = sample_data[1:11,], rho = 0.7,heter=FALSE,type=1)
#' ### Estimates of correlation parameters
#' b$tau
#' ### Sub-network for the first five  variables
#' b$omega[1:5,1:5]
#' ### Total number of the edges in the estimated network
#' (length(which(b$omega!=0))-ncol(b$omega))/2
#' ## Heterogeneous model with uniform correlation rate using the first three clusters
#' c=lglasso(data = sample_data[1:11,], rho = 0.7,heter=TRUE,type=0)
#' ### Estimates of correlation parameters
#' c$tau
#' ### Sub-network for the first five  variables
#' c$omega[1:5,1:5]
#' ### Total number of the edges in the estimated network
#' (length(which(c$omega!=0))-ncol(c$omega))/2
#' ## Homogeneous model with uniform correlation rate using the first three clusters
#' d=lglasso(data = sample_data[1:11,], rho = 0.7,heter=FALSE,type=0)
#' ### Estimates of correlation parameters
#' d$tau
#' ### Sub-network for the first five  variables
#' d$omega[1:5,1:5]
#' ### Total number of the edges in the estimated network
#' (length(which(d$omega!=0))-ncol(d$omega))/2


lglasso=function(data, rho,heter=TRUE,type=1, tole=0.01,lower=0.01,upper=10){
  if (heter==TRUE){
    aa=heterlongraph(data=data,rho=rho,type=type,tole=tole,lower=lower,upper=upper)
  }else{
    if (heter==FALSE){
    aa=homolongraph(data=data,rho=rho,type=type,tole=tole,lower=lower,upper=upper)
    }else{
      stop("Parameter heter only accept TRUE or FALSE!")
    }
  }
return(aa)
}




#' Maximum Likelihood Estimate of Precision Matrix and Correlation Parameters for Given Network
#' @param data Data matrix  in which the first column is subject id, the second column is
#'  time points of observations for temporal data or site id for spatial data.
#'   Columns \code{3} to \code{(p+2)} is the observations for \code{p} variables.
#' @param network The network selected by function lglasso
#' @param heter Binary variable \code{TRUE} or \code{FALSE}, indicating heterogeneous model or homogeneous model is fitted. In heterogeneous model,
#' subjects are allowed to have his/her own temporal correlation parameter \code{tau_i}; while in homogeneous model, all the subjects are assumed to
#'  share the same temporal correlation parameter,i.e., \code{tau_1=tau_2=...tau_m}.
#' @param type  A positive number which specify the correlation function. The general form of correlation function  is given by \code{ exp(tau|t_i-t_j|^type)}.
#' in which \code{type=0} can be used for spatial correlation while \code{type>0} are used for temporal correlation. For latter, the default value is set to be \code{type=1}.
#' @param tole Threshold for convergence. Default value is \code{1e-2}. Iterations stop when maximum
#' absolute difference between consecutive estimates of parameter change is less than \code{tole}.
#' @param lower Lower bound for predicts of correlation parameter \code{tau}.
#' Default value is \code{1e-2}. The estimate of \code{tau}(\code{alpha}) will be searched in the
#' interval \code{[lower,upper]}, where parameter \code{upper} is explained in the following.
#' @param upper Upper bound for predicts of correlation parameter \code{tau}.
#'
#' @return A list which include the maximum likelihood estimate of precision matrix, correlation parameter \code{tau}. If \code{heter=TRUE},
#' the output also include the estimate of alpha where \code{tau~exp(alpha)}
#' @author Jie Zhou
#' @export
mle=function(data,network,heter=TRUE,type=1,tole=0.01,lower=0.01,upper=10){
  mlenetwork=mle_net(data = data[,-c(1,2)],priori = network)
  if (heter==TRUE){
mle=mle_alpha(data=data,alpha0=1,omega=mlenetwork, type=type, tole=tole, lower=lower,upper=upper)
  }else{
  mle=mle_tau(data=data, omega=mlenetwork, type=type,lower=lower,upper=upper)
  }
  if (heter==TRUE){
    result=list(network=mlenetwork,alpha=mle$alpha,tau=mle$tau)
  }
  if (heter==FALSE){
    result=list(network=mlenetwork,tau=mle)
  }
return(result)
}

