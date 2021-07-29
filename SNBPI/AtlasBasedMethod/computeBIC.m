function BIC = computeBIC(pwImg,psTPM,regulartermk)
% 计算图像在相应TPM下的贝叶斯信息准则
% BIC = k*log(n)-2log(L)
% 其中k是模型的参数个数，n是数据点个数，也就是图像的体素个数，L是似然函数
% BIC越小越好
[n,TPMnum] = size(psTPM);
%k = 2*TPMnum;
% k = 0;
%k = 15;
logL = computeLogLikelihood(pwImg,psTPM);
BIC = regulartermk*TPMnum*log(n)-logL;
end