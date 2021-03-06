
#' Estimates of correlation parameters and precision matrix
#'
#' @param data Data matrix  in which the first column is subject id, the second column is
#' the time points of observation.  Columns 2 to (p+2) is the observations for p variables.
#' @param type  Type of correlation function, which can take either  "abs" or "sqr".
#' @param rho Tuning parameter used in graphical lasso
#' @param tole Error tolerance for determination of convergence of EM algorithm
#' @param lower Lower bound for prediction of correlation parameter tau
#' @param upper Upper bound for prediction of correlation parameter tau
#' @author Jie Zhou
#' @importFrom glasso glasso
#' @return S list with three components which are the final estimate of alpha, tau and precision matrix omega
heterlongraph=function(data,rho, type,tole, lower,upper){
  alpha0=1
  omega0=diag(ncol(data)-2)
  subject=data[,1]
  subjectid=unique(subject)
  m=length(subjectid)
  p=ncol(data)-2
  tau_em=matrix(1/alpha0,nrow = 1,ncol = m)
  is=vector("list",m)
  tau1=rep(0,m)
  k=1
  while(1){
    print(paste("Iteration ",k,":", " Mean value of tau's","=", mean(tau1),sep=""))
    for (i in 1:m) {
      idata=data[which(data[,1]==subjectid[i]),]
      if (nrow(idata)==1){
        tau1[i]=NA
        is[[i]]=iss(idata = idata,itau = 1,type = type)
        }else{
      x=seq(lower,upper,length=50)
      z=sapply(x, logdensity,idata=idata,omega=omega0,alpha=alpha0,type=type)
      tau1[i]=x[min(which(z==min(z)))]
      is[[i]]=iss(idata = idata,itau = tau1[i],type = type)
        }
    }
    tau_em=rbind(tau_em,tau1)
    s=Reduce("+",is)/nrow(data)
    omega1=glasso(s=s,rho = rho)$wi
    alpha1=1/mean(tau1,na.rm=T)
    if (max(abs(tau_em[nrow(tau_em),]-tau_em[nrow(tau_em)-1,]),na.rm = T)<tole){
      break
    }else{
      alpha0=alpha1
      tau0=tau1
      omega0=omega1
      k=k+1
    }

  }

  result=list(alpha=alpha1,tau=tau1,omega=omega1)
  return(result)
}






#' Maximum likelihood estimate of correlation parameter for given structure of precision matrix
#' @param data Data matrix  in which the first column is subject id, the second column is
#' the time points of observation.  Columns 2 to (p+2) is the observations for p variables.
#' @param alpha0 Initial value for the parameter in exponential distribution
#' @param omega Fixed value for precision matrix
#' @param type Type of correlation function, which can take either  "abs" or "qua".
#' @param tole  Error tolerance for determination of convergence of EM algorithm
#' @param lower Lower bound for prediction of correlation parameter tau
#' @param upper Upper bound for prediction of correlation parameter tau
#' @author Jie Zhou
#' @importFrom glasso glasso

mle_alpha=function(data,alpha0,omega, type, tole, lower,upper){
  subject=data[,1]
  subjectid=unique(subject)
  m=length(subjectid)
  p=ncol(data)-2
  tau_em=matrix(1/alpha0,nrow = 1,ncol = m)
  is=vector("list",m)
  tau1=rep(0,m)

  while(1){
    for (i in 1:m) {
      idata=data[which(data[,1]==subjectid[i]),]
      x=seq(lower,upper,length=50)
      z=sapply(x, logdensity,idata=idata,omega=omega,alpha=alpha0,type=type)
      tau1[i]=x[min(which(z==min(z)))]
      is[[i]]=iss(idata = idata,itau = tau1[i],type = type)
    }

    tau_em=rbind(tau_em,tau1)
    s=Reduce("+",is)/nrow(data)
    alpha1=1/mean(tau1)
    if (max(abs(tau_em[nrow(tau_em),]-tau_em[nrow(tau_em)-1,]))<tole){
      break
    }else{
      alpha0=alpha1
      tau0=tau1
    }

  }

  result=list(alpha=alpha1,tau=tau1)
  return(result)
}



#' Complete likelihood function used in EM algorithm of heterogeneous marginal graphical lasso model
#'
#' @param idata Data matrix for the subject i in which the first column is id for subject, the second column is
#' the time points of observation.  Columns 2 to (p+2) is the observations for p variables.
#' @param omega Precision matrix
#' @param tau Correlation parameter
#' @param alpha Parameter in exponential distribution
#' @param type Type of correlation function, which can take either  "abs" or "qua".
#' @author Jie Zhou
#' @return Value of complete likelihood function at given value of omega, tau and alpha
logdensity=function(idata,omega,tau,alpha,type){
  t=idata[,2]
  yy=as.matrix(idata[,-c(1,2)])
  y=c(t(scale(yy, scale = F)))
  p=nrow(omega)
  n=length(t)
  if (n*p!=length(y)){
    stop("the dimensions do not match")
  }

  phi=phifunction(t=t,tau = tau,type = type)
  a1=(-p/2)*log(det(phi))
  a2=-t(y)%*%kronecker(solve(phi),omega)%*%y/2
  a3=-alpha*tau
  a=-(a1+a2+a3)
  return(a)
}



