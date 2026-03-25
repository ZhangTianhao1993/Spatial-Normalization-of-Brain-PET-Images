function [muList,sigmaList] = estimatePara(pwImg,psTPM)
% Estimate model parameters
[~,TPMnum] = size(psTPM);
muList = zeros(TPMnum,1);
sigmaList = zeros(TPMnum,1);
for i=1:TPMnum
    TPMi = psTPM(:,i);
    t = pwImg.*TPMi;
    muList(i) = mean(t(:))/mean(TPMi); 
    sigmaList(i) =std(pwImg(:),TPMi);
end
% %下面的代码是将上面的for循环向量化
% psTPM_full = full(psTPM);                       % n×TPMnum
% w_sum   = sum(psTPM_full, 1);                   % 1×TPMnum，每列权重之和
% muList  = (pwImg' * psTPM_full) ./ w_sum;       % 1×TPMnum，加权均值（矩阵乘法）
% muList  = muList(:);
% dev2    = (pwImg - muList') .^ 2;               % n×TPMnum，广播
% sigmaList = sqrt(sum(dev2 .* psTPM_full, 1) ./ w_sum);
% sigmaList = sigmaList(:);