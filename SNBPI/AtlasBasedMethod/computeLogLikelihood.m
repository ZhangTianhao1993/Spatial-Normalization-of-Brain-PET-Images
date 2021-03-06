function [logL,Pmap] = computeLogLikelihood(pwImg,psTPM)
% Calculate the log-likelihood of the data
% Input:
% pwImg - preprocessed and spatial normalized image 
% psTPM - preprocessed and shrunken TPM images
% Output:
% logL  - log-likelihood
% Pmap  - Probability mapping
% Author: Zhang Tianhao, 2021/7/29
% =========================================================================
[n,TPMnum] = size(psTPM);
% 估计高斯模型的参数
[muList,sigmaList] = estimatePara(pwImg,psTPM);
Pmap = zeros(n,1); 
for i=1:TPMnum
    Pmap = Pmap + normpdf(pwImg,muList(i),sigmaList(i)).*psTPM(:,i);
end
Pmap(Pmap == 0) = 1; 
t = log(Pmap);
logL = sum(t(:));
end
    