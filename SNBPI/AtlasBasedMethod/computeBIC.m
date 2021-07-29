function BIC = computeBIC(pwImg,psTPM,regulartermk)
% Calculate the Bayesian information criterion of the image under the 
% corresponding TPM
% Input:
% pwImg - preprocessed and spatial normalized image
% psTPM - preprocessed and shrunken TPM images
% Output:
% BIC   - Bayesian information criterion
% Author: Zhang Tianhao, 2021/7/29
% =========================================================================
[n,TPMnum] = size(psTPM);
logL = computeLogLikelihood(pwImg,psTPM);
BIC = regulartermk*TPMnum*log(n)-logL;
end