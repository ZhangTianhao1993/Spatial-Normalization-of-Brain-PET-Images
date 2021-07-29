function diffL = computeDiffL(pwImg,psTPM,i,j)
% 给定两个合并的索引，计算指标变化的大小,新的减去旧的
% 存在的问题是计算过慢
newTPM = psTPM;
newTPM(:,i) = psTPM(:,i)+psTPM(:,j);
newTPM(:,j) = [];
diffL = computeLogLikelihood(pwImg,newTPM)-computeLogLikelihood(pwImg,psTPM);