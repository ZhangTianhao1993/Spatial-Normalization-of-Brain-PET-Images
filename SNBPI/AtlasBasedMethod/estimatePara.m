function [muList,sigmaList] = estimatePara(pwImg,psTPM)
% 估计模型参数
[~,TPMnum] = size(psTPM);
muList = zeros(TPMnum,1);
sigmaList = zeros(TPMnum,1);
for i=1:TPMnum
    TPMi = psTPM(:,i);
    t = pwImg.*TPMi;
    muList(i) = mean(t(:))/mean(TPMi); %加权平均
    sigmaList(i) =std(pwImg(:),TPMi);%加权方差
end

% [~,TPMnum] = size(psTPM);
% meanTPM = mean(psTPM);
% muList = mean(pwImg.*psTPM)./meanTPM;
% pwImg = repmat(pwImg,1,TPMnum);
% sigmaList = (mean((pwImg-muList).^2.*psTPM)./meanTPM).^0.5;