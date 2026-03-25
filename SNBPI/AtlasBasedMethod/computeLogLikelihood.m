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
% for i=1:TPMnum
%     Pmap = Pmap + normpdf(pwImg,muList(i),sigmaList(i)).*psTPM(:,i);
% end
%下面的代码是将上面的for循环进行了向量化
mu_row    = muList';    % 1×TPMnum
sigma_row = sigmaList'; % 1×TPMnum
pdfMat = exp(-0.5 * ((pwImg - mu_row) ./ sigma_row).^2) ...
         ./ (sigma_row * sqrt(2*pi));    % n×TPMnum（广播）
Pmap = sum(pdfMat .* full(psTPM), 2);   % psTPM 是 sparse，需 full()

Pmap(Pmap == 0) = 1; 
t = log(Pmap);
logL = sum(t(:));
end
    