function [logL,Pmap] = computeLogLikelihood(pwImg,psTPM)
% 计算数据和模型的对数似然值
% 认为数据符合 Y = normpdf(X,mu,sigma)
[n,TPMnum] = size(psTPM);
% 估计高斯模型的参数
[muList,sigmaList] = estimatePara(pwImg,psTPM);
Pmap = zeros(n,1); %每一个点出现的概率密度图
for i=1:TPMnum
    Pmap = Pmap + normpdf(pwImg,muList(i),sigmaList(i)).*psTPM(:,i);
end
Pmap(Pmap == 0) = 1; %不考虑没有定义的点
t = log(Pmap);
logL = sum(t(:));
end
    