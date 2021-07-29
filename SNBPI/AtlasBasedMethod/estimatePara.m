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