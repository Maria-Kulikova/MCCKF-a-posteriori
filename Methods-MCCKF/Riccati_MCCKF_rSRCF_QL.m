% ------------------------------------------------------------------- 
% Robust Square-root Covariance Maximum Correntropy Criterion Kalman Filter (MCC-KF)
%      Type: Covariance filtering
%    Method: Cholesky-based implementation with lower triangular factors
%      From: Two stages, a posteriori form
% Recursion: Riccati-type underlying recursion
%   Authors: Maria Kulikova 
% ------------------------------------------------------------------- 
% References:
% 1. This is the implementation of Algorithm 1b from the following paper: 
%    Kulikova M.V. (2020) 
%    On the stable Cholesky factorization-based method for the maximum 
%    correntropy criterion Kalman filtering, IFAC-PapersOnLine,
%    53(2): 482-487. DOI: https://doi.org/10.1016/j.ifacol.2020.12.264
% ------------------------------------------------------------------- 
% Input:
%     matrices        - system matrices F,G etc
%     initials_filter - initials x0,P0
%     measurements    - measurement history
% Output:
%     PI          - performance index (Baram Proximity Measure here)
%     hatX        - estimates (history) 
%     hatDP       - diag of the filtered error covariance (history)
% ------------------------------------------------------------------- 
function [PI,hatX,hatDP] = Riccati_MCCKF_rSRCF_QL(matrices,initials_filter,measurements,handle_kernel)
   [F,G,Q,H,R] = deal(matrices{:});         % get system matrices
         [X,P] = deal(initials_filter{:});  % initials for the filter 
          
        [m,n]  = size(H);                % dimensions
       N_total = size(measurements,2);   % number of measurements
          hatX = zeros(n,N_total+1);     % prelocate for efficiency
         hatDP = zeros(n,N_total+1);     % prelocate for efficiency
            PI = 0;                      % set initial value for the PI

        if isequal(diag(diag(Q)),Q), Q_sqrt = diag(sqrt(diag(Q))); else  Q_sqrt = chol(Q,'lower'); end; clear Q; 
        if isequal(diag(diag(R)),R), R_sqrt = diag(sqrt(diag(R))); else  R_sqrt = chol(R,'lower'); end; 
        if isequal(diag(diag(P)),P), P_sqrt = diag(sqrt(diag(P))); else  P_sqrt = chol(P,'lower'); end;   

 hatX(:,1) = X; hatDP(:,1) = diag(P); % save initials at the first entry
 for k = 1:N_total                  
   [X,P_sqrt] = srcf_predict(X,P_sqrt,F,G,Q_sqrt);  
      lambda_k = feval(handle_kernel,matrices,X,P,measurements(:,k));
   if (size(lambda_k,1)>1)||(size(lambda_k,2)>1), error('The MCC-KF estimator implies a scalar adjusting parameter'); end;
   if lambda_k<0, error('The square-root MCC-KF implementations imply a non-negative adjusting parameter'); end;
   [X,P_sqrt,norm_ek,sqrt_Rek] = sr_mcckf_update(X,P_sqrt,measurements(:,k),H,R_sqrt,lambda_k);
      
    PI = PI + 1/2*log(det(sqrt_Rek*sqrt_Rek')) + 1/2*(norm_ek')*norm_ek; 
    hatX(:,k+1)  = X; hatDP(:,k+1) = diag(P_sqrt*P_sqrt');   % save  information
 end;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%   Time update: a priori estimates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [X,sqrtP] = srcf_predict(X,sqrtP,F,G,Q_sqrt)
     [n,~]      = size(sqrtP);
     PreArray   = [F*sqrtP, G*Q_sqrt;];
          
    [~,PostArray]  = qr(PreArray');
         PostArray = PostArray';
       sqrtP       = PostArray(1:n,1:n); % Predicted factor of P        
       X           = F*X;                % Predicted state estimate   
 end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%   Measurement update: a posteriori estimates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [X,sqrtP,norm_residual,sqrtRe] = sr_mcckf_update(X,sqrtP,z,H,R_sqrt,lambda_k)
    [m,n]     = size(H);
    PreArray  = [R_sqrt,    sqrt(lambda_k)*H*sqrtP;]; 
        
    [~,PostArray]  = qr(PreArray');
         PostArray = PostArray';
           sqrtRe  = PostArray(1:m,1:m);        % Filtered factor of R_{e,k}           
          residual = z-H*X;
     norm_residual = sqrtRe\residual;           % normalized innovations

   Gain = lambda_k*(sqrtP*sqrtP')*H'/sqrtRe'/sqrtRe;
      X = X + Gain * residual;
 
% the MCC-KF method implies Joseph stabilized formula for updating the error covariance matrix at the end

        PreArray  = [(eye(n) - Gain*H)*sqrtP, Gain*R_sqrt;];
   [~,PostArray]  = qr(PreArray');
        PostArray = PostArray';
          sqrtP   = PostArray(1:n,1:n);

end
